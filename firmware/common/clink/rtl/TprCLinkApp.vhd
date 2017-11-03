------------------------------------------------------------------------------
-- File       : TprCLinkApp.vhd
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
use work.TimingPkg.all;
use work.PgpCardG3Pkg.all;

library unisim;
use unisim.vcomponents.all;

entity TprCLinkApp is
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
end TprCLinkApp;

architecture rtl of TprCLinkApp is

   type RegType is record
      enable      : slv         (0 to 7);
      got_code    : slv         (0 to 7);
      cycles      : Slv32Array  (0 to 7);
      cyclesEnd   : Slv32Array  (0 to 7);
      prescale    : Slv8Array   (0 to 7);
      toCl        : EvrToClArray(0 to 7);
      toPci       : EvrToPciType;
      rxError     : sl;
      ledHold     : slv(29 downto 0);
   end record;

   constant REG_INIT_C : RegType := (
     enable       => (others=>'0'),
     got_code     => (others=>'0'),
     cycles       => (others=>(others=>'0')),
     cyclesEnd    => (others=>(others=>'0')),
     prescale     => (others=>(others=>'0')),
     toCl         => (others=>EVR_TO_CL_INIT_C),
     toPci        => EVR_TO_PCI_INIT_C,
     rxError      => '0',
     ledHold      => (others=>'0') );

   constant LED_HOLD_C : slv(29 downto 0) := toSlv(557142857,30); -- 3 seconds
   
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fromPci            : PciToEvrType := PCI_TO_EVR_INIT_C;
   signal timingRx           : TimingRxType;
   signal fiducial           : sl;
   signal streams            : TimingSerialArray(0 downto 0);
   signal streamIds          : Slv4Array        (0 downto 0) := (others=>x"0");
   signal advance            : slv              (0 downto 0);
   signal dframe             : slv(TIMING_MESSAGE_BITS_C-1 downto 0);
   signal dvalid             : sl;
   signal doverflow          : sl;
   signal dstrobe            : sl;
   signal dmsg               : TimingMessageType;
   signal evrResetS          : sl;

begin

   evrToPci <= r.toPci;
   evrToCl  <= r.toCl;

   evrRst   <= fromPci.evrReset;
   pllRst   <= fromPci.pllRst;

   timingRx.data  <= rxData;
   timingRx.dataK <= rxDataK;
   
   RstSync_0 : entity work.RstSync
      port map (
         clk      => evrClk,
         asyncRst => pciToEvr.evrReset,
         syncRst  => evrResetS);

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

   --
   --  Code from lcls-timing-core/LCLS-II/core/rtl/TimingFrameRx
   --

   U_Deserializer : entity work.TimingDeserializer
      generic map ( STREAMS_C => 1 )
      port map ( clk       => evrClk,
                 rst       => fromPci.evrReset,
                 fiducial  => fiducial,
                 streams   => streams,
                 streamIds => streamIds,
                 advance   => advance,
                 data      => timingRx );

   U_Delay0 : entity work.TimingSerialDelay
     generic map ( NWORDS_G => TIMING_MESSAGE_WORDS_C,
                   FDEPTH_G => 100 )
     port map ( clk        => evrClk,
                rst        => fromPci.evrReset,
                delay      => (others=>'0'),
                fiducial_i => fiducial,
                advance_i  => advance(0),
                stream_i   => streams(0),
                frame_o    => dframe,
                strobe_o   => dstrobe,
                valid_o    => dvalid,
                overflow_o => doverflow);

   dmsg                <= toTimingMessageType(dframe);

   comb: process ( r, fromPci, dmsg, dstrobe, dvalid, rxLinkUp, rxError, evrResetS ) is
     variable v : RegType;
     variable rstDelay : slv(3 downto 0) := (others=>'1');
   begin
     v := r;

     v.toPci.linkUp := rxLinkUp;

     fromPci.evrReset <= rstDelay(0);
     rstDelay         := evrResetS & rstDelay(3 downto 1);
     
     if r.ledHold < LED_HOLD_C then
       v.ledHold := r.ledHold+1;
     else
       v.ledHold := (others=>'0');
       v.toPci.evt140 := '0';
     end if;

     -- Error Counting
     if    (fromPci.countRst = '1') then
       v.toPci.errorCnt := (others => '0');
     elsif (r.rxError = '0') and (rxError = '1') and (r.toPci.errorCnt /= x"FFFFFFFF") then
       v.toPci.errorCnt := r.toPci.errorCnt + 1;
     end if;
     v.rxError := rxError;

     for i in 0 to 7 loop
       v.cyclesEnd(i) := fromPci.trgDelay(i)+fromPci.trgWidth(i);
     end loop;
     
     for i in 0 to 7 loop
       if r.got_code(i) = '1' then
         if (r.cycles(i) >= fromPci.trgDelay(i) and
             r.cycles(i) <  r.cyclesEnd(i)) then
           v.toCl(i).trigger := r.enable(i);
         else
           v.toCl(i).trigger := '0';

           if (r.cycles(i) >= r.cyclesEnd(i)) then
             v.enable  (i) := '0';
             v.got_code(i) := '0';
           end if;
         end if;

         if (r.prescale(i) = fromPci.preScale(i)-1) then
           v.cycles  (i) := r.cycles  (i) + 1;
           v.prescale(i) := (others => '0');
         else
           v.prescale(i) := r.prescale(i) + 1;
         end if;
       end if;
     end loop;
     
     if dstrobe = '1' then
       if dvalid = '1' then
         for i in 0 to 7 loop
           if dmsg.control(conv_integer(fromPci.trgCode(i)(7 downto 4)))(conv_integer(fromPci.trgCode(i)(3 downto 0))) = '1' then
             v.enable  (i)      := fromPci.enable(i);
             v.got_code(i)      := '1';
             v.cycles  (i)      := (others=>'0');
             v.prescale(i)      := (others=>'0');
             v.toCl(i).nanosec  := dmsg.timeStamp(31 downto  0);
             v.toCl(i).seconds  := dmsg.timeStamp(63 downto 32);
             v.toCl(i).fiducial := dmsg.pulseId  (31 downto  0);
           end if;
         end loop;
         v.toPci.evt140 := '1';  -- flashes green LED
       end if;
     end if;

     if fromPci.evrReset = '1' then
       v := REG_INIT_C;
     end if;
     
     rin <= v;
   end process;

   seq: process ( evrClk ) is
   begin
     if rising_edge(evrClk) then
       r <= rin;
     end if;
   end process;

end rtl;
