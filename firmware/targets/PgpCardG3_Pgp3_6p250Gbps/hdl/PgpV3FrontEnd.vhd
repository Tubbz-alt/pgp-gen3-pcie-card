-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpV3FrontEnd.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2018-10-01
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

entity PgpV3FrontEnd is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clocking and Resets
      pgpClk       : out slv(7 downto 0);
      pgpRst       : out slv(7 downto 0)                            := (others => '1');
      pgpClk2x     : out sl;
      pgpRst2x     : out sl;
      -- Non VC Rx Signals
      pgpRxIn      : in  Pgp3RxInArray(0 to 7);
      pgpRxOut     : out Pgp3RxOutArray(0 to 7)                     := (others => PGP3_RX_OUT_INIT_C);
      -- Non VC Tx Signals
      pgpTxIn      : in  Pgp3TxInArray(0 to 7);
      pgpTxOut     : out Pgp3TxOutArray(0 to 7)                     := (others => PGP3_TX_OUT_INIT_C);
      -- Frame Transmit Interface
      pgpTxMasters : in  AxiStreamMasterVectorArray(0 to 7, 0 to 3);
      pgpTxSlaves  : out AxiStreamSlaveVectorArray(0 to 7, 0 to 3)  := (others => (others => AXI_STREAM_SLAVE_FORCE_C));
      -- Frame Receive Interface
      pgpRxMasters : out AxiStreamMasterVectorArray(0 to 7, 0 to 3) := (others => (others => AXI_STREAM_MASTER_INIT_C));
      pgpRxCtrl    : in  AxiStreamCtrlVectorArray(0 to 7, 0 to 3);
      -- PGP Fiber Links
      pgpRefClkP   : in  sl;
      pgpRefClkN   : in  sl;
      pgpRxP       : in  slv(3 downto 0);
      pgpRxN       : in  slv(3 downto 0);
      pgpTxP       : out slv(3 downto 0);
      pgpTxN       : out slv(3 downto 0));
end PgpV3FrontEnd;

architecture mapping of PgpV3FrontEnd is

   signal stableClk : sl;
   signal stableRst : sl;

