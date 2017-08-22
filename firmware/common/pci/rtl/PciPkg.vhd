-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciPkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-03
-- Last update: 2016-08-29
-- Platform   : 
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.Pgp2bPkg.all;

package PciPkg is

   constant PCI_AXIS_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(16, TKEEP_NORMAL_C, TUSER_NORMAL_C);
   constant AXIS_32B_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4, TKEEP_COMP_C);
   constant AXIS_16B_CONFIG_C : AxiStreamConfigType := SSI_PGP2B_CONFIG_C;

   -- Max transfer length, words
   constant PCIE_MAX_RX_TRANS_LENGTH_C : integer := 32;  -- 128 Bytes, smallest to ensure comparability
   constant PCIE_MAX_TX_TRANS_LENGTH_C : integer := 256;  -- Request large amounts of data, will be broken up

   ------------------------------------------------------------------------
   -- TranToPci Types/Constants                             
   ------------------------------------------------------------------------          
   -- Transaction FIFO Interface, To PCI
   type TranToPciType is record
      txReq  : sl;                      -- Transaction Request
      trPend : sl;                      -- Transaction is pending
   end record;
   type TranToPciArray is array (integer range<>) of TranToPciType;
   constant TRAN_TO_PCI_INIT_C : TranToPciType := (
      '0',
      '0');    

   ------------------------------------------------------------------------
   -- TranFromPci Types/Constants                             
   ------------------------------------------------------------------------              
   -- Transaction FIFO Interface, From PCI
   type TranFromPciType is record
      locId : slv(15 downto 0);         -- Assigned local ID
      tag   : slv(7 downto 0);          -- Assigned tag
   end record;
   type TranFromPciArray is array (integer range<>) of TranFromPciType;
   constant TRAN_FROM_PCI_INIT_C : TranFromPciType := (
      (others => '0'),
      (others => '0')); 

   ------------------------------------------------------------------------
   -- DescToPci Types/Constants                             
   ------------------------------------------------------------------------                  
   -- Descriptor Interface, To PCI
   -- Status Value
   --   11 = fifoErr
   --   10 = frameErr
   --    9 = tranEofe
   --    8 = tranEofe or frameErr or fifoErr
   --  7:3 = DMA Channel ID
   --  2:0 = Sub Channel ID, Interface Specific
   type DescToPciType is record
      newReq     : sl;                  -- Request for new descriptor address
      doneReq    : sl;                  -- Transfer done request
      doneAddr   : slv(31 downto 2);    -- Address for descriptor
      doneLength : slv(23 downto 0);    -- Length in dwords, 1 based (Rx Only)
      doneStatus : slv(11 downto 0);    -- Status for descriptor     (Rx Only)
   end record;
   type DescToPciArray is array (integer range<>) of DescToPciType;
   constant DESC_TO_PCI_INIT_C : DescToPciType := (
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'));    

   ------------------------------------------------------------------------
   -- DescFromPci Types/Constants                             
   ------------------------------------------------------------------------                      
   -- Descriptor Interface, From PCI
   -- Control Value
   --  7:3 = DMA Channel ID
   --  2:0 = Sub Channel ID, Interface Specific
   type DescFromPciType is record
      newAck     : sl;                  -- New descriptor ack
      newAddr    : slv(31 downto 2);    -- Address for descriptor
      newLength  : slv(23 downto 0);    -- Length in dwords, 1 based (TX Only)
      newControl : slv(7 downto 0);     -- Control word              (TX Only)
      doneAck    : sl;                  -- Descriptor done ack
      contEn     : sl;                  -- Continue enable
      maxFrame   : slv(23 downto 0);    -- Max Frame Length, dwords, 1 based
   end record;
   type DescFromPciArray is array (integer range<>) of DescFromPciType;
   constant DESC_FROM_PCI_INIT_C : DescFromPciType := (
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      '0',
      '0',
      (others => '0')); 

   ------------------------------------------------------------------------
   -- CfgIn Types/Constants                             
   ------------------------------------------------------------------------        
   type CfgInType is record
      irqReq     : sl;
      irqAssert  : sl;
      TrnPending : sl;
   end record;
   constant CFG_IN_INIT_C : CfgInType := (
      '0',
      '0',
      '0');          

   ------------------------------------------------------------------------
   -- CfgOut Types/Constants                             
   ------------------------------------------------------------------------            
   type CfgOutType is record
      irqAck         : sl;
      busNumber      : slv(7 downto 0);
      deviceNumber   : slv(4 downto 0);
      functionNumber : slv(2 downto 0);
      status         : slv(15 downto 0);
      command        : slv(15 downto 0);
      dStatus        : slv(15 downto 0);
      dCommand       : slv(15 downto 0);
      lStatus        : slv(15 downto 0);
      lCommand       : slv(15 downto 0);
      linkState      : slv(2 downto 0);
   end record;
   constant CFG_OUT_INIT_C : CfgOutType := (
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'));          

   ------------------------------------------------------------------------
   -- IrqIn Types/Constants                             
   ------------------------------------------------------------------------    
   type IrqInType is record
      req    : sl;
      enable : sl;
      cntRst : sl;
   end record;
   constant IRQ_IN_INIT_C : IrqInType := (
      req    =>'0',
      enable =>'0',
      cntRst =>'0'); 

   ------------------------------------------------------------------------
   -- IrqOut Types/Constants                             
   ------------------------------------------------------------------------
   type IrqOutType is record
      activeFlag  : sl;
      irqRetryCnt : slv(29 downto 0);
   end record;
   constant IRQ_OUT_INIT_C : IrqOutType := (
      activeFlag  => '0',
      irqRetryCnt => (others => '0'));

   ------------------------------------------------------------------------
   -- 3-DW Header Types/Constants                             
   ------------------------------------------------------------------------
   type PciHdrType is record
      bar       : slv(2 downto 0);
      xLength   : slv(9 downto 0);
      attr      : slv(1 downto 0);
      ep        : sl;
      td        : sl;
      tc        : slv(2 downto 0);
      xType     : slv(4 downto 0);
      fmt       : slv(1 downto 0);
      FirstDwBe : slv(3 downto 0);
      LastDwBe  : slv(3 downto 0);
      Tag       : slv(7 downto 0);
      ReqId     : slv(15 downto 0);
      addr      : slv(31 downto 2);
      data      : slv(31 downto 0);
   end record;
   constant PCI_HDR_INIT_C : PciHdrType := (
      (others => '0'),
      (others => '0'),
      (others => '0'),
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'));   

   function reverseOrderPcie (
      axisMaster : AxiStreamMasterType;
      enReverse  : slv(3 downto 0) := "1111")
      return AxiStreamMasterType;

   function getPcieHdr (
      axisMaster : AxiStreamMasterType)
      return PciHdrType;

end package PciPkg;

package body PciPkg is

   function reverseOrderPcie (
      axisMaster : AxiStreamMasterType;
      enReverse  : slv(3 downto 0) := "1111")
      return AxiStreamMasterType is
      variable retVar : AxiStreamMasterType;
      variable i      : natural;
   begin
      -- Reverse the order for the PCIe data interface
      for i in 0 to 3 loop
         if enReverse(i) = '1' then
            retVar.tdata((32*i)+31 downto (32*i)+24) := axisMaster.tData((32*i)+7 downto (32*i)+0);
            retVar.tdata((32*i)+23 downto (32*i)+16) := axisMaster.tData((32*i)+15 downto (32*i)+8);
            retVar.tdata((32*i)+15 downto (32*i)+8)  := axisMaster.tData((32*i)+23 downto (32*i)+16);
            retVar.tdata((32*i)+7 downto (32*i)+0)   := axisMaster.tData((32*i)+31 downto (32*i)+24);
         else
            retVar.tdata((32*i)+31 downto (32*i)+0) := axisMaster.tData((32*i)+31 downto (32*i)+0);
         end if;
      end loop;
      -- Pass through the other Master AXIS signals
      retVar.tValid := axisMaster.tValid;
      retVar.tStrb  := axisMaster.tStrb;
      retVar.tKeep  := axisMaster.tKeep;
      retVar.tLast  := axisMaster.tLast;
      retVar.tDest  := axisMaster.tDest;
      retVar.tId    := axisMaster.tId;
      retVar.tUser  := axisMaster.tUser;
      return(retVar);
   end function;
   
   function getPcieHdr (
      axisMaster : AxiStreamMasterType)
      return PciHdrType is
      variable retVar : PciHdrType;
   begin
      retVar.addr      := axisMaster.tdata(95 downto 66);
      -- PCIe Reserved := axisMaster.tdata(65 downto 64)
      retVar.ReqId     := axisMaster.tdata(63 downto 48);
      retVar.Tag       := axisMaster.tdata(47 downto 40);
      retVar.LastDwBe  := axisMaster.tdata(39 downto 36);
      retVar.FirstDwBe := axisMaster.tdata(35 downto 32);
      -- PCIe Reserved := axisMaster.tdata(31)
      retVar.fmt       := axisMaster.tdata(30 downto 29);
      retVar.xType     := axisMaster.tdata(28 downto 24);
      -- PCIe Reserved := axisMaster.tdata(23)
      retVar.tc        := axisMaster.tdata(22 downto 20);
      -- PCIe Reserved := axisMaster.tdata(19 downto 16)
      retVar.td        := axisMaster.tdata(15);
      retVar.ep        := axisMaster.tdata(14);
      retVar.attr      := axisMaster.tdata(13 downto 12);
      -- PCIe Reserved := axisMaster.tdata(11 downto 10)
      retVar.xLength   := axisMaster.tdata(9 downto 0);

      -- Reorder Data
      retVar.data(31 downto 24) := axisMaster.tdata(103 downto 96);
      retVar.data(23 downto 16) := axisMaster.tdata(111 downto 104);
      retVar.data(15 downto 8)  := axisMaster.tdata(119 downto 112);
      retVar.data(7 downto 0)   := axisMaster.tdata(127 downto 120);
      -- BAR encoded in the tDest
      retVar.bar                := axisMaster.tDest(2 downto 0);
      return(retVar);
   end function;

end package body PciPkg;
