-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciRxDesc.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2016-08-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- PCI Receive Descriptor Controller
-- https://docs.google.com/spreadsheets/d/1K8m2aPMaHxYG6Ul3f4jVZ44NlyKDHtr_bLjtMZGRRxw/edit?usp=sharing
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.PciPkg.all;

entity PciRxDesc is
   generic (
      DMA_SIZE_G : positive);
   port (
      -- Parallel Interface 
      dmaDescToPci   : in  DescToPciArray(0 to (DMA_SIZE_G-1));
      dmaDescFromPci : out DescFromPciArray(0 to (DMA_SIZE_G-1));
      -- Register Interface
      regCs          : in  sl;
      regAddr        : in  slv(9 downto 2);
      regWrEn        : in  sl;
      regWrData      : in  slv(31 downto 0);
      regRdEn        : in  sl;
      regRdData      : out slv(31 downto 0);
      -- IRQ Request
      irqReq         : out sl;
      -- Counter reset
      countReset     : in  sl;
      --Global Signals
      pciClk         : in  sl;
      pciRst         : in  sl);   
end PciRxDesc;

architecture rtl of PciRxDesc is

   --Free List Record
   type dFifoType is record
      Wr    : sl;
      Rd    : sl;
      Dout  : slv(31 downto 2);
      Full  : sl;
      Empty : sl;
      Cnt   : slv(8 downto 0);
      Valid : sl;
   end record;

   type dFifoVector is array (integer range<>) of dFifoType;
   type newAddrVector is array (integer range<>) of slv(31 downto 2);

   -- Free descriptor write
   signal maxFrame    : slv(23 downto 0);
   signal dFifoDin    : slv(31 downto 2);
   signal dFifo       : dFifoVector(0 to (DMA_SIZE_G-1));
   signal rxFreeEn    : sl;
   signal fifoRst     : sl;
   signal lastDesc    : slv(31 downto 2);
   signal lastDescErr : sl;

   -- New Descriptor allocation
   signal newAck  : slv(0 to (DMA_SIZE_G-1));
   signal newReq  : slv(0 to (DMA_SIZE_G-1));
   signal newAddr : newAddrVector(0 to (DMA_SIZE_G-1));

   -- Receive descriptor done
   signal doneCnt    : integer range 0 to (DMA_SIZE_G-1) := 0;
   signal rFifoDin   : slv(67 downto 0);
   signal rFifoWr    : sl;
   signal rFifoRd    : sl;
   signal rFifoFull  : sl;
   signal rFifoAFull : sl;
   signal rFifoDout  : slv(67 downto 0);
   signal rFifoCnt   : slv(8 downto 0);
   signal rFifoValid : sl;
   signal doneAck    : slv(0 to (DMA_SIZE_G-1));
   signal rxCount    : slv(31 downto 0)                  := (others => '0');
   signal descData   : slv(31 downto 0)                  := (others => '0');
   signal interrupt  : sl;
   signal reqIrq     : sl;
   signal contEn     : sl;
   
