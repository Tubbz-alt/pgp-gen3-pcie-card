-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTxDma.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-03
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

entity PciTxDma is
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
end PciTxDma;

architecture rtl of PciTxDma is

   type StateType is (
      IDLE_S,
      COLLECT_S);    

   type RegType is record
      done      : sl;
      armed     : sl;
      timeout   : sl;
      remLength : slv(23 downto 0);
      timer     : slv(11 downto 0);
      rxSlave   : AxiStreamSlaveType;
      txMaster  : AxiStreamMasterType;
      state     : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '0',
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      AXI_STREAM_SLAVE_INIT_C,
      AXI_STREAM_MASTER_INIT_C,
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal start,
      dmaSof : sl;
   signal newControl : slv(7 downto 0);
   signal newLength  : slv(23 downto 0);
   signal axisMaster : AxiStreamMasterType;
   signal rxMaster   : AxiStreamMasterType;
   signal txSlave    : AxiStreamSlaveType;
   signal dmaSlave   : AxiStreamSlaveType;

   -- attribute dont_touch : string;
   -- attribute dont_touch of
   -- r : signal is "true";
   
begin

   dmaObSlave <= dmaSlave;

   PciTxDmaMemReq_Inst : entity work.PciTxDmaMemReq
      generic map (
         TPD_G => TPD_G)
      port map (
         -- DMA Interface
         dmaIbMaster    => dmaIbMaster,
         dmaIbSlave     => dmaIbSlave,
         dmaObMaster    => dmaObMaster,
         dmaObSlave     => dmaSlave,
         dmaDescFromPci => dmaDescFromPci,
         dmaDescToPci   => dmaDescToPci,
         dmaTranFromPci => dmaTranFromPci,
         -- Transaction Interface
         start          => start,
         done           => r.done,
         remLength      => r.remLength,
         newControl     => newControl,
         newLength      => newLength,
         -- Clock and reset     
         pciClk         => pciClk,
         pciRst         => pciRst);   

   PciFifoSync_RX : entity work.PciFifoSync
      port map (
         pciClk      => pciClk,
         pciRst      => pciRst,
         -- Slave Port
         sAxisMaster => dmaObMaster,
         sAxisSlave  => dmaSlave,
         -- Master Port
         mAxisMaster => axisMaster,
         mAxisSlave  => r.rxSlave);                    

   -- Reverse the data order
   rxMaster <= reverseOrderPcie(axisMaster);

   dmaSof <= '1' when(r.remLength = newLength) else '0';

   comb : process (dmaSof, newControl, newLength, pciRst, r, rxMaster, start, txSlave) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.done    := '0';
      v.timeout := '0';
      ssiResetFlags(v.txMaster);

      ---------------------------
      -- Debugging: Timeout Timer
      ---------------------------
      -- Check if we are running the timer
      if (r.armed = '1') then
         if r.timer /= x"FFF" then
            -- Increment the timer
            v.timer := r.timer + 1;
            -- Check the counter
            if r.timer = 2000 then
               v.timeout := '1';
            end if;
         end if;
      end if;

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            -- Disarm the timer
            v.armed := '0';
            v.timer := (others => '0');
            -- Wait for start signal
            if start = '1' then
               -- Arm the timer
               v.armed          := '1';
               -- Latch the length of the transaction
               v.remLength      := newLength;
               -- Ready for data
               v.rxSlave.tReady := txSlave.tReady;
               -- Next state
               v.state          := COLLECT_S;
            else
               -- Dump any data in the FIFO (first memory request TLP not sent yet)
               v.rxSlave.tReady := '1';
            end if;
         ----------------------------------------------------------------------
         when COLLECT_S =>
            -- Ready for data
            v.rxSlave.tReady := txSlave.tReady;
            -- Check for valid data 
            if (r.rxSlave.tReady = '1') and (rxMaster.tValid = '1') then
               -- Write to the FIFO
               v.txMaster.tValid := '1';
               -- Set the destination
               v.txMaster.tDest  := newControl;
               -- Set the SOF bit
               ssiSetUserSof(AXIS_PCIE_CONFIG_C, v.txMaster, dmaSof);
               -- Check for TLP SOF
               if ssiGetUserSof(AXIS_PCIE_CONFIG_C, rxMaster) = '1' then
                  -- Set the tKeep
                  v.txMaster.tKeep              := x"000F";
                  -- Blow off the 3-DW header and grab the 4th DW
                  v.txMaster.tData(31 downto 0) := rxMaster.tData(127 downto 96);
                  -- Decrement the counter
                  v.remLength                   := r.remLength - 1;
                  -- Check if this is the last DMA word to transfer
                  if r.remLength = 1 then
                     -- Handshake with Memory Requester  
                     v.done           := '1';
                     -- Set the EOF bit
                     v.txMaster.tLast := '1';
                     -- Next state
                     v.state          := IDLE_S;
                  end if;
               else
                  -- Set the tKeep
                  v.txMaster.tKeep := rxMaster.tKeep;
                  -- Latch the data
                  v.txMaster.tData := rxMaster.tData;
                  -- Check RX tKeep 
                  if rxMaster.tKeep(15 downto 12) = x"F" then
                     -- Decrement the counter
                     v.remLength := r.remLength - 4;
                  elsif rxMaster.tKeep(11 downto 8) = x"F" then
                     -- Decrement the counter
                     v.remLength := r.remLength - 3;
                  elsif rxMaster.tKeep(7 downto 4) = x"F" then
                     -- Decrement the counter
                     v.remLength := r.remLength - 2;
                  else
                     -- Decrement the counter
                     v.remLength := r.remLength - 1;
                  end if;
                  ----------------------------------------------------------
                  case r.remLength is
                     when toSlv(1, 24) =>
                        -- Set the tKeep
                        v.txMaster.tKeep := x"000F";
                        -- Handshake with Memory Requester  
                        v.done           := '1';
                        -- Set the EOF bit
                        v.txMaster.tLast := '1';
                        -- Next state
                        v.state          := IDLE_S;
                     when toSlv(2, 24) =>
                        if rxMaster.tKeep(7 downto 0) = x"FF" then
                           -- Set the tKeep
                           v.txMaster.tKeep := x"00FF";
                           -- Handshake with Memory Requester  
                           v.done           := '1';
                           -- Set the EOF bit
                           v.txMaster.tLast := '1';
                           -- Next state
                           v.state          := IDLE_S;
                        end if;
                     when toSlv(3, 24) =>
                        if rxMaster.tKeep(11 downto 0) = x"FFF" then
                           -- Set the tKeep
                           v.txMaster.tKeep := x"0FFF";
                           -- Handshake with Memory Requester  
                           v.done           := '1';
                           -- Set the EOF bit
                           v.txMaster.tLast := '1';
                           -- Next state
                           v.state          := IDLE_S;
                        end if;
                     when toSlv(4, 24) =>
                        if rxMaster.tKeep(15 downto 0) = x"FFFF" then
                           -- Set the tKeep
                           v.txMaster.tKeep := x"FFFF";
                           -- Handshake with Memory Requester  
                           v.done           := '1';
                           -- Set the EOF bit
                           v.txMaster.tLast := '1';
                           -- Next state
                           v.state          := IDLE_S;
                        end if;
                     when others =>
                        null;
                  end case;
               ----------------------------------------------------------
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
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   PciTxDmaFifoMux_Inst : entity work.PciTxDmaFifoMux
      generic map (
         TPD_G => TPD_G)
      port map (
         -- Slave Port
         pciClk      => pciClk,
         pciRst      => pciRst,
         sAxisMaster => r.txMaster,
         sAxisSlave  => txSlave,
         -- Master Port
         mAxisClk    => mAxisClk,
         mAxisRst    => mAxisRst,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);  

end rtl;
