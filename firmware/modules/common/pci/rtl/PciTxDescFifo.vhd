-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciTxDescFifo.vhd
-- Author     : Ryan Herbst <rherbst@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2010-04-27
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
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;

entity PciTxDescFifo is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Input Data
      tFifoWr    : in  sl;
      tFifoDin   : in  slv(63 downto 0);
      tFifoAFull : out sl;
      tFifoCnt   : out slv(8 downto 0);
      -- DMA Controller Interface
      newReq     : in  sl;
      newAck     : out sl;
      newAddr    : out slv(31 downto 2);
      newLength  : out slv(23 downto 0);
      newControl : out slv(7 downto 0);
      --Global Signals
      pciClk     : in  sl;
      pciRst     : in  sl); 
end PciTxDescFifo;

architecture rtl of PciTxDescFifo is

   type StateType is (
      IDLE_S,
      ACK_S);    

   type RegType is record
      newAck     : sl;
      newAddr    : slv(31 downto 2);
      newLength  : slv(23 downto 0);
      newControl : slv(7 downto 0);
      state      : StateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      '0',
      (others => '0'),
      (others => '0'),
      (others => '0'),
      IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal tFifoValid : sl;
   signal tFifoDout  : slv(63 downto 0);
   
begin

   -- FIFO for Transmit dscriptors
   -- Bits[63:32] = Tx Address
   -- Bits[31:24] = Tx Control
   -- Bits[23:00] = Tx Length in words, 1 based
   U_RxFifo : entity work.FifoSync
      generic map(
         BRAM_EN_G    => true,
         FWFT_EN_G    => true,
         FULL_THRES_G => 500,
         DATA_WIDTH_G => 64,
         ADDR_WIDTH_G => 9)    
      port map (
         rst        => pciRst,
         clk        => pciClk,
         din        => tFifoDin,
         wr_en      => tFifoWr,
         rd_en      => r.newAck,
         dout       => tFifoDout,
         valid      => tFifoValid,
         data_count => tFifoCnt,
         prog_full  => tFifoAFull);

   comb : process (newReq, pciRst, r, tFifoDout, tFifoValid) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset strobing signals
      v.newAck := '0';

      case r.state is
         ----------------------------------------------------------------------
         when IDLE_S =>
            if (newReq = '1') and (tFifoValid = '1') then
               v.newAck     := '1';
               v.newAddr    := tFifoDout(63 downto 34);
               v.newControl := tFifoDout(31 downto 24);
               v.newLength  := tFifoDout(23 downto 0);
               -- Next state
               v.state      := ACK_S;
            end if;
         ----------------------------------------------------------------------
         when ACK_S =>
            if newReq = '0'then
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
      newAck     <= r.newAck;
      newAddr    <= r.newAddr;
      newControl <= r.newControl;
      newLength  <= r.newLength;
      
   end process comb;

   seq : process (pciClk) is
   begin
      if rising_edge(pciClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;
