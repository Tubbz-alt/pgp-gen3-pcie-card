-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : ClClk.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2015-01-30
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
use work.PgpCardG3Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity ClClk is
   generic (
      -- GTP Configurations
      GTP_RATE_G           : real;
      -- Quad PLL Configurations
      QPLL_FBDIV_IN_G      : integer;
      QPLL_FBDIV_45_IN_G   : integer;
      QPLL_REFCLK_DIV_IN_G : integer;
      -- MMCM Configurations
      MMCM_DIVCLK_DIVIDE_G : natural;
      MMCM_CLKFBOUT_MULT_G : real;
      MMCM_GTCLK_DIVIDE_G  : real;
      MMCM_CLCLK_DIVIDE_G  : natural;
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
      clRefClkP          : in  sl;
      clRefClkN          : in  sl;
      --Global Signals
      evrClk             : in  sl;
      evrRst             : in  sl;
      stableClk          : out sl;
      clClk              : out sl;
      clRst              : out sl); 
end ClClk;

-- Define architecture
architecture ClClk of ClClk is

   constant EVR_RATES_C : RealArray(0 to 1) := (1.0* EVR_RATE_C, 2.0* EVR_RATE_C);

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
      rst : sl := '0';
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
   clClk     <= clk;
   clRst     <= rst;

   -- GT Reference Clock
   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => clRefClkP,
         IB    => clRefClkN,
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

   RstSync_Inst : entity work.RstSync
      port map (
         clk      => clk,
         asyncRst => stableRst,
         syncRst  => rst);      

   -- Determine which PLL clock and PLL reset to use
   clkRef <= evrClk when((GTP_RATE_G = EVR_RATES_C(0)) or (GTP_RATE_G = EVR_RATES_C(1))) else stableClock;
   clkRst <= evrRst when((GTP_RATE_G = EVR_RATES_C(0)) or (GTP_RATE_G = EVR_RATES_C(1))) else '0';

   mmcm_adv_inst : MMCME2_ADV
      generic map(
         BANDWIDTH            => "LOW",
         CLKOUT4_CASCADE      => false,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => false,
         DIVCLK_DIVIDE        => 1,
         CLKFBOUT_MULT_F      => MMCM_CLKFBOUT_MULT_G,
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => false,
         CLKOUT0_DIVIDE_F     => MMCM_GTCLK_DIVIDE_G,
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => false,
         CLKOUT1_DIVIDE       => MMCM_CLCLK_DIVIDE_G,
         CLKOUT1_PHASE        => 0.000,
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_USE_FINE_PS  => false,
         CLKIN1_PERIOD        => MMCM_CLKIN_PERIOD_G,
         REF_JITTER1          => 0.006)
      port map(
         -- Output clocks
         CLKFBOUT     => clkFbOut,
         CLKFBOUTB    => open,
         CLKOUT0      => clkOut0,
         CLKOUT0B     => open,
         CLKOUT1      => clkOut1,
         CLKOUT1B     => open,
         CLKOUT2      => open,
         CLKOUT2B     => open,
         CLKOUT3      => open,
         CLKOUT3B     => open,
         CLKOUT4      => open,
         CLKOUT5      => open,
         CLKOUT6      => open,
         -- Input clock control
         CLKFBIN      => clkFbIn,
         CLKIN1       => clkRef,
         CLKIN2       => '0',
         -- Tied to always select the primary input clock
         CLKINSEL     => '1',
         -- Ports for dynamic reconfiguration
         DADDR        => (others => '0'),
         DCLK         => '0',
         DEN          => '0',
         DI           => (others => '0'),
         DO           => open,
         DRDY         => open,
         DWE          => '0',
         -- Ports for dynamic phase shift
         PSCLK        => '0',
         PSEN         => '0',
         PSINCDEC     => '0',
         PSDONE       => open,
         -- Other control and status signals
         LOCKED       => open,
         CLKINSTOPPED => open,
         CLKFBSTOPPED => open,
         PWRDWN       => '0',
         RST          => clkRst); 

   BUFH_Inst : BUFH
      port map (
         I => clkFbOut,
         O => clkFbIn); 

   BUFG_1 : BUFG
      port map (
         I => clkOut0,
         O => gtClk);

   BUFG_2 : BUFG
      port map (
         I => clkOut1,
         O => clk);         

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

end ClClk;
