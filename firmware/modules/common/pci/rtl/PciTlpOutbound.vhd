-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTlpOutbound.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-25
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
use work.PciPkg.all;

entity PciTlpOutbound is
   generic (
      TPD_G      : time := 1 ns;
      DMA_SIZE_G : positive);
   port (
      -- PCIe Interface
      sAsixHdr      : in  PciHdrType;
      sAxisMaster   : in  AxiStreamMasterType;
      sAxisSlave    : out AxiStreamSlaveType;
      -- Outbound DMA Interface
      regObMaster   : out AxiStreamMasterType;
      regObSlave    : in  AxiStreamSlaveType;
      dmaTxObMaster : out AxiStreamMasterArray(0 to DMA_SIZE_G-1);
      dmaTxObSlave  : in  AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      -- Global Signals
      pciClk        : in  sl;           --125 MHz
      pciRst        : in  sl);       
end PciTlpOutbound;

architecture rtl of PciTlpOutbound is

   type StateType is (
      IDLE_S,
      REG_S,
      DMA_S);   

   type RegType is record
      chPntr        : natural range 0 to DMA_SIZE_G-1;
      sAxisSlave    : AxiStreamSlaveType;
      regObMaster   : AxiStreamMasterType;
      dmaTxObMaster : AxiStreamMasterArray(0 to DMA_SIZE_G-1);
      state         : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      0,
      AXI_STREAM_SLAVE_INIT_C,
      AXI_STREAM_MASTER_INIT_C,
      (others => AXI_STREAM_MASTER_INIT_C),
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dmaTag     : slv(7 downto 0);
   signal dmaTagPntr : natural range 0 to 127;
   
begin

   dmaTag     <= sAxisMaster.tData(79 downto 72);
   dmaTagPntr <= conv_integer(dmaTag(7 downto 1));

   comb : process (dmaTag, dmaTagPntr, dmaTxObSlave, pciRst, r, regObSlave, sAsixHdr, sAxisMaster) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals   
      v.sAxisSlave.tReady := '0';
      ssiResetFlags(v.regObMaster);
      for i in 0 to DMA_SIZE_G-1 loop
         ssiResetFlags(v.dmaTxObMaster(i));
      end loop;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for valid data
            if (r.sAxisSlave.tReady = '0') and (sAxisMaster.tValid = '1') then
               -- Check for SOF and correct request ID
               if (sAxisMaster.tUser(1) = '1') then
                  -- Check for memory read or write always goes to reg block
                  if sAsixHdr.xType = "00000" then
                     -- Set the tReady flag
                     v.sAxisSlave.tReady := regObSlave.tReady;
                     -- Next state
                     v.state             := REG_S;
                  -- Else check for a a completion header with data payload and for TX DMA tag
                  elsif (sAsixHdr.xType = "01010") and (dmaTag(0) = '1') and (dmaTagPntr < DMA_SIZE_G) then
                     -- Set the channel pointer
                     v.chPntr            := dmaTagPntr;
                     -- Set the tReady flag
                     v.sAxisSlave.tReady := dmaTxObSlave(dmaTagPntr).tReady;
                     -- Next state
                     v.state             := DMA_S;
                  else
                     -- Blow off the data
                     v.sAxisSlave.tReady := '1';
                  end if;
               else
                  -- Blow off the data
                  v.sAxisSlave.tReady := '1';
               end if;
            end if;
         ----------------------------------------------------------------------
         when REG_S =>
            -- Set the ready flag
            v.sAxisSlave.tReady := regObSlave.tReady;
            -- Check for valid data 
            if (r.sAxisSlave.tReady = '1') and (sAxisMaster.tValid = '1') then
               -- Write to the FIFO
               v.regObMaster := sAxisMaster;
               -- Check for tLast
               if sAxisMaster.tLast = '1' then
                  -- Stop reading out the FIFO
                  v.sAxisSlave.tReady := '0';
                  -- Next state
                  v.state             := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DMA_S =>
            -- Set the ready flag
            v.sAxisSlave.tReady := dmaTxObSlave(r.chPntr).tReady;
            -- Check for valid data 
            if (r.sAxisSlave.tReady = '1') and (sAxisMaster.tValid = '1') then
               -- Write to the FIFO
               v.dmaTxObMaster(r.chPntr) := sAxisMaster;
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
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      sAxisSlave    <= r.sAxisSlave;
      dmaTxObMaster <= r.dmaTxObMaster;
      regObMaster   <= r.regObMaster;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
