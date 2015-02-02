-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciRxDmaEmpty.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-08-26
-- Last update: 2014-08-26
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.PciPkg.all;

entity PciRxDmaEmpty is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- 32-bit Streaming RX Interface
      sAxisClk       : in  sl;
      sAxisRst       : in  sl;
      sAxisMaster    : in  AxiStreamMasterType;
      sAxisSlave     : out AxiStreamSlaveType;
      -- 128-bit Streaming TX Interface
      pciClk         : in  sl;
      pciRst         : in  sl;
      dmaIbMaster    : out AxiStreamMasterType;
      dmaIbSlave     : in  AxiStreamSlaveType;
      dmaDescFromPci : in  DescFromPciType;
      dmaDescToPci   : out DescToPciType;
      dmaTranFromPci : in  TranFromPciType;
      dmaChannel     : in  slv(3 downto 0));
end PciRxDmaEmpty;

architecture rtl of PciRxDmaEmpty is

begin

   sAxisSlave   <= AXI_STREAM_SLAVE_FORCE_C;
   dmaIbMaster  <= AXI_STREAM_MASTER_INIT_C;
   dmaDescToPci <= DESC_TO_PCI_INIT_C;

end rtl;
