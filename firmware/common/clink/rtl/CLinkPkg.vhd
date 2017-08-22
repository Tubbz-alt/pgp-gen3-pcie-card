-------------------------------------------------------------------------------
-- Title      : Camera link package
-------------------------------------------------------------------------------
-- File       : CLinkPkg.vhd
-- Created    : 2017-08-22
-- Platform   : 
-- Standard   : VHDL'93/02
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.PciPkg.all;
use work.AxiStreamPkg.all;

package CLinkPkg is

   constant EVR_ACCEPT_DELAY_C : integer := 9;     -- accepted delayed by (2^EVR_ACCEPT_DELAY_C)-1
   constant EVR_RATE_C         : real := 2.38E+9;  -- 2.38 Gbps

   type ClToPciType is record -- Cl Clock Domain
      dmaTxIbMaster     : AxiStreamMasterArray(0 to 7);
      dmaTxObSlave      : AxiStreamSlaveArray (0 to 7);
      dmaTxDescToPci    : DescToPciArray      (0 to 7);
      dmaRxIbMaster     : AxiStreamMasterArray(0 to 7);
      dmaRxDescToPci    : DescToPciArray      (0 to 7);

      rxPllLock         : slv(1 downto 0);
      txPllLock         : slv(1 downto 0);
      locLinkReady      : slv                 (0 to 7);
      remLinkReady      : slv                 (0 to 7);
      cellErrorCnt      : Slv4Array           (0 to 7);
      linkDownCnt       : Slv4Array           (0 to 7);
      linkErrorCnt      : Slv4Array           (0 to 7);
      fifoErrorCnt      : Slv4Array           (0 to 7);
      rxCount           : Slv4VectorArray     (0 to 7, 0 to 3);

      linkUp            : slv                 (0 to 7);
      camLock           : slv                 (0 to 7);

      trgCount          : Slv32Array          (0 to 7);
      trgToFrameDly     : Slv32Array          (0 to 7);
      frameCount        : Slv32Array          (0 to 7);
      frameRate         : Slv32Array          (0 to 7);

      serFifoValid      : slv                 (0 to 7);
      serFifoRd         : Slv8Array           (0 to 7);
   end record;

   constant CL_TO_PCI_INIT_C : ClToPciType := (
      dmaTxIbMaster     => (others => AXI_STREAM_MASTER_INIT_C),
      dmaTxObSlave      => (others => AXI_STREAM_SLAVE_INIT_C ),
      dmaTxDescToPci    => (others => DESC_TO_PCI_INIT_C      ),
      dmaRxIbMaster     => (others => AXI_STREAM_MASTER_INIT_C),
      dmaRxDescToPci    => (others => DESC_TO_PCI_INIT_C      ),

      rxPllLock         => (others => '0'),
      txPllLock         => (others => '0'),
      locLinkReady      => (others => '0'),
      remLinkReady      => (others => '0'),
      cellErrorCnt      => (others => (others => '0')),
      linkDownCnt       => (others => (others => '0')),
      linkErrorCnt      => (others => (others => '0')),
      fifoErrorCnt      => (others => (others => '0')),
      rxCount           => (others => (others => (others => '0'))),

      linkUp            => (others => '0'),
      camLock           => (others => '0'),

      trgCount          => (others => (others => '0')),
      trgToFrameDly     => (others => (others => '0')),
      frameCount        => (others => (others => '0')),
      frameRate         => (others => (others => '0')),

      serFifoValid      => (others => '0'),
      serFifoRd         => (others => (others => '0')));

   -- PCIe -> CL Parallel Interface
   type PciToClType is record          -- pciClk Domain
      txPllRst          : slv(1 downto 0);
      rxPllRst          : slv(1 downto 0);
      dmaTxIbSlave      : AxiStreamSlaveArray (0 to 7);
      dmaTxObMaster     : AxiStreamMasterArray(0 to 7);
      dmaTxDescFromPci  : DescFromPciArray    (0 to 7);
      dmaTxTranFromPci  : TranFromPciArray    (0 to 7);
      dmaRxIbSlave      : AxiStreamSlaveArray (0 to 7);
      dmaRxDescFromPci  : DescFromPciArray    (0 to 7);
      dmaRxTranFromPci  : TranFromPciArray    (0 to 7);

      txRst             : slv                 (0 to 7);
      rxRst             : slv                 (0 to 7);
      countRst          : slv                 (0 to 7);
      pack16            : slv                 (0 to 7);
      trgCC             : Slv2Array           (0 to 7);
      trgPolarity       : slv                 (0 to 7);
      enable            : slv                 (0 to 7);

      numTrains         : Slv32Array          (0 to 7);
      numCycles         : Slv32Array          (0 to 7);
      numBits           : Slv8Array           (0 to 7);

      serBaud           : Slv32Array          (0 to 7);

      serFifoWr         : Slv8Array           (0 to 7);
      serFifoWrEn       : slv                 (0 to 7);
      serFifoRdEn       : slv                 (0 to 7);
   end record;

   -- EVR -> PGP Parallel Interface
   type EvrToClType is record          --evrClk Domain
      trigger  : sl;
      fiducial : slv(31 downto 0);
      seconds  : slv(31 downto 0);
      nanosec  : slv(31 downto 0);
   end record;

   constant EVR_TO_CL_INIT_C : EvrToClType := (
      trigger  => '0',
      fiducial => (others => '0'),
      seconds  => (others => '0'),
      nanosec  => (others => '0'));       

   type EvrToClArray is array (integer range<>) of EvrToClType;

   -- EVR -> PCIe Parallel Interface
   type EvrToPciType is record          --evrClk Domain
      linkUp    : sl;
      evt140    : sl;
      errorCnt  : slv(31 downto 0);
   end record;

   constant EVR_TO_PCI_INIT_C : EvrToPciType := (
      linkUp    => '0',
      evt140    => '0',
      errorCnt  => (others => '0'));

   -- PCIe -> EVR Parallel Interface
   type PciToEvrType is record          -- pciClk Domain
      reset     : sl;
      pllRst    : sl;
      errCntRst : sl;
      enable    : slv       (0 to 7);
      update    : slv       (0 to 7);
      preScale  : Slv8Array (0 to 7);
      trgCode   : Slv8Array (0 to 7);
      trgDelay  : Slv32Array(0 to 7);
      trgWidth  : Slv32Array(0 to 7);
   end record;

   constant PCI_TO_EVR_INIT_C : PciToEvrType := (
      reset     => '0',
      pllRst    => '0',
      errCntRst => '0',
      enable    => (others => '0'),
      update    => (others => '0'),
      preScale  => (others => (others => '0')),
      trgCode   => (others => (others => '0')),
      trgDelay  => (others => (others => '0')),
      trgWidth  => (others => (others => '0')));

   constant idle_string : slv(495 downto 0) := X"45524242524120474D45524120464E4B4C4941204552414D20435259544F5241424F4C415220544F52414C45434541434C204E41494F4154204E4143534C";

end package CLinkPkg;

