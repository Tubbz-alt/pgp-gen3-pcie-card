-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EvrGtp7.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-24
-- Last update: 2015-11-16
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

entity EvrGtp7 is
   port (
      -- GT Clocking
      stableClk        : in  sl;        -- GT needs a stable clock to "boot up"
      gtQPllOutRefClk  : in  slv(1 downto 0);
      gtQPllOutClk     : in  slv(1 downto 0);
      gtQPllLock       : in  slv(1 downto 0);
      gtQPllRefClkLost : in  slv(1 downto 0);
      gtQPllReset      : out slv(1 downto 0);
      -- Gt Serial IO
      gtTxP            : out sl;        -- GT Serial Transmit Positive
      gtTxN            : out sl;        -- GT Serial Transmit Negative
      gtRxP            : in  sl;        -- GT Serial Receive Positive
      gtRxN            : in  sl;        -- GT Serial Receive Negative
      -- Rx clocking
      evrRxClk         : out sl;
      evrRxRst         : in  sl;
      -- EVR Interface
      rxLinkUp         : out sl;
      rxError          : out sl;
      rxData           : out slv(15 downto 0);
      rxDataK          : out slv(1 downto 0));
end EvrGtp7;

architecture mapping of EvrGtp7 is

   signal gtRxResetDone,
      dataValid,
      evrRxRecClk,
      linkUp : sl;
   signal decErr,
      dispErr : slv(1 downto 0);
   signal cnt      : slv(7 downto 0);
   signal gtRxData : slv(19 downto 0);
   signal data     : slv(15 downto 0);
   signal dataK    : slv(1 downto 0);
   
begin
   -------------------------------
   -- Output Bus Mapping
   ------------------------------- 
   rxError  <= not(dataValid) and linkUp;
   rxLinkUp <= linkUp;
   evrRxClk <= evrRxRecClk;

   --------------------------------------------------------------------------------------------------
   -- Rx Data Path
   -- Hold Decoder and PgpRx in reset until GtRxResetDone.
   --------------------------------------------------------------------------------------------------
   Decoder8b10b_Inst : entity work.Decoder8b10b
      generic map (
         RST_POLARITY_G => '0',         -- Active low polarity
         NUM_BYTES_G    => 2)
      port map (
         clk      => evrRxRecClk,
         rst      => gtRxResetDone,
         dataIn   => gtRxData,
         dataOut  => data,
         dataKOut => dataK,
         codeErr  => decErr,
         dispErr  => dispErr);

   rxData    <= data  when(linkUp = '1') else (others => '0');
   rxDataK   <= dataK when(linkUp = '1') else (others => '0');
   dataValid <= not (uOr(decErr) or uOr(dispErr));

   -- Link up watchdog process
   process(evrRxRecClk)
   begin
      if rising_edge(evrRxRecClk) then
         if gtRxResetDone = '0' then
            cnt    <= (others => '0');
            linkUp <= '0';
         else
            if cnt = x"FF" then
               linkUp <= '1';
            else
               cnt <= cnt + 1;
            end if;
         end if;
      end if;
   end process;

   --------------------------------------------------------------------------------------------------
   -- Generate the GTX channels (fixed latency)
   --------------------------------------------------------------------------------------------------

   Gtp7Core_Inst : entity work.Gtp7Core
      generic map (
         -- Simulation Generics
         TPD_G                 => 1 ns,
         SIM_GTRESET_SPEEDUP_G => "FALSE",
         SIM_VERSION_G         => "1.0",
         SIMULATION_G          => false,
         -- TX/RX Settings
         RXOUT_DIV_G           => 2,
         TXOUT_DIV_G           => 2,
         RX_CLK25_DIV_G        => 5,
         TX_CLK25_DIV_G        => 5,
         RX_OS_CFG_G           => "0001111110000",
         RXCDR_CFG_G           => x"0000107FE206001041010",
         RXLPM_INCM_CFG_G      => '1',
         RXLPM_IPCM_CFG_G      => '0',
         -- Configure PLL sources
         TX_PLL_G              => "PLL0",
         RX_PLL_G              => "PLL1",
         -- Configure Data widths
         RX_EXT_DATA_WIDTH_G   => 20,
         RX_INT_DATA_WIDTH_G   => 20,
         RX_8B10B_EN_G         => false,
         -- Configure RX comma alignment and buffer usage
         RX_ALIGN_MODE_G       => "FIXED_LAT",
         RX_BUF_EN_G           => false,
         RX_OUTCLK_SRC_G       => "OUTCLKPMA",
         RX_USRCLK_SRC_G       => "RXOUTCLK",
         RX_DLY_BYPASS_G       => '1',
         RX_DDIEN_G            => '0',
         RXSLIDE_MODE_G        => "PMA",
         -- Fixed Latency comma alignment (If RX_ALIGN_MODE_G = "FIXED_LAT")
         FIXED_COMMA_EN_G      => "0011",
         FIXED_ALIGN_COMMA_0_G => "----------0101111100",  -- Normal Comma
         FIXED_ALIGN_COMMA_1_G => "----------1010000011",  -- Inverted Comma
         FIXED_ALIGN_COMMA_2_G => "XXXXXXXXXXXXXXXXXXXX",  -- Unused
         FIXED_ALIGN_COMMA_3_G => "XXXXXXXXXXXXXXXXXXXX")  -- Unused         
      port map (
         stableClkIn      => stableClk,
         qPllRefClkIn     => gtQPllOutRefClk,
         qPllClkIn        => gtQPllOutClk,
         qPllLockIn       => gtQPllLock,
         qPllRefClkLostIn => gtQPllRefClkLost,
         qPllResetOut     => gtQPllReset,
         gtRxRefClkBufg   => stableClk,
         -- Serial IO
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         -- Rx Clock related signals
         rxOutClkOut      => evrRxRecClk,
         rxUsrClkIn       => evrRxRecClk,
         rxUsrClk2In      => evrRxRecClk,
         rxUserRdyOut     => open,
         rxMmcmResetOut   => open,
         rxMmcmLockedIn   => '1',
         -- Rx User Reset Signals
         rxUserResetIn    => evrRxRst,
         rxResetDoneOut   => gtRxResetDone,
         -- Manual Comma Align signals
         rxDataValidIn    => dataValid,
         rxSlideIn        => '0',
         -- Rx Data and decode signals
         rxDataOut        => gtRxData,
         rxCharIsKOut     => open,
         rxDecErrOut      => open,
         rxDispErrOut     => open,
         rxPolarityIn     => '0',
         rxBufStatusOut   => open,
         -- Rx Channel Bonding
         rxChBondLevelIn  => (others => '0'),
         rxChBondIn       => (others => '0'),
         rxChBondOut      => open,
         -- Tx Clock Related Signals
         txOutClkOut      => open,
         txUsrClkIn       => '0',
         txUsrClk2In      => '0',
         txUserRdyOut     => open,
         txMmcmResetOut   => open,
         txMmcmLockedIn   => '1',
         -- Tx User Reset signals
         txUserResetIn    => '0',
         txResetDoneOut   => open,
         -- Tx Data
         txDataIn         => (others => '0'),
         txCharIsKIn      => (others => '0'),
         txBufStatusOut   => open,
         -- Misc.
         loopbackIn       => (others => '0'),
         txPowerDown      => (others => '1'),
         rxPowerDown      => (others => '0'));         

end mapping;
