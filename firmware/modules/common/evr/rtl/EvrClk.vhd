-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrClk.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-24
-- Last update: 2014-07-09
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity EvrClk is
   port (
      -- GT Clocking
      qPllRefClk     : out slv(1 downto 0);
      qPllClk        : out slv(1 downto 0);
      qPllLock       : out slv(1 downto 0);
      qPllRst        : in  slv(1 downto 0);
      qPllRefClkLost : out slv(1 downto 0);
      -- GT CLK Pins
      evrRefClkP     : in  sl;
      evrRefClkN     : in  sl;
      -- Reference Clock
      stableClk      : out  sl);
end EvrClk;

architecture mapping of EvrClk is

   signal refClk        : sl;
   signal refClk119MHz  : sl;
   signal pllRefClk     : slv(1 downto 0);
   signal pllReset      : slv(1 downto 0);
   signal pllLockDetClk : slv(1 downto 0);

begin

   stableClk <= refClk119MHz;

   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => evrRefClkP,
         IB    => evrRefClkN,
         CEB   => '0',
         ODIV2 => refClk,
         O     => open);   
         
   BUFG_Inst : BUFG
      port map (
         I => refClk,
         O => refClk119MHz);         
         
   pllRefClk(0) <= refClk119MHz;
   pllRefClk(1) <= refClk119MHz;

   pllLockDetClk(0) <= refClk119MHz;
   pllLockDetClk(1) <= refClk119MHz;

   pllReset(0) <= qPllRst(0);
   pllReset(1) <= qPllRst(1);

   Gtp7QuadPll_Inst : entity work.Gtp7QuadPll
      generic map (
         PLL0_REFCLK_SEL_G    => "111",  -- Figure 2-6 of UG482
         PLL0_FBDIV_IN_G      => 4,      -- 119 MHz clock reference
         PLL0_FBDIV_45_IN_G   => 5,
         PLL0_REFCLK_DIV_IN_G => 1,
         PLL1_REFCLK_SEL_G    => "111",  -- Figure 2-6 of UG482
         PLL1_FBDIV_IN_G      => 4,      -- 119 MHz clock reference
         PLL1_FBDIV_45_IN_G   => 5,
         PLL1_REFCLK_DIV_IN_G => 1)         
      port map (
         qPllRefClk     => pllRefClk,
         qPllOutClk     => qPllClk,
         qPllOutRefClk  => qPllRefClk,
         qPllLock       => qPllLock,
         qPllLockDetClk => pllLockDetClk,
         qPllRefClkLost => qPllRefClkLost,
         qPllReset      => pllReset);  
         
end mapping;