begin

   U_PwrUpRst : entity work.PwrUpRst
      generic map (
         TPD_G => TPD_G)
      port map (
         clk    => stableClk,
         rstOut => stableRst);

   U_PGP_WEST : entity work.Pgp3Gtp7Wrapper
      generic map (
         TPD_G                       => TPD_G,
         NUM_LANES_G                 => 4,
         NUM_VC_G                    => 4,
         RATE_G                      => "6.25Gbps",
         REFCLK_TYPE_G               => PGP3_REFCLK_250_C,
         TX_MUX_ILEAVE_EN_G          => false,
         TX_MUX_ILEAVE_ON_NOTVALID_G => false,
         EN_PGP_MON_G                => false,
         EN_GTH_DRP_G                => false,
         EN_QPLL_DRP_G               => false)
      port map (
         debugClk(0)       => open,
         debugClk(1)       => open,
         debugClk(2)       => pgpClk2x,
         debugRst(0)       => open,
         debugRst(1)       => open,
         debugRst(2)       => pgpRst2x,
         -- Stable Clock and Reset
         stableClk         => stableClk,
         stableRst         => stableRst,
         -- Gt Serial IO
         pgpGtTxP          => pgpTxP(3 downto 0),
         pgpGtTxN          => pgpTxN(3 downto 0),
         pgpGtRxP          => pgpRxP(3 downto 0),
         pgpGtRxN          => pgpRxN(3 downto 0),
         -- GT Clocking
         pgpRefClkP        => pgpRefClkP,
         pgpRefClkN        => pgpRefClkN,
         pgpRefClkDiv2Bufg => stableClk,
         -- Clocking
         pgpClk            => pgpClk(3 downto 0),
         pgpClkRst         => pgpRst(3 downto 0),
         -- Non VC TX Signals
         pgpTxIn(0)        => pgpTxIn(0),
         pgpTxIn(1)        => pgpTxIn(1),
         pgpTxIn(2)        => pgpTxIn(2),
         pgpTxIn(3)        => pgpTxIn(3),
         pgpTxOut(0)       => pgpTxOut(0),
         pgpTxOut(1)       => pgpTxOut(1),
         pgpTxOut(2)       => pgpTxOut(2),
         pgpTxOut(3)       => pgpTxOut(3),
         -- Non VC RX Signals
         pgpRxIn(0)        => pgpRxIn(0),
         pgpRxIn(1)        => pgpRxIn(1),
         pgpRxIn(2)        => pgpRxIn(2),
         pgpRxIn(3)        => pgpRxIn(3),
         pgpRxOut(0)       => pgpRxOut(0),
         pgpRxOut(1)       => pgpRxOut(1),
         pgpRxOut(2)       => pgpRxOut(2),
         pgpRxOut(3)       => pgpRxOut(3),
         -- Frame Transmit Interface
         pgpTxMasters(0)   => pgpTxMasters(0, 0),
         pgpTxMasters(1)   => pgpTxMasters(0, 1),
         pgpTxMasters(2)   => pgpTxMasters(0, 2),
         pgpTxMasters(3)   => pgpTxMasters(0, 3),
         pgpTxMasters(4)   => pgpTxMasters(1, 0),
         pgpTxMasters(5)   => pgpTxMasters(1, 1),
         pgpTxMasters(6)   => pgpTxMasters(1, 2),
         pgpTxMasters(7)   => pgpTxMasters(1, 3),
         pgpTxMasters(8)   => pgpTxMasters(2, 0),
         pgpTxMasters(9)   => pgpTxMasters(2, 1),
         pgpTxMasters(10)  => pgpTxMasters(2, 2),
         pgpTxMasters(11)  => pgpTxMasters(2, 3),
         pgpTxMasters(12)  => pgpTxMasters(3, 0),
         pgpTxMasters(13)  => pgpTxMasters(3, 1),
         pgpTxMasters(14)  => pgpTxMasters(3, 2),
         pgpTxMasters(15)  => pgpTxMasters(3, 3),
         pgpTxSlaves(0)    => pgpTxSlaves(0, 0),
         pgpTxSlaves(1)    => pgpTxSlaves(0, 1),
         pgpTxSlaves(2)    => pgpTxSlaves(0, 2),
         pgpTxSlaves(3)    => pgpTxSlaves(0, 3),
         pgpTxSlaves(4)    => pgpTxSlaves(1, 0),
         pgpTxSlaves(5)    => pgpTxSlaves(1, 1),
         pgpTxSlaves(6)    => pgpTxSlaves(1, 2),
         pgpTxSlaves(7)    => pgpTxSlaves(1, 3),
         pgpTxSlaves(8)    => pgpTxSlaves(2, 0),
         pgpTxSlaves(9)    => pgpTxSlaves(2, 1),
         pgpTxSlaves(10)   => pgpTxSlaves(2, 2),
         pgpTxSlaves(11)   => pgpTxSlaves(2, 3),
         pgpTxSlaves(12)   => pgpTxSlaves(3, 0),
         pgpTxSlaves(13)   => pgpTxSlaves(3, 1),
         pgpTxSlaves(14)   => pgpTxSlaves(3, 2),
         pgpTxSlaves(15)   => pgpTxSlaves(3, 3),
         -- Frame Receive Interface
         pgpRxMasters(0)   => pgpRxMasters(0, 0),
         pgpRxMasters(1)   => pgpRxMasters(0, 1),
         pgpRxMasters(2)   => pgpRxMasters(0, 2),
         pgpRxMasters(3)   => pgpRxMasters(0, 3),
         pgpRxMasters(4)   => pgpRxMasters(1, 0),
         pgpRxMasters(5)   => pgpRxMasters(1, 1),
         pgpRxMasters(6)   => pgpRxMasters(1, 2),
         pgpRxMasters(7)   => pgpRxMasters(1, 3),
         pgpRxMasters(8)   => pgpRxMasters(2, 0),
         pgpRxMasters(9)   => pgpRxMasters(2, 1),
         pgpRxMasters(10)  => pgpRxMasters(2, 2),
         pgpRxMasters(11)  => pgpRxMasters(2, 3),
         pgpRxMasters(12)  => pgpRxMasters(3, 0),
         pgpRxMasters(13)  => pgpRxMasters(3, 1),
         pgpRxMasters(14)  => pgpRxMasters(3, 2),
         pgpRxMasters(15)  => pgpRxMasters(3, 3),
         pgpRxCtrl(0)      => pgpRxCtrl(0, 0),
         pgpRxCtrl(1)      => pgpRxCtrl(0, 1),
         pgpRxCtrl(2)      => pgpRxCtrl(0, 2),
         pgpRxCtrl(3)      => pgpRxCtrl(0, 3),
         pgpRxCtrl(4)      => pgpRxCtrl(1, 0),
         pgpRxCtrl(5)      => pgpRxCtrl(1, 1),
         pgpRxCtrl(6)      => pgpRxCtrl(1, 2),
         pgpRxCtrl(7)      => pgpRxCtrl(1, 3),
         pgpRxCtrl(8)      => pgpRxCtrl(2, 0),
         pgpRxCtrl(9)      => pgpRxCtrl(2, 1),
         pgpRxCtrl(10)     => pgpRxCtrl(2, 2),
         pgpRxCtrl(11)     => pgpRxCtrl(2, 3),
         pgpRxCtrl(12)     => pgpRxCtrl(3, 0),
         pgpRxCtrl(13)     => pgpRxCtrl(3, 1),
         pgpRxCtrl(14)     => pgpRxCtrl(3, 2),
         pgpRxCtrl(15)     => pgpRxCtrl(3, 3));

   pgpClk(7 downto 4) <= (others => stableClk);

end mapping;
