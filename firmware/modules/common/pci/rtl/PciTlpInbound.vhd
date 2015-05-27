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
      DMA_RX_S);    

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
      trnPending   => '0',
      arbCnt       => 0,
      chPntr       => 0,
      regIbSlave   => AXI_STREAM_SLAVE_INIT_C,
      dmaTxIbSlave => (others => AXI_STREAM_SLAVE_INIT_C),
      dmaRxIbSlave => (others => AXI_STREAM_SLAVE_INIT_C),
      txMaster     => AXI_STREAM_MASTER_INIT_C,
      state        => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   -- attribute dont_touch : string;
   -- attribute dont_touch of r : signal is "true";
   
begin

   comb : process (dmaRxIbMaster, dmaTxIbMaster, mAxisSlave, pciRst, r, regIbMaster) is
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

      -- Update tValid register
      if mAxisSlave.tReady = '1' then
         v.txMaster.tValid := '0';
      end if;

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
            -- Check if target is ready for data
            if v.txMaster.tValid = '0' then
               -- 1st priority: Register access (single 32-bit MEM IO access only)
               if regIbMaster.tValid = '1' then
                  -- Ready for data
                  v.regIbSlave.tReady := '1';
                  v.txMaster          := regIbMaster;
               -- 2nd priority: TX DMA's Memory Requesting
               elsif dmaTxIbMaster(r.arbCnt).tValid = '1' then
                  -- Ready for data
                  v.dmaTxIbSlave(r.arbCnt).tReady := '1';
                  v.txMaster          := dmaTxIbMaster(r.arbCnt);             
               else
                  -- Check for RX DMA data
                  if dmaRxIbMaster(r.arbCnt).tValid = '1' then
                     -- Select the register path
                     v.chPntr                        := r.arbCnt;
                     -- Ready for data
                     v.dmaRxIbSlave(r.arbCnt).tReady := '1';
                     v.txMaster                      := dmaRxIbMaster(r.arbCnt);
                     -- Check for not(tLast)
                     if dmaRxIbMaster(r.arbCnt).tLast = '0'then
                        -- Next state
                        v.state := DMA_RX_S;
                     end if;
                  end if;
                  -- Increment counters
                  if r.arbCnt = DMA_SIZE_G-1 then
                     v.arbCnt := 0;
                  else
                     v.arbCnt := r.arbCnt + 1;
                  end if;
               end if;
            end if;
         ----------------------------------------------------------------------
         when DMA_RX_S =>
            -- Check if target is ready for data
            if (v.txMaster.tValid = '0') and (dmaRxIbMaster(r.chPntr).tValid = '1') then
               -- Ready for data
               v.dmaRxIbSlave(r.chPntr).tReady := '1';
               v.txMaster                      := dmaRxIbMaster(r.chPntr);
               -- Check for tLast
               if dmaRxIbMaster(r.chPntr).tLast = '1' then
                  -- Next state
                  v.state := IDLE_S;
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
      regIbSlave   <= v.regIbSlave;
      dmaTxIbSlave <= v.dmaTxIbSlave;
      dmaRxIbSlave <= v.dmaRxIbSlave;
      mAxisMaster  <= r.txMaster;

   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
