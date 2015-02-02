-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTlpInbound.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-25
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

entity PciTlpInbound is
   generic (
      TPD_G      : time := 1 ns;
      DMA_SIZE_G : positive);
   port (
      -- Inbound DMA Interface
      regIbMaster   : in  AxiStreamMasterType;
      regIbSlave    : out AxiStreamSlaveType;
      dmaTxIbMaster : in  AxiStreamMasterArray(0 to DMA_SIZE_G-1);
      dmaTxIbSlave  : out AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      dmaRxIbMaster : in  AxiStreamMasterArray(0 to DMA_SIZE_G-1);
      dmaRxIbSlave  : out AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      -- PCIe Interface
      trnPending    : out sl;
      mAxisMaster   : out AxiStreamMasterType;
      mAxisSlave    : in  AxiStreamSlaveType;
      -- Global Signals
      pciClk        : in  sl;           --125 MHz
      pciRst        : in  sl);       
end PciTlpInbound;

architecture rtl of PciTlpInbound is

   type StateType is (
      IDLE_S,
      REG_S,
      TX_DMA_S,
      RX_DMA_S);    

   type RegType is record
      trnPending   : sl;
      arbCnt       : natural range 0 to DMA_SIZE_G-1;
      chPntr       : natural range 0 to DMA_SIZE_G-1;
      regIbSlave   : AxiStreamSlaveType;
      dmaTxIbSlave : AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      dmaRxIbSlave : AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      txMaster     : AxiStreamMasterType;
      state        : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '0',
      0,
      0,
      AXI_STREAM_SLAVE_INIT_C,
      (others => AXI_STREAM_SLAVE_INIT_C),
      (others => AXI_STREAM_SLAVE_INIT_C),
      AXI_STREAM_MASTER_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal txSlave : AxiStreamSlaveType;
   
begin
   
   comb : process (dmaRxIbMaster, dmaTxIbMaster, pciRst, r, regIbMaster, txSlave) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.trnPending        := '0';
      v.regIbSlave.tReady := '0';
      for i in 0 to DMA_SIZE_G-1 loop
         v.dmaTxIbSlave(i).tReady := '0';
         v.dmaRxIbSlave(i).tReady := '0';
      end loop;
      ssiResetFlags(v.txMaster);

      -- Check if there is a pending transaction
      if regIbMaster.tValid = '1' then
         v.trnPending := '1';
      end if;
      for i in 0 to DMA_SIZE_G-1 loop
         if dmaTxIbMaster(i).tValid = '1' then
            v.trnPending := '1';
         end if;
         if dmaRxIbMaster(i).tValid = '1' then
            v.trnPending := '1';
         end if;
      end loop;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Highest priority: Register access
            if (regIbMaster.tValid = '1') and (r.regIbSlave.tReady = '0') then
               -- Check for SOF bit
               if (ssiGetUserSof(AXIS_PCIE_CONFIG_C, regIbMaster) = '1') then
                  -- Set the ready flag
                  v.regIbSlave.tReady := txSlave.tReady;
                  -- Next state
                  v.state             := REG_S;
               else
                  -- Blow of the data
                  v.regIbSlave.tReady := '1';
               end if;
            else
               -- Check for TX data (only 4DW occur here for TX DMA engine)
               if (dmaTxIbMaster(r.arbCnt).tValid = '1') and (r.dmaTxIbSlave(r.arbCnt).tReady = '0') then
                  -- Check for SOF bit
                  if (ssiGetUserSof(AXIS_PCIE_CONFIG_C, dmaTxIbMaster(r.arbCnt)) = '1') then
                     -- Select the register path
                     v.chPntr                        := r.arbCnt;
                     -- Set the ready flag
                     v.dmaTxIbSlave(r.arbCnt).tReady := txSlave.tReady;
                     -- Next state
                     v.state                         := TX_DMA_S;
                  else
                     -- Blow of the data
                     v.dmaTxIbSlave(r.arbCnt).tReady := '1';
                  end if;
               -- Check for RX data
               elsif (dmaRxIbMaster(r.arbCnt).tValid = '1') and (r.dmaRxIbSlave(r.arbCnt).tReady = '0') then
                  -- Check for SOF bit
                  if (ssiGetUserSof(AXIS_PCIE_CONFIG_C, dmaRxIbMaster(r.arbCnt)) = '1') then
                     -- Select the register path
                     v.chPntr                        := r.arbCnt;
                     -- Set the ready flag
                     v.dmaRxIbSlave(r.arbCnt).tReady := txSlave.tReady;
                     -- Next state
                     v.state                         := RX_DMA_S;
                  else
                     -- Blow of the data
                     v.dmaRxIbSlave(r.arbCnt).tReady := '1';
                  end if;
                  -- Increment counters
                  if r.arbCnt = DMA_SIZE_G-1 then
                     v.arbCnt := 0;
                  else
                     v.arbCnt := r.arbCnt + 1;
                  end if;
               else
                  -- Increment counters
                  if r.arbCnt = DMA_SIZE_G-1 then
                     v.arbCnt := 0;
                  else
                     v.arbCnt := r.arbCnt + 1;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when REG_S =>
            -- Set the ready flag
            v.regIbSlave.tReady := txSlave.tReady;
            -- Check for valid data 
            if (r.regIbSlave.tReady = '1') and (regIbMaster.tValid = '1') then
               -- Write to the FIFO
               v.txMaster := regIbMaster;
               -- Check for tLast
               if regIbMaster.tLast = '1' then
                  -- Stop reading out the FIFO
                  v.regIbSlave.tReady := '0';
                  -- Next state
                  v.state             := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when TX_DMA_S =>
            -- Set the ready flag
            v.dmaTxIbSlave(r.chPntr).tReady := txSlave.tReady;
            -- Check for valid data 
            if (r.dmaTxIbSlave(r.chPntr).tReady = '1') and (dmaTxIbMaster(r.chPntr).tValid = '1') then
               -- Write to the FIFO
               v.txMaster := dmaTxIbMaster(r.chPntr);
               -- Check for tLast
               if dmaTxIbMaster(r.chPntr).tLast = '1' then
                  -- Stop reading out the FIFO
                  v.dmaTxIbSlave(r.chPntr).tReady := '0';
                  -- Next state
                  v.state                         := IDLE_S;
               end if;
            end if;
         ----------------------------------------------------------------------
         when RX_DMA_S =>
            -- Set the ready flag
            v.dmaRxIbSlave(r.chPntr).tReady := txSlave.tReady;
            -- Check for valid data 
            if (r.dmaRxIbSlave(r.chPntr).tReady = '1') and (dmaRxIbMaster(r.chPntr).tValid = '1') then
               -- Write to the FIFO
               v.txMaster := dmaRxIbMaster(r.chPntr);
               -- Check for tLast
               if dmaRxIbMaster(r.chPntr).tLast = '1' then
                  -- Stop reading out the FIFO
                  v.dmaRxIbSlave(r.chPntr).tReady := '0';
                  -- Next state
                  v.state                         := IDLE_S;
               end if;
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
      trnPending   <= r.trnPending;
      regIbSlave   <= r.regIbSlave;
      dmaTxIbSlave <= r.dmaTxIbSlave;
      dmaRxIbSlave <= r.dmaRxIbSlave;

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
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);         

end rtl;
