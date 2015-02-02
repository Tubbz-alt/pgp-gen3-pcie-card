-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTxDma.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-03
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;

entity PciTxDmaEmpty is
   generic (
      TPD_G : time := 1 ns); 
   port (
      -- 128-bit Streaming RX Interface
      pciClk         : in  sl;
      pciRst         : in  sl;
      dmaIbMaster    : out AxiStreamMasterType;
      dmaIbSlave     : in  AxiStreamSlaveType;
      dmaObMaster    : in  AxiStreamMasterType;
      dmaObSlave     : out AxiStreamSlaveType;
      dmaDescFromPci : in  DescFromPciType;
      dmaDescToPci   : out DescToPciType;
      dmaTranFromPci : in  TranFromPciType;
      -- 32-bit Streaming TX Interface
      mAxisClk       : in  sl;
      mAxisRst       : in  sl;
      mAxisMaster    : out AxiStreamMasterType;
      mAxisSlave     : in  AxiStreamSlaveType);     
end PciTxDmaEmpty;

architecture rtl of PciTxDmaEmpty is

   type StateType is (
      IDLE_S,
      CYCLE_WAIT_S,
      TR_DONE_S);    

   type RegType is record
      dmaDescToPci : DescToPciType;
      state        : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      DESC_TO_PCI_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
begin

   mAxisMaster <= AXI_STREAM_MASTER_INIT_C;
   dmaIbMaster <= AXI_STREAM_MASTER_INIT_C;
   dmaObSlave  <= AXI_STREAM_SLAVE_FORCE_C;
   
   comb : process (dmaDescFromPci, pciRst, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Ready to send request memory headers
            v.dmaDescToPci.newReq := '1';
            -- Wait for descriptor to ACK
            if dmaDescFromPci.newAck = '1' then
               -- De-assert request to descriptor
               v.dmaDescToPci.newReq   := '0';
               -- Latch the descriptor values
               v.dmaDescToPci.doneAddr := dmaDescFromPci.newAddr;
               -- Next state
               v.state                 := CYCLE_WAIT_S;
            end if;
         ----------------------------------------------------------------------
         when CYCLE_WAIT_S =>
            v.state := TR_DONE_S;
         ----------------------------------------------------------------------
         when TR_DONE_S =>
            -- Let the descriptor know that we are done
            v.dmaDescToPci.doneReq := '1';
            -- Wait for descriptor to ACK
            if dmaDescFromPci.doneAck = '1' then
               -- Reset flag
               v.dmaDescToPci.doneReq := '0';
               -- Next state
               v.state                := IDLE_S;
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Reset
      if (pciRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs
      dmaDescToPci <= r.dmaDescToPci;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
