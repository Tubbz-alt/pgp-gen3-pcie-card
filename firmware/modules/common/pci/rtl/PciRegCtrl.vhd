-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciRegCtrl.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-22
-- Last update: 2014-08-18
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

   type stateType is (
      IDLE_S,
      COMMON_CHECK_S,
      PIPE_WAIT_S,
      ACK_HDR_S);   

   type RegType is record
      wrEn     : sl;
      rdEn     : sl;
      hdr      : PciHdrType;
      rxSlave  : AxiStreamSlaveType;
      txMaster : AxiStreamMasterType;
      state    : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '0',
      '0',
      PCI_HDR_INIT_C,
      AXI_STREAM_SLAVE_INIT_C,
      AXI_STREAM_MASTER_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal rxMaster : AxiStreamMasterType;
   signal txSlave  : AxiStreamSlaveType;

   -- attribute dont_touch      : string;
   -- attribute dont_touch of r : signal is "true";

begin

   PciFifoSync_RX : entity work.PciFifoSync
      generic map (
         TPD_G => TPD_G)   
      port map (
         pciClk      => pciClk,
         pciRst      => pciRst,
         -- Slave Port
         sAxisMaster => regObMaster,
         sAxisSlave  => regObSlave,
         -- Master Port
         mAxisMaster => rxMaster,
         mAxisSlave  => r.rxSlave);             

   comb : process (pciRst, r, regBusy, regRdData, regTranFromPci, rxMaster, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.wrEn           := '0';
      v.rdEn           := '0';
      v.rxSlave.tReady := '0';
      ssiResetFlags(v.txMaster);

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Check for FIFO data
            if (rxMaster.tValid = '1') and (r.rxSlave.tReady = '0') and (regBusy = '0') then
               -- ACK the FIFO tValid
               v.rxSlave.tReady := '1';
               -- Latch the header
               v.hdr            := getPcieHdr(rxMaster);
               -- Check for SOF
               if (ssiGetUserSof(AXIS_PCIE_CONFIG_C, rxMaster) = '1') then
                  -- Next state
                  v.state := COMMON_CHECK_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when COMMON_CHECK_S =>
            -- Check for FMT
            if r.hdr.fmt(1) = '1' then
               -- Write to the register
               v.wrEn  := '1';
               -- Next state
               v.state := ACK_HDR_S;
            -- Else perform a read
            else
               -- Read from the register
               v.rdEn  := '1';
               -- Next state
               v.state := PIPE_WAIT_S;
            end if;
         ----------------------------------------------------------------------
         when PIPE_WAIT_S =>
            -- Next state
            v.state := ACK_HDR_S;
         ----------------------------------------------------------------------
         when ACK_HDR_S =>
            -- Check if FIFO is ready and either write operation or wait for read to complete
            if (txSlave.tReady = '1') and ((r.hdr.fmt(1) = '1') or (regBusy = '0')) then
               ------------------------------------------------------
               -- Generate a 3-DW completion TPL             
               ------------------------------------------------------
               --DW0
               if r.hdr.fmt(1) = '1' then              --echo back write data
                  -- Reorder Data
                  v.txMaster.tData(103 downto 96)  := r.hdr.data(31 downto 24);
                  v.txMaster.tData(111 downto 104) := r.hdr.data(23 downto 16);
                  v.txMaster.tData(119 downto 112) := r.hdr.data(15 downto 8);
                  v.txMaster.tData(127 downto 120) := r.hdr.data(7 downto 0);
               else                     --send read data 
                  -- Reorder Data
                  v.txMaster.tData(103 downto 96)  := regRdData(31 downto 24);
                  v.txMaster.tData(111 downto 104) := regRdData(23 downto 16);
                  v.txMaster.tData(119 downto 112) := regRdData(15 downto 8);
                  v.txMaster.tData(127 downto 120) := regRdData(7 downto 0);
               end if;
               --H2
               v.txMaster.tData(95 downto 80) := r.hdr.ReqId;           -- Echo back requester ID
               v.txMaster.tData(79 downto 72) := r.hdr.Tag;             -- Echo back Tag
               v.txMaster.tData(71)           := '0';  -- PCIe Reserved
               v.txMaster.tData(70 downto 64) := r.hdr.addr(6 downto 2) & "00";  -- Send back Lower Address
               --H1
               v.txMaster.tData(63 downto 48) := regTranFromPci.locId;  -- Send Completer ID
               -- Check for write operation
               if r.hdr.xType /= 0 then
                  v.txMaster.tData(47 downto 45) := "001";              -- Unsupported
               else
                  v.txMaster.tData(47 downto 45) := "000";              -- Success
               end if;
               v.txMaster.tData(44)           := '0';  --The BCM field is always zero, except when a packet origins from a bridge with PCI-X. So it’s zero.
               v.txMaster.tData(43 downto 32) := x"004";   --Byte Count - sending 4 bytes
               --H0
               v.txMaster.tData(31)           := '0';  -- PCIe Reserved
               -- Check for write operation
               if r.hdr.fmt(1) = '1' then
                  v.txMaster.tData(30 downto 29) := "00";
               else
                  v.txMaster.tData(30 downto 29) := "10";
               end if;
               v.txMaster.tData(28 downto 24) := "01010";  --Type=0x0A for completion TLP
               v.txMaster.tData(23)           := '0';  -- PCIe Reserved
               v.txMaster.tData(22 downto 20) := r.hdr.tc;              -- Echo back TC bit
               v.txMaster.tData(19 downto 16) := "0000";   -- PCIe Reserved
               v.txMaster.tData(15)           := r.hdr.td;              -- Echo back TD bit
               v.txMaster.tData(14)           := r.hdr.ep;              -- Echo back EP bit
               v.txMaster.tData(13 downto 12) := r.hdr.attr;            -- Echo back ATTR
               v.txMaster.tData(11 downto 10) := "00";     -- PCIe Reserved
               v.txMaster.tData(9 downto 0)   := r.hdr.xLength;         -- Echo back the length
               ------------------------------------------------------  
               -- Write to the FIFO
               v.txMaster.tValid              := '1';
               -- Set the SOF bit
               ssiSetUserSof(AXIS_PCIE_CONFIG_C, v.txMaster, '1');
               -- Set the EOF bit
               v.txMaster.tLast               := '1';
               -- Check for write operation
               if r.hdr.fmt(1) = '1' then
                  v.txMaster.tKeep := x"0FFF";
               else
                  v.txMaster.tKeep := x"FFFF";
               end if;
               -- Next state
               v.state := IDLE_S;
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
      regBar    <= r.hdr.bar;
      regAddr   <= r.hdr.addr;
      regWrEn   <= r.wrEn;
      regWrData <= r.hdr.data;
      regRdEn   <= r.rdEn;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   PciFifoSync_TX : entity work.PciFifoSync
      generic map (
         TPD_G => TPD_G)   
      port map (
         pciClk      => pciClk,
         pciRst      => pciRst,
         -- Slave Port
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisMaster => regIbMaster,
         mAxisSlave  => regIbSlave);

end rtl;
