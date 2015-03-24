-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpCardG3Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-29
-- Last update: 2015-03-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.PgpCardG3Pkg.all;

entity PgpCardG3Core is
   generic (
      -- PGP Configurations
      PGP_RATE_G           : real;
      -- MGT Configurations
      CLK_DIV_G            : integer;
      CLK25_DIV_G          : integer;
      RX_OS_CFG_G          : bit_vector;
      RXCDR_CFG_G          : bit_vector;
      RXLPM_INCM_CFG_G     : bit;
      RXLPM_IPCM_CFG_G     : bit;
      -- Quad PLL Configurations
      QPLL_FBDIV_IN_G      : integer;
      QPLL_FBDIV_45_IN_G   : integer;
      QPLL_REFCLK_DIV_IN_G : integer;
      -- MMCM Configurations
      MMCM_DIVCLK_DIVIDE_G : natural;
      MMCM_CLKFBOUT_MULT_G : real;
      MMCM_GTCLK_DIVIDE_G  : real;
      MMCM_PGPCLK_DIVIDE_G : natural;
      MMCM_CLKIN_PERIOD_G  : real);       
   port (
      -- FLASH Interface 
      flashAddr  : out   slv(25 downto 0);
      flashData  : inout slv(15 downto 0);
      flashAdv   : out   sl;
      flashCe    : out   sl;
      flashOe    : out   sl;
      flashWe    : out   sl;
      -- System Signals
      sysClk     : in    sl;
      led        : out   slv(7 downto 0);
      tieToGnd   : out   slv(3 downto 0);
      tieToVdd   : out   slv(0 downto 0);
      -- PCIe Ports
      pciRstL    : in    sl;
      pciRefClkP : in    sl;
      pciRefClkN : in    sl;
      pciRxP     : in    slv(3 downto 0);
      pciRxN     : in    slv(3 downto 0);
      pciTxP     : out   slv(3 downto 0);
      pciTxN     : out   slv(3 downto 0);
      -- EVR Ports
      evrRefClkP : in    sl;
      evrRefClkN : in    sl;
      evrRxP     : in    sl;
      evrRxN     : in    sl;
      evrTxP     : out   sl;
      evrTxN     : out   sl;
      -- PGP Ports
      pgpRefClkP : in    sl;
      pgpRefClkN : in    sl;
      pgpRxP     : in    slv(7 downto 0);
      pgpRxN     : in    slv(7 downto 0);
      pgpTxP     : out   slv(7 downto 0);
      pgpTxN     : out   slv(7 downto 0));
end PgpCardG3Core;

architecture rtl of PgpCardG3Core is

   signal stableClk,
      pgpClk,
      pgpRst,
      evrClk,
      evrRst,
      pciClk,
      pciRst,
      pciLinkUp : sl;
   signal pgpToPci : PgpToPciType;
   signal pciToPgp : PciToPgpType;
   signal evrToPci : EvrToPciType;
   signal pciToEvr : PciToEvrType;
   signal evrToPgp : EvrToPgpArray(0 to 7);

