-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2016-08-10
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
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.PgpCardG3Pkg.all;

entity PgpCore is
   generic (
      LSST_MODE_G          : boolean;
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
      -- Parallel Interface
      PciToPgp   : in  PciToPgpType;
      PgpToPci   : out PgpToPciType;
      evrToPgp   : in  EvrToPgpArray(0 to 7);
      -- GT Pins
      pgpRefClkP : in  sl;
      pgpRefClkN : in  sl;
      pgpRxP     : in  slv(7 downto 0);
      pgpRxN     : in  slv(7 downto 0);
      pgpTxP     : out slv(7 downto 0);
      pgpTxN     : out slv(7 downto 0);
      -- Global Signals
      stableClk  : out sl;
      pgpClk     : out sl;
      pgpRst     : out sl;
      evrClk     : in  sl;
      evrRst     : in  sl;
      pciClk     : in  sl;
      pciRst     : in  sl);      
end PgpCore;

architecture mapping of PgpCore is

   signal stableClock,
      locClk,
      locRst : sl := '0';
   
   signal westQPllRefClk,
      westQPllClk,
      westQPllLock,
      westQPllRefClkLost,
      westQPllRst,
      eastQPllRefClk,
      eastQPllClk,
      eastQPllLock,
      eastQPllRefClkLost,
      eastQPllRst,
      pllTxReady,
      pllRxReady,
      pllTxRst,
      pllRxRst : slv(1 downto 0);
   
   signal pgpTxRst,
      pgpRxRst : slv(7 downto 0);
   
   signal westQPllReset,
      eastQPllReset : Slv2Array(0 to 3);
   
   signal pgpRxIn  : Pgp2bRxInArray(0 to 7);
   signal pgpRxOut : Pgp2bRxOutArray(0 to 7);

   signal pgpTxIn  : Pgp2bTxInArray(0 to 7);
   signal pgpTxOut : Pgp2bTxOutArray(0 to 7);

   signal pgpTxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));
   signal pgpTxSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3)  := (others => (others => AXI_STREAM_SLAVE_FORCE_C));

   signal pgpRxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));
   signal pgpRxCtrl    : AxiStreamCtrlVectorArray(0 to 7, 0 to 3)   := (others => (others => AXI_STREAM_CTRL_UNUSED_C));

   signal dmaTxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));
   signal dmaTxSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3)  := (others => (others => AXI_STREAM_SLAVE_FORCE_C));

   signal dmaRxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));
   signal dmaRxCtrl    : AxiStreamCtrlVectorArray(0 to 7, 0 to 3)   := (others => (others => AXI_STREAM_CTRL_UNUSED_C));
   
