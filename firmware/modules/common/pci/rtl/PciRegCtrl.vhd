-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciRegCtrl.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-22
-- Last update: 2015-06-01
-- Platform   : Vivado 2015.1
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

entity PciRegCtrl is
   generic (
      TPD_G : time := 1 ns); 
   port (
      -- PCI Interface
      regTranFromPci : in  TranFromPciType;
      regObMaster    : in  AxiStreamMasterType;
      regObSlave     : out AxiStreamSlaveType;
      regIbMaster    : out AxiStreamMasterType;
      regIbSlave     : in  AxiStreamSlaveType;
      -- Register Signals
      regBar         : out slv(2 downto 0);
      regAddr        : out slv(31 downto 2);
      regWrEn        : out sl;
      regWrData      : out slv(31 downto 0);
      regRdEn        : out sl;
      regRdData      : in  slv(31 downto 0);
      regBusy        : in  sl;
      --Global Signals
      pciClk         : in  sl;
      pciRst         : in  sl);       
end PciRegCtrl;

architecture rtl of PciRegCtrl is

   -- TLP Header format/type values
   constant PIO_CPLD_FMT_TYPE_C : slv(6 downto 0) := "1001010";
   constant PIO_CPL_FMT_TYPE_C  : slv(6 downto 0) := "0001010";

   type stateType is (
      IDLE_S,
      PIPE0_WAIT_S,
      PIPE1_WAIT_S,
      ACK_HDR_S);   

   type RegType is record
      wrEn       : sl;
      rdEn       : sl;
      hdr        : PciHdrType;
      regObSlave : AxiStreamSlaveType;
      txMaster   : AxiStreamMasterType;
      state      : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      wrEn       => '0',
      rdEn       => '0',
      hdr        => PCI_HDR_INIT_C,
      regObSlave => AXI_STREAM_SLAVE_INIT_C,
      txMaster   => AXI_STREAM_MASTER_INIT_C,
      state      => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   comb : process (pciRst, r, regBusy, regIbSlave, regObMaster, regRdData, regTranFromPci) is
      variable v         : RegType;
      variable header    : PciHdrType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.wrEn := '0';
      v.rdEn := '0';

      -- Reset strobing signals
      v.regObSlave.tReady := '0';

      -- Update tValid register
      if regIbSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

      -- Decode the current header for the FIFO
      header := getPcieHdr(regObMaster);

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for FIFO data
            if (regObMaster.tValid = '1') and (regBusy = '0') then
               -- ACK the FIFO tValid
               v.regObSlave.tReady := '1';
               -- Latch the header
               v.hdr               := header;
               -- Check the bar
               if header.bar = 0 then
                  -- Check for read operation
                  if (header.fmt(1) = '0') then
                     -- Read from the register
                     v.rdEn  := '1';
                     -- Next state
                     v.state := PIPE0_WAIT_S;
                  else
                     -- Write to the register
                     v.wrEn  := '1';
                     -- Next state
                     v.state := ACK_HDR_S;
                  end if;
               else
                  -- Next state
                  v.state := ACK_HDR_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when PIPE0_WAIT_S =>
            -- Next state
            v.state := PIPE1_WAIT_S;
         ----------------------------------------------------------------------
         when PIPE1_WAIT_S =>
            -- Next state
            v.state := ACK_HDR_S;            
         ----------------------------------------------------------------------
         when ACK_HDR_S =>
            -- Check if target is ready for data
            if (v.txMaster.tValid = '0') and (regBusy = '0') then
               -- Check for read operation
               if r.hdr.fmt(1) = '0' then
                  -- Write to the FIFO
                  v.txMaster.tValid := '1';
                  -- Set the EOF bit
                  v.txMaster.tLast  := '1';               
                  -- TLP = DW0/H2/H1/H0
                  v.txMaster.tKeep                 := x"FFFF";
                  --DW0 (Reordered Data)
                  v.txMaster.tData(103 downto 96)  := regRdData(31 downto 24);
                  v.txMaster.tData(111 downto 104) := regRdData(23 downto 16);
                  v.txMaster.tData(119 downto 112) := regRdData(15 downto 8);
                  v.txMaster.tData(127 downto 120) := regRdData(7 downto 0);
                  --H2
                  v.txMaster.tData(95 downto 80)   := r.hdr.ReqId;         -- Echo back requester ID
                  v.txMaster.tData(79 downto 72)   := r.hdr.Tag;  -- Echo back Tag               
                  v.txMaster.tData(71)             := '0';        -- PCIe Reserved
                  v.txMaster.tData(70 downto 64)   := r.hdr.addr(6 downto 2) & "00";
                  --H1
                  v.txMaster.tData(63 downto 48)   := regTranFromPci.locId;  -- Send Completer ID                  
                  v.txMaster.tData(47 downto 45)   := "000";      -- Success
                  v.txMaster.tData(44)             := '0';        -- PCIe Reserved
                  v.txMaster.tData(43 downto 32)   := x"004";
                  --H0
                  v.txMaster.tData(31)             := '0';        -- PCIe Reserved               
                  v.txMaster.tData(30 downto 24)   := PIO_CPLD_FMT_TYPE_C;
                  v.txMaster.tData(23)             := '0';        -- PCIe Reserved
                  v.txMaster.tData(22 downto 20)   := r.hdr.tc;   -- Echo back TC bit
                  v.txMaster.tData(19 downto 16)   := "0000";     -- PCIe Reserved
                  v.txMaster.tData(15)             := '0';   -- TD Field
                  v.txMaster.tData(14)             := '0';   -- EP Field
                  v.txMaster.tData(13 downto 12)   := r.hdr.attr;          -- Echo back ATTR
                  v.txMaster.tData(11 downto 10)   := "00";       -- PCIe Reserved                  
                  v.txMaster.tData(9 downto 0)     := toSlv(1,10);               
               end if;
               -------------------------------------------------------------------
               -- Note: Memory write operation are "posted" only, which should not
               --       respond with a completion TLP (Refer to page 179 of 
               --       "PCI Express System Architecture" ISBN: 0-321-15630-7)
               -------------------------------------------------------------------               
               -- Next state
               v.state           := IDLE_S;
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
      regObSlave  <= v.regObSlave;
      regIbMaster <= r.txMaster;
      regBar      <= r.hdr.bar;
      regAddr     <= r.hdr.addr;
      regWrEn     <= r.wrEn;
      regWrData   <= r.hdr.data;
      regRdEn     <= r.rdEn;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
