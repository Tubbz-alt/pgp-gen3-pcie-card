-------------------------------------------------------------------------------
-- File       : PgpCardG3_Pgp3_6p250Gbps.vhd
-- Company    : SLAC National Accelerator Laboratory
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

entity PgpCardG3_Pgp3_6p250Gbps is
   generic (
      TPD_G          : time    := 1 ns;
      DMA_LOOPBACK_G : boolean := false;
      BUILD_INFO_G   : BuildInfoType);
   port (
      -- FLASH Interface 
      flashAddr  : out   slv(25 downto 0);
      flashData  : inout slv(15 downto 0);
      flashAdv   : out   sl;
      flashCe    : out   sl;
      flashOe    : out   sl;
      flashWe    : out   sl;
      -- System Signals
      sysClk     : in    sl;            -- 50 MHz
      led        : out   slv(7 downto 0);
      tieToGnd   : out   slv(5 downto 0);
      tieToVdd   : out   slv(0 downto 0);
      -- PCIe Ports
      pciRstL    : in    sl;
      pciRefClkP : in    sl;            -- 100 MHz
      pciRefClkN : in    sl;            -- 100 MHz
      pciRxP     : in    slv(3 downto 0);
      pciRxN     : in    slv(3 downto 0);
      pciTxP     : out   slv(3 downto 0);
      pciTxN     : out   slv(3 downto 0);
      -- EVR Ports
      evrRefClkP : in    sl;            -- 238 MHz
      evrRefClkN : in    sl;            -- 238 MHz
      evrRxP     : in    sl;
      evrRxN     : in    sl;
      evrTxP     : out   sl;
      evrTxN     : out   sl;
      -- PGP Ports
      pgpRefClkP : in    sl;            -- 250 MHz
      pgpRefClkN : in    sl;            -- 250 MHz
      pgpRxP     : in    slv(0 downto 0);
      pgpRxN     : in    slv(0 downto 0);
      pgpTxP     : out   slv(0 downto 0);
      pgpTxN     : out   slv(0 downto 0));
end PgpCardG3_Pgp3_6p250Gbps;

architecture top_level of PgpCardG3_Pgp3_6p250Gbps is

begin

   PgpCardG3Core_Inst : entity work.PgpCardG3Pgp3Core
      generic map (
         TPD_G          => TPD_G,
         DMA_LOOPBACK_G => DMA_LOOPBACK_G,
         BUILD_INFO_G   => BUILD_INFO_G)
      port map (
         -- FLASH Interface 
         flashAddr  => flashAddr,
         flashData  => flashData,
         flashAdv   => flashAdv,
         flashCe    => flashCe,
         flashOe    => flashOe,
         flashWe    => flashWe,
         -- System Signals
         sysClk     => sysClk,
         led        => led,
         tieToGnd   => tieToGnd,
         tieToVdd   => tieToVdd,
         -- PCIe Ports
         pciRstL    => pciRstL,
         pciRefClkP => pciRefClkP,
         pciRefClkN => pciRefClkN,
         pciRxP     => pciRxP,
         pciRxN     => pciRxN,
         pciTxP     => pciTxP,
         pciTxN     => pciTxN,
         -- EVR Ports
         evrRefClkP => evrRefClkP,
         evrRefClkN => evrRefClkN,
         evrRxP     => evrRxP,
         evrRxN     => evrRxN,
         evrTxP     => evrTxP,
         evrTxN     => evrTxN,
         -- PGP Ports
         pgpRefClkP => pgpRefClkP,
         pgpRefClkN => pgpRefClkN,
         pgpRxP     => pgpRxP,
         pgpRxN     => pgpRxN,
         pgpTxP     => pgpTxP,
         pgpTxN     => pgpTxN);

end top_level;
