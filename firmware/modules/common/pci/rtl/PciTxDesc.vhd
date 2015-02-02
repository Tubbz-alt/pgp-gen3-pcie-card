-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTxDesc.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2014-07-31
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- PCI Transmit Descriptor Controller
-- TX Descriptor contains length then address.
--
-----------------------------
-- Write Registers:
-----------------------------
--
-- for(i=0;i<DMA_SIZE_G;i++)
-- {
--    Addr i      : Bits[31:27] = DMA_TX[i].DMA_CH
--                : Bits[26:24] = DMA_TX[i].SUB_ID 
--                : Bits[23:00] = DMA_TX[i].newLength   
-- }
--
-- for(i=0;i<DMA_SIZE_G;i++)
-- {
--    Addr (i+32) : Bits[31:02] = DMA_TX[i].newAddr
--                : Bits[01:00] = Unused   
-- }
--
-----------------------------
-- Read Registers:
-----------------------------
--
-- for(i=0;i<DMA_SIZE_G;i++)
-- {
--    Addr 64 : Bits[i]    = Desc_Fifo(i).AFull
-- }
--
-- Addr 65  : Bits[31]    = Done_Fifo.Valid
--          : Bits[29:09] = zeros
--          : Bits[08:00] = Done_Fifo(i).Fill_Count
--
-- Addr 66  : Bits[31:00] = Tx Counter
--
-- Addr 67  : Bits[31:02] = Done Entry Address
--          : Bits[01]    = zero
--          : Bits[00]    = Done_Fifo.Valid
--
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.PciPkg.all;

entity PciTxDesc is
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
end PciTxDesc;

architecture rtl of PciTxDesc is
   -- Transmit descriptor write
   signal tFifoDin : std_logic_vector(63 downto 0);
   signal tFifoWr  : std_logic_vector(0 to (DMA_SIZE_G-1));

   -- Done Descriptor Logic
   signal doneCnt      : std_logic_vector(4 downto 0) := (others=>'0');
   signal doneAck      : std_logic_vector(0 to (DMA_SIZE_G-1));
   signal txCount      : std_logic_vector(31 downto 0);
   signal dmaDescAFull : std_logic_vector(0 to (DMA_SIZE_G-1));
   signal dFifoDin     : std_logic_vector(31 downto 0);
   signal dFifoWr      : std_logic;
   signal dFifoRd      : std_logic;
   signal dFifoAFull   : std_logic;
   signal dFifoDout    : std_logic_vector(31 downto 0);
   signal dFifoCnt     : std_logic_vector(8 downto 0);
   signal dFifoValid   : std_logic;
   signal interrupt    : sl;
   signal reqIrq       : sl;

