-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpCardG3DmaLoopbackCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-29
-- Last update: 2015-03-24
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
use work.PgpCardG3Pkg.all;

entity PgpCardG3DmaLoopbackCore is  
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
      tieToGnd   : out   slv(3 downto 0);
      tieToVdd   : out   slv(0 downto 0);
      -- PCIe Ports
      pciRstL    : in    sl;
      pciRefClkP : in    sl;
      pciRefClkN : in    sl;
      pciRxP     : in    slv(3 downto 0);
      pciRxN     : in    slv(3 downto 0);
      pciTxP     : out   slv(3 downto 0);
      pciTxN     : out   slv(3 downto 0));
end PgpCardG3DmaLoopbackCore;

architecture rtl of PgpCardG3DmaLoopbackCore is

   signal pciClk: sl;
   signal pciRst: sl;
   signal pciLinkUp: sl;
   signal pgpToPci : PgpToPciType;
   signal pciToPgp : PciToPgpType;

begin

   led(7 downto 1) <= (others => '0');
   led(0) <= pciLinkUp;

   tieToGnd <= (others => '0');
   tieToVdd <= (others => '1');

   -----------
   -- PGP Core
   -----------
   PgpCore_Inst : entity work.PgpCoreDmaLoopback
      port map (
         -- Parallel Interface
         pciToPgp   => pciToPgp,
         pgpToPci   => pgpToPci,
         -- Global Signals
         pciClk     => pciClk,
         pciRst     => pciRst);       

   ------------
   -- PCIe Core
   ------------
   PciCore_Inst : entity work.PciCore
      generic map (
         -- PGP Configurations
         PGP_RATE_G => (0.0))      
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
         pciToEvr   => open,
         evrToPci   => EVR_TO_PCI_INIT_C,
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
         pgpClk     => pciClk,
         pgpRst     => pciRst,
         evrClk     => pciClk,
         evrRst     => pciRst,
         pciClk     => pciClk,
         pciRst     => pciRst);  
end rtl;
