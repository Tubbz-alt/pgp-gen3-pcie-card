-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpV3App.vhd
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Pgp3Pkg.all;
use work.AxiStreamPkg.all;
use work.PciPkg.all;
use work.PgpCardG3Pkg.all;

entity PgpV3App is
   generic (
      TPD_G            : time    := 1 ns;
      SLAVE_READY_EN_G : boolean := false;
      PGP_RATE_G       : real    := 6.25E+9);
   port (
      -- External Interfaces     
      pciToPgp     : in  PciToPgpType;
      pgpToPci     : out PgpToPciType;
      evrToPgp     : in  EvrToPgpArray(0 to 7);
      -- Non VC Rx Signals
      pgpRxIn      : out Pgp3RxInArray(0 to 7) := (others => PGP3_RX_IN_INIT_C);
      pgpRxOut     : in  Pgp3RxOutArray(0 to 7);
      -- Non VC Tx Signals
      pgpTxIn      : out Pgp3TxInArray(0 to 7) := (others => PGP3_TX_IN_INIT_C);
      pgpTxOut     : in  Pgp3TxOutArray(0 to 7);
      -- Frame Transmit Interface
      pgpTxMasters : out AxiStreamMasterVectorArray(0 to 7, 0 to 3);
      pgpTxSlaves  : in  AxiStreamSlaveVectorArray(0 to 7, 0 to 3);
      -- Frame Receive Interface
      pgpRxMasters : in  AxiStreamMasterVectorArray(0 to 7, 0 to 3);
      pgpRxSlaves  : out AxiStreamSlaveVectorArray(0 to 7, 0 to 3);
      pgpRxCtrl    : out AxiStreamCtrlVectorArray(0 to 7, 0 to 3);
      -- Global Signals
      pgpClk       : in  slv(7 downto 0);
      pgpRst       : in  slv(7 downto 0);
      pgpClk2x     : in sl;
      pgpRst2x     : in sl;      
      evrClk       : in  sl;
      evrRst       : in  sl;
      pciClk       : in  sl;
      pciRst       : in  sl);
end PgpV3App;

architecture mapping of PgpV3App is

   signal countRst    : slv(7 downto 0);
   signal loopback    : slv(7 downto 0);
   signal evrSyncEn   : slv(7 downto 0);
   signal evrSyncSel  : slv(7 downto 0);
   signal pgpTxReset  : slv(7 downto 0);
   signal pgpRxReset  : slv(7 downto 0);
   signal pgpTxRstDly : slv(7 downto 0);
   signal pgpRxRstDly : slv(7 downto 0);
   signal fifoError   : slv(7 downto 0);

   signal enHeaderCheck : SlVectorArray(0 to 7, 0 to 3);
   signal trigLutIn     : TrigLutInVectorArray(0 to 7, 0 to 3);
   signal trigLutOut    : TrigLutOutVectorArray(0 to 7, 0 to 3);
   signal pgpRxCtrls    : AxiStreamCtrlVectorArray(0 to 7, 0 to 3);
   signal txSlaves      : AxiStreamSlaveVectorArray(0 to 7, 0 to 3);
   signal runDelay      : Slv32Array(0 to 7);
   signal acceptDelay   : Slv32Array(0 to 7);
   signal acceptCntRst  : slv(7 downto 0);
   signal evrOpCodeMask : slv(7 downto 0);
   signal evrSyncWord   : Slv32Array(0 to 7);

