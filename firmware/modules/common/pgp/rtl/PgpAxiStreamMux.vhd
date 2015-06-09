-------------------------------------------------------------------------------
-- Title      : AXI Stream Multiplexer
-- Project    : General Purpose Core
-------------------------------------------------------------------------------
-- File       : PgpAxiStreamMux.vhd
-- Author     : Ryan Herbst, rherbst@slac.stanford.edu
-- Created    : 2014-04-25
-- Last update: 2015-06-07
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- Block to connect multiple incoming AXI streams into a single encoded
-- outbound stream. The destination field is updated accordingly.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/25/2014: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity PgpAxiStreamMux is
   generic (
      TPD_G        : time     := 1 ns;
      NUM_SLAVES_G : positive := 4);
   port (
      -- Clock and reset
      axisClk      : in  sl;
      axisRst      : in  sl;
      -- Slaves
      sAxisMasters : in  AxiStreamMasterArray(NUM_SLAVES_G-1 downto 0);
      sAxisSlaves  : out AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      -- Master
      mAxisMaster  : out AxiStreamMasterType;
      mAxisSlave   : in  AxiStreamSlaveType);
end PgpAxiStreamMux;

architecture rtl of PgpAxiStreamMux is

   type StateType is (
      IDLE_S,
      MOVE_S);

   type RegType is record
      cnt         : natural range 0 to NUM_SLAVES_G-1;
      index       : natural range 0 to NUM_SLAVES_G-1;
      sAxisSlaves : AxiStreamSlaveArray(NUM_SLAVES_G-1 downto 0);
      mAxisMaster : AxiStreamMasterType;
      state       : StateType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      cnt         => 0,
      index       => 0,
      sAxisSlaves => (others => AXI_STREAM_SLAVE_INIT_C),
      mAxisMaster => AXI_STREAM_MASTER_INIT_C,
      state       => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axisRst, mAxisSlave, r, sAxisMasters) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value   
      v := r;

      -- Loop through the incoming channels
      for i in 0 to (NUM_SLAVES_G-1) loop
         -- Reset the strobing signals
         v.sAxisSlaves(i).tReady := '0';
      end loop;
      
      -- Update tValid register
      if mAxisSlave.tReady = '1' then
         v.mAxisMaster.tValid := '0';
      end if;      

      -- State machine
      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Increment the counter
            if r.cnt = (NUM_SLAVES_G-1) then
               v.cnt := 0;
            else
               v.cnt := r.cnt + 1;
            end if;
            -- Check if we need to move data
            if (v.mAxisMaster.tValid = '0') and (sAxisMasters(r.cnt).tValid = '1') then
               -- Accept the data
               v.sAxisSlaves(r.cnt).tReady := '1';
               -- Set the bus
               v.mAxisMaster               := sAxisMasters(r.cnt);
               -- Overwrite tDest
               v.mAxisMaster.tDest         := toSlv(r.cnt, 8);
               -- Latch the index pointer
               v.index                     := r.cnt;
               -- Check for no tLast
               if sAxisMasters(r.cnt).tLast = '0' then
                  -- Next State
                  v.state := MOVE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when MOVE_S =>
            -- Check if we need to move data
            if (v.mAxisMaster.tValid = '0') and (sAxisMasters(r.index).tValid = '1') then
               -- Accept the data
               v.sAxisSlaves(r.index).tReady := '1';
               -- Set the bus
               v.mAxisMaster                 := sAxisMasters(r.index);
               -- Overwrite tDest
               v.mAxisMaster.tDest           := toSlv(r.index, 8);
               -- Check for tLast
               if sAxisMasters(r.index).tLast = '1' then
                  -- Next State
                  v.state := IDLE_S;
               end if;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxisSlaves <= v.sAxisSlaves;
      mAxisMaster <= r.mAxisMaster;

   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
