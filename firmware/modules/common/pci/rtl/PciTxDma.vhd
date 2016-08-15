-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTxDma.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-03
-- Last update: 2016-08-15
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;

entity PciTxDma is
   generic (
      TPD_G : time := 1 ns); 
   port (
      -- 128-bit Streaming RX Interface
      pciClk         : in  sl;
      pciRst         : in  sl;
      dmaIbMaster    : out AxiStreamMasterType;
      dmaIbSlave     : in  AxiStreamSlaveType;
      dmaObMaster    : in  AxiStreamMasterType;
      dmaObSlave     : out AxiStreamSlaveType;
      dmaDescFromPci : in  DescFromPciType;
      dmaDescToPci   : out DescToPciType;
      dmaTranFromPci : in  TranFromPciType;
      -- 32-bit Streaming TX Interface
      mAxisClk       : in  sl;
      mAxisRst       : in  sl;
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType);     
end PciTxDma;

architecture rtl of PciTxDma is

   type StateType is (
      IDLE_S,
      COLLECT_S);    

   type RegType is record
      sof       : sl;
      contEn    : sl;
      done      : sl;
      remLength : slv(23 downto 0);
      rxSlave   : AxiStreamSlaveType;
      txMaster  : AxiStreamMasterType;
      state     : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      sof       => '1',
      contEn    => '0',
      done      => '0',
      remLength => (others => '0'),
      rxSlave   => AXI_STREAM_SLAVE_INIT_C,
      txMaster  => AXI_STREAM_MASTER_INIT_C,
      state     => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal start  : sl;
   signal dmaSof : sl;

   signal newControl : slv(7 downto 0);
   signal newLength  : slv(23 downto 0);

   signal axisMaster : AxiStreamMasterType;
   signal rxMaster   : AxiStreamMasterType;
   signal rxSlave    : AxiStreamSlaveType;
   signal txSlave    : AxiStreamSlaveType;
   signal dmaCtrl    : AxiStreamCtrlType;

   -- attribute dont_touch               : string;
   -- attribute dont_touch of r          : signal is "true";
   -- attribute dont_touch of start      : signal is "true";
   -- attribute dont_touch of dmaSof     : signal is "true";
   -- attribute dont_touch of newControl : signal is "true";
   -- attribute dont_touch of newLength  : signal is "true";
   
