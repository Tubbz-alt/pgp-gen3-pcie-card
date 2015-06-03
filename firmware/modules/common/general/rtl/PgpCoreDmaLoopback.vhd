-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpCoreDmaLoopback.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2015-05-29
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

entity PgpCoreDmaLoopback is
   port (
      -- Parallel Interface
      pciToPgp : in  PciToPgpType;
      pgpToPci : out PgpToPciType;
      -- Global Signals
      pciClk   : in  sl;
      pciRst   : in  sl);      
end PgpCoreDmaLoopback;

architecture mapping of PgpCoreDmaLoopback is

   signal pgpTxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3);
   signal pgpTxSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3);

   signal sAxisMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3);
   signal sAxisSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3);

   signal pgpRxMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3);
   signal pgpRxSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3);

   signal pgpRxOut : Pgp2bRxOutArray(0 to 7);
   signal pgpTxOut : Pgp2bTxOutArray(0 to 7);
   
begin

   GEN_DMA_CH :
   for i in 0 to 7 generate
      GEN_VC_CH :
      for j in 0 to 3 generate
         
         sAxisMasters(i, j) <= pgpTxMasters(i, j) when(pciToPgp.loopback(i) = '1') else AXI_STREAM_MASTER_INIT_C;
         pgpTxSlaves(i, j)  <= sAxisSlaves(i, j)  when(pciToPgp.loopback(i) = '1') else AXI_STREAM_SLAVE_FORCE_C;

         LOOPBACK_FIFO : entity work.AxiStreamFifo
            generic map (
               -- General Configurations
               PIPE_STAGES_G       => 0,
               SLAVE_READY_EN_G    => true,
               VALID_THOLD_G       => 1,
               -- FIFO configurations
               BRAM_EN_G           => false,
               USE_BUILT_IN_G      => false,
               GEN_SYNC_FIFO_G     => true,
               CASCADE_SIZE_G      => 1,
               FIFO_ADDR_WIDTH_G   => 4,
               -- AXI Stream Port Configurations
               SLAVE_AXI_CONFIG_G  => SSI_PGP2B_CONFIG_C,
               MASTER_AXI_CONFIG_G => SSI_PGP2B_CONFIG_C) 
            port map (
               -- Slave Port
               sAxisClk    => pciClk,
               sAxisRst    => pciRst,
               sAxisMaster => sAxisMasters(i, j),
               sAxisSlave  => sAxisSlaves(i, j),
               -- Master Port
               mAxisClk    => pciClk,
               mAxisRst    => pciRst,
               mAxisMaster => pgpRxMasters(i, j),
               mAxisSlave  => pgpRxSlaves(i, j));       
      end generate GEN_VC_CH;

      pgpRxOut(i).phyRxReady   <= '1';
      pgpRxOut(i).linkReady    <= '1';
      pgpRxOut(i).linkPolarity <= (others => '0');
      pgpRxOut(i).frameRx      <= '0';
      pgpRxOut(i).frameRxErr   <= '0';
      pgpRxOut(i).cellError    <= '0';
      pgpRxOut(i).linkDown     <= '0';
      pgpRxOut(i).linkError    <= '0';
      pgpRxOut(i).opCodeEn     <= '0';
      pgpRxOut(i).opCode       <= (others => '0');
      pgpRxOut(i).remLinkReady <= '1';
      pgpRxOut(i).remLinkData  <= (others => '0');
      pgpRxOut(i).remOverflow  <= (others => '0');
      pgpRxOut(i).remPause     <= (others => '0');

      pgpTxOut(i).locOverflow <= (others => '0');
      pgpTxOut(i).locPause    <= (others => '0');
      pgpTxOut(i).phyTxReady  <= '1';
      pgpTxOut(i).linkReady   <= '1';
      pgpTxOut(i).frameTx     <= '0';
      pgpTxOut(i).frameTxErr  <= '0';
      
   end generate GEN_DMA_CH;

   PgpApp_Inst : entity work.PgpApp
      generic map (
         CASCADE_SIZE_G   => 1,
         SLAVE_READY_EN_G => true)
      port map (
         -- External Interfaces
         PciToPgp     => PciToPgp,
         PgpToPci     => PgpToPci,
         EvrToPgp     => (others => EVR_TO_PGP_INIT_C),
         -- Non VC Rx Signals
         pgpRxIn      => open,
         pgpRxOut     => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn      => open,
         pgpTxOut     => pgpTxOut,
         -- Frame Transmit Interface
         pgpTxMasters => pgpTxMasters,
         pgpTxSlaves  => pgpTxSlaves,
         -- Frame Receive Interface
         pgpRxMasters => pgpRxMasters,
         pgpRxSlaves  => pgpRxSlaves,
         pgpRxCtrl    => open,
         -- PLL Status
         pllTxReady   => "11",
         pllRxReady   => "11",
         pllTxRst     => open,
         pllRxRst     => open,
         pgpRxRst     => open,
         pgpTxRst     => open,
         -- Global Signals
         pgpClk       => pciClk,
         pgpRst       => pciRst,
         evrClk       => pciClk,
         evrRst       => pciRst,
         pciClk       => pciClk,
         pciRst       => pciRst); 

end mapping;
