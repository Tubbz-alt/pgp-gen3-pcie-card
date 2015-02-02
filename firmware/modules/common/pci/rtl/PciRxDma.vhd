-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciRxDma.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-03
-- Last update: 2014-08-18
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;

entity PciRxDma is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- 32-bit Streaming RX Interface
      sAxisClk       : in  sl;
      sAxisRst       : in  sl;
      sAxisMaster    : in  AxiStreamMasterType;
      sAxisSlave     : out AxiStreamSlaveType;
      -- 128-bit Streaming TX Interface
      pciClk         : in  sl;
      pciRst         : in  sl;
      dmaIbMaster    : out AxiStreamMasterType;
      dmaIbSlave     : in  AxiStreamSlaveType;
      dmaDescFromPci : in  DescFromPciType;
      dmaDescToPci   : out DescToPciType;
      dmaTranFromPci : in  TranFromPciType;
      dmaChannel     : in  slv(3 downto 0));
end PciRxDma;

architecture rtl of PciRxDma is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);  -- 32-bit interface

   type StateType is (
      IDLE_S,
      DATA_DUMP_S,
      ACK_WAIT_S,
      READ_TRANS_S,
      SEND_IO_REQ_HDR_S,
      COLLECT_S,
      TR_DONE_S);    

   type RegType is record
      tranRd        : sl;
      frameErr      : sl;
      tranEofe      : sl;
      tranSubId     : slv(3 downto 0);
      tranLength    : slv(9 downto 0);
      tranCnt       : slv(9 downto 0);
      cnt           : slv(9 downto 0);
      dumpCnt       : slv(9 downto 0);
      newAddr       : slv(29 downto 0);
      maxFrameCheck : Slv24Array(0 to 3);
      dmaDescToPci  : DescToPciType;
      rxSlave       : AxiStreamSlaveType;
      txMaster      : AxiStreamMasterType;
      state         : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '0',
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => (others => '0')),
      DESC_TO_PCI_INIT_C,
      AXI_STREAM_SLAVE_INIT_C,
      AXI_STREAM_MASTER_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal tranValid,
      tranEofe : sl;
   signal tranSubId : slv(3 downto 0);
   signal tranLength,
      tranCnt : slv(8 downto 0);

   signal rxMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   SsiFifo_RX : entity work.PciRxTransFifo
      generic map(
         TPD_G => TPD_G)
      port map(
         -- Streaming RX Interface
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         -- Streaming RX Interface
         pciClk      => pciClk,
         pciRst      => pciRst,
         mAxisMaster => rxMaster,
         mAxisSlave  => r.rxSlave,
         tranRd      => r.tranRd,
         tranValid   => tranValid,
         tranSubId   => tranSubId,
         tranEofe    => tranEofe,
         tranLength  => tranLength,
         tranCnt     => tranCnt);

   comb : process (dmaChannel, dmaDescFromPci, dmaTranFromPci, pciRst, r, rxMaster, tranCnt,
                   tranEofe, tranLength, tranSubId, tranValid, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.tranRd         := '0';
      v.rxSlave.tReady := '0';
      ssiResetFlags(v.txMaster);

      -- Status value
      v.dmaDescToPci.doneStatus(11 downto 8) := (others => '0');
      v.dmaDescToPci.doneStatus(7)           := r.frameErr;
      v.dmaDescToPci.doneStatus(6)           := r.tranEofe;
      v.dmaDescToPci.doneStatus(5 downto 2)  := dmaChannel;
      v.dmaDescToPci.doneStatus(1 downto 0)  := r.tranSubId(1 downto 0);

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for data in the transaction FIFO and data FIFO
            if (tranValid = '1') and (r.tranRd = '0') and (rxMaster.tValid = '1') then
               -- Check for start of frame bit
               if ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1' then
                  -- Send a request to the descriptor
                  v.dmaDescToPci.newReq := '1';
                  -- Next state
                  v.state               := ACK_WAIT_S;
               else
                  -- Configure the FIFO to dump the data
                  v.rxSlave.tReady := '1';
                  v.dumpCnt        := toSlv(1, 9);
                  -- Next state
                  v.state          := DATA_DUMP_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DATA_DUMP_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := '1';
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Increment the counter
               v.dumpCnt := r.dumpCnt + 1;
               -- Compare the dump counter and check the EOF bit
               if (r.dumpCnt = (tranCnt+1)) or (rxMaster.tLast = '1') then
                  -- Read the transaction FIFO
                  v.tranRd         := '1';
                  -- Stop Reading out the data FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when ACK_WAIT_S =>
            -- Send a request to the descriptor
            v.dmaDescToPci.newReq := '1';
            -- Wait for descriptor 
            if dmaDescFromPci.newAck = '1' then
               -- Reset request flag
               v.dmaDescToPci.newReq     := '0';
               -- Reset the error flag
               v.frameErr                := '0';
               -- Latch the descriptor values
               v.dmaDescToPci.doneAddr   := dmaDescFromPci.newAddr;
               v.newAddr(29 downto 0)    := dmaDescFromPci.newAddr;
               v.dmaDescToPci.doneLength := (others => '0');
               if dmaDescFromPci.maxFrame = 0 then
                  -- Set the error flag
                  v.frameErr := '1';
               elsif dmaDescFromPci.maxFrame = 1 then
                  -- Set the error flag
                  v.frameErr := '1';
               elsif dmaDescFromPci.maxFrame = 2 then
                  -- Set the error flag
                  v.frameErr := '1';
               elsif dmaDescFromPci.maxFrame = 3 then
                  -- Set the error flag
                  v.frameErr := '1';
               else
                  v.maxFrameCheck(0) := dmaDescFromPci.maxFrame - 1;
                  v.maxFrameCheck(1) := dmaDescFromPci.maxFrame - 2;
                  v.maxFrameCheck(2) := dmaDescFromPci.maxFrame - 3;
                  v.maxFrameCheck(3) := dmaDescFromPci.maxFrame - 4;
               end if;
               -- Next state
               v.state := READ_TRANS_S;
            end if;
         ----------------------------------------------------------------------
         when READ_TRANS_S =>
            -- Wait for FIFO data Transaction FIFO
            if tranValid = '1' then
               -- Read the FIFO
               v.tranRd         := '1';
               -- Latch the transaction length
               v.tranSubId      := tranSubId;
               v.tranEofe       := tranEofe;
               v.tranLength     := '0' & tranLength;
               v.tranCnt        := '0' & tranCnt;
               v.cnt            := (others => '0');
               -- Ready to readout the FIFO
               v.rxSlave.tReady := txSlave.tReady;
               -- Next state
               v.state          := SEND_IO_REQ_HDR_S;
            end if;
         ----------------------------------------------------------------------
         when SEND_IO_REQ_HDR_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := txSlave.tReady;
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               ------------------------------------------------------
               -- generated a TLP 3-DW data transfer with payload 
               --
               -- data(127:96) = D0  
               -- data(095:64) = H2  
               -- data(063:32) = H1
               -- data(031:00) = H0                 
               ------------------------------------------------------                                      
               --D0
               v.txMaster.tData(127 downto 96) := rxMaster.tData(31 downto 0);
               --H2
               v.txMaster.tData(95 downto 66)  := r.newAddr;
               v.txMaster.tData(65 downto 64)  := "00";                  --PCIe reserved
               --H1
               v.txMaster.tData(63 downto 48)  := dmaTranFromPci.locId;  -- Requester ID
               v.txMaster.tData(47 downto 40)  := dmaTranFromPci.tag;    -- Tag

               -- Last DW byte enable must be zero if the transaction is a single DWORD transfer
               if r.tranLength = 1 then
                  v.txMaster.tData(39 downto 36) := "0000";  -- Last DW Byte Enable
               else
                  v.txMaster.tData(39 downto 36) := "1111";  -- Last DW Byte Enable
               end if;

               v.txMaster.tData(35 downto 32) := "1111";   -- First DW Byte Enable
               --H0
               v.txMaster.tData(31)           := '0';   --PCIe reserved
               v.txMaster.tData(30 downto 29) := "10";  -- FMT = Memory write, 3-DW header with payload
               v.txMaster.tData(28 downto 24) := "00000";  -- Type = Memory read or write
               v.txMaster.tData(23)           := '0';   --PCIe reserved
               v.txMaster.tData(22 downto 20) := "000";    -- TC = 0
               v.txMaster.tData(19 downto 16) := "0000";   --PCIe reserved
               v.txMaster.tData(15)           := '0';   -- TD = 0
               v.txMaster.tData(14)           := '0';   -- EP = 0
               v.txMaster.tData(13 downto 12) := "00";  -- Attr = 0
               v.txMaster.tData(11 downto 10) := "00";  --PCIe reserved

               -- Check for frame length error
               if (r.frameErr = '1') or (r.dmaDescToPci.doneLength = r.maxFrameCheck(0)) then
                  v.txMaster.tData(9 downto 0)   := toSlv(1, 10);  -- Force a length of 1
                  v.txMaster.tData(39 downto 36) := "0000";        -- Last DW Byte Enable
               else                                                --no error detected
                  v.txMaster.tData(9 downto 0) := r.tranLength;    -- Transaction length
               end if;

               -- Write the header to FIFO
               v.txMaster.tValid := '1';

               -- Calculate the next transmit address
               v.newAddr := r.newAddr + r.tranLength;

               -- Increment the frameLength
               v.dmaDescToPci.doneLength := r.dmaDescToPci.doneLength + 1;

               -- Check for frame length error
               if r.dmaDescToPci.doneLength = r.maxFrameCheck(0) then
                  -- Set the error flag
                  v.frameErr := '1';
               end if;

               -- Set the SOF bit
               ssiSetUserSof(AXIS_PCIE_CONFIG_C, v.txMaster, '1');

               -- Set AXIS tKeep
               v.txMaster.tKeep := x"FFFF";

               -- Check for frame length error
               if (r.frameErr = '1') or (r.dmaDescToPci.doneLength = r.maxFrameCheck(0)) then
                  -- Assert the end of TLP packet flag
                  v.txMaster.tLast       := '1';  --EOF 
                  -- Ready to readout the FIFO
                  v.rxSlave.tReady       := '0';
                  -- Let the descriptor know that we are done
                  v.dmaDescToPci.doneReq := '1';
                  -- Next state
                  v.state                := TR_DONE_S;
               -- Check if this is last data read
               elsif r.tranLength = 1 then
                  -- Assert the end of TLP packet flag
                  v.txMaster.tLast := '1';        --EOF 
                  -- Ready to readout the FIFO
                  v.rxSlave.tReady := '0';
                  -- Check if this is the end of frame
                  if rxMaster.tLast = '1' then
                     -- Let the descriptor know that we are done
                     v.dmaDescToPci.doneReq := '1';
                     -- Next state
                     v.state                := TR_DONE_S;
                  else
                     -- Next state
                     v.state := READ_TRANS_S;
                  end if;
               else
                  -- Next state
                  v.state := COLLECT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when COLLECT_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := txSlave.tReady;
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Write to FIFO
               v.txMaster.tValid := '1';
               v.txMaster.tData  := rxMaster.tData;
               v.txMaster.tKeep  := rxMaster.tKeep;
               -- Increment the frameLength based on tKeep
               if rxMaster.tKeep = x"000F" then
                  -- Increment the counter by 1
                  v.dmaDescToPci.doneLength := r.dmaDescToPci.doneLength + 1;
                  -- Check for frame length error
                  if r.dmaDescToPci.doneLength = r.maxFrameCheck(0) then
                     -- Set the error flag
                     v.frameErr := '1';
                  end if;
               elsif rxMaster.tKeep = x"00FF" then
                  -- Increment the counter by 1
                  v.dmaDescToPci.doneLength := r.dmaDescToPci.doneLength + 2;
                  -- Check for frame length error
                  if (r.dmaDescToPci.doneLength = r.maxFrameCheck(0))
                     or (r.dmaDescToPci.doneLength = r.maxFrameCheck(1)) then
                     -- Set the error flag
                     v.frameErr := '1';
                  end if;
               elsif rxMaster.tKeep = x"0FFF" then
                  -- Increment the counter by 1
                  v.dmaDescToPci.doneLength := r.dmaDescToPci.doneLength + 3;
                  -- Check for frame length error
                  if (r.dmaDescToPci.doneLength = r.maxFrameCheck(0))
                     or (r.dmaDescToPci.doneLength = r.maxFrameCheck(1))
                     or (r.dmaDescToPci.doneLength = r.maxFrameCheck(2)) then
                     -- Set the error flag
                     v.frameErr := '1';
                  end if;
               else
                  -- Increment the counter by 1
                  v.dmaDescToPci.doneLength := r.dmaDescToPci.doneLength + 4;
                  -- Check for frame length error
                  if (r.dmaDescToPci.doneLength = r.maxFrameCheck(0))
                     or (r.dmaDescToPci.doneLength = r.maxFrameCheck(1))
                     or (r.dmaDescToPci.doneLength = r.maxFrameCheck(2))
                     or (r.dmaDescToPci.doneLength = r.maxFrameCheck(3)) then
                     -- Set the error flag
                     v.frameErr := '1';
                  end if;
               end if;
               -- Increment counter
               v.cnt := r.cnt + 1;
               -- Check the counter
               if r.cnt = r.tranCnt then
                  -- Assert the end of TLP packet flag
                  v.txMaster.tLast := '1';        --EOF 
                  -- Ready to readout the FIFO
                  v.rxSlave.tReady := '0';
                  --check if this is the end of frame
                  if rxMaster.tLast = '1' then
                     -- Let the descriptor know that we are done
                     v.dmaDescToPci.doneReq := '1';
                     -- Next state
                     v.state                := TR_DONE_S;
                  else
                     -- Next state
                     v.state := READ_TRANS_S;
                  end if;
               end if;
               
            end if;
         ----------------------------------------------------------------------
         when TR_DONE_S =>
            -- Wait for descriptor to ACK signal
            if dmaDescFromPci.doneAck = '1' then
               -- Reset flag
               v.dmaDescToPci.doneReq := '0';
               -- Next state
               v.state                := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      dmaDescToPci <= r.dmaDescToPci;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   PciFifoSync_TX : entity work.PciFifoSync
      generic map (
         TPD_G => TPD_G)   
      port map (
         pciClk      => pciClk,
         pciRst      => pciRst,
         -- Slave Port
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisMaster => dmaIbMaster,
         mAxisSlave  => dmaIbSlave);   

end rtl;