begin

   stableClk <= stableClock;
   pgpClk    <= locClk;
   pgpRst    <= locRst;

   pllTxReady(0) <= westQPllLock(0);
   pllRxReady(0) <= westQPllLock(1);
   pllTxReady(1) <= eastQPllLock(0);
   pllRxReady(1) <= eastQPllLock(1);

   westQPllRst(0) <= pllTxRst(0);
   westQPllRst(1) <= pllRxRst(0);
   eastQPllRst(0) <= pllTxRst(1);
   eastQPllRst(1) <= pllRxRst(1);

   PgpClk_Inst : entity work.PgpClk
      generic map (
         -- PGP Configurations
         PGP_RATE_G           => PGP_RATE_G,
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
         -- GT Clocking PGP[3:0]
         westQPllRefClk     => westQPllRefClk,
         westQPllClk        => westQPllClk,
         westQPllLock       => westQPllLock,
         westQPllRefClkLost => westQPllRefClkLost,
         westQPllReset      => westQPllReset,
         westQPllRst        => westQPllRst,
         -- GT Clocking PGP[7:4]
         eastQPllRefClk     => eastQPllRefClk,
         eastQPllClk        => eastQPllClk,
         eastQPllLock       => eastQPllLock,
         eastQPllRefClkLost => eastQPllRefClkLost,
         eastQPllReset      => eastQPllReset,
         eastQPllRst        => eastQPllRst,
         -- GT CLK Pins
         pgpRefClkP         => pgpRefClkP,
         pgpRefClkN         => pgpRefClkN,
         -- Global Signals
         evrClk             => evrClk,
         evrRst             => evrRst,
         stableClk          => stableClock,
         pgpClk             => locClk,
         pgpRst             => locRst);    

   PgpFrontEnd_Inst : entity work.PgpFrontEnd
      generic map (
         LSST_MODE_G      => LSST_MODE_G,
         -- MGT Configurations
         CLK_DIV_G        => CLK_DIV_G,
         CLK25_DIV_G      => CLK25_DIV_G,
         RX_OS_CFG_G      => RX_OS_CFG_G,
         RXCDR_CFG_G      => RXCDR_CFG_G,
         RXLPM_INCM_CFG_G => RXLPM_INCM_CFG_G,
         RXLPM_IPCM_CFG_G => RXLPM_IPCM_CFG_G)          
      port map (
         -- GT Clocking
         stableClk          => stableClock,
         westQPllRefClk     => westQPllRefClk,
         westQPllClk        => westQPllClk,
         westQPllLock       => westQPllLock,
         westQPllRefClkLost => westQPllRefClkLost,
         westQPllReset      => westQPllReset,
         eastQPllRefClk     => eastQPllRefClk,
         eastQPllClk        => eastQPllClk,
         eastQPllLock       => eastQPllLock,
         eastQPllRefClkLost => eastQPllRefClkLost,
         eastQPllReset      => eastQPllReset,
         -- Clocking and Resets
         pgpClk             => locClk,
         pgpRxRst           => pgpRxRst,
         pgpTxRst           => pgpTxRst,
         -- Non VC Rx Signals
         pgpRxIn            => pgpRxIn,
         pgpRxOut           => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn            => pgpTxIn,
         pgpTxOut           => pgpTxOut,
         -- Frame Transmit Interface
         pgpTxMasters       => pgpTxMasters,
         pgpTxSlaves        => pgpTxSlaves,
         -- Frame Receive Interface
         pgpRxMasters       => pgpRxMasters,
         pgpRxCtrl          => pgpRxCtrl,
         -- PGP Fiber Links
         pgpRxP             => pgpRxP,
         pgpRxN             => pgpRxN,
         pgpTxP             => pgpTxP,
         pgpTxN             => pgpTxN);        

   NORMAL_BUILD : if (LSST_MODE_G = false) generate
      pgpTxMasters <= dmaTxMasters;
      dmaTxSlaves  <= pgpTxSlaves;
      dmaRxMasters <= pgpRxMasters;
      pgpRxCtrl    <= dmaRxCtrl;
   end generate;

   LSST_BUILD : if (LSST_MODE_G = true) generate
      GEN_MAP :
      for i in 0 to 3 generate

         -- PGP.LANE[0].VC[0] = DMA.LANE[0].VC[0]
         pgpTxMasters((2*i)+0, 0) <= dmaTxMasters((2*i)+0, 0);
         dmaTxSlaves((2*i)+0, 0)  <= pgpTxSlaves((2*i)+0, 0);

         -- PGP.LANE[0].VC[1] = DMA.LANE[1].VC[0]
         pgpTxMasters((2*i)+0, 1) <= dmaTxMasters((2*i)+1, 0);
         dmaTxSlaves((2*i)+1, 0)  <= pgpTxSlaves((2*i)+0, 1);

         -- DMA.LANE[0].VC[0] = PGP.LANE[0].VC[0]
         dmaRxMasters((2*i)+0, 0) <= pgpRxMasters((2*i)+0, 0);
         pgpRxCtrl((2*i)+0, 0)    <= dmaRxCtrl((2*i)+0, 0);

         -- DMA.LANE[1].VC[0] = PGP.LANE[0].VC[1]
         dmaRxMasters((2*i)+1, 0) <= pgpRxMasters((2*i)+0, 1);
         pgpRxCtrl((2*i)+0, 1)    <= dmaRxCtrl((2*i)+1, 0);
         
      end generate GEN_MAP;
   end generate;

   PgpApp_Inst : entity work.PgpApp
      generic map (
         PGP_RATE_G => PGP_RATE_G)
      port map (
         -- External Interfaces
         PciToPgp     => PciToPgp,
         PgpToPci     => PgpToPci,
         EvrToPgp     => EvrToPgp,
         -- Non VC Rx Signals
         pgpRxIn      => pgpRxIn,
         pgpRxOut     => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn      => pgpTxIn,
         pgpTxOut     => pgpTxOut,
         -- Frame Transmit Interface
         pgpTxMasters => dmaTxMasters,
         pgpTxSlaves  => dmaTxSlaves,
         -- Frame Receive Interface
         pgpRxMasters => dmaRxMasters,
         pgpRxCtrl    => dmaRxCtrl,
         -- PLL Status
         pllTxReady   => pllTxReady,
         pllRxReady   => pllRxReady,
         pllTxRst     => pllTxRst,
         pllRxRst     => pllRxRst,
         pgpRxRst     => pgpRxRst,
         pgpTxRst     => pgpTxRst,
         -- Global Signals
         pgpClk       => locClk,
         pgpRst       => locRst,
         evrClk       => evrClk,
         evrRst       => evrRst,
         pciClk       => pciClk,
         pciRst       => pciRst); 

end mapping;
