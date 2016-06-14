-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpApp.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2016-06-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.PciPkg.all;
use work.PgpCardG3Pkg.all;

entity PgpApp is
   generic (
      TPD_G            : time    := 1 ns;
      SLAVE_READY_EN_G : boolean := false;
      PGP_RATE_G       : real    := 5.0E+9);
   port (
      -- External Interfaces     
      pciToPgp     : in  PciToPgpType;
      pgpToPci     : out PgpToPciType;
      evrToPgp     : in  EvrToPgpArray(0 to 7);
      -- Non VC Rx Signals
      pgpRxIn      : out Pgp2bRxInArray(0 to 7);
      pgpRxOut     : in  Pgp2bRxOutArray(0 to 7);
      -- Non VC Tx Signals
      pgpTxIn      : out Pgp2bTxInArray(0 to 7);
      pgpTxOut     : in  Pgp2bTxOutArray(0 to 7);
      -- Frame Transmit Interface
      pgpTxMasters : out AxiStreamMasterVectorArray(0 to 7, 0 to 3);
      pgpTxSlaves  : in  AxiStreamSlaveVectorArray(0 to 7, 0 to 3);
      -- Frame Receive Interface
      pgpRxMasters : in  AxiStreamMasterVectorArray(0 to 7, 0 to 3);
      pgpRxSlaves  : out AxiStreamSlaveVectorArray(0 to 7, 0 to 3);
      pgpRxCtrl    : out AxiStreamCtrlVectorArray(0 to 7, 0 to 3);
      -- PLL Status
      pllTxReady   : in  slv(1 downto 0);
      pllRxReady   : in  slv(1 downto 0);
      pllTxRst     : out slv(1 downto 0);
      pllRxRst     : out slv(1 downto 0);
      pgpTxRst     : out slv(7 downto 0);
      pgpRxRst     : out slv(7 downto 0);
      -- Global Signals
      pgpClk       : in  sl;
      pgpRst       : in  sl;
      evrClk       : in  sl;
      evrRst       : in  sl;
      pciClk       : in  sl;
      pciRst       : in  sl);       
end PgpApp;

architecture mapping of PgpApp is

   signal countRst : sl;
   signal pllTxReset,
      pllRxReset : slv(1 downto 0);
   signal pgpTxReset,
      pgpRxReset,
      pgpTxRstDly,
      pgpRxRstDly,
      loopback,
      evrSyncEn,
      evrSyncSel,
      fifoError : slv(7 downto 0);

   signal enHeaderCheck : SlVectorArray(0 to 7, 0 to 3);
   signal trigLutIn     : TrigLutInVectorArray(0 to 7, 0 to 3);
   signal trigLutOut    : TrigLutOutVectorArray(0 to 7, 0 to 3);
   signal pgpRxCtrls    : AxiStreamCtrlVectorArray(0 to 7, 0 to 3);
   signal runDelay      : Slv32Array(0 to 7);
   signal acceptDelay   : Slv32Array(0 to 7);
   signal acceptCntRst  : slv(7 downto 0);
   signal evrOpCodeMask : slv(7 downto 0);
   signal evrSyncWord   : Slv32Array(0 to 7);
   
