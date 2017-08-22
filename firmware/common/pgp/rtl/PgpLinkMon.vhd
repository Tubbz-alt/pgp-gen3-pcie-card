-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpLinkMon.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2016-08-21
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
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;

entity PgpLinkMon is
   generic (
      TPD_G : time := 1 ns);
   port (
      countRst     : in  sl;
      fifoError    : in  sl;
      locLinkReady : out sl;
      remLinkReady : out sl;
      cellErrorCnt : out slv(3 downto 0);
      linkDownCnt  : out slv(3 downto 0);
      linkErrorCnt : out slv(3 downto 0);
      fifoErrorCnt : out slv(3 downto 0);
      rxCount      : out Slv4Array(0 to 3);
      pgpRemData   : out slv(7 downto 0);
      locPause     : out slv(3 downto 0);
      locOverflow  : out slv(3 downto 0);
      remPause     : out slv(3 downto 0);
      remOverflow  : out slv(3 downto 0);
      -- Non VC Rx Signals
      pgpRxOut     : in  Pgp2bRxOutType;
      -- Non VC Tx Signals
      pgpTxOut     : in  Pgp2bTxOutType;
      -- Frame Receive Interface
      pgpRxMasters : in  AxiStreamMasterArray(0 to 3);
      pgpRxCtrl    : in  AxiStreamCtrlArray(0 to 3);
      -- Global Signals
      pgpClk       : in  sl;
      pgpRst       : in  sl);       
end PgpLinkMon;

architecture rtl of PgpLinkMon is
   
   type RegType is record
      locLinkReady : sl;
      remLinkReady : sl;
      locPause     : slv(3 downto 0);
      locOverflow  : slv(3 downto 0);
      remPause     : slv(3 downto 0);
      remOverflow  : slv(3 downto 0);
      pgpRemData   : slv(7 downto 0);
      countRst     : slv(1 downto 0);
      cellErrorCnt : slv(3 downto 0);
      linkDownCnt  : slv(3 downto 0);
      linkErrorCnt : slv(3 downto 0);
      fifoErrorCnt : slv(3 downto 0);
      rxCount      : Slv4Array(0 to 3);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => (others => '0')));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin


   -------------------------------
   -- Lane Status and Health
   ------------------------------- 
   comb : process (countRst, fifoError, pgpRst, pgpRxCtrl, pgpRxMasters, pgpRxOut, pgpTxOut, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Added register to help with timing
      v.pgpRemData  := pgpRxOut.remLinkData;
      v.locPause    := pgpTxOut.locPause;
      v.locOverflow := pgpTxOut.locOverflow;
      v.remPause    := pgpRxOut.remPause;
      v.remOverflow := pgpRxOut.remOverflow;
      v.countRst(0) := countRst;
      v.countRst(1) := r.countRst(0);

      -- Local and remote link status
      v.locLinkReady := pgpRxOut.linkReady and PgpTxOut.linkReady;
      v.remLinkReady := pgpRxOut.remLinkReady;

      -- Cell Error Count
      if (r.countRst(1) = '1') or (r.locLinkReady = '0') then
         v.cellErrorCnt := (others => '0');
      elsif (pgpRxOut.cellError = '1') and (r.cellErrorCnt /= x"F") then
         v.cellErrorCnt := r.cellErrorCnt + 1;
      end if;

      -- Link Down Count
      if (r.countRst(1) = '1') then
         v.linkDownCnt := (others => '0');
      elsif (pgpRxOut.linkDown = '1') and (r.linkDownCnt /= x"F") then
         v.linkDownCnt := r.linkDownCnt + 1;
      end if;

      -- Link Error Count
      if (r.countRst(1) = '1') or (r.locLinkReady = '0') then
         v.linkErrorCnt := (others => '0');
      elsif (pgpRxOut.linkError = '1') and (r.linkErrorCnt /= x"F") then
         v.linkErrorCnt := r.linkErrorCnt + 1;
      end if;

      -- FIFO Error Count
      if (r.countRst(1) = '1') or (r.locLinkReady = '0') then
         v.fifoErrorCnt := (others => '0');
      elsif (fifoError = '1') and (r.linkErrorCnt /= x"F") then
         v.fifoErrorCnt := r.fifoErrorCnt + 1;
      end if;

      -- Receive Counter
      for vc in 3 downto 0 loop
         if (r.countRst(1) = '1') or (r.locLinkReady = '0') then
            v.rxCount(vc) := (others => '0');
         elsif (pgpRxMasters(vc).tValid = '1') and (pgpRxMasters(vc).tLast = '1') and (pgpRxCtrl(vc).pause = '0') then
            v.rxCount(vc) := r.rxCount(vc) + 1;
         end if;
      end loop;

      -- Reset
      if (pgpRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      locLinkReady <= r.locLinkReady;
      remLinkReady <= r.remLinkReady;
      cellErrorCnt <= r.cellErrorCnt;
      linkDownCnt  <= r.linkDownCnt;
      linkErrorCnt <= r.linkErrorCnt;
      fifoErrorCnt <= r.fifoErrorCnt;
      rxCount      <= r.rxCount;
      pgpRemData   <= r.pgpRemData;
      locPause     <= r.locPause;
      locOverflow  <= r.locOverflow;
      remPause     <= r.remPause;
      remOverflow  <= r.remOverflow;
      
   end process comb;

   seq : process (pgpClk) is
   begin
      if rising_edge(pgpClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
