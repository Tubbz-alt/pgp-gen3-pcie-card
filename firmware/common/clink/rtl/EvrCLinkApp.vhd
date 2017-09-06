-------------------------------------------------------------------------------
-- File       : EvrCLinkApp.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-08-23
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.CLinkPkg.all;
use work.PgpCardG3Pkg.all;

entity EvrCLinkApp is
   port (
      -- External Interfaces
      pciToEvr : in  PciToEvrType;
      evrToPci : out EvrToPciType;
      evrToCl  : out EvrToClArray(0 to 7);
      -- MGT physical channel
      rxLinkUp : in  sl;
      rxError  : in  sl;
      rxData   : in  slv(15 downto 0);
      rxDataK  : in  slv( 1 downto 0);
      -- PLL Reset
      pllRst   : out sl;
      -- Global Signals
      clClk    : in  sl;
      clRst    : in  sl;
      evrClk   : in  sl;
      evrRst   : out sl;
      pciClk   : in  sl;
      pciRst   : in  sl);
end EvrCLinkApp;

architecture rtl of EvrCLinkApp is

   constant EVR_OFFSET_CORRECTION_C : slv(31 downto 0) := x"FFFFFFFE";
   constant DELAY_C                 : integer          := (2**EVR_ACCEPT_DELAY_C)-1;

   type RegType is record
      rxError     : sl;
      seconds_2   : slv(31 downto 0);
      seconds_1   : slv(31 downto 0);
      seconds     : slv(31 downto 0);

      nanosec_2   : slv(31 downto 0);
      nanosec_1   : slv(31 downto 0);
      nanosec     : slv(31 downto 0);

      offset      : slv(31 downto 0);
      fiducialTmp : slv(31 downto 0);
      fiducial    : slv(31 downto 0);
      toCl        : EvrToClArray(0 to 7);
      toPci       : EvrToPciType;
   end record;

   constant REG_INIT_C : RegType := (
      rxError     => '0',
      seconds_2   => (others => '0'),
      seconds_1   => (others => '0'),
      seconds     => (others => '0'),

      nanosec_2   => (others => '0'),
      nanosec_1   => (others => '0'),
      nanosec     => (others => '0'),

      offset      => EVR_OFFSET_CORRECTION_C,
      fiducialTmp => (others => '0'),
      fiducial    => (others => '0'),
      toCl        => (others => EVR_TO_CL_INIT_C),
      toPci       => EVR_TO_PCI_INIT_C);

   signal r       : RegType      := REG_INIT_C;
   signal fromPci : PciToEvrType := PCI_TO_EVR_INIT_C;

   attribute dont_touch : string;
   attribute dont_touch of
      r,
      fromPci : signal is "TRUE";

   signal count_to_3    : slv(28 downto 0)      := (others => '0');
   signal evt140        : sl                    := '0';

   signal dbbyte        : natural range 0 to 63 := 0;

   signal prescale      : Slv8Array (0 to 7)    := (others => (others => '0'));
   signal cycles        : Slv32Array(0 to 7)    := (others => (others => '0'));

   signal enable,
          got_code      : slv       (0 to 7)    := (others => '0');

begin

   evrToPci <= r.toPci;
   evrToCl  <= r.toCl;

   evrRst   <= fromPci.evrReset;
   pllRst   <= fromPci.pllRst;
   enable   <= fromPci.enable;

   RstSync_0 : entity work.RstSync
      port map (
         clk      => evrClk,
         asyncRst => pciToEvr.evrReset,
         syncRst  => fromPci.evrReset);

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
         asyncRst => pciToEvr.countRst,
         syncRst  => fromPci.countRst);

   SynchronizerVector_enable : entity work.SynchronizerVector
      generic map (
         WIDTH_G => 8)
      port map (
         clk     => evrClk,
         dataIn  => pciToEvr.enable,
         dataOut => fromPci.enable);

   SYNC_TRIG_MISC :
   for i in 0 to 7 generate
