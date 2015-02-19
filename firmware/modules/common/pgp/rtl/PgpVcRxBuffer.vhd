-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpVcRxBuffer.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-29
-- Last update: 2015-02-18
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.PgpCardG3Pkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.Pgp2bPkg.all;

entity PgpVcRxBuffer is
   generic (
      TPD_G      : time := 1 ns;
      PGP_RATE_G : real); 
   port (
      -- EVR Trigger Interface
      enHeaderCheck : in  sl;
      trigLutOut    : in  TrigLutOutType;
      trigLutIn     : out TrigLutInType;
      -- 16-bit Streaming RX Interface
      pgpRxMaster   : in  AxiStreamMasterType;
      pgpRxCtrl     : out AxiStreamCtrlType;
      -- 32-bit Streaming TX Interface
      mAxisMaster   : out AxiStreamMasterType;
      mAxisSlave    : in  AxiStreamSlaveType;
      -- FIFO Overflow Error Strobe
      fifoError     : out sl;
      -- Global Signals
      clk           : in  sl;
      rst           : in  sl);
end PgpVcRxBuffer;

architecture rtl of PgpVcRxBuffer is

   constant AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);  -- 32-bit interface
   constant CLK_FREQ_C    : real                := getRealDiv(PGP_RATE_G, 20);
   constant TIMEOUT_C     : slv(31 downto 0)    := toSlv(getTimeRatio(CLK_FREQ_C, 0.2E+0), 32);  -- 5 seconds

   type StateType is (
      IDLE_S,
      RD_HDR0_S,
      RD_HDR1_S,
      LUT_WAIT0_S,
      LUT_WAIT1_S,
      LUT_WAIT2_S,
      CHECK_ACCEPT_S,
      WR_HDR0_S,
      WR_HDR1_S,
      RD_WR_HDR2_S,
      RD_WR_HDR3_S,
      RD_WR_HDR4_S,
      SEND_SOF_S,
      EOF_WAIT_S);    

   type RegType is record
      timer      : slv(31 downto 0);
      hrdData    : Slv32Array(0 to 1);
      trigLutIn  : TrigLutInType;
      trigLutOut : TrigLutOutType;
      rxSlave    : AxiStreamSlaveType;
      txMaster   : AxiStreamMasterType;
      state      : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      timer      => (others => '0'),
      hrdData    => (others => (others => '0')),
      trigLutIn  => TRIG_LUT_IN_INIT_C,
      trigLutOut => TRIG_LUT_OUT_INIT_C,
      rxSlave    => AXI_STREAM_SLAVE_INIT_C,
      txMaster   => AXI_STREAM_MASTER_INIT_C,
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;
   signal txCtrl   : AxiStreamCtrlType;
   signal axisCtrl : AxiStreamCtrlType;
   
