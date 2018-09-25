-------------------------------------------------------------------------------
-- File       : PgpCardG3Pgp3Core.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
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
use work.PgpCardG3Pkg.all;

entity PgpCardG3Pgp3Core is
   generic (
      TPD_G          : time;
      DMA_LOOPBACK_G : boolean;
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
      sysClk     : in    sl;
      led        : out   slv(7 downto 0);
      tieToGnd   : out   slv(5 downto 0);
      tieToVdd   : out   slv(0 downto 0);
      -- PCIe Ports
      pciRstL    : in    sl;
      pciRefClkP : in    sl;
      pciRefClkN : in    sl;
      pciRxP     : in    slv(3 downto 0);
      pciRxN     : in    slv(3 downto 0);
      pciTxP     : out   slv(3 downto 0);
      pciTxN     : out   slv(3 downto 0);
      -- EVR Ports
      evrRefClkP : in    sl;
      evrRefClkN : in    sl;
      evrRxP     : in    sl;
      evrRxN     : in    sl;
      evrTxP     : out   sl;
      evrTxN     : out   sl;
      -- PGP Ports
      pgpRefClkP : in    sl;
      pgpRefClkN : in    sl;
      pgpRxP     : in    slv(0 downto 0);
      pgpRxN     : in    slv(0 downto 0);
      pgpTxP     : out   slv(0 downto 0);
      pgpTxN     : out   slv(0 downto 0));
end PgpCardG3Pgp3Core;

architecture rtl of PgpCardG3Pgp3Core is

   signal evrClk    : sl;
   signal evrRst    : sl;
   signal pciClk    : sl;
   signal pciRst    : sl;
   signal pciLinkUp : sl;

   signal pgpToPci : PgpToPciType;
   signal pciToPgp : PciToPgpType;
   signal evrToPci : EvrToPciType;
   signal pciToEvr : PciToEvrType;
   signal evrToPgp : EvrToPgpArray(0 to 7);

   signal pgpClk : slv(7 downto 0);
   signal pgpRst : slv(7 downto 0);

begin

   led      <= (others => pciLinkUp);
   tieToGnd <= (others => '0');
   tieToVdd <= (others => '1');

   -----------
   -- PGP Core
   -----------
   PgpCore_Inst : entity work.PgpV3Core
      generic map (
         DMA_LOOPBACK_G => DMA_LOOPBACK_G)
      port map (
         -- Parallel Interface
         evrToPgp   => evrToPgp,
         pciToPgp   => pciToPgp,
         pgpToPci   => pgpToPci,
         -- PGP Fiber Links         
         pgpRefClkP => pgpRefClkP,
         pgpRefClkN => pgpRefClkN,
         pgpRxP     => pgpRxP,
         pgpRxN     => pgpRxN,
         pgpTxP     => pgpTxP,
         pgpTxN     => pgpTxN,
         -- Global Signals
         pgpClk     => pgpClk,
         pgpRst     => pgpRst,
         evrClk     => evrClk,
         evrRst     => evrRst,
         pciClk     => pciClk,
         pciRst     => pciRst);

   -----------
   -- EVR Core
   -----------
   EvrCore_Inst : entity work.EvrCore
      port map (
         -- External Interfaces
         pciToEvr   => pciToEvr,
         evrToPci   => evrToPci,
         evrToPgp   => evrToPgp,
         -- EVR Ports       
         evrRefClkP => evrRefClkP,
         evrRefClkN => evrRefClkN,
         evrRxP     => evrRxP,
         evrRxN     => evrRxN,
         evrTxP     => evrTxP,
         evrTxN     => evrTxN,
         -- Global Signals
         evrClk     => evrClk,
         evrRst     => evrRst,
         pciClk     => pciClk,
         pciRst     => pciRst);

   ------------
   -- PCIe Core
   ------------
   PciCore_Inst : entity work.PciCore
      generic map (
         TPD_G          => TPD_G,
         BUILD_INFO_G   => BUILD_INFO_G,
         LSST_MODE_G    => false,
         DMA_LOOPBACK_G => DMA_LOOPBACK_G,
         -- PGP Configurations
         PGP_RATE_G     => 6.25E+9)
      port map (
         -- FLASH Interface 
         flashAddr  => flashAddr,
         flashData  => flashData,
         flashAdv   => flashAdv,
         flashCe    => flashCe,
         flashOe    => flashOe,
         flashWe    => flashWe,
         -- Parallel Interface
         pgpToPci   => pgpToPci,
         pciToPgp   => pciToPgp,
         pciToEvr   => pciToEvr,
         evrToPci   => evrToPci,
         -- PCIe Ports      
         pciRstL    => pciRstL,
         pciRefClkP => pciRefClkP,
         pciRefClkN => pciRefClkN,
         pciRxP     => pciRxP,
         pciRxN     => pciRxN,
         pciTxP     => pciTxP,
         pciTxN     => pciTxN,
         pciLinkUp  => pciLinkUp,
         -- Global Signals
         pgpClk     => pgpClk,
         pgpRst     => pgpRst,
         evrClk     => evrClk,
         evrRst     => evrRst,
         pciClk     => pciClk,
         pciRst     => pciRst);
end rtl;
