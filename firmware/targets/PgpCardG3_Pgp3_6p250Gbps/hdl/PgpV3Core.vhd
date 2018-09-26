-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpV3Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2018-09-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC PGP Gen3 Card'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC PGP Gen3 Card', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.Pgp3Pkg.all;
use work.AxiStreamPkg.all;
use work.PgpCardG3Pkg.all;

entity PgpV3Core is
   generic (
      DMA_LOOPBACK_G : boolean := false);
   port (
      -- Parallel Interface
      PciToPgp   : in  PciToPgpType;
      PgpToPci   : out PgpToPciType;
      evrToPgp   : in  EvrToPgpArray(0 to 7);
      -- GT Pins
      pgpRefClkP : in  sl;
      pgpRefClkN : in  sl;
      pgpRxP     : in  slv(1 downto 0);
      pgpRxN     : in  slv(1 downto 0);
      pgpTxP     : out slv(1 downto 0);
      pgpTxN     : out slv(1 downto 0);
      -- Global Signals
      pgpClk     : out slv(7 downto 0);
      pgpRst     : out slv(7 downto 0);
      evrClk     : in  sl;
      evrRst     : in  sl;
      pciClk     : in  sl;
      pciRst     : in  sl);
end PgpV3Core;

architecture mapping of PgpV3Core is

   signal locClk : slv(7 downto 0);
   signal locRst : slv(7 downto 0);

   signal pgpRxIn  : Pgp3RxInArray(0 to 7);
   signal pgpRxOut : Pgp3RxOutArray(0 to 7);

   signal pgpTxIn  : Pgp3TxInArray(0 to 7);
   signal pgpTxOut : Pgp3TxOutArray(0 to 7);

   signal txMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));
   signal txSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3)  := (others => (others => AXI_STREAM_SLAVE_FORCE_C));

   signal rxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));

   signal pgpTxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));
   signal pgpTxSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3)  := (others => (others => AXI_STREAM_SLAVE_FORCE_C));

   signal pgpRxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));
   signal pgpRxSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3)  := (others => (others => AXI_STREAM_SLAVE_FORCE_C));
   signal pgpRxCtrl    : AxiStreamCtrlVectorArray(0 to 7, 0 to 3)   := (others => (others => AXI_STREAM_CTRL_UNUSED_C));

   signal dmaTxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));
   signal dmaTxSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3)  := (others => (others => AXI_STREAM_SLAVE_FORCE_C));

   signal dmaRxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));
   signal dmaRxSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3)  := (others => (others => AXI_STREAM_SLAVE_FORCE_C));
   signal dmaRxCtrl    : AxiStreamCtrlVectorArray(0 to 7, 0 to 3)   := (others => (others => AXI_STREAM_CTRL_UNUSED_C));

begin

   pgpClk <= locClk;
   pgpRst <= locRst;

   U_PgpV3FrontEnd : entity work.PgpV3FrontEnd
      port map (
         -- Clocking and Resets
         pgpClk       => locClk,
         pgpRst       => locRst,
         -- Non VC Rx Signals
         pgpRxIn      => pgpRxIn,
         pgpRxOut     => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn      => pgpTxIn,
         pgpTxOut     => pgpTxOut,
         -- Frame Transmit Interface
         pgpTxMasters => txMasters,
         pgpTxSlaves  => txSlaves,
         -- Frame Receive Interface
         pgpRxMasters => rxMasters,
         pgpRxCtrl    => pgpRxCtrl,
         -- PGP Fiber Links
         pgpRefClkP   => pgpRefClkP,
         pgpRefClkN   => pgpRefClkN,
         pgpRxP       => pgpRxP,
         pgpRxN       => pgpRxN,
         pgpTxP       => pgpTxP,
         pgpTxN       => pgpTxN);

   GEN_CORE : if (DMA_LOOPBACK_G = false) generate
      GEN_LANE :
      for i in 0 to 7 generate
         GEN_VC :
         for j in 0 to 3 generate
            txMasters(i, j)    <= pgpTxMasters(i, j);
            pgpTxSlaves(i, j)  <= txSlaves(i, j);
            pgpRxMasters(i, j) <= rxMasters(i, j);
         end generate GEN_VC;
      end generate GEN_LANE;
   end generate;

   BYPASS_CORE : if (DMA_LOOPBACK_G = true) generate
      GEN_LANE :
      for i in 0 to 7 generate
         GEN_VC :
         for j in 0 to 3 generate
            pgpRxMasters(i, j) <= pgpTxMasters(i, j);
            pgpTxSlaves(i, j)  <= pgpRxSlaves(i, j);
         end generate GEN_VC;
      end generate GEN_LANE;
   end generate;

   GEN_LANE :
   for i in 0 to 7 generate
      GEN_VC :
      for j in 0 to 3 generate
         pgpTxMasters(i, j) <= dmaTxMasters(i, j);
         dmaTxSlaves(i, j)  <= pgpTxSlaves(i, j);
         dmaRxMasters(i, j) <= pgpRxMasters(i, j);
         pgpRxSlaves(i, j)  <= dmaRxSlaves(i, j);
         pgpRxCtrl(i, j)    <= dmaRxCtrl(i, j);
      end generate GEN_VC;
   end generate GEN_LANE;

   PgpApp_Inst : entity work.PgpV3App
      generic map (
         SLAVE_READY_EN_G => DMA_LOOPBACK_G)
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
         pgpRxSlaves  => dmaRxSlaves,
         pgpRxCtrl    => dmaRxCtrl,
         -- Global Signals
         pgpClk       => locClk,
         pgpRst       => locRst,
         evrClk       => evrClk,
         evrRst       => evrRst,
         pciClk       => pciClk,
         pciRst       => pciRst);

end mapping;