begin

   --led(0) <= uOr(EvrToPci.errorCnt);  
   ClkOutBufSingle_Inst : entity work.ClkOutBufSingle
      port map (
         clkIn  => evrClk,
         clkOut => led(0));   

   led(1) <= EvrToPci.linkUp;
   led(7) <= PciToEvr.countRst;
   led(2) <= PciToEvr.pllRst;
   led(3) <= PciToEvr.evrReset;
   led(4) <= PciToEvr.enable;

   led(5) <= not(pciRst);
   led(6) <= pciLinkUp;

   tieToGnd <= (others => '0');
   tieToVdd <= (others => '1');

   -----------
   -- PGP Core
   -----------
   PgpCore_Inst : entity work.PgpCore
      generic map (
         -- PGP Configurations
         PGP_RATE_G           => PGP_RATE_G,
         -- MGT Configurations
         CLK_DIV_G            => CLK_DIV_G,
         CLK25_DIV_G          => CLK25_DIV_G,
         RX_OS_CFG_G          => RX_OS_CFG_G,
         RXCDR_CFG_G          => RXCDR_CFG_G,
         RXLPM_INCM_CFG_G     => RXLPM_INCM_CFG_G,
         RXLPM_IPCM_CFG_G     => RXLPM_IPCM_CFG_G,
         -- Quad PLL Configurations
         QPLL_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         QPLL_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         QPLL_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G,
         -- MMCM Configurations
         MMCM_DIVCLK_DIVIDE_G => MMCM_DIVCLK_DIVIDE_G,
         MMCM_CLKFBOUT_MULT_G => MMCM_CLKFBOUT_MULT_G,
         MMCM_GTCLK_DIVIDE_G  => MMCM_GTCLK_DIVIDE_G,
         MMCM_PGPCLK_DIVIDE_G => MMCM_PGPCLK_DIVIDE_G,
         MMCM_CLKIN_PERIOD_G  => MMCM_CLKIN_PERIOD_G)  
      port map (
         -- Parallel Interface
         evrToPgp   => evrToPgp,
         pciToPgp   => pciToPgp,
         pgpToPci   => pgpToPci,
         -- PGP Fiber Links         
         pgpRefClkP => pgpRefClkP,
         pgpRefClkN => pgpRefClkN,
         pgpRxP     => pgpRxP,
         pgpRxN     => pgpRxN,
         pgpTxP     => pgpTxP,
         pgpTxN     => pgpTxN,
         -- Global Signals
         stableClk  => stableClk,
         pgpClk     => pgpClk,
         pgpRst     => pgpRst,
         evrClk     => evrClk,
         evrRst     => evrRst,
         pciClk     => pciClk,
         pciRst     => pciRst);       

   -----------
   -- EVR Core
   -----------
   EvrCore_Inst : entity work.EvrCore
      port map (
         -- External Interfaces
         pciToEvr   => pciToEvr,
         evrToPci   => evrToPci,
         evrToPgp   => evrToPgp,
         -- EVR Ports       
         evrRefClkP => evrRefClkP,
         evrRefClkN => evrRefClkN,
         evrRxP     => evrRxP,
         evrRxN     => evrRxN,
         evrTxP     => evrTxP,
         evrTxN     => evrTxN,
         -- Global Signals
         pgpClk     => pgpClk,
         pgpRst     => pgpRst,
         evrClk     => evrClk,
         evrRst     => evrRst,
         pciClk     => pciClk,
         pciRst     => pciRst);  

   ------------
   -- PCIe Core
   ------------
   PciCore_Inst : entity work.PciCore
      generic map (
         -- PGP Configurations
         PGP_RATE_G => PGP_RATE_G)      
      port map (
         -- FLASH Interface 
         flashAddr  => flashAddr,
         flashData  => flashData,
         flashAdv   => flashAdv,
         flashCe    => flashCe,
         flashOe    => flashOe,
         flashWe    => flashWe,
         -- Parallel Interface
         pgpToPci   => pgpToPci,
         pciToPgp   => pciToPgp,
         pciToEvr   => pciToEvr,
         evrToPci   => evrToPci,
         -- PCIe Ports      
         pciRstL    => pciRstL,
         pciRefClkP => pciRefClkP,
         pciRefClkN => pciRefClkN,
         pciRxP     => pciRxP,
         pciRxN     => pciRxN,
         pciTxP     => pciTxP,
         pciTxN     => pciTxN,
         pciLinkUp  => pciLinkUp,
         -- Global Signals
         pgpClk     => pgpClk,
         pgpRst     => pgpRst,
         evrClk     => evrClk,
         evrRst     => evrRst,
         pciClk     => pciClk,
         pciRst     => pciRst);  
end rtl;