--      RstSync_i : entity work.RstSync
--         port map (
--            clk      => evrClk,
--            asyncRst => pciToEvr.trgCntRst(i),
--            syncRst  => fromPci.trgCntRst(i));

      SynchronizerFifo_preScale : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G =>  8)
         port map(
            -- Write Ports (wr_clk domain)
            wr_clk => pciClk,
            din    => pciToEvr.preScale(i),
            -- Read Ports (rd_clk domain)
            rd_clk => evrClk,
            dout   => fromPci.preScale(i));

      SynchronizerFifo_trgCode : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G =>  8)
         port map(
            -- Write Ports (wr_clk domain)
            wr_clk => pciClk,
            din    => pciToEvr.trgCode(i),
            -- Read Ports (rd_clk domain)
            rd_clk => evrClk,
            dout   => fromPci.trgCode(i));

      SynchronizerFifo_trgDelay : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 32)
         port map(
            -- Write Ports (wr_clk domain)
            wr_clk => pciClk,
            din    => pciToEvr.trgDelay(i),
            -- Read Ports (rd_clk domain)
            rd_clk => evrClk,
            dout   => fromPci.trgDelay(i));

      SynchronizerFifo_trgWidth : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 32)
         port map(
            -- Write Ports (wr_clk domain)
            wr_clk => pciClk,
            din    => pciToEvr.trgWidth(i),
            -- Read Ports (rd_clk domain)
            rd_clk => evrClk,
            dout   => fromPci.trgWidth(i));
   end generate SYNC_TRIG_MISC;

   process (evrClk)
      variable i : natural;
   begin
      if rising_edge(evrClk) then
         if (fromPci.evrReset = '1') then
            count_to_3 <= (others => '0');
            evt140     <= '0';

            r          <= REG_INIT_C;
         else
            if (rxLinkUp = '1') then
               if (rxDataK = "00") and (rxData(7 downto 0) = 140) then
                  count_to_3 <= (others => '0');
                  evt140     <= '1';
               else
                  if (count_to_3 < 357000000) then
                     count_to_3 <= count_to_3 + 1;
                  else
                     evt140     <= '0';
                  end if;
               end if;
            else
               evt140 <= '0';
            end if;

            for i in 0 to 7 loop
               r.toCl(i).trigger <= '0';
            end loop;

            r.toPci.linkUp <= rxLinkUp;
            r.toPci.evt140 <= evt140;

            -- Error Counting
            if    (fromPci.countRst = '1') then
               r.toPci.errorCnt <= (others => '0');
            elsif (r.rxError = '0') and (rxError = '1') and (r.toPci.errorCnt /= x"FFFFFFFF") then
               r.toPci.errorCnt <= r.toPci.errorCnt + 1;
            end if;
            r.rxError <= rxError;

            -- Counting number of triggers
--            for i in 0 to 7 loop
--               if (fromPci.trgCntRst(i) = '1') then
--                  r.toPci.triggerCnt(i) <= (others => '0');
--               else
--                if (rxLinkUp = '1') and (fromPci.enable(i) = '1') and (r.eventStream = fromPci.trgCode(i)) then
--                  if (rxLinkUp = '1') and (r.eventStream = fromPci.trgCode(i)) then
--                     r.toPci.triggerCnt(i) <= r.toPci.triggerCnt(i) + 1;
--                  end if;
--               end if;
--            end loop;

            -- Extract out the event and data bus