begin

   PciTxDmaMemReq_Inst : entity work.PciTxDmaMemReq
      generic map (
         TPD_G => TPD_G)
      port map (
         -- DMA Interface
         dmaIbMaster    => dmaIbMaster,
         dmaIbSlave     => dmaIbSlave,
         dmaDescFromPci => dmaDescFromPci,
         dmaDescToPci   => dmaDescToPci,
         dmaTranFromPci => dmaTranFromPci,
         -- Transaction Interface
         start          => start,
         done           => r.done,
         pause          => dmaCtrl.pause,
         remLength      => r.remLength,
         newControl     => newControl,
         newLength      => newLength,
         -- Clock and reset     
         pciClk         => pciClk,
         pciRst         => pciRst);   

   FIFO_RX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 256,  -- min. threshold =  (511 - 2*(PCIE_MAX_TX_TRANS_LENGTH_C/4))
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => PCI_AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => PCI_AXIS_CONFIG_C)            
      port map (
         -- Slave Port
         sAxisClk    => pciClk,
         sAxisRst    => pciRst,
         sAxisMaster => dmaObMaster,
         sAxisSlave  => dmaObSlave,
         sAxisCtrl   => dmaCtrl,
         -- Master Port
         mAxisClk    => pciClk,
         mAxisRst    => pciRst,
         mAxisMaster => axisMaster,
         mAxisSlave  => rxSlave);                   

   -- Reverse the data order
   rxMaster <= reverseOrderPcie(axisMaster);

   dmaSof <= '1' when(r.remLength = newLength) else '0';

   comb : process (dmaSof, newControl, newLength, pciRst, r, rxMaster, start, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.done           := '0';
      v.rxSlave.tReady := '0';

      -- Update tValid register
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Wait for start signal
            if start = '1' then
               -- Latch the length of the transaction
               v.remLength                  := newLength;
               -- Set the continuous mode flag
               v.contEn                     := newControl(2);
               -- Set the destination
               v.txMaster.tDest(7 downto 2) := (others => '0');
               v.txMaster.tDest(1 downto 0) := newControl(1 downto 0);
               -- Next state
               v.state                      := COLLECT_S;
            else
               -- Dump any data in the FIFO (first memory request TLP not sent yet)
               v.rxSlave.tReady := '1';
            end if;
         ----------------------------------------------------------------------
         when COLLECT_S =>
            -- Check if ready to move data 
            if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') then
               -- Ready for data
               v.rxSlave.tReady  := '1';
               -- Write to the FIFO
               v.txMaster.tValid := '1';
               -- Check local & DMA SOF variable
               if (r.sof = '1') and (dmaSof = '1') then
                  -- Reset the flag
                  v.sof := '0';
                  -- Set the SOF bit
                  ssiSetUserSof(PCI_AXIS_CONFIG_C, v.txMaster, '1');
               end if;
               -- Check for TLP SOF
               if ssiGetUserSof(PCI_AXIS_CONFIG_C, rxMaster) = '1' then
                  -- Set the tKeep
                  v.txMaster.tKeep              := x"000F";
                  -- Blow off the 3-DW header and grab the 4th DW
                  v.txMaster.tData(31 downto 0) := rxMaster.tData(127 downto 96);
                  -- Decrement the counter
                  v.remLength                   := r.remLength - 1;
                  -- Check if this is the last DMA word to transfer
                  if r.remLength = 1 then
                     -- Handshake with Memory Requester  
                     v.done := '1';
                     -- Check for not continuous mode
                     if r.contEn = '0' then
                        -- Reset the flag
                        v.sof            := '1';
                        -- Set the EOF bit
                        v.txMaster.tLast := '1';
                     end if;
                     -- Next state
                     v.state := IDLE_S;
                  end if;
               else
                  -- Set the tKeep
                  v.txMaster.tKeep := rxMaster.tKeep;
                  -- Latch the data
                  v.txMaster.tData := rxMaster.tData;
                  -- Check RX tKeep 
                  if rxMaster.tKeep(15 downto 12) = x"F" then
                     -- Decrement the counter
                     v.remLength := r.remLength - 4;
                  elsif rxMaster.tKeep(11 downto 8) = x"F" then
                     -- Decrement the counter
                     v.remLength := r.remLength - 3;
                  elsif rxMaster.tKeep(7 downto 4) = x"F" then
                     -- Decrement the counter
                     v.remLength := r.remLength - 2;
                  else
                     -- Decrement the counter
                     v.remLength := r.remLength - 1;
                  end if;
                  ----------------------------------------------------------
                  case r.remLength is
                     when toSlv(1, 24) =>
                        -- Set the tKeep
                        v.txMaster.tKeep := x"000F";
                        -- Handshake with Memory Requester  
                        v.done           := '1';
                        -- Check for not continuous mode
                        if r.contEn = '0' then
                           -- Reset the flag
                           v.sof            := '1';
                           -- Set the EOF bit
                           v.txMaster.tLast := '1';
                        end if;
                        -- Next state
                        v.state := IDLE_S;
                     when toSlv(2, 24) =>
                        if rxMaster.tKeep(7 downto 0) = x"FF" then
                           -- Set the tKeep
                           v.txMaster.tKeep := x"00FF";
                           -- Handshake with Memory Requester  
                           v.done           := '1';
                           -- Check for not continuous mode
                           if r.contEn = '0' then
                              -- Reset the flag
                              v.sof            := '1';
                              -- Set the EOF bit
                              v.txMaster.tLast := '1';
                           end if;
                           -- Next state
                           v.state := IDLE_S;
                        end if;
                     when toSlv(3, 24) =>
                        if rxMaster.tKeep(11 downto 0) = x"FFF" then
                           -- Set the tKeep
                           v.txMaster.tKeep := x"0FFF";
                           -- Handshake with Memory Requester  
                           v.done           := '1';
                           -- Check for not continuous mode
                           if r.contEn = '0' then
                              -- Reset the flag
                              v.sof            := '1';
                              -- Set the EOF bit
                              v.txMaster.tLast := '1';
                           end if;
                           -- Next state
                           v.state := IDLE_S;
                        end if;
                     when toSlv(4, 24) =>
                        if rxMaster.tKeep(15 downto 0) = x"FFFF" then
                           -- Set the tKeep
                           v.txMaster.tKeep := x"FFFF";
                           -- Handshake with Memory Requester  
                           v.done           := '1';
                           -- Check for not continuous mode
                           if r.contEn = '0' then
                              -- Reset the flag
                              v.sof            := '1';
                              -- Set the EOF bit
                              v.txMaster.tLast := '1';
                           end if;
                           -- Next state
                           v.state := IDLE_S;
                        end if;
                     when others =>
                        null;
                  end case;
               ----------------------------------------------------------
               end if;
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
      rxSlave <= v.rxSlave;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   PciTxDmaFifoMux_Inst : entity work.PciTxDmaFifoMux
      generic map (
         TPD_G => TPD_G)
      port map (
         -- 128-bit Streaming RX Interface
         pciClk      => pciClk,
         pciRst      => pciRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- 32-bit Streaming TX Interface
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);           

end rtl;
