-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciRxDmaTb.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory 
-- Created    : 2014-06-22
-- Last update: 2016-08-25
-- Platform   :   
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation testbed for AtlasAsmPackFexHitDetComparator.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory 
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;

entity PciRxDmaTb is end PciRxDmaTb;

architecture testbed of PciRxDmaTb is

   constant LOC_CLK_PERIOD_C : time := 10 ns;
   constant TPD_C            : time := LOC_CLK_PERIOD_C/4;

   constant MAX_CNT_C   : slv(31 downto 0) := toSlv(100, 32);
   constant MAX_FRAME_C : slv(23 downto 0) := toSlv(300, 24);

   signal clk,
      rst : sl := '0';
   
   
   type RegType is record
      dmaDescFromPci : DescFromPci;
      dmaTranFromPci : TranFromPci;
      mAxisSlave     : AxiStreamSlaveType;
      cnt            : slv(31 downto 0);
      sAxisMaster    : AxiStreamMasterType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      DESC_FROM_PCI_INIT_C,
      TRAN_FROM_PCI_INIT_C,
      AXI_STREAM_SLAVE_INIT_C,
      (others => '0'),
      AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sAxisSlave   : AxiStreamSlaveType;
   signal mAxisMaster  : AxiStreamMasterType;
   signal dmaDescToPci : DescToPci;
   
begin

   -- Generate clocks and resets
   ClkRst_loc : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => LOC_CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,     -- Wait this long into simulation before asserting reset
         RST_HOLD_TIME_G   => 200 ns)   -- Hold reset for this long)
      port map (
         clkP => clk,
         clkN => open,
         rst  => rst,
         rstL => open);  

   PciRxDma_Inst : entity work.PciRxDma
      generic map (
         TPD_G => TPD_C)   
      port map (
         -- 32-bit Streaming RX Interface
         sAxisClk       => clk,
         sAxisRst       => rst,
         sAxisMaster    => r.sAxisMaster,
         sAxisSlave     => sAxisSlave,
         -- 128-bit Streaming TX Interface
         pciClk         => clk,
         pciRst         => rst,
         mAxisMaster    => mAxisMaster,
         mAxisSlave     => r.mAxisSlave,
         dmaTranFromPci => r.dmaTranFromPci,
         dmaDescToPci   => dmaDescToPci,
         dmaDescFromPci => r.dmaDescFromPci,
         dmaChannel     => x"0");        

   
   comb : process (r, rst, sAxisSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      ssiResetFlags(v.sAxisMaster);

      -- Always ready for data
      v.mAxisSlave.tReady := '1';

      -- Setup the descriptor
      v.dmaDescFromPci.newAck     := '1';
      v.dmaDescFromPci.newAddr    := (others => '0');
      v.dmaDescFromPci.newLength  := (others => '0');  -- TX only
      v.dmaDescFromPci.newControl := (others => '0');  -- TX only
      v.dmaDescFromPci.doneAck    := '1';
      v.dmaDescFromPci.maxFrame   := MAX_FRAME_C;

      -- Check if FIFO is ready
      if (sAxisSlave.tReady = '1') then
         if r.cnt = 0 then
            v.cnt                            := r.cnt + 1;
            v.sAxisMaster.tValid             := '1';
            ssiSetUserSof(AXIS_32B_CONFIG_C, v.sAxisMaster, '1');
            v.sAxisMaster.tData(31 downto 0) := r.cnt;
         elsif r.cnt < (MAX_CNT_C-1) then
            v.cnt                            := r.cnt + 1;
            v.sAxisMaster.tValid             := '1';
            v.sAxisMaster.tData(31 downto 0) := r.cnt;
         elsif r.cnt = (MAX_CNT_C-1) then
            v.cnt                            := r.cnt + 1;
            v.sAxisMaster.tValid             := '1';
            v.sAxisMaster.tLast              := '1';
            ssiSetUserEofe(AXIS_32B_CONFIG_C, v.sAxisMaster, '0');
            v.sAxisMaster.tData(31 downto 0) := r.cnt;
         else
            null;
         end if;
      end if;

      -- Reset
      if (rst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
      
   end process comb;

   seq : process (clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_C;
      end if;
   end process seq;
   
end testbed;
