-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
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

library surf;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.PgpCardG3Pkg.all;

entity EvrCLinkAppTb is end EvrCLinkAppTb;

architecture testbed of EvrCLinkAppTb is

   constant CLK_PERIOD_C : time := 10 ns;
   constant TPD_G        : time := CLK_PERIOD_C/4;

   signal clk : sl := '0';
   signal rst : sl := '1';

   signal rxData  : slv(15 downto 0) := (others => '0');
   signal rxDataK : slv(1 downto 0)  := (others => '0');

   signal pciToEvr : PciToEvrType          := PCI_TO_EVR_INIT_C;
   signal evrToPci : EvrToPciType          := EVR_TO_PCI_INIT_C;
   signal evrToPgp : EvrToPgpArray(0 to 7) := (others => EVR_TO_PGP_INIT_C);

begin

   U_ClkRst : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => CLK_PERIOD_C,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 1000 ns)
      port map (
         clkP => clk,
         rst  => rst);

   U_TPGMiniCore : entity work.TPGMiniCore
      generic map (
         TPD_G      => TPD_G,
         NARRAYSBSA => 2)
      port map (
         txClk          => clk,
         txRst          => rst,
         txRdy          => '1',
         txData(0)      => rxData,
         txData(1)      => open,
         txDataK(0)     => rxDataK,
         txDataK(1)     => open,
         axiClk         => clk,
         axiRst         => rst,
         axiReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
         axiReadSlave   => open,
         axiWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
         axiWriteSlave  => open);

   U_EvrApp : entity work.EvrApp
      port map (
         -- External Interfaces
         pciToEvr => pciToEvr,
         evrToPci => evrToPci,
         evrToPgp => evrToPgp,
         -- MGT physical channel
         rxLinkUp => '1',
         rxError  => '0',
         rxData   => rxData,
         -- PLL Reset
         pllRst   => open,
         -- Global Signals
         evrClk   => clk,
         evrRst   => rst,
         pciClk   => clk,
         pciRst   => rst);

end testbed;