begin

   -----------------------------
   -- IRQ Control
   -----------------------------
   -- Assert IRQ request when there is a entry in the receive queue
   irqReq <= rFifoValid;

   -----------------------------
   -- Free Descriptor Logic
   -----------------------------
   -- Free descriptor write
   process (pciClk)
      variable i : integer;
   begin
      if rising_edge(pciClk) then
         for i in 0 to (DMA_SIZE_G-1) loop
            dFifo(i).Wr <= '0';
         end loop;
         if pciRst = '1' then
            dFifoDin    <= (others => '0');
            maxFrame    <= (others => '0');
            rxFreeEn    <= '0';
            contEn      <= '0';
            lastDesc    <= (others => '0');
            lastDescErr <= '0';
         else
            -- Free Descriptor Write
            if regWrEn = '1' and regCs = '1' then
               for i in 0 to (DMA_SIZE_G-1) loop
                  if regAddr = i then
                     lastDesc              <= regWrData(31 downto 2);
                     dFifoDin(31 downto 2) <= regWrData(31 downto 2);
                     dFifo(i).Wr           <= '1';
                     if regWrData(31 downto 2) = lastDesc then
                        lastDescErr <= '1';
                     end if;
                  end if;
               end loop;
               -- Max frame length write
               if regAddr = 64 then
                  rxFreeEn <= regWrData(31);
                  contEn   <= regWrData(30);
                  maxFrame <= regWrData(23 downto 0);
               end if;
            end if;
         end if;
      end if;
   end process;

   -- FIFO reset
   fifoRst <= pciRst or (not rxFreeEn);

   Gen_Free_List_Fifo :
   for i in 0 to (DMA_SIZE_G-1) generate
      -- FIFO for free descriptors
      -- 31:2  = Address
      U_DescFifo : entity work.FifoSync
         generic map(
            BRAM_EN_G    => true,
            FWFT_EN_G    => true,
            DATA_WIDTH_G => 30,
            ADDR_WIDTH_G => 9)   
         port map (
            rst        => fifoRst,
            clk        => pciClk,
            din        => dFifoDin(31 downto 2),
            wr_en      => dFifo(i).Wr,
            rd_en      => dFifo(i).Rd,
            dout       => dFifo(i).Dout(31 downto 2),
            full       => dFifo(i).Full,
            valid      => dFifo(i).valid,
            data_count => dFifo(i).Cnt);           

      -- New Descriptor allocation
      process (pciClk)
      begin
         if rising_edge(pciClk) then
            dFifo(i).Rd <= '0';
            newAck(i)   <= '0';
            if pciRst = '1' then
               newAddr(i) <= (others => '0');
            else
               -- Ack is not asserted and not reading FIFO
               if (newAck(i) = '0') and (dFifo(i).Rd = '0') then
                  -- Register address
                  newAddr(i) <= dFifo(i).Dout(31 downto 2);
                  -- Look for a new request and valid data to send
                  if (newReq(i) = '1') and (dFifo(i).Valid = '1') then
                     dFifo(i).Rd <= '1';
                     newAck(i)   <= '1';
                  end if;
               end if;
            end if;
         end if;
      end process;

      -- New Req
      newReq(i) <= dmaDescToPci(i).newReq;

      -- New Ack
      dmaDescFromPci(i).newAck <= newAck(i);

      -- Address
      dmaDescFromPci(i).newAddr <= newAddr(i);

      -- Max Frame
      dmaDescFromPci(i).maxFrame <= maxFrame;

      -- Continue enable
      dmaDescFromPci(i).contEn <= contEn;

      -- Unused fields
      dmaDescFromPci(i).newLength  <= (others => '0');
      dmaDescFromPci(i).newControl <= (others => '0');

      -- Done Ack
      dmaDescFromPci(i).doneAck <= doneAck(i);
      
   end generate Gen_Free_List_Fifo;

   -----------------------------
   -- Done Descriptor Logic
   -----------------------------
   -- Receive descriptor done
   process (pciClk)
   begin
      if rising_edge(pciClk) then
         rFifoWr <= '0';
         doneAck <= (others => '0');
         if pciRst = '1' then
            doneCnt  <= 0;
            rxCount  <= (others => '0');
            rFifoDin <= (others => '0');
         else
            --reset RX counter
            if countReset = '1' then
               rxCount <= (others => '0');
            elsif rFifoAFull = '0' then
               -- poll the doneReq
               if (dmaDescToPci(doneCnt).doneReq = '1') and (doneAck(doneCnt) = '0') then
                  doneAck(doneCnt) <= '1';
                  rxCount          <= rxCount + 1;
                  rFifoWr          <= '1';

                  rFifoDin(67 downto 56) <= dmaDescToPci(doneCnt).doneStatus;
                  rFifoDin(55 downto 32) <= dmaDescToPci(doneCnt).doneLength;
                  rFifoDin(31 downto 2)  <= dmaDescToPci(doneCnt).doneAddr;
               end if;
               --increment DMA channel pointer counter
               if doneCnt = (DMA_SIZE_G-1) then  --prevent roll over
                  doneCnt <= 0;
               else
                  doneCnt <= doneCnt + 1;
               end if;
            end if;
         end if;
      end if;
   end process;

   -- FIFO for done descriptors
   -- 67:56 = Status
   -- 55:32 = Length, 1 based
   -- 31:0  = Address
   U_RxFifo : entity work.FifoSync
      generic map(
         BRAM_EN_G    => true,
         FWFT_EN_G    => true,
         DATA_WIDTH_G => 68,
         ADDR_WIDTH_G => 9)    
      port map (
         rst         => fifoRst,
         clk         => pciClk,
         din         => rFifoDin,
         wr_en       => rFifoWr,
         rd_en       => rFifoRd,
         dout        => rFifoDout,
         almost_full => rFifoAFull,
         full        => rFifoFull,
         valid       => rFifoValid,
         data_count  => rFifoCnt);

   -- Register Read
   process (pciClk)
      variable i : integer;
   begin
      if rising_edge(pciClk) then
         rFifoRd   <= '0';
         interrupt <= '0';
         if pciRst = '1' then
            reqIrq    <= '0';
            regRdData <= (others => '0');
            descData  <= (others => '0');
         else
            --generate interrupt
            if rxFreeEn = '0' then
               reqIrq <= '0';
            elsif (reqIrq = '0') and (rFifoValid = '1') and (rFifoRd = '0') then
               reqIrq    <= '1';
               interrupt <= '1';
            end if;
            -- Register Read
            if regRdEn = '1' and regCs = '1' then
               regRdData <= (others => '0');
               for i in 0 to (DMA_SIZE_G-1) loop
                  -- Free Descriptor status
                  if regAddr = (i+32) then
                     regRdData(31)         <= dFifo(i).Full;
                     regRdData(30)         <= dFifo(i).Valid;
                     regRdData(8 downto 0) <= dFifo(i).Cnt;
                  end if;
               end loop;
               -- Read back the rxFreeEn and maxFrame
               if regAddr = 64 then
                  regRdData(31)          <= rxFreeEn;
                  regRdData(23 downto 0) <= maxFrame;
               end if;
               -- Counter read
               if regAddr = 65 then
                  regRdData <= rxCount;
               end if;
               -- Status read
               if regAddr = 66 then
                  regRdData(31)         <= rFifoValid;
                  regRdData(30)         <= rFifoFull;
                  regRdData(29)         <= lastDescErr;
                  regRdData(28)         <= '0';            -- spare
                  regRdData(27)         <= rFifoDout(63);  -- frameErr
                  regRdData(26)         <= rFifoDout(62);  -- EOFE
                  regRdData(8 downto 0) <= rFifoCnt;
               end if;
               -- FIFO Read, low value
               if (regAddr = 67) or (regAddr = 69) then
                  if rFifoValid = '1' then
                     regRdData             <= rFifoDout(63 downto 32);
                     descData(31 downto 2) <= rFifoDout(31 downto 2);
                     descData(1)           <= '0';
                     descData(0)           <= '1';
                  else
                     regRdData <= (others => '0');
                     descData  <= (others => '0');
                  end if;
               end if;
               -- FIFO Read
               if (regAddr = 68) or (regAddr = 70) then
                  regRdData <= descData;
                  -- Check if we need to reset the flag
                  if descData(0) = '1' then
                     descData(0) <= '0';
                     reqIrq      <= '0';
                     rFifoRd     <= '1';
                  end if;
               end if;
            end if;
         end if;
      end if;
   end process;
end rtl;