begin
   -----------------------------
   -- IRQ Control
   -----------------------------
   -- Assert IRQ when transmit desc is ready
   irqReq <= dFifoValid;

   -----------------------------
   -- Transmit descriptor write
   -----------------------------
   process (pciClk)
      variable i : natural;
   begin
      if rising_edge(pciClk) then
         tFifoWr <= (others => '0');
         if pciRst = '1' then
            tFifoDin <= (others => '0');
         else
            -- Transmit Descriptor Write
            if regWrEn = '1' and regCs = '1' then
               for i in 0 to (DMA_SIZE_G-1) loop
                  -- Low Address
                  if regAddr = (i+0) then
                     tFifoDin(63 downto 32) <= (others => '0');
                     tFifoDin(31 downto 0)  <= regWrData;
                  end if;
                  -- High Address
                  if regAddr = (i+32) then
                     tFifoDin(63 downto 32) <= regWrData;
                     tFifoWr(i)             <= '1';
                  end if;
               end loop;
            end if;
         end if;
      end if;
   end process;

   GEN_PciTxDescFifo :
   for i in 0 to (DMA_SIZE_G-1) generate
      PciTxDescFifo_Inst : entity work.PciTxDescFifo
         port map (
            pciClk     => pciClk,
            pciRst     => pciRst,
            tFifoWr    => tFifoWr(i),
            tFifoDin   => tFifoDin,
            tFifoAFull => dmaDescAFull(i),
            newReq     => dmaDescToPci(i).newReq,
            newAck     => dmaDescFromPci(i).newAck,
            newAddr    => dmaDescFromPci(i).newAddr,
            newLength  => dmaDescFromPci(i).newLength,
            newControl => dmaDescFromPci(i).newControl);

      -- Done Ack
      dmaDescFromPci(i).doneAck  <= doneAck(i);
      -- Unused Fields
      dmaDescFromPci(i).maxFrame <= (others => '0');
   end generate GEN_PciTxDescFifo;

   -----------------------------
   -- Done Descriptor Logic
   -----------------------------
   -- Receive descriptor done
   process (pciClk)
   begin
      if rising_edge(pciClk) then
         dFifoWr <= '0';
         doneAck <= (others => '0');
         if pciRst = '1' then
            doneCnt  <= (others => '0');
            txCount  <= (others => '0');
            dFifoDin <= (others => '0');
         else
            -- Reset RX counter
            if countReset = '1' then
               txCount <= (others => '0');
            elsif dFifoAFull = '0' then
               -- Poll the doneReq
               if dmaDescToPci(conv_integer(doneCnt)).doneReq = '1' and (doneAck(conv_integer(doneCnt)) = '0') then
                  doneAck(conv_integer(doneCnt))      <= '1';
                  txCount               <= txCount + 1;
                  dFifoWr               <= '1';
                  dFifoDin(31 downto 0) <= dmaDescToPci(conv_integer(doneCnt)).doneAddr & "00";
               end if;
               -- Increment DMA channel pointer counter
               if doneCnt = (DMA_SIZE_G-1) then  --prevent roll over
                  doneCnt <= (others => '0');
               else
                  doneCnt <= doneCnt + 1;
               end if;
            end if;
         end if;
      end if;
   end process;

   -- FIFO for done descriptors
   -- 31:0  = Addr
   U_RxFifo : entity work.FifoSync
      generic map(
         BRAM_EN_G    => true,
         FWFT_EN_G    => true,
         DATA_WIDTH_G => 32,
         FULL_THRES_G => 500,
         ADDR_WIDTH_G => 9)    
      port map (
         rst        => pciRst,
         clk        => pciClk,
         din        => dFifoDin,
         wr_en      => dFifoWr,
         rd_en      => dFifoRd,
         dout       => dFifoDout,
         prog_full  => dFifoAFull,
         valid      => dFifoValid,
         data_count => dFifoCnt);

   -- Register Read
   process (pciClk)
   begin
      if rising_edge(pciClk) then
         dFifoRd   <= '0';
         interrupt <= '0';
         if pciRst = '1' then
            reqIrq    <= '0';
            regRdData <= (others => '0');
         else
            -- Generate interrupt
            if (reqIrq = '0') and (dFifoValid = '1') and (dFifoRd = '0') then
               reqIrq    <= '1';
               interrupt <= '1';
            end if;
            -- Register Read
            if regRdEn = '1' and regCs = '1' then
               regRdData <= (others => '0');
               -- Status read: AFull
               if regAddr = 64 then
                  regRdData((DMA_SIZE_G-1) downto 0) <= dmaDescAFull;
               end if;
               -- Status read: valid and count
               if regAddr = 65 then
                  regRdData(31)         <= dFifoValid;
                  regRdData(8 downto 0) <= dFifoCnt;
               end if;
               -- Counter read
               if regAddr = 66 then
                  regRdData <= txCount;
               end if;
               -- FIFO Read
               if regAddr = 67 then
                  -- Check if we need to read the FIFO
                  if dFifoValid = '1' then
                     regRdData(31 downto 2) <= dFifoDout(31 downto 2);
                     regRdData(1)           <= '0';
                     regRdData(0)           <= '1';
                     reqIrq                 <= '0';
                     dFifoRd                <= '1';
                  else
                     regRdData <= (others => '0');
                  end if;
               end if;
            end if;
         end if;
      end if;
   end process;
end rtl;
