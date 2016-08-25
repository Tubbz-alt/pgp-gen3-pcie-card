-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTxDmaFifoTb.vhd
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
use work.Pgp2bPkg.all;

entity PciTxDmaFifoTb is end PciTxDmaFifoTb;

architecture testbed of PciTxDmaFifoTb is

   constant LOC_CLK_PERIOD_C : time := 10 ns;
   constant TPD_C            : time := LOC_CLK_PERIOD_C/4;

   constant MAX_CNT_C : slv(31 downto 0) := toSlv(4, 32);

   type RegType is record
      mAxisSlave  : AxiStreamSlaveType;
      cnt         : natural;
      sAxisMaster : AxiStreamMasterType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      AXI_STREAM_SLAVE_INIT_C,
      0,
      AXI_STREAM_MASTER_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal sAxisSlave : AxiStreamSlaveType;
   signal axisMaster : AxiStreamMasterType;
   signal axisSlave  : AxiStreamSlaveType;
   signal pgpMaster  : AxiStreamMasterType;

   signal clk,
      rst : sl := '0';
   
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


   PciTxDmaFifoMux_Inst : entity work.PciTxDmaFifoMux
      generic map (
         TPD_G => TPD_C)
      port map (
         -- Slave Port
         pciClk      => clk,
         pciRst      => rst,
         sAxisMaster => r.sAxisMaster,
         sAxisSlave  => sAxisSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => axisMaster,
         mAxisSlave  => axisSlave);             

   SsiFifo_TX : entity work.SsiFifo
      generic map (
         -- General Configurations         
         TPD_G               => TPD_C,
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
         SLAVE_AXI_CONFIG_G  => AXIS_32B_CONFIG_C,
         MASTER_AXI_CONFIG_G => AXIS_16B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => clk,
         sAxisRst    => rst,
         sAxisMaster => axisMaster,
         sAxisSlave  => axisSlave,
         -- Master Port
         mAxisClk    => clk,
         mAxisRst    => rst,
         mAxisMaster => pgpMaster,
         mAxisSlave  => AXI_STREAM_SLAVE_FORCE_C);            

   comb : process (r, rst, sAxisSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.sAxisMaster.tData := (others => '0');
      ssiResetFlags(v.sAxisMaster);

      -- Always ready for data
      v.mAxisSlave.tReady := '1';

      -- Check if FIFO is ready
      if (sAxisSlave.tReady = '1') then
         if r.cnt = 0 then
            -- Increment the counter
            v.cnt                := r.cnt + 1;
            -- Write to the FIFO
            v.sAxisMaster.tValid := '1';
            ssiSetUserSof(AXIS_PCIE_MUX_CONFIG_C, v.sAxisMaster, '1');
            v.sAxisMaster.tData  := (others => '1');
            v.sAxisMaster.tKeep  := x"000F";
            -- Check for last write
            if r.cnt = (MAX_CNT_C-1) then
               v.sAxisMaster.tLast := '1';
            end if;
         elsif r.cnt < (MAX_CNT_C-1) then
            -- Increment the counter
            v.cnt                := r.cnt + 1;
            -- Write to the FIFO
            v.sAxisMaster.tValid := '1';
            v.sAxisMaster.tKeep  := x"FFFF";
            for i in 0 to 7 loop
               v.sAxisMaster.tData((i*16)+15 downto (i*16)) := toSlv((8*r.cnt)+i-8, 16);
            end loop;
         elsif r.cnt = (MAX_CNT_C-1) then
            -- Increment the counter
            v.cnt                              := r.cnt + 1;
            -- Write to the FIFO
            v.sAxisMaster.tValid               := '1';
            v.sAxisMaster.tLast                := '1';
            v.sAxisMaster.tKeep                := x"00FF";
            v.sAxisMaster.tData(31 downto 0)   := x"11111111";
            v.sAxisMaster.tData(63 downto 32)  := x"22222222";
            v.sAxisMaster.tData(95 downto 64)  := x"33333333";
            v.sAxisMaster.tData(127 downto 96) := x"44444444";
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
