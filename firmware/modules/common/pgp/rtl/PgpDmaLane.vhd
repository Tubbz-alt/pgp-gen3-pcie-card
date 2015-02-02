-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpDmaLane.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2014-08-18
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;
use work.Pgp2bPkg.all;
use work.PgpCardG3Pkg.all;

entity PgpDmaLane is
   generic (
      TPD_G      : time                 := 1 ns;
      PGP_RATE_G : real;
      LANE_G     : integer range 0 to 7 := 0);
   port (
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
      pgpRxCtrl        : out AxiStreamCtrlArray(0 to 3);
      -- EVR Trigger Interface
      enHeaderCheck    : in  slv(3 downto 0);
      trigLutOut       : in  TrigLutOutArray(0 to 3);
      trigLutIn        : out TrigLutInArray(0 to 3);
      -- FIFO Overflow Error Strobe
      fifoError        : out sl;
      -- Global Signals
      pgpClk           : in  sl;
      pgpTxRst         : in  sl;
      pgpRxRst         : in  sl;
      pciClk           : in  sl;
      pciRst           : in  sl);       
end PgpDmaLane;

architecture rtl of PgpDmaLane is

   constant DMA_CH_C : slv(3 downto 0) := toSlv(LANE_G, 4);

   signal rxMasters   : AxiStreamMasterArray(0 to 3);
   signal rxSlaves    : AxiStreamSlaveArray(0 to 3);
   signal rxMaster    : AxiStreamMasterType;
   signal rxSlave     : AxiStreamSlaveType;
   signal txMaster    : AxiStreamMasterType;
   signal txSlave     : AxiStreamSlaveType;
   signal pgpTxMaster : AxiStreamMasterType;
   signal pgpTxSlave  : AxiStreamSlaveType;
   signal fifoErr     : slv(3 downto 0);

   attribute dont_touch : string;
   attribute dont_touch of
      txMaster,
      txSlave,
      pgpTxMaster,
      pgpTxSlave : signal is "true";
   
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

   SsiFifo_TX : entity work.SsiFifo
      generic map (
         -- General Configurations         
         TPD_G               => TPD_G,
         PIPE_STAGES_G       => 0,
         EN_FRAME_FILTER_G   => false,
         VALID_THOLD_G       => 1,
         -- FIFO configurations
         CASCADE_SIZE_G      => 1,
         BRAM_EN_G           => true,
         XIL_DEVICE_G        => "7SERIES",
         USE_BUILT_IN_G      => false,
         GEN_SYNC_FIFO_G     => true,
         ALTERA_SYN_G        => false,
         ALTERA_RAM_G        => "M9K",
         FIFO_ADDR_WIDTH_G   => 9,
         FIFO_FIXED_THRESH_G => true,
         FIFO_PAUSE_THRESH_G => 500,
         SLAVE_AXI_CONFIG_G  => ssiAxiStreamConfig(4),
         MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C)
      port map (
         -- Slave Port
         sAxisClk    => pgpClk,
         sAxisRst    => pgpTxRst,
         sAxisMaster => txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => pgpClk,
         mAxisRst    => pgpTxRst,
         mAxisMaster => pgpTxMaster,
         mAxisSlave  => pgpTxSlave);           

   AxiStreamDeMux_Inst : entity work.AxiStreamDeMux
      generic map (
         TPD_G         => TPD_G,
         NUM_MASTERS_G => 4)
      port map (
         -- Clock and reset
         axisClk => pgpClk,
         axisRst => pgpTxRst,

         -- Slave
         sAxisMaster.tValid               => pgpTxMaster.tValid,
         sAxisMaster.tData(15 downto 0)   => pgpTxMaster.tData(15 downto 0),
         sAxisMaster.tData(127 downto 16) => (others => '0'),
         sAxisMaster.tStrb                => (others => '1'),
         sAxisMaster.tKeep                => (others => '1'),
         sAxisMaster.tLast                => pgpTxMaster.tLast,
         sAxisMaster.tDest(1 downto 0)    => pgpTxMaster.tDest(1 downto 0),
         sAxisMaster.tDest(7 downto 2)    => (others => '0'),
         sAxisMaster.tId                  => (others => '0'),
         sAxisMaster.tUser(1 downto 0)    => pgpTxMaster.tUser(1 downto 0),
         sAxisMaster.tUser(127 downto 2)  => (others => '0'),


         sAxisSlave      => pgpTxSlave,
         -- Masters
         mAxisMasters(0) => pgpTxMasters(0),
         mAxisMasters(1) => pgpTxMasters(1),
         mAxisMasters(2) => pgpTxMasters(2),
         mAxisMasters(3) => pgpTxMasters(3),
         mAxisSlaves(0)  => pgpTxSlaves(0),
         mAxisSlaves(1)  => pgpTxSlaves(1),
         mAxisSlaves(2)  => pgpTxSlaves(2),
         mAxisSlaves(3)  => pgpTxSlaves(3));    

   --------------------
   -- RX DMA Controller
   --------------------

   fifoError <= uOr(fifoErr);

   GEN_VC_RX_BUFFER :
   for vc in 0 to 3 generate
      PgpVcRxBuffer_Inst : entity work.PgpVcRxBuffer
         generic map (
            TPD_G      => TPD_G,
            PGP_RATE_G => PGP_RATE_G)
         port map (
            -- EVR Trigger Interface
            enHeaderCheck => enHeaderCheck(vc),
            trigLutOut    => trigLutOut(vc),
            trigLutIn     => trigLutIn(vc),
            -- 16-bit Streaming RX Interface
            pgpRxMaster   => pgpRxMasters(vc),
            pgpRxCtrl     => pgpRxCtrl(vc),
            -- 32-bit Streaming TX Interface
            mAxisMaster   => rxMasters(vc),
            mAxisSlave    => rxSlaves(vc),
            -- FIFO Overflow Error Strobe
            fifoError     => fifoErr(vc),
            -- Global Signals
            clk           => pgpClk,
            rst           => pgpRxRst); 
   end generate GEN_VC_RX_BUFFER;

   AxiStreamMux_Inst : entity work.AxiStreamMux
      generic map (
         TPD_G        => TPD_G,
         NUM_SLAVES_G => 4)
      port map (
         -- Clock and reset
         axisClk         => pgpClk,
         axisRst         => pgpRxRst,
         -- Slave
         sAxisMasters(0) => rxMasters(0),
         sAxisMasters(1) => rxMasters(1),
         sAxisMasters(2) => rxMasters(2),
         sAxisMasters(3) => rxMasters(3),
         sAxisSlaves(0)  => rxSlaves(0),
         sAxisSlaves(1)  => rxSlaves(1),
         sAxisSlaves(2)  => rxSlaves(2),
         sAxisSlaves(3)  => rxSlaves(3),
         -- Masters
         mAxisMaster     => rxMaster,
         mAxisSlave      => rxSlave);   

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
