-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTlpCtrl.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-08-30
-- Last update: 2014-07-31
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
use work.SsiPkg.all;
use work.PciPkg.all;

entity PciTlpCtrl is
   generic (
      TPD_G      : time     := 1 ns;
      DMA_SIZE_G : positive := 8);
   port (
      -- PCIe Interface
      locId            : in  slv(15 downto 0);
      trnPending       : out sl;
      sAxisMaster      : in  AxiStreamMasterType;
      sAxisSlave       : out AxiStreamSlaveType;
      mAxisMaster      : out AxiStreamMasterType;
      mAxisSlave       : in  AxiStreamSlaveType;
      -- Register Interface
      regTranFromPci   : out TranFromPciType;
      regObMaster      : out AxiStreamMasterType;
      regObSlave       : in  AxiStreamSlaveType;
      regIbMaster      : in  AxiStreamMasterType;
      regIbSlave       : out AxiStreamSlaveType;
      -- DMA Interface      
      dmaTxTranFromPci : out TranFromPciArray(0 to DMA_SIZE_G-1);
      dmaRxTranFromPci : out TranFromPciArray(0 to DMA_SIZE_G-1);
      dmaTxObMaster    : out AxiStreamMasterArray(0 to DMA_SIZE_G-1);
      dmaTxObSlave     : in  AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      dmaTxIbMaster    : in  AxiStreamMasterArray(0 to DMA_SIZE_G-1);
      dmaTxIbSlave     : out AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      dmaRxIbMaster    : in  AxiStreamMasterArray(0 to DMA_SIZE_G-1);
      dmaRxIbSlave     : out AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      -- Global Signals
      pciClk           : in  sl;        --125 MHz
      pciRst           : in  sl);       
end PciTlpCtrl;

architecture rtl of PciTlpCtrl is

   type StateType is (
      SOF_00_S,
      SOF_10_S,
      EOF_10_S);    

   type RegType is record
      sAxisSlave : AxiStreamSlaveType;
      txMaster   : AxiStreamMasterType;
      master     : AxiStreamMasterType;
      state      : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      AXI_STREAM_SLAVE_INIT_C,
      AXI_STREAM_MASTER_INIT_C,
      AXI_STREAM_MASTER_INIT_C,
      SOF_00_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txSlave    : AxiStreamSlaveType;
   signal axisHdr    : PciHdrType;
   signal axisMaster : AxiStreamMasterType;
   signal axisSlave  : AxiStreamSlaveType;

   signal tFirst : sl;
   signal sof    : slv(3 downto 0);
   signal eof    : slv(3 downto 0);
   
