-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpAxiStreamDeMux.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-11
-- Last update: 2015-06-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;

entity PgpAxiStreamDeMux is
   generic (
      TPD_G         : time     := 1 ns;
      NUM_MASTERS_G : positive := 4); 
   port (
      -- Clock and reset
      axisClk      : in  sl;
      axisRst      : in  sl;
      -- Slave
      sAxisMaster  : in  AxiStreamMasterType;
      sAxisSlave   : out AxiStreamSlaveType;
      -- Masters
      mAxisMasters : out AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
      mAxisSlaves  : in  AxiStreamSlaveArray(NUM_MASTERS_G-1 downto 0));
end PgpAxiStreamDeMux;

architecture rtl of PgpAxiStreamDeMux is

   type RegType is record
      mAxisMasters : AxiStreamMasterArray(NUM_MASTERS_G-1 downto 0);
      sAxisSlave   : AxiStreamSlaveType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      mAxisMasters => (others => AXI_STREAM_MASTER_INIT_C),
      sAxisSlave   => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   comb : process (axisRst, mAxisSlaves, r, sAxisMaster) is
      variable v   : RegType;
      variable i : natural;
      variable idx : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals   
      v.sAxisSlave.tReady := '0';
      
      -- Decode destination
      idx := conv_integer(sAxisMaster.tDest);      

      -- Loop through the channels
      for i in 0 to NUM_MASTERS_G-1 loop

         -- Update tValid register      
         if mAxisSlaves(i).tReady = '1' then
            v.mAxisMasters(i).tValid := '0';
         end if;

         -- Check the destination
         if idx = i then
            -- Check if ready to move data 
            if (v.mAxisMasters(i).tValid = '0') and (sAxisMaster.tValid = '1') then
               -- Accept for data
               v.sAxisSlave.tReady := '1';
               -- Latch the bus
               v.mAxisMasters(i)   := sAxisMaster;
            end if;
         end if;
         
      end loop;

      -- Reset
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxisSlave   <= v.sAxisSlave;
      mAxisMasters <= r.mAxisMasters;
      
   end process comb;

   seq : process (axisClk) is
   begin
      if (rising_edge(axisClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
