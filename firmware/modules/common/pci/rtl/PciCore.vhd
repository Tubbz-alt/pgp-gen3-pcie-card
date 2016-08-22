-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciCore.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2016-08-21
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2016 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;
use work.PgpCardG3Pkg.all;

entity PciCore is
   generic (
      LSST_MODE_G    : boolean;
      DMA_LOOPBACK_G : boolean;
      PGP_RATE_G     : real);
   port (
      -- FLASH Interface 
      flashAddr  : out   slv(25 downto 0);
      flashData  : inout slv(15 downto 0);
      flashAdv   : out   sl;
      flashCe    : out   sl;
      flashOe    : out   sl;
      flashWe    : out   sl;
      -- Parallel Interface
      pgpToPci   : in    PgpToPciType;
      pciToPgp   : out   PciToPgpType;
      evrToPci   : in    EvrToPciType;
      pciToEvr   : out   PciToEvrType;
      -- PCIe Ports 
      pciRstL    : in    sl;
      pciRefClkP : in    sl;
      pciRefClkN : in    sl;
      pciRxP     : in    slv(3 downto 0);
      pciRxN     : in    slv(3 downto 0);
      pciTxP     : out   slv(3 downto 0);
      pciTxN     : out   slv(3 downto 0);
      pciLinkUp  : out   sl;
      -- Global Signals
      pgpClk     : in    sl;
      pgpRst     : in    sl;
      evrClk     : in    sl;
      evrRst     : in    sl;
      pciClk     : out   sl;
      pciRst     : out   sl);      
end PciCore;

architecture mapping of PciCore is

   signal locClk,
      cardReset,
      locRst : sl;
   signal serNumber : slv(63 downto 0);

   signal cfgOut : CfgOutType;
   signal irqIn  : IrqInType;
   signal irqOut : IrqOutType;

   signal regTranFromPci : TranFromPciType;
   signal regObMaster    : AxiStreamMasterType;
   signal regObSlave     : AxiStreamSlaveType;
   signal regIbMaster    : AxiStreamMasterType;
   signal regIbSlave     : AxiStreamSlaveType;

   signal dmaTxTranFromPci : TranFromPciArray(0 to 7);
   signal dmaRxTranFromPci : TranFromPciArray(0 to 7);
   signal dmaTxObMaster    : AxiStreamMasterArray(0 to 7);
   signal dmaTxObSlave     : AxiStreamSlaveArray(0 to 7);
   signal dmaTxIbMaster    : AxiStreamMasterArray(0 to 7);
   signal dmaTxIbSlave     : AxiStreamSlaveArray(0 to 7);
   signal dmaRxIbMaster    : AxiStreamMasterArray(0 to 7);
   signal dmaRxIbSlave     : AxiStreamSlaveArray(0 to 7);

   -- attribute KEEP_HIERARCHY : string;
   -- attribute KEEP_HIERARCHY of
   -- PciFrontEnd_Inst,
   -- PciApp_Inst : label is "TRUE";
   
begin

   pciClk <= locClk;

   -- Add register to help with timing
   process (locClk)
   begin
      if rising_edge(locClk) then
         pciRst <= locRst or cardReset;
      end if;
   end process;

   PciFrontEnd_Inst : entity work.PciFrontEnd
      generic map (
         DMA_SIZE_G => 8)
      port map (
         -- Parallel Interface
         cfgOut           => cfgOut,
         irqIn            => irqIn,
         irqOut           => irqOut,
         -- Register Interface
         regTranFromPci   => regTranFromPci,
         regObMaster      => regObMaster,
         regObSlave       => regObSlave,
         regIbMaster      => regIbMaster,
         regIbSlave       => regIbSlave,
         -- DMA Interface      
         dmaTxTranFromPci => dmaTxTranFromPci,
         dmaRxTranFromPci => dmaRxTranFromPci,
         dmaTxObMaster    => dmaTxObMaster,
         dmaTxObSlave     => dmaTxObSlave,
         dmaTxIbMaster    => dmaTxIbMaster,
         dmaTxIbSlave     => dmaTxIbSlave,
         dmaRxIbMaster    => dmaRxIbMaster,
         dmaRxIbSlave     => dmaRxIbSlave,
         -- PCIe Ports 
         pciRstL          => pciRstL,
         pciRefClkP       => pciRefClkP,
         pciRefClkN       => pciRefClkN,
         pciRxP           => pciRxP,
         pciRxN           => pciRxN,
         pciTxP           => pciTxP,
         pciTxN           => pciTxN,
         pciLinkUp        => pciLinkUp,
         -- System Signals
         serNumber        => serNumber,
         --Global Signals
         pciClk           => locClk,
         pciRst           => locRst);

   PciApp_Inst : entity work.PciApp
      generic map (
         LSST_MODE_G    => LSST_MODE_G,
         DMA_LOOPBACK_G => DMA_LOOPBACK_G,
         PGP_RATE_G     => PGP_RATE_G)     
      port map (
         -- FLASH Interface 
         flashAddr        => flashAddr,
         flashData        => flashData,
         flashAdv         => flashAdv,
         flashCe          => flashCe,
         flashOe          => flashOe,
         flashWe          => flashWe,
         -- System Signals
         serNumber        => serNumber,
         cardReset        => cardReset,
         -- Register Interface
         regTranFromPci   => regTranFromPci,
         regObMaster      => regObMaster,
         regObSlave       => regObSlave,
         regIbMaster      => regIbMaster,
         regIbSlave       => regIbSlave,
         -- DMA Interface      
         dmaTxTranFromPci => dmaTxTranFromPci,
         dmaRxTranFromPci => dmaRxTranFromPci,
         dmaTxObMaster    => dmaTxObMaster,
         dmaTxObSlave     => dmaTxObSlave,
         dmaTxIbMaster    => dmaTxIbMaster,
         dmaTxIbSlave     => dmaTxIbSlave,
         dmaRxIbMaster    => dmaRxIbMaster,
         dmaRxIbSlave     => dmaRxIbSlave,
         -- PCIe Interface
         cfgOut           => cfgOut,
         irqIn            => irqIn,
         irqOut           => irqOut,
         -- Parallel Interface
         PgpToPci         => PgpToPci,
         PciToPgp         => PciToPgp,
         PciToEvr         => PciToEvr,
         EvrToPci         => EvrToPci,
         --Global Signals
         pgpClk           => pgpClk,
         pgpRst           => pgpRst,
         evrClk           => evrClk,
         evrRst           => evrRst,
         pciClk           => locClk,
         pciRst           => locRst); 

end mapping;
