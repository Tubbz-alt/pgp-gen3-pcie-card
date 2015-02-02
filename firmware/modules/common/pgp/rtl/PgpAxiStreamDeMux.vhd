-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpAxiStreamDeMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-11
-- Last update: 2014-07-31
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
use work.Pgp2bPkg.all;

entity PgpAxiStreamDeMux is
   generic (
      TPD_G         : time                  := 1 ns;
      NUM_MASTERS_G : integer range 1 to 32 := 4); 
   port (
      -- Clock and reset
      axisClk       : in  sl;
      axisRst       : in  sl;
      -- Slave
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;
      -- Masters
      mAxisMasters : out AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
      mAxisSlaves  : in  AxiStreamSlaveArray(NUM_MASTERS_G-1 downto 0));
end PgpAxiStreamDeMux;

architecture structure of PgpAxiStreamDeMux is

   type StateType is (
      IDLE_S,
      DEMUX_S); 

   type RegType is record
      chPntr       : natural range 0 to NUM_MASTERS_G-1;
      mAxisMasters : AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
      sAxisSlave   : AxiStreamSlaveType;
      state        : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      0,
      (others => AXI_STREAM_MASTER_INIT_C),
      AXI_STREAM_SLAVE_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (mAxisSlaves, axisRst, r, sAxisMaster) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals   
      v.sAxisSlave.tReady := '0';
      for i in 0 to NUM_MASTERS_G-1 loop
         ssiResetFlags(v.mAxisMasters(i));
      end loop;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for valid data
            if (r.sAxisSlave.tReady = '0') and (sAxisMaster.tValid = '1') then
               -- Check for SOF bit
               if (ssiGetUserSof(SSI_PGP2B_CONFIG_C, sAxisMaster) = '1') then
                  -- Set the ready flag
                  v.sAxisSlave.tReady := mAxisSlaves(conv_integer(sAxisMaster.tDest)).tReady;
                  -- Decode destination
                  v.chPntr            := conv_integer(sAxisMaster.tDest);
                  -- Next state
                  v.state             := DEMUX_S;
               else
                  -- Blow of the data
                  v.sAxisSlave.tReady := '1';
               end if;
            end if;
         ----------------------------------------------------------------------
         when DEMUX_S =>
            -- Set the ready flag
            v.sAxisSlave.tReady := mAxisSlaves(r.chPntr).tReady;
            -- Check for valid data 
            if (r.sAxisSlave.tReady = '1') and (sAxisMaster.tValid = '1') then
               -- Write to the FIFO
               v.mAxisMasters(r.chPntr) := sAxisMaster;
               -- Check for tLast
               if sAxisMaster.tLast = '1' then
                  -- Stop reading out the FIFO
                  v.sAxisSlave.tReady := '0';
                  -- Next state
                  v.state             := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxisSlave   <= r.sAxisSlave;
      mAxisMasters <= r.mAxisMasters;
      
   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end structure;
