-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpVcRxBuffer.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-29
-- Last update: 2018-09-28
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.PgpCardG3Pkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;
use work.Pgp2bPkg.all;

entity PgpVcRxBuffer is
   generic (
      TPD_G               : time     := 1 ns;
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType;
      CASCADE_SIZE_G      : natural;
      GEN_SYNC_FIFO_G     : boolean;
      SLAVE_READY_EN_G    : boolean;
      FIFO_ADDR_WIDTH_G   : positive := 10;
      FIFO_PAUSE_THRESH_G : positive := 512;
      LANE_G              : natural;
      VC_G                : natural);
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
      -- Diagnostic Monitoring Interface
      fifoError     : out sl;
      vcPause       : out sl;
      vcOverflow    : out sl;
      -- Global Signals
      sAxisClk      : in  sl;
      sAxisRst      : in  sl;
      mAxisClk      : in  sl;
      mAxisRst      : in  sl);
end PgpVcRxBuffer;

architecture rtl of PgpVcRxBuffer is

   constant LUT_WAIT_C     : natural := 7;
   constant CASCADE_SIZE_C : natural := ite(SLAVE_READY_EN_G, 1, CASCADE_SIZE_G);

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
      eofe       : sl;
      fifoError  : sl;
      vcPause    : sl;
      vcOverflow : sl;
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
      eofe       => '0',
      fifoError  => '0',
      vcPause    => '0',
      vcOverflow => '0',
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

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   pgpRxCtrl <= axisCtrl;

   FIFO_RX : entity work.AxiStreamFifoV2
      generic map (
         -- General Configurations
         TPD_G               => TPD_G,
         INT_PIPE_STAGES_G   => 1,
         PIPE_STAGES_G       => 1,
         SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         BRAM_EN_G           => true,
         GEN_SYNC_FIFO_G     => GEN_SYNC_FIFO_G,
         CASCADE_SIZE_G      => CASCADE_SIZE_C,
         FIFO_ADDR_WIDTH_G   => FIFO_ADDR_WIDTH_G,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => FIFO_PAUSE_THRESH_G,
         CASCADE_PAUSE_SEL_G => (CASCADE_SIZE_C-1),
         -- AXI Stream Port Configurations
         SLAVE_AXI_CONFIG_G  => SLAVE_AXI_CONFIG_G,
         MASTER_AXI_CONFIG_G => AXIS_32B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => sAxisClk,
         sAxisRst    => sAxisRst,
         sAxisMaster => pgpRxMaster,
         sAxisSlave  => pgpRxSlave,
         sAxisCtrl   => axisCtrl,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => rxMaster,
         mAxisSlave  => rxSlave);

   comb : process (axisCtrl, countRst, enHeaderCheck, mAxisRst, r, rxMaster,
                   trigLutOut, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Add registers to help with timing
      v.fifoError     := axisCtrl.overflow;
      v.trigLutDly(1) := trigLutOut;
      v.trigLutDly(0) := r.trigLutDly(1);
      v.vcPause       := axisCtrl.pause;

      -- Check for overflow strobe   
      if axisCtrl.overflow = '1' then
         -- Latch the error flag
         v.vcOverflow := '1';
      end if;

      -- Reset strobing signals
      v.eofe           := '0';
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
            -- Check if ready to move data 
            if (rxMaster.tValid = '1') then
               -- Check for SOF
               if ssiGetUserSof(AXIS_32B_CONFIG_C, rxMaster) = '1' then
                  -- Check we are are checking the header
                  if (enHeaderCheck = '1') then
                     -- Next state
                     v.state := RD_HDR0_S;
                  elsif (v.txMaster.tValid = '0') then
                     -- Accept the data
                     v.rxSlave.tReady := '1';
                     -- Write to the FIFO         
                     v.txMaster       := rxMaster;
                     -- Check for non-EOF
                     if rxMaster.tLast = '0' then
                        -- Next state
                        v.state := FWD_PAYLOAD_S;
                     end if;
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
               if (rxMaster.tLast = '1') then
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
               ssiSetUserSof(AXIS_32B_CONFIG_C, v.txMaster, '1');
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
               if rxMaster.tLast = '1' then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_32B_CONFIG_C, v.txMaster, '1');
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
               if rxMaster.tLast = '1' then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_32B_CONFIG_C, v.txMaster, '1');
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
               if rxMaster.tLast = '1' then
                  -- Set the EOF bit
                  v.txMaster.tLast := '1';
                  -- Set the EOFE bit
                  ssiSetUserEofe(AXIS_32B_CONFIG_C, v.txMaster, '1');
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
               -- Check for EOF
               if rxMaster.tLast = '1' then
                  -- Next state
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      if countRst = '1' then
         v.lutDropCnt := x"00";
      end if;

      -- Always 32-bit transactions
      v.txMaster.tKeep := (others => '1');

      -- Reset
      if (mAxisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      fifoError  <= r.fifoError;
      vcPause    <= r.vcPause;
      vcOverflow <= r.vcOverflow;
      trigLutIn  <= r.trigLutIn;
      lutDropCnt <= r.lutDropCnt;
      rxSlave    <= v.rxSlave;

   end process comb;

   seq : process (mAxisClk) is
   begin
      if rising_edge(mAxisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   U_Pipeline : entity work.AxiStreamPipeline
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1)
      port map (
         axisClk     => mAxisClk,
         axisRst     => mAxisRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

end rtl;
