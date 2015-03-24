-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrApp.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2015-03-24
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.PgpCardG3Pkg.all;

entity EvrApp is
   port (
      -- External Interfaces
      pciToEvr : in  PciToEvrType;
      evrToPci : out EvrToPciType;
      evrToPgp : out EvrToPgpArray(0 to 7);
      -- MGT physical channel
      rxLinkUp : in  sl;
      rxError  : in  sl;
      rxData   : in  slv(15 downto 0);
      -- PLL Reset
      pllRst   : out sl;
      -- Global Signals
      pgpClk   : in  sl;
      pgpRst   : in  sl;
      evrClk   : in  sl;
      evrRst   : out sl;
      pciClk   : in  sl;
      pciRst   : in  sl);        
end EvrApp;

architecture rtl of EvrApp is

   constant DELAY_C : integer := (2**EVR_ACCEPT_DELAY_C)-1;

   type RegType is record
      eventStream : slv(7 downto 0);
      dataStream  : slv(7 downto 0);
      offset      : slv(31 downto 0);
      secondsTmp  : slv(31 downto 0);
      seconds     : slv(31 downto 0);
      toPgp       : EvrToPgpArray(0 to 7);
      toPci       : EvrToPciType;
   end record;
   constant REG_INIT_C : RegType := (
      eventStream => (others => '0'),
      dataStream  => (others => '0'),
      offset      => (others => '0'),
      secondsTmp  => (others => '0'),
      seconds     => (others => '0'),
      toPgp       => (others => EVR_TO_PGP_INIT_C),
      toPci       => EVR_TO_PCI_INIT_C);   
   signal r       : RegType      := REG_INIT_C;
   signal fromPci : PciToEvrType := PCI_TO_EVR_INIT_C;

   attribute dont_touch : string;
   attribute dont_touch of
      r,
      fromPci : signal is "TRUE";

begin

   evrToPci <= r.toPci;
   evrToPgp <= r.toPgp;

   evrRst <= fromPci.evrReset;
   pllRst <= fromPci.pllRst;

   RstSync_0 : entity work.RstSync
      port map (
         clk      => evrClk,
         asyncRst => pciToEvr.countRst,
         syncRst  => fromPci.countRst); 

   -- RstSync_1 : entity work.RstSync
   -- port map (
   -- clk      => evrClk,
   -- asyncRst => pciToEvr.pllRst,
   -- syncRst  => fromPci.pllRst);          

   -- Don't using a RstSync Synchronizer 
   -- because a recovered clock will never be generated.  
   fromPci.pllRst <= pciToEvr.pllRst;

   RstSync_2 : entity work.RstSync
      port map (
         clk      => evrClk,
         asyncRst => pciToEvr.evrReset,
         syncRst  => fromPci.evrReset);      

   Synchronizer_Inst : entity work.Synchronizer
      port map (
         clk     => evrClk,
         dataIn  => pciToEvr.enable,
         dataOut => fromPci.enable);       

   SYNC_TRIG_CODES :
   for i in 0 to 7 generate
      SynchronizerFifo_0 : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 16)
         port map(
            -- Write Ports (wr_clk domain)
            wr_clk            => pciClk,
            din(7 downto 0)   => pciToEvr.runCode(i),
            din(15 downto 8)  => pciToEvr.acceptCode(i),
            -- Read Ports (rd_clk domain)
            rd_clk            => evrClk,
            dout(7 downto 0)  => fromPci.runCode(i),
            dout(15 downto 8) => fromPci.acceptCode(i));  
   end generate SYNC_TRIG_CODES;

   process (evrClk)
      variable i : natural;
   begin
      if rising_edge(evrClk) then
         if fromPci.evrReset = '1' then
            r <= REG_INIT_C;
         else
            for i in 0 to 7 loop
               r.toPgp(i).run    <= '0';
               r.toPgp(i).accept <= '0';
            end loop;
            r.toPci.linkUp <= rxLinkUp;

            -- Error Counting
            if (fromPci.countRst = '1') or (rxLinkUp = '0') then
               r.toPci.errorCnt <= (others => '0');
            elsif (rxError = '1') and (r.toPci.errorCnt /= x"F") then
               r.toPci.errorCnt <= r.toPci.errorCnt + 1;
            end if;

            -- Extract out the event and data bus
            r.eventStream <= rxData(7 downto 0);
            r.dataStream  <= rxData(15 downto 8);

            ----------------------------------------------
            -- Decode time from event stream
            -- Increment offset every cycle
            -- On receive of 0x7D, clear offset, move secondsTmp to output register
            -- On receive of 0x71, shift a 1 into secondsTmp
            -- On receive of 0x70, shift a 0 into secondsTmp
            ----------------------------------------------
            r.offset <= r.offset + 1;
            if r.eventStream = x"7D" then
               r.seconds    <= r.secondsTmp;
               r.secondsTmp <= (others => '0');
               r.offset     <= (others => '0');
            elsif r.eventStream = x"71" then
               r.secondsTmp <= r.secondsTmp(30 downto 0) & '1';
            elsif r.eventStream = x"70" then
               r.secondsTmp <= r.secondsTmp(30 downto 0) & '0';
            end if;

            for i in 0 to 7 loop
               -- Check for run code event 
               if (fromPci.enable = '1') and (r.eventStream = fromPci.runCode(i)) then
                  -- Latch the seconds and offset
                  r.toPgp(i).run     <= '1';
                  r.toPgp(i).seconds <= r.seconds;
                  r.toPgp(i).offset  <= r.offset;
               end if;
               -- Check for accept code event 
               if (fromPci.enable = '1') and (r.eventStream = fromPci.acceptCode(i)) then
                  r.toPgp(i).accept <= '1';
               end if;
            end loop;
            
         end if;
      end if;
   end process;
   
end rtl;
