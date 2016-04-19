-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpVcRxBuffer.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-29
-- Last update: 2015-11-06
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
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
      TPD_G            : time := 1 ns;
      CASCADE_SIZE_G   : natural;
      SLAVE_READY_EN_G : boolean;
      LANE_G           : natural;
      VC_G             : natural); 
   port (
      countRst      : in  sl;
      -- EVR Trigger Interface
      enHeaderCheck : in  sl;
      trigLutOut    : in  TrigLutOutType;
      trigLutIn     : out TrigLutInType;
      lutDropCnt    : out slv(7 downto 0);
      -- 16-bit Streaming RX Interface
      pgpRxMaster   : in  AxiStreamMasterType;
      pgpRxSlave    : out AxiStreamSlaveType;
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
   constant LUT_WAIT_C    : natural             := 7;

   type StateType is (
      IDLE_S,
      RD_HDR0_S,
      RD_HDR1_S,
      LUT_WAIT_S,
      CHECK_ACCEPT_S,
      WR_HDR0_S,
      WR_HDR1_S,
      RD_WR_HDR2_S,
      RD_WR_HDR3_S,
      RD_WR_HDR4_S,
      FWD_PAYLOAD_S);    

   type RegType is record
      fifoError  : sl;
      lutDropCnt : slv(7 downto 0);
      lutWaitCnt : natural range 0 to LUT_WAIT_C;
      hrdData    : Slv32Array(0 to 1);
      trigLutIn  : TrigLutInType;
      trigLutOut : TrigLutOutType;
      trigLutDly : TrigLutOutArray(0 to 1);
      rxSlave    : AxiStreamSlaveType;
      txMaster   : AxiStreamMasterType;
      state      : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      fifoError  => '0',
      lutDropCnt => (others => '0'),
      lutWaitCnt => 0,
      hrdData    => (others => (others => '0')),
      trigLutIn  => TRIG_LUT_IN_INIT_C,
      trigLutOut => TRIG_LUT_OUT_INIT_C,
      trigLutDly => (others => TRIG_LUT_OUT_INIT_C),
      rxSlave    => AXI_STREAM_SLAVE_INIT_C,
      txMaster   => AXI_STREAM_MASTER_INIT_C,
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;

   signal txSlave  : AxiStreamSlaveType;
   signal axisCtrl : AxiStreamCtrlType;
   
begin
   
   pgpRxCtrl <= axisCtrl;

   FIFO_RX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         CASCADE_SIZE_G      => CASCADE_SIZE_G,
         FIFO_ADDR_WIDTH_G   => 10,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 512,
         CASCADE_PAUSE_SEL_G => (CASCADE_SIZE_G-1),
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C)        
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => pgpRxMaster,
         sAxisSlave  => pgpRxSlave,
         sAxisCtrl   => axisCtrl,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);  

   comb : process (axisCtrl, countRst, enHeaderCheck, r, rst, rxMaster, trigLutOut, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Add registers to help with timing
      v.fifoError     := axisCtrl.overflow;
      v.trigLutDly(1) := trigLutOut;
      v.trigLutDly(0) := r.trigLutDly(1);

      -- Reset strobing signals
      v.rxSlave.tReady := '0';

      -- Update tValid register
      if txSlave.tReady = '1' then
         v.txMaster.tValid := '0';
         v.txMaster.tLast  := '0';
         v.txMaster.tUser  := (others => '0');
         v.txMaster.tDest  := toSlv(VC_G, 8);
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check if ready to move data 
            if (rxMaster.tValid = '1') then
               -- Check for SOF
               if ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1' then
                  -- Check we are are checking the header
                  if (enHeaderCheck = '1') then
                     -- Next state
                     v.state := RD_HDR0_S;
                  elsif (v.txMaster.tValid = '0') then
                     -- Accept the data
                     v.rxSlave.tReady := '1';
                     -- Write to the FIFO         
                     v.txMaster       := rxMaster;
                     -- Next state
                     v.state          := FWD_PAYLOAD_S;
                  end if;
               else
                  -- Blow off the data
                  v.rxSlave.tReady := '1';
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_HDR0_S =>
            -- Check for data
            if rxMaster.tValid = '1' then
               -- Accept the data
               v.rxSlave.tReady := '1';
               -- Store the header locally
               v.hrdData(0)     := rxMaster.tData(31 downto 0);
               -- Check for EOF
               if rxMaster.tLast = '1' then
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Next state
                  v.state := RD_HDR1_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_HDR1_S =>
            -- Check for data
            if rxMaster.tValid = '1' then
               -- Accept the data
               v.rxSlave.tReady  := '1';
               -- Store the header locally
               v.hrdData(1)      := rxMaster.tData(31 downto 0);
               -- Latch the OpCode, which is used to address the trigger LUT
               v.trigLutIn.raddr := rxMaster.tData(23 downto 16);
               -- Check for EOF or SOF
               if (rxMaster.tLast = '1') or (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1') then
                  -- Next state
                  v.state := IDLE_S;
               else
                  -- Next state
                  v.state := LUT_WAIT_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when LUT_WAIT_S =>
            -- Increment the counter
            v.lutWaitCnt := r.lutWaitCnt + 1;
            -- Check the counter size
            if r.lutWaitCnt = LUT_WAIT_C then
               -- Reset the counter
               v.lutWaitCnt := 0;
               -- Next state
               v.state      := CHECK_ACCEPT_S;
            end if;
         ----------------------------------------------------------------------
         when CHECK_ACCEPT_S =>
            -- Check for a valid trigger address
            if r.trigLutDly(0).accept = '1' then
               -- Latch the trigger LUT values
               v.trigLutOut := r.trigLutDly(0);
               -- Next state
               v.state      := WR_HDR0_S;
            else
               if r.lutDropCnt /= x"FF" then
                  v.lutDropCnt := r.lutDropCnt + 1;
               end if;
               -- Next state
               v.state := IDLE_S;
            end if;
         ----------------------------------------------------------------------
         when WR_HDR0_S =>
            -- Check if FIFO is ready
            if v.txMaster.tValid = '0' then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               ssiSetUserSof(AXIS_CONFIG_C, v.txMaster, '1');
               v.txMaster.tData(31 downto 8) := r.hrdData(0)(31 downto 8);
               v.txMaster.tData(7 downto 5)  := toSlv(LANE_G, 3);
               v.txMaster.tData(4 downto 2)  := r.hrdData(0)(4 downto 2);
               v.txMaster.tData(1 downto 0)  := toSlv(VC_G, 2);
               -- Next state
               v.state                       := WR_HDR1_S;
            end if;
         ----------------------------------------------------------------------
         when WR_HDR1_S =>
            -- Check if FIFO is ready
            if v.txMaster.tValid = '0' then
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.hrdData(1);
               -- Next state
               v.state                       := RD_WR_HDR2_S;
            end if;
         ----------------------------------------------------------------------
         when RD_WR_HDR2_S =>
            -- Check if ready to move data 
            if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') then
               -- Ready for data
               v.rxSlave.tReady              := '1';
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.trigLutOut.acceptCnt;
               -- Check for EOF
               if rxMaster.tLast = '1' or (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1') then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, '1');
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Next state
                  v.state := RD_WR_HDR3_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_WR_HDR3_S =>
            -- Check if ready to move data 
            if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') then
               -- Ready for data
               v.rxSlave.tReady              := '1';
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.trigLutOut.offset;
               -- Check for EOF
               if rxMaster.tLast = '1' or (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1') then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, '1');
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Next state
                  v.state := RD_WR_HDR4_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RD_WR_HDR4_S =>
            -- Check if ready to move data 
            if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') then
               -- Ready for data
               v.rxSlave.tReady              := '1';
               -- Write to the FIFO
               v.txMaster.tValid             := '1';
               v.txMaster.tData(31 downto 0) := r.trigLutOut.seconds;
               -- Check for EOF
               if rxMaster.tLast = '1' or (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1') then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, '1');
                  -- Next state
                  v.state          := IDLE_S;
               else
                  -- Next state
                  v.state := FWD_PAYLOAD_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when FWD_PAYLOAD_S =>
            -- Check if ready to move data 
            if (v.txMaster.tValid = '0') and (rxMaster.tValid = '1') then
               -- Ready for data
               v.rxSlave.tReady := '1';
               -- Write to the FIFO         
               v.txMaster       := rxMaster;
               -- Check for second SOF
               if (ssiGetUserSof(AXIS_CONFIG_C, rxMaster) = '1') then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_CONFIG_C, v.txMaster, '1');
                  -- Next state
                  v.state          := IDLE_S;
               -- Check for EOF
               elsif rxMaster.tLast = '1' then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      if countRst = '1' then
         v.lutDropCnt := x"00";
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      fifoError  <= r.fifoError;
      trigLutIn  <= r.trigLutIn;
      lutDropCnt <= r.lutDropCnt;
      rxSlave    <= v.rxSlave;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   FIFO_TX : entity work.AxiStreamFifo
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => true,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => false,
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         CASCADE_SIZE_G      => 1,
         FIFO_ADDR_WIDTH_G   => 4,
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => AXIS_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_CONFIG_C)      
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);        

end rtl;
