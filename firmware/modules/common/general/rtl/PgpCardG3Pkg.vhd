-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpCardG3Pkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2016-04-26
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.PciPkg.all;
use work.AxiStreamPkg.all;

package PgpCardG3Pkg is

   constant EVR_ACCEPT_DELAY_C : integer := 9;  --accepted delayed by (2^EVR_ACCEPT_DELAY_C)-1

   constant EVR_RATE_C : real := 2.38E+9;  -- 2.38 Gbps

   -- PGP -> PCIe Parallel Interface
   type PgpToPciType is record          -- pgpClk Domain 
      acceptCnt      : Slv32Array(0 to 7);
      evrSyncStatus  : slv(7 downto 0);
      pllTxReady     : slv(1 downto 0);
      pllRxReady     : slv(1 downto 0);
      locLinkReady   : slv(7 downto 0);
      remLinkReady   : slv(7 downto 0);
      cellErrorCnt   : Slv4Array(0 to 7);
      linkDownCnt    : Slv4Array(0 to 7);
      linkErrorCnt   : Slv4Array(0 to 7);
      fifoErrorCnt   : Slv4Array(0 to 7);
      lutDropCnt     : Slv8VectorArray(0 to 7, 0 to 3);
      rxCount        : Slv4VectorArray(0 to 7, 0 to 3);
      dmaTxIbMaster  : AxiStreamMasterArray(0 to 7);
      dmaTxObSlave   : AxiStreamSlaveArray(0 to 7);
      dmaTxDescToPci : DescToPciArray(0 to 7);
      dmaRxIbMaster  : AxiStreamMasterArray(0 to 7);
      dmaRxDescToPci : DescToPciArray(0 to 7);
   end record;
   constant PGP_TO_PCI_INIT_C : PgpToPciType := (
      acceptCnt      => (others => (others => '0')),
      evrSyncStatus  => (others => '0'),
      pllTxReady     => (others => '0'),
      pllRxReady     => (others => '0'),
      locLinkReady   => (others => '0'),
      remLinkReady   => (others => '0'),
      cellErrorCnt   => (others => (others => '0')),
      linkDownCnt    => (others => (others => '0')),
      linkErrorCnt   => (others => (others => '0')),
      fifoErrorCnt   => (others => (others => '0')),
      lutDropCnt     => (others => (others => (others => '0'))),
      rxCount        => (others => (others => (others => '0'))),
      dmaTxIbMaster  => (others => AXI_STREAM_MASTER_INIT_C),
      dmaTxObSlave   => (others => AXI_STREAM_SLAVE_INIT_C),
      dmaTxDescToPci => (others => DESC_TO_PCI_INIT_C),
      dmaRxIbMaster  => (others => AXI_STREAM_MASTER_INIT_C),
      dmaRxDescToPci => (others => DESC_TO_PCI_INIT_C));

   -- PCIe -> PGP Parallel Interface
   type PciToPgpType is record          -- pciClk Domain
      pllTxRst         : slv(1 downto 0);
      pllRxRst         : slv(1 downto 0);
      pgpTxRst         : slv(7 downto 0);
      pgpRxRst         : slv(7 downto 0);
      countRst         : sl;
      loopback         : slv(7 downto 0);
      pgpOpCodeEn      : sl;
      pgpOpCode        : slv(7 downto 0);
      enHeaderCheck    : SlVectorArray(0 to 7, 0 to 3);
      dmaTxIbSlave     : AxiStreamSlaveArray(0 to 7);
      dmaTxObMaster    : AxiStreamMasterArray(0 to 7);
      dmaTxDescFromPci : DescFromPciArray(0 to 7);
      dmaTxTranFromPci : TranFromPciArray(0 to 7);
      dmaRxIbSlave     : AxiStreamSlaveArray(0 to 7);
      dmaRxDescFromPci : DescFromPciArray(0 to 7);
      dmaRxTranFromPci : TranFromPciArray(0 to 7);
      runDelay         : Slv32Array(0 to 7);
      acceptDelay      : Slv32Array(0 to 7);
      acceptCntRst     : slv(7 downto 0);
      evrOpCodeMask    : slv(7 downto 0);
      evrSyncSel       : slv(7 downto 0);
      evrSyncEn        : slv(7 downto 0);
      evrSyncWord      : Slv32Array(0 to 7);
   end record;

   -- EVR -> PGP Parallel Interface
   type EvrToPgpType is record          --evrClk Domain
      run     : sl;
      accept  : sl;
      seconds : slv(31 downto 0);
      offset  : slv(31 downto 0);
   end record;
   type EvrToPgpArray is array (integer range<>) of EvrToPgpType;
   constant EVR_TO_PGP_INIT_C : EvrToPgpType := (
      run     => '0',
      accept  => '0',
      seconds => (others => '0'),
      offset  => (others => '0'));       

   -- EVR -> PCIe Parallel Interface
   type EvrToPciType is record          --evrClk Domain
      linkUp     : sl;
      errorCnt   : slv(31 downto 0);
      seconds    : slv(31 downto 0);
      runCodeCnt : Slv32Array(0 to 7);
   end record;
   constant EVR_TO_PCI_INIT_C : EvrToPciType := (
      linkUp     => '0',
      errorCnt   => (others => '0'),
      seconds    => (others => '0'),
      runCodeCnt => (others => (others => '0')));

   -- PCIe -> EVR Parallel Interface
   type PciToEvrType is record          -- pciClk Domain
      countRst   : sl;
      pllRst     : sl;
      evrReset   : sl;
      enable     : sl;
      runCode    : Slv8Array(0 to 7);
      acceptCode : Slv8Array(0 to 7);
   end record;
   constant PCI_TO_EVR_INIT_C : PciToEvrType := (
      countRst   => '0',
      pllRst     => '0',
      evrReset   => '0',
      enable     => '0',
      runCode    => (others => x"00"),
      acceptCode => (others => x"00"));  

   type TrigLutInType is record         --pgpClk Domain
      raddr : slv(7 downto 0);
   end record;
   type TrigLutInArray is array (integer range<>) of TrigLutInType;
   type TrigLutInVectorArray is array (integer range<>, integer range<>) of TrigLutInType;
   constant TRIG_LUT_IN_INIT_C : TrigLutInType := (
      raddr => (others => '0'));        

   type TrigLutOutType is record        --pgpClk Domain
      accept    : sl;
      seconds   : slv(31 downto 0);
      offset    : slv(31 downto 0);
      acceptCnt : slv(31 downto 0);
   end record;
   type TrigLutOutArray is array (integer range<>) of TrigLutOutType;
   type TrigLutOutVectorArray is array (integer range<>, integer range<>) of TrigLutOutType;
   constant TRIG_LUT_OUT_INIT_C : TrigLutOutType := (
      accept    => '0',
      seconds   => (others => '0'),
      offset    => (others => '0'),
      acceptCnt => (others => '0'));       

end package PgpCardG3Pkg;
