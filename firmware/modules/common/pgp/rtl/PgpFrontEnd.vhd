-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpFrontEnd.vhd
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

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;

entity PgpFrontEnd is
   generic (
      -- MGT Configurations
      CLK_DIV_G        : integer;
      CLK25_DIV_G      : integer;
      RX_OS_CFG_G      : bit_vector;
      RXCDR_CFG_G      : bit_vector;
      RXLPM_INCM_CFG_G : bit;
      RXLPM_IPCM_CFG_G : bit);    
   port (
      -- GT Clocking
      stableClk          : in  sl;
      westQPllRefClk     : in  slv(1 downto 0);
      westQPllClk        : in  slv(1 downto 0);
      westQPllLock       : in  slv(1 downto 0);
      westQPllRefClkLost : in  slv(1 downto 0);
      westQPllReset      : out Slv2Array(0 to 3);
      eastQPllRefClk     : in  slv(1 downto 0);
      eastQPllClk        : in  slv(1 downto 0);
      eastQPllLock       : in  slv(1 downto 0);
      eastQPllRefClkLost : in  slv(1 downto 0);
      eastQPllReset      : out Slv2Array(0 to 3);
      -- Clocking and Resets
      pgpClk             : in  sl;
      pgpTxRst           : in  slv(7 downto 0);
      pgpRxRst           : in  slv(7 downto 0);
      -- Non VC Rx Signals
      pgpRxIn            : in  Pgp2bRxInArray(0 to 7);
      pgpRxOut           : out Pgp2bRxOutArray(0 to 7);
      -- Non VC Tx Signals
      pgpTxIn            : in  Pgp2bTxInArray(0 to 7);
      pgpTxOut           : out Pgp2bTxOutArray(0 to 7);
      -- Frame Transmit Interface
      pgpTxMasters       : in  AxiStreamMasterVectorArray(0 to 7, 0 to 3);
      pgpTxSlaves        : out AxiStreamSlaveVectorArray(0 to 7, 0 to 3);
      -- Frame Receive Interface
      pgpRxMasters       : out AxiStreamMasterVectorArray(0 to 7, 0 to 3);
      pgpRxCtrl          : in  AxiStreamCtrlVectorArray(0 to 7, 0 to 3);
      -- PGP Fiber Links
      pgpRxP             : in  slv(7 downto 0);
      pgpRxN             : in  slv(7 downto 0);
      pgpTxP             : out slv(7 downto 0);
      pgpTxN             : out slv(7 downto 0));
end PgpFrontEnd;

architecture mapping of PgpFrontEnd is

   signal pgpRxReset : slv(7 downto 0);
   signal pgpRxMon   : Pgp2bRxOutArray(0 to 7);

