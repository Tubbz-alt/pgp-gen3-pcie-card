-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpDmaLoopbackCore.vhd
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
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.PgpCardG3Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity PgpDmaLoopbackCore is
   generic (
      -- PGP Configurations
      PGP_RATE_G : real);          
   port (
      -- Parallel Interface
      PciToPgp : in  PciToPgpType;
      PgpToPci : out PgpToPciType;
      -- Global Signals
      pciClk   : in  sl;
      pciRst   : in  sl);      
end PgpDmaLoopbackCore;

architecture mapping of PgpDmaLoopbackCore is

   signal locked,
      clkFbIn,
      clkFbOut,
      clkOut0,
      pgpclk,
      pgpRst : sl;

   signal pgpTxOut : Pgp2bTxOutArray(0 to 7) := (others => PGP2B_TX_OUT_INIT_C);
   signal pgpRxOut : Pgp2bRxOutArray(0 to 7) := (others => PGP2B_RX_OUT_INIT_C);

   signal pgpMasters : AxiStreamMasterVectorArray(0 to 7, 0 to 3);
   signal pgpSlaves  : AxiStreamSlaveVectorArray(0 to 7, 0 to 3);
   signal pgpCtrls   : AxiStreamCtrlVectorArray(0 to 7, 0 to 3);

begin

   GEN_LANE :
   for i in 0 to 7 generate
      
      pgpTxOut(i).phyTxReady <= '1';
      pgpTxOut(i).linkReady  <= '1';

      pgpRxOut(i).phyRxReady   <= '1';
      pgpRxOut(i).linkReady    <= '1';
      pgpRxOut(i).remLinkReady <= '1';

      GEN_VC :
      for j in 0 to 3 generate
         pgpSlaves(i, j).tReady <= not(pgpCtrls(i, j).pause);
      end generate GEN_VC;
   end generate GEN_LANE;

   PgpApp_Inst : entity work.PgpApp
      generic map (
         PGP_RATE_G => PGP_RATE_G)
      port map (
         -- External Interfaces
         PciToPgp => PciToPgp,
         PgpToPci => PgpToPci,
         EvrToPgp => EVR_TO_PGP_INIT_C,
         -- Non VC Rx Signals
         pgpRxIn  => open,
         pgpRxOut => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn  => open,
         pgpTxOut => pgpTxOut,

         -- Frame Transmit Interface
         pgpTxMasters => pgpMasters,
         pgpTxSlaves  => pgpSlaves,
         -- Frame Receive Interface
         pgpRxMasters => pgpMasters,
         pgpRxCtrl    => pgpCtrls,

         -- -- Frame Transmit Interface
         -- pgpTxMasters => open,
         -- pgpTxSlaves  => (others => (others => AXI_STREAM_SLAVE_FORCE_C)),
         -- -- Frame Receive Interface
         -- pgpRxMasters => (others => (others => AXI_STREAM_MASTER_INIT_C)),
         -- pgpRxCtrl    => open,

         -- PLL Status
         pllTxReady => (others => '1'),
         pllRxReady => (others => '1'),
         pllTxRst   => open,
         pllRxRst   => open,
         pgpRxRst   => open,
         pgpTxRst   => open,

         pgpClk => pgpClk,
         pgpRst => pgpRst,

         -- pgpClk     => pciClk,
         -- pgpRst     => pciRst,

         -- Global Signals
         evrClk => pciClk,
         evrRst => pciRst,
         pciClk => pciClk,
         pciRst => pciRst); 


   RstSync_Inst : entity work.RstSync
      generic map(
         IN_POLARITY_G  => '0',
         OUT_POLARITY_G => '1')      
      port map (
         clk      => pgpClk,
         asyncRst => locked,
         syncRst  => pgpRst);   

   mmcm_adv_inst : MMCME2_ADV
      generic map(
         BANDWIDTH            => "LOW",
         CLKOUT4_CASCADE      => false,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => false,
         DIVCLK_DIVIDE        => 1,
         CLKFBOUT_MULT_F      => 8.000,
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => false,
         CLKOUT0_DIVIDE_F     => 4.000,
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => false,
         CLKIN1_PERIOD        => 8.000,
         REF_JITTER1          => 0.006)
      port map(
         -- Output clocks
         CLKFBOUT     => clkFbOut,
         CLKFBOUTB    => open,
         CLKOUT0      => clkOut0,
         CLKOUT0B     => open,
         CLKOUT1      => open,
         CLKOUT1B     => open,
         CLKOUT2      => open,
         CLKOUT2B     => open,
         CLKOUT3      => open,
         CLKOUT3B     => open,
         CLKOUT4      => open,
         CLKOUT5      => open,
         CLKOUT6      => open,
         -- Input clock control
         CLKFBIN      => clkFbIn,
         CLKIN1       => pciClk,
         CLKIN2       => '0',
         -- Tied to always select the primary input clock
         CLKINSEL     => '1',
         -- Ports for dynamic reconfiguration
         DADDR        => (others => '0'),
         DCLK         => '0',
         DEN          => '0',
         DI           => (others => '0'),
         DO           => open,
         DRDY         => open,
         DWE          => '0',
         -- Ports for dynamic phase shift
         PSCLK        => '0',
         PSEN         => '0',
         PSINCDEC     => '0',
         PSDONE       => open,
         -- Other control and status signals
         LOCKED       => locked,
         CLKINSTOPPED => open,
         CLKFBSTOPPED => open,
         PWRDWN       => '0',
         RST          => pciRst);          

   BUFH_Inst : BUFH
      port map (
         I => clkFbOut,
         O => clkFbIn); 

   BUFG_1 : BUFG
      port map (
         I => clkOut0,
         O => pgpClk);         

end mapping;