begin
   
   pgpRxCtrl <= axisCtrl;
   fifoError <= axisCtrl.overflow;

   SsiFifo_RX : entity work.SsiFifo
      generic map (
         -- General Configurations         
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         EN_FRAME_FILTER_G   => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 128,
         SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C) 
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => pgpRxMaster,
         sAxisSlave  => open,
         sAxisCtrl   => axisCtrl,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => rxMaster,
         mAxisSlave  => r.rxSlave);  


   comb : process (enHeaderCheck, r, rst, rxMaster, trigLutOut, txCtrl, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.rxSlave.tReady := '0';
      ssiResetFlags(v.txMaster);

      -- Increment the counter
      v.timer := r.timer + 1;

      -- Check if we need to reset the timer
      if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
         -- Reset the timer
         v.timer := (others => '0');
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Reset the timer
            v.timer := (others => '0');
            -- Check for valid data 
            if (r.rxSlave.tReady = '0') and (rxMaster.tValid = '1') then
               -- Check for start of frame bit
               if ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1' then
                  -- Check we are are checking the header
                  if (enHeaderCheck = '1') then
                     ----------------------------------------------------------------
                     -- Note: We check the header before making a DMA request
                     --       to prevent unnecessary DMA traffic
                     ----------------------------------------------------------------
                     -- Ready to readout the FIFO
                     v.rxSlave.tReady := '1';
                     -- Next state
                     v.state          := RD_HDR0_S;
                  else
                     -- Ready to readout the FIFO
                     v.rxSlave.tReady := not(txCtrl.pause);
                     -- Next state
                     v.state          := SEND_SOF_S;
                  end if;
               else
                  -- Blow off the data
                  v.rxSlave.tReady := '1';
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_HDR0_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := '1';
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Store the header locally
               v.hrdData(0) := rxMaster.tData(31 downto 0);
               -- Check for EOF
               if rxMaster.tLast = '1' then
                  -- Stop Reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Next state
                  v.state := RD_HDR1_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_HDR1_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := '1';
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Stop Reading out the FIFO
               v.rxSlave.tReady  := '0';
               -- Store the header locally
               v.hrdData(1)      := rxMaster.tData(31 downto 0);
               -- Latch the OpCode, which is used to address the trigger LUT
               v.trigLutIn.raddr := rxMaster.tData(23 downto 16);
               -- Check for EOF
               if rxMaster.tLast = '1' then
                  -- Next state
                  v.state := IDLE_S;
               -- Check for SOF
               elsif ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1' then
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Next state
                  v.state := LUT_WAIT0_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LUT_WAIT0_S =>
            -- Next state
            v.state := LUT_WAIT1_S;
         ----------------------------------------------------------------------
         when LUT_WAIT1_S =>
            -- Next state
            v.state := LUT_WAIT2_S;
         ----------------------------------------------------------------------
         when LUT_WAIT2_S =>
            -- Next state
            v.state := CHECK_ACCEPT_S;
         ----------------------------------------------------------------------
         when CHECK_ACCEPT_S =>
            -- Check for a valid trigger address
            if trigLutOut.accept = '1' then
               -- Latch the trigger LUT values
               v.trigLutOut := trigLutOut;
               -- Next state
               v.state      := WR_HDR0_S;
            else
               -- Next state
               v.state := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when WR_HDR0_S =>
            -- Check if FIFO is ready
            if (txCtrl.pause = '0') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.hrdData(0);
               ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');
               -- Next state
               v.state                       := WR_HDR1_S;
            end if;
         ----------------------------------------------------------------------
         when WR_HDR1_S =>
            -- Check if FIFO is ready
            if (txCtrl.pause = '0') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.hrdData(1);
               -- Ready to readout the FIFO
               v.rxSlave.tReady              := not(txCtrl.pause);
               -- Next state
               v.state                       := RD_WR_HDR2_S;
            end if;
         ----------------------------------------------------------------------
         when RD_WR_HDR2_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := not(txCtrl.pause);
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.trigLutOut.acceptCnt;
               -- Check for EOF and SOF
               if (rxMaster.tLast = '1') or (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1') then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, '1');
                  -- Stop Reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Next state
                  v.state := RD_WR_HDR3_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_WR_HDR3_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := not(txCtrl.pause);
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.trigLutOut.offset;
               -- Check for EOF and SOF
               if (rxMaster.tLast = '1') or (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1') then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, '1');
                  -- Stop Reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Next state
                  v.state := RD_WR_HDR4_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_WR_HDR4_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := not(txCtrl.pause);
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.trigLutOut.seconds;
               -- Check for EOF and SOF
               if (rxMaster.tLast = '1') or (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1') then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, '1');
                  -- Stop Reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Next state
                  v.state := EOF_WAIT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SEND_SOF_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := not(txCtrl.pause);
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := rxMaster.tData(31 downto 0);
               ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');
               -- Check for EOF
               if rxMaster.tLast = '1' then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, ssiGetUserEofe(AXIS_CONFIG_C, rxMaster));
                  -- Stop Reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Next state
                  v.state := EOF_WAIT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when EOF_WAIT_S =>
            -- Ready to readout the FIFO
            v.rxSlave.tReady := not(txCtrl.pause);
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := rxMaster.tData(31 downto 0);
               -- Check for EOF
               if rxMaster.tLast = '1' then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, ssiGetUserEofe(AXIS_CONFIG_C, rxMaster));
                  -- Stop Reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               -- Check for SOF
               elsif ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1' then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, '1');
                  -- Stop Reading out the FIFO
                  v.rxSlave.tReady := '0';
                  -- Next state
                  v.state          := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Check for timeout
      if r.timer = TIMEOUT_C then
         -- Reset the timer
         v.timer           := (others => '0');
         -- Terminate the frame
         v.txMaster.tValid := txSlave.tReady;
         -- Set the EOF bit
         v.txMaster.tLast  := '1';
         -- Set the EOFE bit
         ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, '1');
         -- Stop Reading out the FIFO
         v.rxSlave.tReady  := '0';
         -- Next state
         v.state           := IDLE_S;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      trigLutIn <= r.trigLutIn;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   SsiFifo_TX : entity work.SsiFifo
      generic map (
         -- General Configurations         
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         EN_FRAME_FILTER_G   => false,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 500,
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C) 
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         sAxisCtrl   => txCtrl,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);    

end rtl;
