-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpDmaLane.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2018-09-27
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;
use work.Pgp2bPkg.all;
use work.PgpCardG3Pkg.all;

entity PgpDmaLane is
   generic (
      TPD_G            : time                 := 1 ns;
      SLAVE_READY_EN_G : boolean;
      LANE_G           : integer range 0 to 7 := 0);
   port (
      countRst         : in  sl;
      -- DMA TX Interface
      dmaTxIbMaster    : out AxiStreamMasterType;
      dmaTxIbSlave     : in  AxiStreamSlaveType;
      dmaTxObMaster    : in  AxiStreamMasterType;
      dmaTxObSlave     : out AxiStreamSlaveType;
      dmaTxDescFromPci : in  DescFromPciType;
      dmaTxDescToPci   : out DescToPciType;
      dmaTxTranFromPci : in  TranFromPciType;
      -- DMA RX Interface
      dmaRxIbMaster    : out AxiStreamMasterType;
      dmaRxIbSlave     : in  AxiStreamSlaveType;
      dmaRxDescFromPci : in  DescFromPciType;
      dmaRxDescToPci   : out DescToPciType;
      dmaRxTranFromPci : in  TranFromPciType;
      -- Frame Transmit Interface
      pgpTxMasters     : out AxiStreamMasterArray(0 to 3);
      pgpTxSlaves      : in  AxiStreamSlaveArray(0 to 3);
      -- Frame Receive Interface
      pgpRxMasters     : in  AxiStreamMasterArray(0 to 3);
      pgpRxSlaves      : out AxiStreamSlaveArray(0 to 3);
      pgpRxCtrl        : out AxiStreamCtrlArray(0 to 3);
      -- EVR Trigger Interface
      enHeaderCheck    : in  slv(3 downto 0);
      trigLutOut       : in  TrigLutOutArray(0 to 3);
      trigLutIn        : out TrigLutInArray(0 to 3);
      lutDropCnt       : out Slv8Array(0 to 3);
      -- Diagnostic Monitoring Interface
      fifoError        : out sl;
      vcPause          : out slv(3 downto 0);
      vcOverflow       : out slv(3 downto 0);
      -- Global Signals
      pgpClk           : in  sl;
      pgpTxRst         : in  sl;
      pgpRxRst         : in  sl;
      pciClk           : in  sl;
      pciRst           : in  sl);
end PgpDmaLane;

architecture rtl of PgpDmaLane is

   constant DMA_CH_C : slv(2 downto 0) := toSlv(LANE_G, 3);

   signal rxMasters : AxiStreamMasterArray(3 downto 0);
   signal rxSlaves  : AxiStreamSlaveArray(3 downto 0);

   signal rxMaster : AxiStreamMasterType;
   signal rxSlave  : AxiStreamSlaveType;

   signal txMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   signal txMasters : AxiStreamMasterArray(3 downto 0);
   signal txSlaves  : AxiStreamSlaveArray(3 downto 0);

   signal pgpTxMaster : AxiStreamMasterType;
   signal pgpTxSlave  : AxiStreamSlaveType;

   signal fifoErr : slv(3 downto 0);