begin

   --------------
   -- TLP Mapping 
   --------------
   DMA_TLP_MAPPING :
   for i in 0 to DMA_SIZE_G-1 generate

      dmaRxTranFromPci(i).tag <= toSlv((2*i)+0, 8);
      dmaTxTranFromPci(i).tag <= toSlv((2*i)+1, 8);

      dmaTxTranFromPci(i).locId <= locId;
      dmaRxTranFromPci(i).locId <= locId;
      
   end generate DMA_TLP_MAPPING;

   regTranFromPci.tag   <= x"00";       -- Not Used
   regTranFromPci.locId <= locId;


   -------------------------------
   -- Receive Interface
   -------------------------------
   tFirst <= sAxisMaster.tUser(1);
   sof    <= sAxisMaster.tUser(7 downto 4);
   eof    <= sAxisMaster.tUser(11 downto 8);

   comb : process (eof, pciRst, r, sAxisMaster, sof, tFirst, txSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals   
      ssiResetFlags(v.txMaster);

      -- Sample the FIFO status
      v.sAxisSlave := txSlave;

      case r.state is
         ----------------------------------------------------------------------
         when SOF_00_S =>
            -- Check for valid data
            if (r.sAxisSlave.tReady = '1') and (sAxisMaster.tValid = '1') then
               -- Pass the data to the FIFO
               v.txMaster := sAxisMaster;
               -- Save this transaction
               v.master   := sAxisMaster;
               -- Check for straddling SOF
               if (tFirst = '1') and (sof /= x"0") then
                  -- Terminate the incoming packet
                  v.txMaster.tLast    := '1';
                  -- Block the SOF in straddling packet
                  v.txMaster.tUser(1) := '0';
                  -- Reset the tLast value
                  v.master.tLast      := '0';
                  -- Set the tKeep value
                  v.master.tKeep      := x"FFFF";
                  -- Next state
                  v.state             := SOF_10_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when SOF_10_S =>
            -- Check for valid data
            if (r.sAxisSlave.tReady = '1') and (sAxisMaster.tValid = '1') then
               -- Pass the data to the FIFO
               v.txMaster                      := r.master;
               -- Update tData value
               v.txMaster.tData(63 downto 0)   := r.master.tData(127 downto 64);
               v.txMaster.tData(127 downto 64) := sAxisMaster.tData(63 downto 0);
               -- Update tKeep value
               v.txMaster.tKeep(7 downto 0)    := r.master.tKeep(15 downto 8);
               v.txMaster.tKeep(15 downto 8)   := sAxisMaster.tKeep(7 downto 0);
               -- Save this transaction
               v.master                        := sAxisMaster;
               -- Check for straddling SOF
               if (tFirst = '1') and (sof /= x"0") then
                  -- Terminate the incoming packet
                  v.txMaster.tLast := '1';
                  -- Reset the tLast value
                  v.master.tLast   := '0';
                  -- Set the tKeep value
                  v.master.tKeep   := x"FFFF";
               -- Check for tLast
               elsif (sAxisMaster.tLast = '1') then
                  -- Check the upper half for EOF
                  if (eof(3) = '1') then
                     -- Stop receiving
                     v.sAxisSlave.tReady := '0';
                     -- Next state
                     v.state             := EOF_10_S;
                  else
                     -- Assert tLast
                     v.txMaster.tLast := '1';
                     -- Next state
                     v.state          := SOF_00_S;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when EOF_10_S =>
            -- Stop receiving
            v.sAxisSlave.tReady := '0';
            -- Check for valid data
            if (txSlave.tReady = '1') then
               -- Pass the data to the FIFO
               v.txMaster                      := r.master;
               -- Update tData value
               v.txMaster.tData(63 downto 0)   := r.master.tData(127 downto 64);
               v.txMaster.tData(127 downto 64) := (others => '0');
               -- Update tKeep value
               v.txMaster.tKeep(7 downto 0)    := r.master.tKeep(15 downto 8);
               v.txMaster.tKeep(15 downto 8)   := x"00";
               -- Terminate the incoming packet
               v.txMaster.tLast                := '1';
               -- Next state
               v.state                         := SOF_00_S;
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
      sAxisSlave <= r.sAxisSlave;
      
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
         mAxisMaster => axisMaster,
         mAxisSlave  => axisSlave);         

   axisHdr <= getPcieHdr(axisMaster);

   PciTlpOutbound_Inst : entity work.PciTlpOutbound
      generic map (
         TPD_G      => TPD_G,
         DMA_SIZE_G => DMA_SIZE_G)
      port map (
         -- PCIe Interface
         sAsixHdr      => axisHdr,
         sAxisMaster   => axisMaster,
         sAxisSlave    => axisSlave,
         -- Outbound DMA Interface
         regObMaster   => regObMaster,
         regObSlave    => regObSlave,
         dmaTxObMaster => dmaTxObMaster,
         dmaTxObSlave  => dmaTxObSlave,
         -- Global Signals
         pciClk        => pciClk,
         pciRst        => pciRst);    

   -------------------------------
   -- Transmit Interface
   -------------------------------
   PciTlpInbound_Inst : entity work.PciTlpInbound
      generic map (
         TPD_G      => TPD_G,
         DMA_SIZE_G => DMA_SIZE_G)
      port map (
         -- Inbound DMA Interface
         regIbMaster   => regIbMaster,
         regIbSlave    => regIbSlave,
         dmaTxIbMaster => dmaTxIbMaster,
         dmaRxIbMaster => dmaRxIbMaster,
         dmaTxIbSlave  => dmaTxIbSlave,
         dmaRxIbSlave  => dmaRxIbSlave,
         -- PCIe Interface
         trnPending    => trnPending,
         mAxisMaster   => mAxisMaster,
         mAxisSlave    => mAxisSlave,
         -- Global Signals
         pciClk        => pciClk,
         pciRst        => pciRst); 

end rtl;