--          r.eventStream <= rxData( 7 downto 0);
--          r.dataStream  <= rxData(15 downto 8);

            --------------------------------------------------------------------
            -- Decode seconds and nanoseconds from data stream
            --------------------------------------------------------------------
            if    (rxDataK = "10") and (rxData(15 downto 8) = x"1C") then
               r.seconds_1  <= r.seconds_2;
               r.seconds    <= r.seconds_1;

               r.nanosec_1  <= r.nanosec_2;
               r.nanosec    <= r.nanosec_1;

               r.seconds_2  <= (others => '0');
               r.nanosec_2  <= (others => '0');

               dbbyte       <= 1;
            elsif (rxDataK = "10") and (rxData(15 downto 8) = x"3C") then
               dbbyte       <= 0;
            elsif (rxDataK = "00") and (dbbyte > 0) then
               if    (dbbyte = 29) then
                  r.seconds_2( 7 downto  0) <= rxData(15 downto 8);
               elsif (dbbyte = 30) then
                  r.seconds_2(15 downto  8) <= rxData(15 downto 8);
               elsif (dbbyte = 31) then
                  r.seconds_2(23 downto 16) <= rxData(15 downto 8);
               elsif (dbbyte = 32) then
                  r.seconds_2(31 downto 24) <= rxData(15 downto 8);
               elsif (dbbyte = 33) then
                  r.nanosec_2( 7 downto  0) <= rxData(15 downto 8);
               elsif (dbbyte = 34) then
                  r.nanosec_2(15 downto  8) <= rxData(15 downto 8);
               elsif (dbbyte = 35) then
                  r.nanosec_2(23 downto 16) <= rxData(15 downto 8);
               elsif (dbbyte = 36) then
                  r.nanosec_2(31 downto 24) <= rxData(15 downto 8);
               end if;

               if (dbbyte < 36) then
                  dbbyte <= dbbyte + 1;
               else
                  dbbyte <= 0;
               end if;
            end if;

            --------------------------------------------------------------------
            -- Decode fiducial from event stream
            -- Increment offset every cycle
            -- On receive of 0x70, shift a 0 into fiducialTmp
            -- On receive of 0x71, shift a 1 into fiducialTmp
            -- On receive of 0x7D, clear offset, move fiducialTmp to FIFO
            --------------------------------------------------------------------
            r.offset <= r.offset + 1;
            if (rxDataK = "00") then
               if    (rxData(7 downto 0) = x"70") then
                  r.fiducialTmp <= r.fiducialTmp(30 downto 0) & '0';
               elsif (rxData(7 downto 0) = x"71") then
                  r.fiducialTmp <= r.fiducialTmp(30 downto 0) & '1';
               elsif (rxData(7 downto 0) = x"7D") then
                  r.fiducial    <= r.fiducialTmp;

                  r.fiducialTmp <= (others => '0');
                  r.offset      <= EVR_OFFSET_CORRECTION_C;
               end if;
            end if;

            if (rxLinkUp = '1') then
               for i in 0 to 7 loop
                  if (got_code(i) = '1') then
                     if (cycles(i) >= fromPci.trgDelay(i)                      ) and
                        (cycles(i) <= fromPci.trgDelay(i)+fromPci.trgWidth(i)-1)     then
                        r.toCl(i).trigger <= enable(i);
                     else
                        r.toCl(i).trigger <= '0';

                        if (cycles(i) >= fromPci.trgDelay(i)+fromPci.trgWidth(i)) then
                           enable  (i) <= '0';
                           got_code(i) <= '0';
                        end if;
                     end if;

                     if (prescale(i) = fromPci.preScale(i)-1) then
                        cycles  (i) <= cycles  (i) + 1;
                        prescale(i) <= (others => '0');
                     else
                        prescale(i) <= prescale(i) + 1;
                     end if;
                  elsif (rxDataK(0) = '1') then
                     if (prescale(i) = fromPci.preScale(i)-1) then
                        cycles  (i) <= cycles  (i) + 1;
                        prescale(i) <= (others => '0');
                     else
                        prescale(i) <= prescale(i) + 1;
                     end if;
                  else
                     if ((rxData(7 downto 0) =  40) and (fromPci.trgCode(i) < 100)) or
                        ((rxData(7 downto 0) = 140) and (fromPci.trgCode(i) >  99))    then
                        cycles  (i) <= (others => '0');
                        prescale(i) <= (others => '0');
                     else
                        if (prescale(i) = fromPci.preScale(i)-1) then
                           cycles  (i) <= cycles  (i) + 1;
                           prescale(i) <= (others => '0');
                        else
                           prescale(i) <= prescale(i) + 1;
                        end if;
                     end if;

                     if (rxData(7 downto 0) = fromPci.trgCode(i)) then
                        r.toCl(i).seconds  <= r.seconds;
                        r.toCl(i).nanosec  <= r.nanosec;
                        r.toCl(i).fiducial <= r.fiducial;
--                      r.toCl(i).offset   <= r.offset;

                        r.toCl(i).trigger  <= '0';

                        enable  (i)         <= fromPci.enable(i);
                        got_code(i)         <= '1';
                     end if;
                  end if;
               end loop;
            end if;
         end if;
      end if;
   end process;

end rtl;