begin

   --------------------
   -- TX DMA Controller
   --------------------
   PciTxDma_Inst : entity work.PciTxDma
      generic map (
         TPD_G => TPD_G)
      port map (
         -- 128-bit Streaming RX Interface
         pciClk         => pciClk,
         pciRst         => pciRst,
         dmaIbMaster    => dmaTxIbMaster,
         dmaIbSlave     => dmaTxIbSlave,
         dmaObMaster    => dmaTxObMaster,
         dmaObSlave     => dmaTxObSlave,
         dmaDescFromPci => dmaTxDescFromPci,
         dmaDescToPci   => dmaTxDescToPci,
         dmaTranFromPci => dmaTxTranFromPci,
         -- 32-bit Streaming RX Interface
         mAxisClk       => pgpClk,
         mAxisRst       => pgpTxRst,
         mAxisMaster    => txMaster,
         mAxisSlave     => txSlave);

   AxiStreamDeMux_Inst : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1,
         NUM_MASTERS_G => 4)
      port map (
         -- Clock and reset
         axisClk      => pgpClk,
         axisRst      => pgpTxRst,
         -- Slave         
         sAxisMaster  => txMaster,
         sAxisSlave   => txSlave,
         -- Masters
         mAxisMasters => txMasters,
         mAxisSlaves  => txSlaves);

   GEN_VC_TX_BUFFER :
   for vc in 0 to 3 generate
      FIFO_VC_TX : entity work.AxiStreamFifo
         generic map (
            -- General Configurations
            TPD_G               => TPD_G,
            INT_PIPE_STAGES_G   => 1,
            PIPE_STAGES_G       => 1,
            SLAVE_READY_EN_G    => true,
            VALID_THOLD_G       => 1,
            -- FIFO configurations
            BRAM_EN_G           => false,
            USE_BUILT_IN_G      => false,
            GEN_SYNC_FIFO_G     => true,
            CASCADE_SIZE_G      => 1,
            FIFO_ADDR_WIDTH_G   => 4,
            -- AXI Stream Port Configurations
            SLAVE_AXI_CONFIG_G  => AXIS_32B_CONFIG_C,
            MASTER_AXI_CONFIG_G => AXIS_16B_CONFIG_C)
         port map (
            -- Slave Port
            sAxisClk    => pgpClk,
            sAxisRst    => pgpTxRst,
            sAxisMaster => txMasters(vc),
            sAxisSlave  => txSlaves(vc),
            -- Master Port
            mAxisClk    => pgpClk,
            mAxisRst    => pgpTxRst,
            mAxisMaster => pgpTxMasters(vc),
            mAxisSlave  => pgpTxSlaves(vc));
   end generate GEN_VC_TX_BUFFER;

   --------------------
   -- RX DMA Controller
   --------------------

   fifoError <= uOr(fifoErr);

   GEN_VC_RX_BUFFER :
   for vc in 0 to 3 generate
      PgpVcRxBuffer_Inst : entity work.PgpVcRxBuffer
         generic map (
            TPD_G              => TPD_G,
            SLAVE_AXI_CONFIG_G => AXIS_16B_CONFIG_C,
            CASCADE_SIZE_G     => 4,
            SLAVE_READY_EN_G   => SLAVE_READY_EN_G,
            GEN_SYNC_FIFO_G    => true,
            LANE_G             => LANE_G,
            VC_G               => vc)
         port map (
            countRst      => countRst,
            -- EVR Trigger Interface
            enHeaderCheck => enHeaderCheck(vc),
            trigLutOut    => trigLutOut(vc),
            trigLutIn     => trigLutIn(vc),
            lutDropCnt    => lutDropCnt(vc),
            -- 16-bit Streaming RX Interface
            pgpRxMaster   => pgpRxMasters(vc),
            pgpRxSlave    => pgpRxSlaves(vc),
            pgpRxCtrl     => pgpRxCtrl(vc),
            -- 32-bit Streaming TX Interface
            mAxisMaster   => rxMasters(vc),
            mAxisSlave    => rxSlaves(vc),
            -- Diagnostic Monitoring Interface
            fifoError     => fifoErr(vc),
            vcPause       => vcPause(vc),
            vcOverflow    => vcOverflow(vc),
            -- Global Signals
            sAxisClk      => pgpClk,
            sAxisRst      => pgpRxRst,
            mAxisClk      => pgpClk,
            mAxisRst      => pgpRxRst);

   end generate GEN_VC_RX_BUFFER;

   AxiStreamMux_Inst : entity work.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
         PIPE_STAGES_G => 1,
         NUM_SLAVES_G  => 4)
      port map (
         -- Clock and reset
         axisClk      => pgpClk,
         axisRst      => pgpRxRst,
         -- Slave
         sAxisMasters => rxMasters,
         sAxisSlaves  => rxSlaves,
         -- Masters
         mAxisMaster  => rxMaster,
         mAxisSlave   => rxSlave);

   PciRxDma_Inst : entity work.PciRxDma
      generic map (
         TPD_G => TPD_G)
      port map (
         -- 32-bit Streaming RX Interface
         sAxisClk       => pgpClk,
         sAxisRst       => pgpRxRst,
         sAxisMaster    => rxMaster,
         sAxisSlave     => rxSlave,
         -- 128-bit Streaming TX Interface
         pciClk         => pciClk,
         pciRst         => pciRst,
         dmaIbMaster    => dmaRxIbMaster,
         dmaIbSlave     => dmaRxIbSlave,
         dmaDescFromPci => dmaRxDescFromPci,
         dmaDescToPci   => dmaRxDescToPci,
         dmaTranFromPci => dmaRxTranFromPci,
         dmaChannel     => DMA_CH_C);
end rtl;