begin

   -- Outputs
   pgpRxCtrl <= pgpRxCtrls;

   pgpToPci.pllTxReady <= (others=>'1');
   pgpToPci.pllRxReady <= (others=>'1');

   GEN_LANE :
   for i in 0 to 7 generate

      U_pgpTxRstDly : entity work.RstPipeline
         generic map (
            TPD_G => TPD_G)
         port map (
            clk    => pgpClk(i),
            rstIn  => pgpRst(i),
            rstOut => pgpTxRstDly(i));

      U_pgpRxRstDly : entity work.RstPipeline
         generic map (
            TPD_G => TPD_G)
         port map (
            clk    => pgpClk(i),
            rstIn  => pgpRst(i),
            rstOut => pgpRxRstDly(i));

      SynchronizerVector_0 : entity work.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 4)
         port map (
            clk        => pgpClk(i),
            dataIn(0)  => PciToPgp.enHeaderCheck(i, 0),
            dataIn(1)  => PciToPgp.enHeaderCheck(i, 1),
            dataIn(2)  => PciToPgp.enHeaderCheck(i, 2),
            dataIn(3)  => PciToPgp.enHeaderCheck(i, 3),
            dataOut(0) => enHeaderCheck(i, 0),
            dataOut(1) => enHeaderCheck(i, 1),
            dataOut(2) => enHeaderCheck(i, 2),
            dataOut(3) => enHeaderCheck(i, 3));

      SynchronizerVector_1 : entity work.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 32)
         port map (
            clk     => evrClk,
            dataIn  => PciToPgp.runDelay(i),
            dataOut => runDelay(i));

      SynchronizerVector_2 : entity work.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 32)
         port map (
            clk     => evrClk,
            dataIn  => PciToPgp.acceptDelay(i),
            dataOut => acceptDelay(i));

      SynchronizerVector_3 : entity work.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 32)
         port map (
            clk     => pgpClk(i),
            dataIn  => PciToPgp.evrSyncWord(i),
            dataOut => evrSyncWord(i));

      RstSync_0 : entity work.RstSync
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => pgpClk(i),
            asyncRst => PciToPgp.acceptCntRst(i),
            syncRst  => acceptCntRst(i));

      U_countRst : entity work.RstSync
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => pgpClk(i),
            asyncRst => PciToPgp.countRst,
            syncRst  => countRst(i));

      U_loopback : entity work.Synchronizer
         generic map (
            TPD_G   => TPD_G)
         port map (
            clk     => pgpClk(i),
            dataIn  => PciToPgp.loopback(i),
            dataOut => loopback(i));

      U_evrSyncEn : entity work.Synchronizer
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => pgpClk(i),
            dataIn  => PciToPgp.evrSyncEn(i),
            dataOut => evrSyncEn(i));

      U_evrSyncSel : entity work.Synchronizer
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => pgpClk(i),
            dataIn  => PciToPgp.evrSyncSel(i),
            dataOut => evrSyncSel(i));

      U_evrOpCodeMask : entity work.Synchronizer
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => pgpClk(i),
            dataIn  => PciToPgp.evrOpCodeMask(i),
            dataOut => evrOpCodeMask(i));

      --------------------------
      -- Loopback Configuration
      --------------------------
      pgpRxIn(i).loopback <= "0" & loopback(i) & "0";

      ----------------------------
      -- EVR OP Code Look Up Table
      ----------------------------      
      PgpOpCode_Inst : entity work.PgpV3OpCode
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Software OP-Code
            pgpOpCodeEn   => pciToPgp.pgpOpCodeEn,
            pgpOpCode     => pciToPgp.pgpOpCode,
            pgpLocData    => pciToPgp.pgpLocData(i),
            -- Configurations
            runDelay      => runDelay(i),
            acceptDelay   => acceptDelay(i),
            acceptCntRst  => acceptCntRst(i),
            evrOpCodeMask => evrOpCodeMask(i),
            evrSyncSel    => evrSyncSel(i),
            evrSyncEn     => evrSyncEn(i),
            evrSyncWord   => evrSyncWord(i),
            evrSyncStatus => pgpToPci.evrSyncStatus(i),
            acceptCnt     => pgpToPci.acceptCnt(i),
            -- External Interfaces
            evrToPgp      => evrToPgp(i),
            --PGP Core interfaces
            pgpTxIn       => pgpTxIn(i),
            -- RX Virtual Channel Interface
            trigLutIn(0)  => trigLutIn(i, 0),
            trigLutIn(1)  => trigLutIn(i, 1),
            trigLutIn(2)  => trigLutIn(i, 2),
            trigLutIn(3)  => trigLutIn(i, 3),
            trigLutOut(0) => trigLutOut(i, 0),
            trigLutOut(1) => trigLutOut(i, 1),
            trigLutOut(2) => trigLutOut(i, 2),
            trigLutOut(3) => trigLutOut(i, 3),
            --Global Signals
            pciClk        => pciClk,
            pciRst        => pciRst,
            pgpClk        => pgpClk(i),
            pgpRst        => pgpRst(i),
            evrClk        => evrClk,
            evrRst        => evrRst);

      -------------------------------
      -- Lane Status and Health
      ------------------------------- 
      PgpLinkMon_Inst : entity work.PgpV3LinkMon
         generic map (
            TPD_G => TPD_G)
         port map (
            countRst        => countRst(i),
            fifoError       => fifoError(i),
            locLinkReady    => pgpToPci.locLinkReady(i),
            remLinkReady    => pgpToPci.remLinkReady(i),
            cellErrorCnt    => pgpToPci.cellErrorCnt(i),
            linkDownCnt     => pgpToPci.linkDownCnt(i),
            linkErrorCnt    => pgpToPci.linkErrorCnt(i),
            fifoErrorCnt    => pgpToPci.fifoErrorCnt(i),
            rxCount(0)      => pgpToPci.rxCount(i, 0),
            rxCount(1)      => pgpToPci.rxCount(i, 1),
            rxCount(2)      => pgpToPci.rxCount(i, 2),
            rxCount(3)      => pgpToPci.rxCount(i, 3),
            pgpRemData      => pgpToPci.pgpRemData(i),
            locPause        => pgpToPci.locPause(i),
            locOverflow     => pgpToPci.locOverflow(i),
            remPause        => pgpToPci.remPause(i),
            remOverflow     => pgpToPci.remOverflow(i),
            -- Non VC Rx Signals
            pgpRxOut        => pgpRxOut(i),
            -- Non VC Tx Signals
            pgpTxOut        => pgpTxOut(i),
            -- Frame Receive Interface
            pgpRxMasters(0) => pgpRxMasters(i, 0),
            pgpRxMasters(1) => pgpRxMasters(i, 1),
            pgpRxMasters(2) => pgpRxMasters(i, 2),
            pgpRxMasters(3) => pgpRxMasters(i, 3),
            pgpRxCtrl(0)    => pgpRxCtrls(i, 0),
            pgpRxCtrl(1)    => pgpRxCtrls(i, 1),
            pgpRxCtrl(2)    => pgpRxCtrls(i, 2),
            pgpRxCtrl(3)    => pgpRxCtrls(i, 3),
            -- Global Signals
            pgpClk          => pgpClk(i),
            pgpRst          => pgpRst(i));

      ---------------
      -- DMA channels
      ---------------
      PgpDmaLane_Inst : entity work.PgpV3DmaLane
         generic map (
            TPD_G            => TPD_G,
            LANE_G           => i,
            SLAVE_READY_EN_G => SLAVE_READY_EN_G)
         port map (
            countRst         => countRst(i),
            -- DMA TX Interface
            dmaTxIbMaster    => pgpToPci.dmaTxIbMaster(i),
            dmaTxIbSlave     => pciToPgp.dmaTxIbSlave(i),
            dmaTxObMaster    => pciToPgp.dmaTxObMaster(i),
            dmaTxObSlave     => pgpToPci.dmaTxObSlave(i),
            dmaTxDescFromPci => pciToPgp.dmaTxDescFromPci(i),
            dmaTxDescToPci   => pgpToPci.dmaTxDescToPci(i),
            dmaTxTranFromPci => pciToPgp.dmaTxTranFromPci(i),
            -- DMA RX Interface
            dmaRxIbMaster    => pgpToPci.dmaRxIbMaster(i),
            dmaRxIbSlave     => pciToPgp.dmaRxIbSlave(i),
            dmaRxDescFromPci => pciToPgp.dmaRxDescFromPci(i),
            dmaRxDescToPci   => pgpToPci.dmaRxDescToPci(i),
            dmaRxTranFromPci => pciToPgp.dmaRxTranFromPci(i),
            -- Frame Transmit Interface
            pgpTxMasters(0)  => pgpTxMasters(i, 0),
            pgpTxMasters(1)  => pgpTxMasters(i, 1),
            pgpTxMasters(2)  => pgpTxMasters(i, 2),
            pgpTxMasters(3)  => pgpTxMasters(i, 3),
            pgpTxSlaves(0)   => txSlaves(i, 0),
            pgpTxSlaves(1)   => txSlaves(i, 1),
            pgpTxSlaves(2)   => txSlaves(i, 2),
            pgpTxSlaves(3)   => txSlaves(i, 3),
            -- Frame Receive Interface
            pgpRxMasters(0)  => pgpRxMasters(i, 0),
            pgpRxMasters(1)  => pgpRxMasters(i, 1),
            pgpRxMasters(2)  => pgpRxMasters(i, 2),
            pgpRxMasters(3)  => pgpRxMasters(i, 3),
            pgpRxSlaves(0)   => pgpRxSlaves(i, 0),
            pgpRxSlaves(1)   => pgpRxSlaves(i, 1),
            pgpRxSlaves(2)   => pgpRxSlaves(i, 2),
            pgpRxSlaves(3)   => pgpRxSlaves(i, 3),
            pgpRxCtrl(0)     => pgpRxCtrls(i, 0),
            pgpRxCtrl(1)     => pgpRxCtrls(i, 1),
            pgpRxCtrl(2)     => pgpRxCtrls(i, 2),
            pgpRxCtrl(3)     => pgpRxCtrls(i, 3),
            -- EVR Trigger Interface
            enHeaderCheck(0) => enHeaderCheck(i, 0),
            enHeaderCheck(1) => enHeaderCheck(i, 1),
            enHeaderCheck(2) => enHeaderCheck(i, 2),
            enHeaderCheck(3) => enHeaderCheck(i, 3),
            trigLutIn(0)     => trigLutIn(i, 0),
            trigLutIn(1)     => trigLutIn(i, 1),
            trigLutIn(2)     => trigLutIn(i, 2),
            trigLutIn(3)     => trigLutIn(i, 3),
            trigLutOut(0)    => trigLutOut(i, 0),
            trigLutOut(1)    => trigLutOut(i, 1),
            trigLutOut(2)    => trigLutOut(i, 2),
            trigLutOut(3)    => trigLutOut(i, 3),
            lutDropCnt(0)    => pgpToPci.lutDropCnt(i, 0),
            lutDropCnt(1)    => pgpToPci.lutDropCnt(i, 1),
            lutDropCnt(2)    => pgpToPci.lutDropCnt(i, 2),
            lutDropCnt(3)    => pgpToPci.lutDropCnt(i, 3),
            -- Diagnostic Monitoring Interface
            fifoError        => fifoError(i),
            --Global Signals
            pgpClk           => pgpClk(i),
            pgpTxRst         => pgpTxRstDly(i),
            pgpRxRst         => pgpRxRstDly(i),
            pgpClk2x         => pgpClk2x,
            pgpRst2x         => pgpRst2x,             
            pciClk           => pciClk,
            pciRst           => pciRst);

      -- Blow off TX DMA if link is down (request from Jack Pines)
      txSlaves(i, 0).tReady <= pgpTxSlaves(i, 0).tReady or not(pgpRxOut(i).linkReady);
      txSlaves(i, 1).tReady <= pgpTxSlaves(i, 1).tReady or not(pgpRxOut(i).linkReady);
      txSlaves(i, 2).tReady <= pgpTxSlaves(i, 2).tReady or not(pgpRxOut(i).linkReady);
      txSlaves(i, 3).tReady <= pgpTxSlaves(i, 3).tReady or not(pgpRxOut(i).linkReady);

   end generate GEN_LANE;
end mapping;
