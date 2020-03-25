-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciRxDma.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-03
-- Last update: 2016-08-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC PGP Gen3 Card'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC PGP Gen3 Card', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
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
      dmaChannel     : in  slv(2 downto 0));
end PciRxDma;

architecture rtl of PciRxDma is

   type StateType is (
      IDLE_S,
      ACK_WAIT_S,
      READ_TRANS_S,
      SEND_IO_REQ_HDR_S,
      COLLECT_S,
      TR_DONE_S);    

   type RegType is record
      errDet       : sl;
      tranRd       : sl;
      contEn       : sl;
      lengthErr    : sl;
      tranEof      : sl;
      tranEofe     : sl;
      tranSubId    : slv(1 downto 0);
      tranLength   : slv(9 downto 0);
      tranCnt      : slv(9 downto 0);
      cnt          : slv(9 downto 0);
      dumpCnt      : slv(9 downto 0);
      newAddr      : slv(29 downto 0);
      maxFrame     : slv(23 downto 0);
      dmaDescToPci : DescToPciType;
      rxSlave      : AxiStreamSlaveType;
      txMaster     : AxiStreamMasterType;
      state        : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      errDet       => '0',
      tranRd       => '0',
      contEn       => '0',
      lengthErr    => '0',
      tranEof      => '0',
      tranEofe     => '0',
      tranSubId    => (others => '0'),
      tranLength   => (others => '0'),
      tranCnt      => (others => '0'),
      cnt          => (others => '0'),
      dumpCnt      => (others => '0'),
      newAddr      => (others => '0'),
      maxFrame     => (others => '0'),
      dmaDescToPci => DESC_TO_PCI_INIT_C,
      rxSlave      => AXI_STREAM_SLAVE_INIT_C,
      txMaster     => AXI_STREAM_MASTER_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal tranValid  : sl;
   signal tranRd     : sl;
   signal tranSof    : sl;
   signal tranEof    : sl;
   signal tranEofe   : sl;
   signal tranSubId  : slv(1 downto 0);
   signal tranLength : slv(8 downto 0);
   signal tranCnt    : slv(8 downto 0);

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;
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
         mAxisSlave  => rxSlave,
         tranRd      => tranRd,
         tranValid   => tranValid,
         tranSubId   => tranSubId,
         tranSof     => tranSof,
         tranEof     => tranEof,
         tranEofe    => tranEofe,
         tranLength  => tranLength,
         tranCnt     => tranCnt);

   comb : process (dmaChannel, dmaDescFromPci, dmaTranFromPci, pciRst, r, rxMaster, tranCnt,
                   tranEof, tranEofe, tranLength, tranSof, tranSubId, tranValid, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.tranRd         := '0';
      v.rxSlave.tReady := '0';

      -- Update tValid register
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for start of transaction w/ data
            if (tranValid = '1') and (rxMaster.tValid = '1') then
               -- Check for Continue enabled
               if (r.contEn = '1') then
                  -- Send a request to the descriptor
                  v.dmaDescToPci.newReq := '1';
                  -- Next state
                  v.state               := ACK_WAIT_S;
               -- Check for tranSof and axisSof
               elsif (tranSof = '1') and (ssiGetUserSof(AXIS_32B_CONFIG_C, rxMaster) = '1') then
                  -- Send a request to the descriptor
                  v.dmaDescToPci.newReq := '1';
                  -- Next state
                  v.state               := ACK_WAIT_S;
               end if;
            end if;
            -- Check for SOF state
            if (r.contEn = '0') then
               -- Set the flag
               v.errDet         := '1';
               -- Blowoff transaction and/or data
               v.tranRd         := tranValid and not(tranSof);
               v.rxSlave.tReady := rxMaster.tValid and not(ssiGetUserSof(AXIS_32B_CONFIG_C, rxMaster));
            end if;
         ----------------------------------------------------------------------
         when ACK_WAIT_S =>
            -- Wait for descriptor 
            if dmaDescFromPci.newAck = '1' then
               -- Reset request flag
               v.dmaDescToPci.newReq     := '0';
               -- Reset the error flag
               v.lengthErr               := '0';
               -- Latch the descriptor values
               v.contEn                  := dmaDescFromPci.contEn;
               v.dmaDescToPci.doneAddr   := dmaDescFromPci.newAddr;
               v.newAddr(29 downto 0)    := dmaDescFromPci.newAddr;
               v.maxFrame                := dmaDescFromPci.maxFrame;
               v.dmaDescToPci.doneLength := (others => '0');
               -- Next state
               v.state                   := READ_TRANS_S;
            end if;
         ----------------------------------------------------------------------
         when READ_TRANS_S =>
            -- Wait for FIFO data Transaction FIFO
            if tranValid = '1' then
               -- Read the FIFO
               v.tranRd     := '1';
               -- Latch the transaction length
               v.tranSubId  := tranSubId;
               v.tranEof    := tranEof;
               v.tranEofe   := tranEofe;
               v.tranLength := '0' & tranLength;
               v.tranCnt    := '0' & tranCnt;
               v.cnt        := (others => '0');
               -- Next state
               v.state      := SEND_IO_REQ_HDR_S;
            end if;
         ----------------------------------------------------------------------
         when SEND_IO_REQ_HDR_S =>
            -- Check if we need to move data
            if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') then
               -- Ready for data
               v.rxSlave.tReady                := '1';
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
               if r.lengthErr = '1' then
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
               if (r.dmaDescToPci.doneLength = r.maxFrame) then
                  -- Set the error flag
                  v.lengthErr := '1';
               end if;

               -- Set AXIS tKeep
               v.txMaster.tKeep := x"FFFF";

               -- Check for frame length error
               if (v.lengthErr = '1') and (r.contEn = '0') then
                  -- Assert the end of TLP packet flag
                  v.txMaster.tLast       := '1';  --EOF 
                  -- Let the descriptor know that we are done
                  v.dmaDescToPci.doneReq := '1';
                  -- Reset the flag
                  v.contEn               := '0';
                  -- Next state
                  v.state                := TR_DONE_S;
               -- Check if this is last data read
               elsif r.tranLength = 1 then
                  -- Assert the end of TLP packet flag
                  v.txMaster.tLast := '1';        --EOF
                  -- Check for continuous mode
                  if r.contEn = '1' then
                     -- Override the frame length checking
                     v.lengthErr := '0';
                     -- Update the flag
                     v.contEn    := not(rxMaster.tLast or r.tranEof);
                  end if;
                  -- Check if this is the end of frame
                  if (rxMaster.tLast = '1') or (r.tranEof = '1') then
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
            -- Check if we need to move data
            if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') then
               -- Ready for data
               v.rxSlave.tReady  := '1';
               -- Write to FIFO
               v.txMaster.tValid := '1';
               v.txMaster.tData  := rxMaster.tData;
               v.txMaster.tKeep  := rxMaster.tKeep;
               -- Increment the frameLength based on WORD[0]
               if rxMaster.tKeep(3 downto 0) = x"F" then
                  -- Increment the counter
                  v.dmaDescToPci.doneLength := r.dmaDescToPci.doneLength + 1;
                  -- Check for frame length error
                  if v.dmaDescToPci.doneLength = r.maxFrame then
                     -- Set the error flag
                     v.lengthErr := '1';
                  end if;
               end if;
               -- Increment the frameLength based on WORD[1]
               if rxMaster.tKeep(7 downto 4) = x"F" then
                  -- Increment the counter
                  v.dmaDescToPci.doneLength := r.dmaDescToPci.doneLength + 2;
                  -- Check for frame length error
                  if v.dmaDescToPci.doneLength = r.maxFrame then
                     -- Set the error flag
                     v.lengthErr := '1';
                  end if;
               end if;
               -- Increment the frameLength based on WORD[2]
               if rxMaster.tKeep(11 downto 8) = x"F" then
                  -- Increment the counter
                  v.dmaDescToPci.doneLength := r.dmaDescToPci.doneLength + 3;
                  -- Check for frame length error
                  if v.dmaDescToPci.doneLength = r.maxFrame then
                     -- Set the error flag
                     v.lengthErr := '1';
                  end if;
               end if;
               -- Increment the frameLength based on WORD[3]
               if rxMaster.tKeep(15 downto 12) = x"F" then
                  -- Increment the counter
                  v.dmaDescToPci.doneLength := r.dmaDescToPci.doneLength + 4;
                  -- Check for frame length error
                  if v.dmaDescToPci.doneLength = r.maxFrame then
                     -- Set the error flag
                     v.lengthErr := '1';
                  end if;
               end if;
               -- Increment counter
               v.cnt := r.cnt + 1;
               -- Check the counter
               if r.cnt = r.tranCnt then
                  -- Assert the end of TLP packet flag
                  v.txMaster.tLast := '1';        --EOF 
                  -- Check for continuous mode
                  if r.contEn = '1' then
                     -- Override the frame length checking
                     v.lengthErr := '0';
                     -- Update the flag
                     v.contEn    := not(rxMaster.tLast or r.tranEof);
                  end if;
                  -- Check if this is the end of frame or error
                  if (rxMaster.tLast = '1') or (r.tranEof = '1') or (v.lengthErr = '1') then
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

      -- Update the done status
      v.dmaDescToPci.doneStatus(11 downto 8) := (others => '0');
      v.dmaDescToPci.doneStatus(7)           := v.lengthErr;
      v.dmaDescToPci.doneStatus(6)           := v.tranEofe;
      v.dmaDescToPci.doneStatus(5)           := v.contEn;
      v.dmaDescToPci.doneStatus(4 downto 2)  := dmaChannel;
      v.dmaDescToPci.doneStatus(1 downto 0)  := r.tranSubId;

      rxSlave      <= v.rxSlave;
      tranRd       <= v.tranRd;      
      
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

   U_Pipeline : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => pciClk,
         axisRst     => pciRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => dmaIbMaster,
         mAxisSlave  => dmaIbSlave);        

end rtl;
