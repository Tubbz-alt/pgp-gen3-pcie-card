-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpCardG3_4p760Gbps.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-28
-- Last update: 2016-08-10
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

-------------------------------------------------------------------------------
-- Select the PGP configuration package here
-------------------------------------------------------------------------------
use work.Pgp4p760GbpsPkg.all;

entity PgpCardG3_4p760Gbps is
   port (
      -- FLASH Interface 
      flashAddr  : out   slv(25 downto 0);
      flashData  : inout slv(15 downto 0);
      flashAdv   : out   sl;
      flashCe    : out   sl;
      flashOe    : out   sl;
      flashWe    : out   sl;
      -- System Signals
      sysClk     : in    sl;            -- 50 MHz
      led        : out   slv(7 downto 0);
      tieToGnd   : out   slv(5 downto 0);
      tieToVdd   : out   slv(0 downto 0);
      -- PCIe Ports
      pciRstL    : in    sl;
      pciRefClkP : in    sl;            -- 100 MHz
      pciRefClkN : in    sl;            -- 100 MHz
      pciRxP     : in    slv(3 downto 0);
      pciRxN     : in    slv(3 downto 0);
      pciTxP     : out   slv(3 downto 0);
      pciTxN     : out   slv(3 downto 0);
      -- EVR Ports
      evrRefClkP : in    sl;            -- 238 MHz
      evrRefClkN : in    sl;            -- 238 MHz
      evrRxP     : in    sl;
      evrRxN     : in    sl;
      evrTxP     : out   sl;
      evrTxN     : out   sl;
      -- PGP Ports
      pgpRefClkP : in    sl;            -- 250 MHz
      pgpRefClkN : in    sl;            -- 250 MHz
      pgpRxP     : in    slv(7 downto 0);
      pgpRxN     : in    slv(7 downto 0);
      pgpTxP     : out   slv(7 downto 0);
      pgpTxN     : out   slv(7 downto 0));
end PgpCardG3_4p760Gbps;

architecture top_level of PgpCardG3_4p760Gbps is

begin

   PgpCardG3Core_Inst : entity work.PgpCardG3Core
      generic map (
         LSST_MODE_G          => false,
         -- PGP Configurations
         PGP_RATE_G           => PGP_RATE_C,
         -- MGT Configurations
         CLK_DIV_G            => CLK_DIV_C,
         CLK25_DIV_G          => CLK25_DIV_C,
         RX_OS_CFG_G          => RX_OS_CFG_C,
         RXCDR_CFG_G          => RXCDR_CFG_C,
         RXLPM_INCM_CFG_G     => RXLPM_INCM_CFG_C,
         RXLPM_IPCM_CFG_G     => RXLPM_IPCM_CFG_C,
         -- Quad PLL Configurations
         QPLL_FBDIV_IN_G      => QPLL_FBDIV_IN_C,
         QPLL_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_C,
         QPLL_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_C,
         -- MMCM Configurations
         MMCM_DIVCLK_DIVIDE_G => MMCM_DIVCLK_DIVIDE_C,
         MMCM_CLKFBOUT_MULT_G => MMCM_CLKFBOUT_MULT_C,
         MMCM_GTCLK_DIVIDE_G  => MMCM_GTCLK_DIVIDE_C,
         MMCM_PGPCLK_DIVIDE_G => MMCM_PGPCLK_DIVIDE_C,
         MMCM_CLKIN_PERIOD_G  => MMCM_CLKIN_PERIOD_C) 
      port map (
         -- FLASH Interface 
         flashAddr  => flashAddr,
         flashData  => flashData,
         flashAdv   => flashAdv,
         flashCe    => flashCe,
         flashOe    => flashOe,
         flashWe    => flashWe,
         -- System Signals
         sysClk     => sysClk,
         led        => led,
         tieToGnd   => tieToGnd,
         tieToVdd   => tieToVdd,
         -- PCIe Ports
         pciRstL    => pciRstL,
         pciRefClkP => pciRefClkP,
         pciRefClkN => pciRefClkN,
         pciRxP     => pciRxP,
         pciRxN     => pciRxN,
         pciTxP     => pciTxP,
         pciTxN     => pciTxN,
         -- EVR Ports
         evrRefClkP => evrRefClkP,
         evrRefClkN => evrRefClkN,
         evrRxP     => evrRxP,
         evrRxN     => evrRxN,
         evrTxP     => evrTxP,
         evrTxN     => evrTxN,
         -- PGP Ports
         pgpRefClkP => pgpRefClkP,
         pgpRefClkN => pgpRefClkN,
         pgpRxP     => pgpRxP,
         pgpRxN     => pgpRxN,
         pgpTxP     => pgpTxP,
         pgpTxN     => pgpTxN);      

end top_level;
