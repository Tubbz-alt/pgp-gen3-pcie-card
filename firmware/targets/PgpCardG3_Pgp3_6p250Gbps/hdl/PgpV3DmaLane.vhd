-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpV3DmaLane.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2018-09-28
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
use work.Pgp3Pkg.all;
use work.PgpCardG3Pkg.all;

entity PgpV3DmaLane is
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
      pgpTxMasters     : out AxiStreamMasterArray(0 to 3) := (others => AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves      : in  AxiStreamSlaveArray(0 to 3);
      -- Frame Receive Interface
      pgpRxMasters     : in  AxiStreamMasterArray(0 to 3);
      pgpRxSlaves      : out AxiStreamSlaveArray(0 to 3)  := (others => AXI_STREAM_SLAVE_FORCE_C);
      pgpRxCtrl        : out AxiStreamCtrlArray(0 to 3)   := (others => AXI_STREAM_CTRL_UNUSED_C);
      -- EVR Trigger Interface
      enHeaderCheck    : in  slv(3 downto 0);
      trigLutOut       : in  TrigLutOutArray(0 to 3);
      trigLutIn        : out TrigLutInArray(0 to 3)       := (others => TRIG_LUT_IN_INIT_C);
      lutDropCnt       : out Slv8Array(0 to 3)            := (others => x"00");
      -- Diagnostic Monitoring Interface
      fifoError        : out sl                           := '0';
      vcPause          : out slv(3 downto 0)              := (others => '0');
      vcOverflow       : out slv(3 downto 0)              := (others => '0');
      -- Global Signals
      pgpClk           : in  sl;
      pgpTxRst         : in  sl;
      pgpRxRst         : in  sl;
      pgpClk2x         : in  sl;
      pgpRst2x         : in  sl;
      pciClk           : in  sl;
      pciRst           : in  sl);
end PgpV3DmaLane;

architecture rtl of PgpV3DmaLane is

   constant CASCADE_SIZE_C : PositiveArray(3 downto 0) := (
      0 => 48,  -- VC0 - data path 1095232 bytes @ 120 Hz + commands on RX
      1 => 1,                           -- VC1 - register access
      2 => 4,   -- VC2 - debug data path 32768 bytes @ 120 Hz 
      3 => 1);  -- VC3 - monitoring data path less than 1 kbyte @ 1Hz


   constant DMA_CH_C : slv(2 downto 0) := toSlv(LANE_G, 3);

   signal rxMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal rxSlaves  : AxiStreamSlaveArray(3 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal txMasters : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
   signal txSlaves  : AxiStreamSlaveArray(3 downto 0)  := (others => AXI_STREAM_SLAVE_FORCE_C);

   signal pgpTxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal pgpTxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

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
         mAxisClk       => pgpClk2x,
         mAxisRst       => pgpRst2x,
         mAxisMaster    => txMaster,
         mAxisSlave     => txSlave);

   ENABLE_PGP : if (LANE_G = 0) generate

      AxiStreamDeMux_Inst : entity work.AxiStreamDeMux
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => 1,
            NUM_MASTERS_G => 4)
         port map (
            -- Clock and reset
            axisClk      => pgpClk2x,
            axisRst      => pgpRst2x,
            -- Slave         
            sAxisMaster  => txMaster,
            sAxisSlave   => txSlave,
            -- Masters
            mAxisMasters => txMasters,
            mAxisSlaves  => txSlaves);

      GEN_VC_TX_BUFFER :
      for vc in 0 to 3 generate
         FIFO_VC_TX : entity work.AxiStreamFifoV2
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
               GEN_SYNC_FIFO_G     => false,
               CASCADE_SIZE_G      => 1,
               FIFO_ADDR_WIDTH_G   => 4,
               -- AXI Stream Port Configurations
               SLAVE_AXI_CONFIG_G  => AXIS_32B_CONFIG_C,
               MASTER_AXI_CONFIG_G => PGP3_AXIS_CONFIG_C)
            port map (
               -- Slave Port
               sAxisClk    => pgpClk2x,
               sAxisRst    => pgpRst2x,
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
               TPD_G               => TPD_G,
               SLAVE_AXI_CONFIG_G  => PGP3_AXIS_CONFIG_C,
               CASCADE_SIZE_G      => CASCADE_SIZE_C(vc),
               SLAVE_READY_EN_G    => SLAVE_READY_EN_G,
               GEN_SYNC_FIFO_G     => false,
               FIFO_ADDR_WIDTH_G   => 10,
               FIFO_PAUSE_THRESH_G => 512,
               LANE_G              => LANE_G,
               VC_G                => vc)
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
               mAxisClk      => pgpClk2x,
               mAxisRst      => pgpRst2x);
      end generate GEN_VC_RX_BUFFER;

      AxiStreamMux_Inst : entity work.AxiStreamMux
         generic map (
            TPD_G         => TPD_G,
            PIPE_STAGES_G => 1,
            NUM_SLAVES_G  => 4)
         port map (
            -- Clock and reset
            axisClk      => pgpClk2x,
            axisRst      => pgpRst2x,
            -- Slave
            sAxisMasters => rxMasters,
            sAxisSlaves  => rxSlaves,
            -- Masters
            mAxisMaster  => rxMaster,
            mAxisSlave   => rxSlave);

   end generate;

   PciRxDma_Inst : entity work.PciRxDma
      generic map (
         TPD_G => TPD_G)
      port map (
         -- 32-bit Streaming RX Interface
         sAxisClk       => pgpClk2x,
         sAxisRst       => pgpRst2x,
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
