-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpLinkWatchDog.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-12-17
-- Last update: 2015-01-30
-- Platform   : Vivado 2014.1
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
use work.Pgp2bPkg.all;

entity PgpLinkWatchDog is
   generic (
      TPD_G : time := 1 ns);
   port (
      pgpRxIn     : in  Pgp2bRxOutType;
      pgpRxOut    : out Pgp2bRxOutType;
      stableClk   : in  sl;
      pgpClk      : in  sl;
      pgpRxRstIn  : in  sl;
      pgpRxRstOut : out sl);       
end PgpLinkWatchDog;

architecture rtl of PgpLinkWatchDog is
   
   type StateType is (
      IDLE_S,
      RST_S);      

   type RegType is record
      linkDown : sl;
      state    : StateType;
   end record;
   
   constant REG_INIT_C : RegType := (
      linkDown => '0',
      state    => IDLE_S);  

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal wdtRst,
      pwrUpRst,
      reset,
      linkReady : sl;
   
begin

   -- Pass through signals
   pgpRxOut.phyRxReady   <= pgpRxIn.phyRxReady;
   pgpRxOut.linkReady    <= pgpRxIn.linkReady;
   pgpRxOut.linkPolarity <= pgpRxIn.linkPolarity;
   pgpRxOut.frameRx      <= pgpRxIn.frameRx;
   pgpRxOut.frameRxErr   <= pgpRxIn.frameRxErr;
   pgpRxOut.cellError    <= pgpRxIn.cellError;
   pgpRxOut.linkError    <= pgpRxIn.linkError;
   pgpRxOut.opCodeEn     <= pgpRxIn.opCodeEn;
   pgpRxOut.opCode       <= pgpRxIn.opCode;
   pgpRxOut.remLinkReady <= pgpRxIn.remLinkReady;
   pgpRxOut.remLinkData  <= pgpRxIn.remLinkData;
   pgpRxOut.remOverflow  <= pgpRxIn.remOverflow;
   pgpRxOut.remPause     <= pgpRxIn.remPause;

   Synchronizer_linkReady : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => stableClk,
         dataIn  => pgpRxIn.linkReady,
         dataOut => linkReady);

   WatchDogRst_Inst : entity work.WatchDogRst
      generic map(
         TPD_G      => TPD_G,
         DURATION_G => getTimeRatio(125.0E+6, 0.2))  -- 5 s timeout
      port map (
         clk    => stableClk,
         monIn  => linkReady,
         rstOut => wdtRst);         

   PwrUpRst_Inst : entity work.PwrUpRst
      generic map(
         TPD_G      => TPD_G,
         DURATION_G => getTimeRatio(125.0E+6, 10.0))  -- 100 ms reset
      port map (
         arst   => wdtRst,
         clk    => stableClk,
         rstOut => pwrUpRst);          

   Sync_pllArst : entity work.RstSync
      generic map (
         TPD_G => TPD_G)
      port map (
         clk      => pgpClk,
         asyncRst => pwrUpRst,
         syncRst  => reset);

   comb : process (pgpRxIn, pgpRxRstIn, r, reset) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Pass the status signal
            v.linkDown := pgpRxIn.linkDown;
            -- Check for WDT reset or external reset
            if (pgpRxRstIn = '1') or (reset = '1') then
               -- Next state
               v.state := RST_S;
            end if;
         ----------------------------------------------------------------------
         when RST_S =>
            -- Mask off the status signal
            v.linkDown := '0';
            -- Check if link is up
            if (pgpRxIn.linkReady = '1') then
               -- Next state
               v.state := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      pgpRxOut.linkDown <= r.linkDown;
      
   end process comb;

   seq : process (pgpClk) is
   begin
      if rising_edge(pgpClk) then
         r           <= rin                 after TPD_G;
         pgpRxRstOut <= pgpRxRstIn or reset after TPD_G;
      end if;
   end process seq;
   
end rtl;
