-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTxDmaFifoMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-13
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

entity PciTxDmaFifoMux is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Slave Port
      pciClk      : in  sl;
      pciRst      : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      -- Master Port
      mAxisClk    : in  sl;
      mAxisRst    : in  sl;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);        
end PciTxDmaFifoMux;

architecture rtl of PciTxDmaFifoMux is

   type StateType is (
      WORD0_S,
      WORD1_S,
      WORD2_S,
      WORD3_S);    

   type RegType is record
      rxSlave  : AxiStreamSlaveType;
      txMaster : AxiStreamMasterType;
      saved    : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      AXI_STREAM_SLAVE_INIT_C,
      AXI_STREAM_MASTER_INIT_C,
      AXI_STREAM_MASTER_INIT_C,
      WORD0_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sAxisCtrl : AxiStreamCtrlType;
   signal rxMaster  : AxiStreamMasterType;
   signal txCtrl    : AxiStreamCtrlType;

   attribute dont_touch      : string;
   attribute dont_touch of r : signal is "true";

   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of
      SsiFifo_RX,
      SsiFifo_TX : label is "TRUE";

begin

   sAxisSlave.tReady <= not(sAxisCtrl.pause);

   SsiFifo_RX : entity work.SsiFifo
      generic map (
         -- General Configurations         
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         EN_FRAME_FILTER_G   => false,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => false,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         FIFO_ADDR_WIDTH_G   => 6,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 32,
         SLAVE_AXI_CONFIG_G  => AXIS_PCIE_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_PCIE_CONFIG_C) 
      port map (
         -- Slave Port
         sAxisClk    => pciClk,
         sAxisRst    => pciRst,
         sAxisMaster => sAxisMaster,
         sAxisCtrl   => sAxisCtrl,
         -- Master Port
         mAxisClk    => pciClk,
         mAxisRst    => pciRst,
         mAxisMaster => rxMaster,
         mAxisSlave  => r.rxSlave);  

   comb : process (pciRst, r, rxMaster, txCtrl) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      ssiResetFlags(v.txMaster);

      -- Only 32-bit transfers
      v.txMaster.tKeep := x"000F";

      case r.state is
         ----------------------------------------------------------------------
         when WORD0_S =>
            -- Update the tReady flag
            v.rxSlave.tReady := not(txCtrl.pause);
            -- Check for valid data
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := rxMaster.tData(31 downto 0);
               v.txMaster.tDest              := rxMaster.tDest;
               -- Check if we have more data to transfer
               if rxMaster.tKeep(7 downto 4) = x"F" then
                  -- Stop the data flow
                  v.rxSlave.tready := '0';
                  -- Latch the values
                  v.saved          := rxMaster;
                  -- Next state
                  v.state          := WORD1_S;
               else
                  -- Pass the SOF, EOF, and EOFE
                  v.txMaster.tLast              := rxMaster.tLast;
                  v.txMaster.tUser(31 downto 0) := rxMaster.tUser(31 downto 0);
               end if;
            end if;
         ----------------------------------------------------------------------
         when WORD1_S =>
            -- Check for FIFO is ready
            if (txCtrl.pause = '0') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.saved.tData(63 downto 32);
               -- Check if we have more data to transfer
               if r.saved.tKeep(11 downto 8) = x"F" then
                  -- Next state
                  v.state := WORD2_S;
               else
                  -- Pass the SOF, EOF, and EOFE
                  v.txMaster.tLast              := r.saved.tLast;
                  v.txMaster.tUser(31 downto 0) := r.saved.tUser(63 downto 32);
                  -- Update the tReady flag
                  v.rxSlave.tready              := '1';
                  -- Next state
                  v.state                       := WORD0_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WORD2_S =>
            -- Check for FIFO is ready
            if (txCtrl.pause = '0') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.saved.tData(95 downto 64);
               -- Check if we have more data to transfer
               if r.saved.tKeep(15 downto 12) = x"F" then
                  -- Next state
                  v.state := WORD3_S;
               else
                  -- Pass the SOF, EOF, and EOFE
                  v.txMaster.tLast              := r.saved.tLast;
                  v.txMaster.tUser(31 downto 0) := r.saved.tUser(95 downto 64);
                  -- Update the tReady flag
                  v.rxSlave.tready              := '1';
                  -- Next state
                  v.state                       := WORD0_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when WORD3_S =>
            -- Check for FIFO is ready
            if (txCtrl.pause = '0') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.saved.tData(127 downto 96);
               -- Pass the SOF, EOF, and EOFE
               v.txMaster.tLast              := r.saved.tLast;
               v.txMaster.tUser(31 downto 0) := r.saved.tUser(127 downto 96);
               -- Update the tReady flag
               v.rxSlave.tready              := '1';
               -- Next state
               v.state                       := WORD0_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SsiFifo_TX : entity work.SsiFifo
      generic map (
         -- General Configurations         
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         EN_FRAME_FILTER_G   => false,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => false,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => false,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         FIFO_ADDR_WIDTH_G   => 6,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 32,
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         MASTER_AXI_CONFIG_G => ssiAxiStreamConfig(4)) 
      port map (
         -- Slave Port
         sAxisClk    => pciClk,
         sAxisRst    => pciRst,
         sAxisMaster => r.txMaster,
         sAxisCtrl   => txCtrl,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);              

end rtl;