begin

   GEN_WEST :
   for lane in 0 to 3 generate
      Pgp2bGtp7MultiLane_West : entity work.Pgp2bGtp7MultiLane
         generic map (
            -- CPLL Settings -
            RXOUT_DIV_G        => CLK_DIV_G,
            TXOUT_DIV_G        => CLK_DIV_G,
            RX_CLK25_DIV_G     => CLK25_DIV_G,
            TX_CLK25_DIV_G     => CLK25_DIV_G,
            RX_OS_CFG_G        => RX_OS_CFG_G,
            RXCDR_CFG_G        => RXCDR_CFG_G,
            RXLPM_INCM_CFG_G   => RXLPM_INCM_CFG_G,
            RXLPM_IPCM_CFG_G   => RXLPM_IPCM_CFG_G,
            -- Configure TX to be Fixed Latency
            TX_BUF_EN_G        => false,
            TX_OUTCLK_SRC_G    => "PLLREFCLK",
            TX_DLY_BYPASS_G    => '0',
            TX_PHASE_ALIGN_G   => "MANUAL",
            TX_BUF_ADDR_MODE_G => "FAST",
            -- Configure PLL sources
            TX_PLL_G           => "PLL0",
            RX_PLL_G           => "PLL1",
            -- PGP Settings
            VC_INTERLEAVE_G   => 0,
            PAYLOAD_CNT_TOP_G => 7,
            NUM_VC_EN_G       => 4,
            TX_ENABLE_G       => true,
            RX_ENABLE_G       => true)
         port map (
            -- GT Clocking
            stableClk        => stableClk,
            gtQPllOutRefClk  => westQPllRefClk,
            gtQPllOutClk     => westQPllClk,
            gtQPllLock       => westQPllLock,
            gtQPllRefClkLost => westQPllRefClkLost,
            gtQPllReset      => westQPllReset(lane),
            -- Gt Serial IO
            gtTxP(0)         => pgpTxP(lane),
            gtTxN(0)         => pgpTxN(lane),
            gtRxP(0)         => pgpRxP(lane),
            gtRxN(0)         => pgpRxN(lane),
            -- Tx Clocking
            pgpTxReset       => pgpTxRst(lane),
            pgpTxClk         => pgpClk,
            pgpTxMmcmReset   => open,
            pgpTxMmcmLocked  => '1',
            -- Rx clocking
            pgpRxReset       => pgpRxReset(lane),
            pgpRxRecClk      => open,
            pgpRxClk         => pgpClk,
            pgpRxMmcmReset   => open,
            pgpRxMmcmLocked  => '1',
            -- Non VC Rx Signals
            pgpRxIn          => pgpRxIn(lane),
            pgpRxOut         => pgpRxMon(lane),
            -- Non VC Tx Signals
            pgpTxIn          => pgpTxIn(lane),
            pgpTxOut         => pgpTxOut(lane),
            -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
            pgpTxMasters(0)  => pgpTxMasters(lane, 0),
            pgpTxMasters(1)  => pgpTxMasters(lane, 1),
            pgpTxMasters(2)  => pgpTxMasters(lane, 2),
            pgpTxMasters(3)  => pgpTxMasters(lane, 3),
            pgpTxSlaves(0)   => pgpTxSlaves(lane, 0),
            pgpTxSlaves(1)   => pgpTxSlaves(lane, 1),
            pgpTxSlaves(2)   => pgpTxSlaves(lane, 2),
            pgpTxSlaves(3)   => pgpTxSlaves(lane, 3),
            -- Frame Receive Interface - 1 Lane, Array of 4 VCs
            pgpRxMasters(0)  => pgpRxMasters(lane, 0),
            pgpRxMasters(1)  => pgpRxMasters(lane, 1),
            pgpRxMasters(2)  => pgpRxMasters(lane, 2),
            pgpRxMasters(3)  => pgpRxMasters(lane, 3),
            pgpRxMasterMuxed => open,
            pgpRxCtrl(0)     => pgpRxCtrl(lane, 0),
            pgpRxCtrl(1)     => pgpRxCtrl(lane, 1),
            pgpRxCtrl(2)     => pgpRxCtrl(lane, 2),
            pgpRxCtrl(3)     => pgpRxCtrl(lane, 3));  
   end generate GEN_WEST;

   GEN_EAST :
   for lane in 4 to 7 generate
      Pgp2bGtp7MultiLane_East : entity work.Pgp2bGtp7MultiLane
         generic map (
            -- CPLL Settings -
            RXOUT_DIV_G        => CLK_DIV_G,
            TXOUT_DIV_G        => CLK_DIV_G,
            RX_CLK25_DIV_G     => CLK25_DIV_G,
            TX_CLK25_DIV_G     => CLK25_DIV_G,
            RX_OS_CFG_G        => RX_OS_CFG_G,
            RXCDR_CFG_G        => RXCDR_CFG_G,
            RXLPM_INCM_CFG_G   => RXLPM_INCM_CFG_G,
            RXLPM_IPCM_CFG_G   => RXLPM_IPCM_CFG_G,
            -- Configure TX to be Fixed Latency
            TX_BUF_EN_G        => false,
            TX_OUTCLK_SRC_G    => "PLLREFCLK",
            TX_DLY_BYPASS_G    => '0',
            TX_PHASE_ALIGN_G   => "MANUAL",
            TX_BUF_ADDR_MODE_G => "FAST",
            -- Configure PLL sources
            TX_PLL_G           => "PLL0",
            RX_PLL_G           => "PLL1",
            -- PGP Settings
            VC_INTERLEAVE_G   => 0,
            PAYLOAD_CNT_TOP_G => 7,
            NUM_VC_EN_G       => 4,
            TX_ENABLE_G       => true,
            RX_ENABLE_G       => true)
         port map (
            -- GT Clocking
            stableClk        => stableClk,
            gtQPllOutRefClk  => eastQPllRefClk,
            gtQPllOutClk     => eastQPllClk,
            gtQPllLock       => eastQPllLock,
            gtQPllRefClkLost => eastQPllRefClkLost,
            gtQPllReset      => eastQPllReset(lane-4),
            -- Gt Serial IO
            gtTxP(0)         => pgpTxP(lane),
            gtTxN(0)         => pgpTxN(lane),
            gtRxP(0)         => pgpRxP(lane),
            gtRxN(0)         => pgpRxN(lane),
            -- Tx Clocking
            pgpTxReset       => pgpTxRst(lane),
            pgpTxClk         => pgpClk,
            pgpTxMmcmReset   => open,
            pgpTxMmcmLocked  => '1',
            -- Rx clocking
            pgpRxReset       => pgpRxReset(lane),
            pgpRxRecClk      => open,
            pgpRxClk         => pgpClk,
            pgpRxMmcmReset   => open,
            pgpRxMmcmLocked  => '1',
            -- Non VC Rx Signals
            pgpRxIn          => pgpRxIn(lane),
            pgpRxOut         => pgpRxMon(lane),
            -- Non VC Tx Signals
            pgpTxIn          => pgpTxIn(lane),
            pgpTxOut         => pgpTxOut(lane),
            -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
            pgpTxMasters(0)  => pgpTxMasters(lane, 0),
            pgpTxMasters(1)  => pgpTxMasters(lane, 1),
            pgpTxMasters(2)  => pgpTxMasters(lane, 2),
            pgpTxMasters(3)  => pgpTxMasters(lane, 3),
            pgpTxSlaves(0)   => pgpTxSlaves(lane, 0),
            pgpTxSlaves(1)   => pgpTxSlaves(lane, 1),
            pgpTxSlaves(2)   => pgpTxSlaves(lane, 2),
            pgpTxSlaves(3)   => pgpTxSlaves(lane, 3),
            -- Frame Receive Interface - 1 Lane, Array of 4 VCs
            pgpRxMasters(0)  => pgpRxMasters(lane, 0),
            pgpRxMasters(1)  => pgpRxMasters(lane, 1),
            pgpRxMasters(2)  => pgpRxMasters(lane, 2),
            pgpRxMasters(3)  => pgpRxMasters(lane, 3),
            pgpRxMasterMuxed => open,
            pgpRxCtrl(0)     => pgpRxCtrl(lane, 0),
            pgpRxCtrl(1)     => pgpRxCtrl(lane, 1),
            pgpRxCtrl(2)     => pgpRxCtrl(lane, 2),
            pgpRxCtrl(3)     => pgpRxCtrl(lane, 3)); 
   end generate GEN_EAST;

   GEN_WDT :
   for lane in 0 to 7 generate
      
      PgpLinkWatchDog_Inst : entity work.PgpLinkWatchDog
         port map (
            pgpRxIn     => pgpRxMon(lane),
            pgpRxOut    => pgpRxOut(lane),
            stableClk   => stableClk,
            pgpClk      => pgpClk,
            pgpRxRstIn  => pgpRxRst(lane),
            pgpRxRstOut => pgpRxReset(lane));           

   end generate GEN_WDT;
   
end mapping;
