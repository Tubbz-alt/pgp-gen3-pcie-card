-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PgpOpCode.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.PgpCardG3Pkg.all;

entity PgpOpCode is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- External Interfaces
      evrToPgp   : in  EvrToPgpType;
      -- PGP core interface
      pgpTxIn    : out Pgp2bTxInType;
      -- RX Virtual Channel Interface
      trigLutIn  : in  TrigLutInArray(0 to 3);
      trigLutOut : out TrigLutOutArray(0 to 3);
      -- Global Signals
      pgpClk     : in  sl;
      pgpRst     : in  sl;
      evrClk     : in  sl;
      evrRst     : in  sl);       
end PgpOpCode;

architecture rtl of PgpOpCode is

   type RegType is record
      ready     : sl;
      valid     : sl;
      we        : sl;
      trigAddr  : slv(7 downto 0);
      waddr     : slv(7 downto 0);
      acceptCnt : slv(31 downto 0);
      seconds   : slv(31 downto 0);
      offset    : slv(31 downto 0);
   end record;
   
   constant REG_INIT_C : RegType := (
      '0',
      '0',
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'));   

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal fromEvr : EvrToPgpType := EVR_TO_PGP_INIT_C;

begin

   -------------------------------
   -- Output Bus Mapping
   ------------------------------- 
   pgpTxIn.flush       <= '0';              -- not used
   pgpTxIn.opCodeEn    <= fromEvr.run;
   pgpTxIn.opCode      <= r.trigAddr;
   pgpTxIn.locData     <= (others => '0');  -- not used
   pgpTxIn.flowCntlDis <= '0';              -- Ignore flow control 

   -------------------------------
   -- Synchronization
   ------------------------------- 
   SynchronizerFifo_Inst : entity work.SynchronizerFifo
      generic map(
         DATA_WIDTH_G => 64)
      port map(
         -- Write Ports (wr_clk domain)
         wr_clk             => evrClk,
         wr_en              => evrToPgp.run,
         din(63 downto 32)  => evrToPgp.seconds,
         din(31 downto 0)   => evrToPgp.offset,
         -- Read Ports (rd_clk domain)
         rd_clk             => pgpClk,
         rd_en              => '1',
         valid              => fromEvr.run,
         dout(63 downto 32) => fromEvr.seconds,
         dout(31 downto 0)  => fromEvr.offset);

   SynchronizerOneShot_Inst : entity work.SynchronizerOneShot
      port map(
         clk     => pgpClk,
         dataIn  => evrToPgp.accept,
         dataOut => fromEvr.accept); 

   -------------------------------
   -- Look up Table
   -------------------------------
   GEN_LUT :
   for vc in 0 to 3 generate
      SimpleDualPortRam_Inst : entity work.SimpleDualPortRam
         generic map(
            BRAM_EN_G    => true,       -- Using BRAM to make the "Place and Route" faster
            DATA_WIDTH_G => 97,
            ADDR_WIDTH_G => 8)
         port map (
            -- Port A
            clka                => pgpClk,
            wea                 => r.we,
            addra               => r.waddr,
            dina(96)            => r.valid,
            dina(95 downto 64)  => r.seconds,
            dina(63 downto 32)  => r.offset,
            dina(31 downto 0)   => r.acceptCnt,
            -- Port B
            clkb                => pgpClk,
            addrb               => trigLutIn(vc).raddr,
            doutb(96)           => trigLutOut(vc).accept,
            doutb(95 downto 64) => trigLutOut(vc).seconds,
            doutb(63 downto 32) => trigLutOut(vc).offset,
            doutb(31 downto 0)  => trigLutOut(vc).acceptCnt);            
   end generate GEN_LUT;

   -------------------------------
   -- Look Up Table Writing Process
   -------------------------------     
   comb : process (fromEvr, pgpRst, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the strobes
      v.we    := '0';
      v.valid := '0';

      -- Check for a trigger
      if fromEvr.run = '1' then
         -- Clear the trigLutOut.accept bit
         v.we       := '1';
         v.waddr    := r.trigAddr;
         -- Latch the Values
         v.seconds  := fromEvr.seconds;
         v.offset   := fromEvr.offset;
         -- Increment the trigAddr
         v.trigAddr := r.trigAddr + 1;
         -- set the ready for accept flag
         v.ready    := '1';
      end if;
      -----------------------------------------------------------------
      -- Check for valid accept bit
      --
      -- Note: The trigger bit must always comes before the accept bit.
      -----------------------------------------------------------------          
      if (fromEvr.accept = '1') and (r.ready = '1') then
         -- Set the trigLutOut.accept bit
         v.we        := '1';
         v.valid     := '1';
         -- Increment the counter
         v.acceptCnt := r.acceptCnt + 1;
         -- Clear the ready for accept flag
         v.ready     := '0';
      end if;

      -- Reset
      if (pgpRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
      
   end process comb;

   seq : process (pgpClk) is
   begin
      if rising_edge(pgpClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
   
end rtl;
