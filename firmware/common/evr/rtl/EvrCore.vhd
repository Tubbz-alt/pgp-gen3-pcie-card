-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-24
-- Last update: 2015-03-24
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
use work.PgpCardG3Pkg.all;

entity EvrCore is
   port (
      -- External Interfaces
      pciToEvr   : in  PciToEvrType;
      evrToPci   : out EvrToPciType;
      evrToPgp   : out EvrToPgpArray(0 to 7);
      -- GT Pins
      evrRefClkP : in  sl;
      evrRefClkN : in  sl;
      evrRxP     : in  sl;
      evrRxN     : in  sl;
      evrTxP     : out sl;
      evrTxN     : out sl;
      -- Global Signals
      pgpClk     : in  sl;
      pgpRst     : in  sl;
      evrClk     : out sl;
      evrRst     : out sl;
      pciClk     : in  sl;
      pciRst     : in  sl);        
end EvrCore;

architecture mapping of EvrCore is

   signal stableClk,
      locClk,
      locRst,
      rxLinkUp,
      rxError,
      pllRst : sl;
   signal qPllRefClk,
      qPllClk,
      qPllLock,
      qPllRefClkLost,
      qPllRst,
      qPllReset : slv(1 downto 0);
   signal rxData : slv(15 downto 0);

   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of
      EvrApp_Inst : label is "TRUE";
   
begin

   evrClk <= locClk;
   evrRst <= locRst or pllRst;

   qPllRst(1) <= qPllReset(1) or pllRst;
   qPllRst(0) <= qPllReset(0) or pllRst;

   EvrClk_Inst : entity work.EvrClk
      port map (
         -- GT Clocking 
         qPllRefClk     => qPllRefClk,
         qPllClk        => qPllClk,
         qPllLock       => qPllLock,
         qPllRst        => qPllRst,
         qPllRefClkLost => qPllRefClkLost,
         -- GT CLK Pins
         evrRefClkP     => evrRefClkP,
         evrRefClkN     => evrRefClkN,
         -- Reference Clock
         stableClk      => stableClk); 

   EvrGtp7_Inst : entity work.EvrGtp7
      port map (
         -- GT Clocking
         stableClk        => stableClk,
         gtQPllOutRefClk  => qPllRefClk,
         gtQPllOutClk     => qPllClk,
         gtQPllLock       => qPllLock,
         gtQPllRefClkLost => qPllRefClkLost,
         gtQPllReset      => qPllReset,
         -- Gt Serial IO
         gtRxP            => evrRxP,
         gtRxN            => evrRxN,
         gtTxP            => evrTxP,
         gtTxN            => evrTxN,
         -- RX Clocking
         evrRxClk         => locClk,
         evrRxRst         => locRst,
         -- EVR Interface
         rxLinkUp         => rxLinkUp,
         rxError          => rxError,
         rxData           => rxData);  

   EvrApp_Inst : entity work.EvrApp
      port map (
         -- External Interfaces
         pciToEvr => pciToEvr,
         evrToPci => evrToPci,
         evrToPgp => evrToPgp,
         -- MGT physical channel
         rxLinkUp => rxLinkUp,
         rxError  => rxError,
         rxData   => rxData,
         -- PLL Reset
         pllRst   => pllRst,
         -- Global Signals
         pgpClk   => pgpClk,
         pgpRst   => pgpRst,
         evrClk   => locClk,
         evrRst   => locRst,
         pciClk   => pciClk,
         pciRst   => pciRst);             
end mapping;
