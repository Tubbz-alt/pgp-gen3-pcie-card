-------------------------------------------------------------------------------
-- File       : PciCLinkCore.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-08-23
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;
use work.CLinkPkg.all;
use work.PgpCardG3Pkg.all;

entity PciCLinkCore is
   generic (
      BUILD_INFO_G   : BuildInfoType;     
      GTP_RATE_G      : real);
   port (
      -- FLASH Interface 
      flashAddr  : out   slv(25 downto 0);
      flashData  : inout slv(15 downto 0);
      flashAdv   : out   sl;
      flashCe    : out   sl;
      flashOe    : out   sl;
      flashWe    : out   sl;
      -- Parallel Interface
      clToPci    : in    ClToPciType;
      pciToCl    : inout PciToClType;
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
      clClk      : in    sl;
      clRst      : in    sl;
      evrClk     : in    sl;
      evrRst     : in    sl;
      pciClk     : out   sl;
      pciRst     : out   sl;      
      -- User LEDs
      led_r      : out   slv(5 downto 0);
      led_b      : out   slv(5 downto 0);
      led_g      : out   slv(5 downto 0));
end PciCLinkCore;

architecture mapping of PciCLinkCore is

   signal locClk,
          locRst,
          cardReset        : sl;
   signal serNumber        : slv(63 downto 0);

   signal cfgOut           : CfgOutType;
   signal irqIn            : IrqInType;
   signal irqOut           : IrqOutType;

   signal regTranFromPci   : TranFromPciType;
   signal regObMaster      : AxiStreamMasterType;
   signal regObSlave       : AxiStreamSlaveType;
   signal regIbMaster      : AxiStreamMasterType;
   signal regIbSlave       : AxiStreamSlaveType;

   signal dmaTxTranFromPci : TranFromPciArray    (0 to 7);
   signal dmaRxTranFromPci : TranFromPciArray    (0 to 7);
   signal dmaTxObMaster    : AxiStreamMasterArray(0 to 7);
   signal dmaTxObSlave     : AxiStreamSlaveArray (0 to 7);
   signal dmaTxIbMaster    : AxiStreamMasterArray(0 to 7);
   signal dmaTxIbSlave     : AxiStreamSlaveArray (0 to 7);
   signal dmaRxIbMaster    : AxiStreamMasterArray(0 to 7);
   signal dmaRxIbSlave     : AxiStreamSlaveArray (0 to 7);

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
         DMA_SIZE_G       => 8)
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

   PciApp_Inst : entity work.PciCLinkApp
      generic map (
         BUILD_INFO_G   => BUILD_INFO_G,
         GTP_RATE_G     => GTP_RATE_G)
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
         clToPci          => clToPci,
         PciToCl          => PciToCl,
         PciToEvr         => PciToEvr,
         EvrToPci         => EvrToPci,
         --Global Signals
         clClk            => clClk,
         clRst            => clRst,
         evrClk           => evrClk,
         evrRst           => evrRst,
         pciClk           => locClk,
         pciRst           => locRst,
         -- User LEDs
         led_r            => led_r,
         led_b            => led_b,
         led_g            => led_g);

end mapping;

