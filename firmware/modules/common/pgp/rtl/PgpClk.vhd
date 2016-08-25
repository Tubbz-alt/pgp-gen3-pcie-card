-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpClk.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2016-08-25
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.PgpCardG3Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity PgpClk is
   generic (
      -- PGP Configurations
      PGP_RATE_G           : real;
      -- Quad PLL Configurations
      QPLL_FBDIV_IN_G      : integer;
      QPLL_FBDIV_45_IN_G   : integer;
      QPLL_REFCLK_DIV_IN_G : integer;
      -- MMCM Configurations
      MMCM_CLKFBOUT_MULT_G : real;
      MMCM_GTCLK_DIVIDE_G  : real;
      MMCM_PGPCLK_DIVIDE_G : natural;
      MMCM_CLKIN_PERIOD_G  : real);      
   port (
      -- GT Clocking
      westQPllRefClk     : out slv(1 downto 0);
      westQPllClk        : out slv(1 downto 0);
      westQPllLock       : out slv(1 downto 0);
      westQPllRefClkLost : out slv(1 downto 0);
      westQPllReset      : in  Slv2Array(0 to 3);
      westQPllRst        : in  slv(1 downto 0);
      eastQPllRefClk     : out slv(1 downto 0);
      eastQPllClk        : out slv(1 downto 0);
      eastQPllLock       : out slv(1 downto 0);
      eastQPllRefClkLost : out slv(1 downto 0);
      eastQPllReset      : in  Slv2Array(0 to 3);
      eastQPllRst        : in  slv(1 downto 0);
      -- GT CLK Pins
      pgpRefClkP         : in  sl;
      pgpRefClkN         : in  sl;
      --Global Signals
      evrClk             : in  sl;
      evrRst             : in  sl;
      pgpMmcmLocked      : out sl;
      stableClk          : out sl;
      pgpClk             : out sl;
      pgpRst             : out sl); 
end PgpClk;

-- Define architecture
architecture PgpClk of PgpClk is

   constant EVR_RATES_C : RealArray(0 to 1) := (
      getRealMult(1, EVR_RATE_C),
      getRealMult(2, EVR_RATE_C));

   signal gtClkDiv2,
      stableClock,
      stableRst,
      clkFbIn,
      clkFbOut,
      clkOut0,
      clkOut1,
      gtClk,
      clkRef,
      clkRst,
      clk,
      rst,
      gtRst : sl := '0';
   signal westPllRefClk,
      westPllReset,
      westPllRst,
      westPllLockDetClk,
      eastPllRefClk,
      eastPllReset,
      eastPllRst,
      eastPllLockDetClk : slv(1 downto 0) := "00";
   
begin

   stableClk <= stableClock;
   pgpClk    <= clk;
   pgpRst    <= rst;

   -- GT Reference Clock
   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => pgpRefClkP,
         IB    => pgpRefClkN,
         CEB   => '0',
         ODIV2 => gtClkDiv2,
         O     => open);

   BUFG_0 : BUFG
      port map (
         I => gtClkDiv2,
         O => stableClock);

   -- Power Up Reset      
   PwrUpRst_Inst : entity work.PwrUpRst
      generic map (
         DURATION_G => 125000000)    
      port map (
         clk    => stableClock,
         rstOut => stableRst);

   -- Determine which PLL clock and PLL reset to use
   clkRef <= evrClk when((PGP_RATE_G = EVR_RATES_C(0)) or (PGP_RATE_G = EVR_RATES_C(1))) else stableClock;
   clkRst <= evrRst when((PGP_RATE_G = EVR_RATES_C(0)) or (PGP_RATE_G = EVR_RATES_C(1))) else stableRst;

   U_MMCM : entity work.ClockManager7
      generic map(
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => true,
         RST_IN_POLARITY_G  => '1',
         NUM_CLOCKS_G       => 2,
         -- MMCM attributes
         BANDWIDTH_G        => "HIGH",
         CLKIN_PERIOD_G     => MMCM_CLKIN_PERIOD_G,
         DIVCLK_DIVIDE_G    => 1,
         CLKFBOUT_MULT_F_G  => MMCM_CLKFBOUT_MULT_G,
         CLKOUT0_DIVIDE_F_G => MMCM_GTCLK_DIVIDE_G,
         CLKOUT1_DIVIDE_G   => MMCM_PGPCLK_DIVIDE_G)
      port map(
         clkIn     => clkRef,
         rstIn     => clkRst,
         clkOut(0) => gtClk,
         clkOut(1) => clk,
         rstOut(0) => gtRst,
         rstOut(1) => rst,
         locked    => pgpMmcmLocked);         

   -- West QPLL 
   westPllRefClk     <= gtClk & gtClk;
   westPllLockDetClk <= stableClock & stableClock;
   westPllReset(0)   <= rst or westQPllRst(0) or westPllRst(0);  -- TX Reset
   westPllReset(1)   <= rst or westQPllRst(1);  -- RX Reset Note: Ignoring MGT's RX PLL resets because I don't want one reset to force the whole QUAD to reset

   westPllRst(0) <= westQPllReset(0)(0) or westQPllReset(1)(0) or westQPllReset(2)(0) or westQPllReset(3)(0);
   westPllRst(1) <= westQPllReset(0)(1) or westQPllReset(1)(1) or westQPllReset(2)(1) or westQPllReset(3)(1);

   Gtp7QuadPll_West : entity work.Gtp7QuadPll  --GTPE2_COMMON_X1Y0
      generic map (
         PLL0_REFCLK_SEL_G    => "111",
         PLL0_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         PLL0_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         PLL0_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G,
         PLL1_REFCLK_SEL_G    => "111",
         PLL1_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         PLL1_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         PLL1_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G)          
      port map (
         qPllRefClk     => westPllRefClk,
         qPllOutClk     => westQPllClk,
         qPllOutRefClk  => westQPllRefClk,
         qPllLock       => westQPllLock,
         qPllLockDetClk => westPllLockDetClk,
         qPllRefClkLost => westQPllRefClkLost,
         qPllReset      => westPllReset);  

   -- East QPLL 
   eastPllRefClk     <= gtClk & gtClk;
   eastPllLockDetClk <= stableClock & stableClock;
   eastPllReset(0)   <= rst or eastQPllRst(0) or eastPllRst(0);  -- TX Reset
   eastPllReset(1)   <= rst or eastQPllRst(1);  -- RX Reset Note: Ignoring MGT's RX PLL resets because I don't want one reset to force the whole QUAD to reset

   eastPllRst(0) <= eastQPllReset(0)(0) or eastQPllReset(1)(0) or eastQPllReset(2)(0) or eastQPllReset(3)(0);
   eastPllRst(1) <= eastQPllReset(0)(1) or eastQPllReset(1)(1) or eastQPllReset(2)(1) or eastQPllReset(3)(1);

   Gtp7QuadPll_East : entity work.Gtp7QuadPll  --GTPE2_COMMON_X0Y0
      generic map (
         PLL0_REFCLK_SEL_G    => "111",
         PLL0_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         PLL0_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         PLL0_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G,
         PLL1_REFCLK_SEL_G    => "111",
         PLL1_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         PLL1_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         PLL1_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G)   
      port map (
         qPllRefClk     => eastPllRefClk,
         qPllOutClk     => eastQPllClk,
         qPllOutRefClk  => eastQPllRefClk,
         qPllLock       => eastQPllLock,
         qPllLockDetClk => eastPllLockDetClk,
         qPllRefClkLost => eastQPllRefClkLost,
         qPllReset      => eastPllReset);

end PgpClk;