begin

   -- Outputs
   pgpRxCtrl <= pgpRxCtrls;

   pllTxRst <= pllTxReset;
   pllRxRst <= pllRxReset;

   pgpTxRst <= pgpTxRstDly;
   pgpRxRst <= pgpRxRstDly;

   pgpToPci.pllTxReady <= pllTxReady;
   pgpToPci.pllRxReady <= pllRxReady;

   -------------------------------
   -- Synchronization
   ------------------------------- 
   GEN_PLL_RST :
   for i in 0 to 1 generate
      RstSync_0 : entity work.RstSync
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => pgpClk,
            asyncRst => PciToPgp.pllTxRst(i),
            syncRst  => pllTxReset(i)); 

      RstSync_1 : entity work.RstSync
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => pgpClk,
            asyncRst => PciToPgp.pllRxRst(i),
            syncRst  => pllRxReset(i));             
   end generate GEN_PLL_RST;

   GEN_SYNC_LANE :
   for i in 0 to 7 generate
      
      RstSync_2 : entity work.PwrUpRst
         generic map (
            TPD_G      => TPD_G,
            DURATION_G => getTimeRatio(PGP_RATE_G, 200.0))  -- 100 ms reset    
         port map (
            clk    => pgpClk,
            arst   => PciToPgp.pgpTxRst(i),
            rstOut => pgpTxReset(i));  

      RstSync_3 : entity work.PwrUpRst
         generic map (
            TPD_G      => TPD_G,
            DURATION_G => getTimeRatio(PGP_RATE_G, 200.0))  -- 100 ms reset    
         port map (
            clk    => pgpClk,
            arst   => PciToPgp.pgpRxRst(i),
            rstOut => pgpRxReset(i));           

      -- Add registers to help with timing
      process(pgpClk)
      begin
         if rising_edge(pgpClk) then
            pgpTxRstDly(i) <= pgpTxReset(i) after TPD_G;
            pgpRxRstDly(i) <= pgpRxReset(i) after TPD_G;
         end if;
      end process;

      SynchronizerVector_0 : entity work.SynchronizerVector
         generic map (
            TPD_G   => TPD_G,
            WIDTH_G => 4)
         port map (
            clk        => pgpClk,
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
            clk     => pgpClk,
            dataIn  => PciToPgp.evrSyncWord(i),
            dataOut => evrSyncWord(i));             

      RstSync_0 : entity work.RstSync
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => pgpClk,
            asyncRst => PciToPgp.acceptCntRst(i),
            syncRst  => acceptCntRst(i));             

   end generate GEN_SYNC_LANE;

   RstSync_4 : entity work.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => pgpClk,
         asyncRst => PciToPgp.countRst,
         syncRst  => countRst);     

   SynchronizerVector_4 : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 8)
      port map (
         clk     => pgpClk,
         dataIn  => PciToPgp.loopback,
         dataOut => loopback);  

   SynchronizerVector_5 : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 8)
      port map (
         clk     => pgpClk,
         dataIn  => PciToPgp.evrSyncEn,
         dataOut => evrSyncEn);    

   SynchronizerVector_6 : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 8)
      port map (
         clk     => pgpClk,
         dataIn  => PciToPgp.evrSyncSel,
         dataOut => evrSyncSel);           

   SynchronizerVector_7 : entity work.SynchronizerVector
      generic map (
         TPD_G   => TPD_G,
         WIDTH_G => 8)
      port map (
         clk     => pgpClk,
         dataIn  => PciToPgp.evrOpCodeMask,
         dataOut => evrOpCodeMask);              

   -------------------
   -- PGP Lane Mapping
   -------------------
   GEN_LANE :
   for lane in 0 to 7 generate

      --------------------------
      -- Loopback Configuration
      --------------------------
      pgpRxIn(lane).flush    <= '0';
      pgpRxIn(lane).resetRx  <= '0';
      pgpRxIn(lane).loopback <= "0" & loopback(lane) & "0";

      ----------------------------
      -- EVR OP Code Look Up Table
      ----------------------------      
      PgpOpCode_Inst : entity work.PgpOpCode
         generic map (
            TPD_G => TPD_G)
         port map (
            -- Software OP-Code
            pgpOpCodeEn   => pciToPgp.pgpOpCodeEn,
            pgpOpCode     => pciToPgp.pgpOpCode,
            -- Configurations
            runDelay      => runDelay(lane),
            acceptDelay   => acceptDelay(lane),
            acceptCntRst  => acceptCntRst(lane),
            evrOpCodeMask => evrOpCodeMask(lane),
            evrSyncSel    => evrSyncSel(lane),
            evrSyncEn     => evrSyncEn(lane),
            evrSyncWord   => evrSyncWord(lane),
            evrSyncStatus => pgpToPci.evrSyncStatus(lane),
            acceptCnt     => pgpToPci.acceptCnt(lane),
            -- External Interfaces
            evrToPgp      => evrToPgp(lane),
            --PGP Core interfaces
            pgpTxIn       => pgpTxIn(lane),
            -- RX Virtual Channel Interface
            trigLutIn(0)  => trigLutIn(lane, 0),
            trigLutIn(1)  => trigLutIn(lane, 1),
            trigLutIn(2)  => trigLutIn(lane, 2),
            trigLutIn(3)  => trigLutIn(lane, 3),
            trigLutOut(0) => trigLutOut(lane, 0),
            trigLutOut(1) => trigLutOut(lane, 1),
            trigLutOut(2) => trigLutOut(lane, 2),
            trigLutOut(3) => trigLutOut(lane, 3),
            --Global Signals
            pciClk        => pciClk,
            pciRst        => pciRst,
            pgpClk        => pgpClk,
            pgpRst        => pgpRst,
            evrClk        => evrClk,
            evrRst        => evrRst);     

      -------------------------------
      -- Lane Status and Health
      ------------------------------- 
      PgpLinkMon_Inst : entity work.PgpLinkMon
         generic map (
            TPD_G => TPD_G)
         port map (
            countRst        => countRst,
            fifoError       => fifoError(lane),
            locLinkReady    => pgpToPci.locLinkReady(lane),
            remLinkReady    => pgpToPci.remLinkReady(lane),
            cellErrorCnt    => pgpToPci.cellErrorCnt(lane),
            linkDownCnt     => pgpToPci.linkDownCnt(lane),
            linkErrorCnt    => pgpToPci.linkErrorCnt(lane),
            fifoErrorCnt    => pgpToPci.fifoErrorCnt(lane),
            rxCount(0)      => pgpToPci.rxCount(lane, 0),
            rxCount(1)      => pgpToPci.rxCount(lane, 1),
            rxCount(2)      => pgpToPci.rxCount(lane, 2),
            rxCount(3)      => pgpToPci.rxCount(lane, 3),
            -- Non VC Rx Signals
            pgpRxOut        => pgpRxOut(lane),
            -- Non VC Tx Signals
            pgpTxOut        => pgpTxOut(lane),
            -- Frame Receive Interface
            pgpRxMasters(0) => pgpRxMasters(lane, 0),
            pgpRxMasters(1) => pgpRxMasters(lane, 1),
            pgpRxMasters(2) => pgpRxMasters(lane, 2),
            pgpRxMasters(3) => pgpRxMasters(lane, 3),
            pgpRxCtrl(0)    => pgpRxCtrls(lane, 0),
            pgpRxCtrl(1)    => pgpRxCtrls(lane, 1),
            pgpRxCtrl(2)    => pgpRxCtrls(lane, 2),
            pgpRxCtrl(3)    => pgpRxCtrls(lane, 3),
            -- Global Signals
            pgpClk          => pgpClk,
            pgpRst          => pgpRst);    

      ---------------
      -- DMA channels
      ---------------
      PgpDmaLane_Inst : entity work.PgpDmaLane
         generic map (
            TPD_G            => TPD_G,
            LANE_G           => lane,
            SLAVE_READY_EN_G => SLAVE_READY_EN_G)          
         port map (
            countRst         => countRst,
            -- DMA TX Interface
            dmaTxIbMaster    => PgpToPci.dmaTxIbMaster(lane),
            dmaTxIbSlave     => PciToPgp.dmaTxIbSlave(lane),
            dmaTxObMaster    => PciToPgp.dmaTxObMaster(lane),
            dmaTxObSlave     => PgpToPci.dmaTxObSlave(lane),
            dmaTxDescFromPci => PciToPgp.dmaTxDescFromPci(lane),
            dmaTxDescToPci   => PgpToPci.dmaTxDescToPci(lane),
            dmaTxTranFromPci => PciToPgp.dmaTxTranFromPci(lane),
            -- DMA RX Interface
            dmaRxIbMaster    => PgpToPci.dmaRxIbMaster(lane),
            dmaRxIbSlave     => PciToPgp.dmaRxIbSlave(lane),
            dmaRxDescFromPci => PciToPgp.dmaRxDescFromPci(lane),
            dmaRxDescToPci   => PgpToPci.dmaRxDescToPci(lane),
            dmaRxTranFromPci => PciToPgp.dmaRxTranFromPci(lane),
            -- Frame Transmit Interface
            pgpTxMasters(0)  => pgpTxMasters(lane, 0),
            pgpTxMasters(1)  => pgpTxMasters(lane, 1),
            pgpTxMasters(2)  => pgpTxMasters(lane, 2),
            pgpTxMasters(3)  => pgpTxMasters(lane, 3),
            pgpTxSlaves(0)   => pgpTxSlaves(lane, 0),
            pgpTxSlaves(1)   => pgpTxSlaves(lane, 1),
            pgpTxSlaves(2)   => pgpTxSlaves(lane, 2),
            pgpTxSlaves(3)   => pgpTxSlaves(lane, 3),
            -- Frame Receive Interface
            pgpRxMasters(0)  => pgpRxMasters(lane, 0),
            pgpRxMasters(1)  => pgpRxMasters(lane, 1),
            pgpRxMasters(2)  => pgpRxMasters(lane, 2),
            pgpRxMasters(3)  => pgpRxMasters(lane, 3),
            pgpRxSlaves(0)   => pgpRxSlaves(lane, 0),
            pgpRxSlaves(1)   => pgpRxSlaves(lane, 1),
            pgpRxSlaves(2)   => pgpRxSlaves(lane, 2),
            pgpRxSlaves(3)   => pgpRxSlaves(lane, 3),
            pgpRxCtrl(0)     => pgpRxCtrls(lane, 0),
            pgpRxCtrl(1)     => pgpRxCtrls(lane, 1),
            pgpRxCtrl(2)     => pgpRxCtrls(lane, 2),
            pgpRxCtrl(3)     => pgpRxCtrls(lane, 3),
            -- EVR Trigger Interface
            enHeaderCheck(0) => enHeaderCheck(lane, 0),
            enHeaderCheck(1) => enHeaderCheck(lane, 1),
            enHeaderCheck(2) => enHeaderCheck(lane, 2),
            enHeaderCheck(3) => enHeaderCheck(lane, 3),
            trigLutIn(0)     => trigLutIn(lane, 0),
            trigLutIn(1)     => trigLutIn(lane, 1),
            trigLutIn(2)     => trigLutIn(lane, 2),
            trigLutIn(3)     => trigLutIn(lane, 3),
            trigLutOut(0)    => trigLutOut(lane, 0),
            trigLutOut(1)    => trigLutOut(lane, 1),
            trigLutOut(2)    => trigLutOut(lane, 2),
            trigLutOut(3)    => trigLutOut(lane, 3),
            lutDropCnt(0)    => PgpToPci.lutDropCnt(lane, 0),
            lutDropCnt(1)    => PgpToPci.lutDropCnt(lane, 1),
            lutDropCnt(2)    => PgpToPci.lutDropCnt(lane, 2),
            lutDropCnt(3)    => PgpToPci.lutDropCnt(lane, 3),
            -- FIFO Overflow Error Strobe
            fifoError        => fifoError(lane),
            --Global Signals
            pgpClk           => pgpClk,
            pgpTxRst         => pgpTxRstDly(lane),
            pgpRxRst         => pgpRxRstDly(lane),
            pciClk           => pciClk,
            pciRst           => pciRst); 
   end generate GEN_LANE;
end mapping;
