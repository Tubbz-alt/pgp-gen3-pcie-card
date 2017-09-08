-------------------------------------------------------------------------------
-- Title      : Camera link core
-------------------------------------------------------------------------------
-- File       : CLinkCore.vhd
-- Created    : 2017-08-22
-- Platform   :
-- Standard   : VHDL'93/02
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.CLinkPkg.all;
use work.PciPkg.all;

entity CLinkCore is
   generic (
      TPD_G                 : time                 := 1 ns;
      --------------------------------------------------------------------------
      -- GT Settings
      --------------------------------------------------------------------------
      -- Sim Generics
      SIM_GTRESET_SPEEDUP_G : string               := "FALSE";
      SIM_VERSION_G         : string               := "1.0";
      STABLE_CLOCK_PERIOD_G : real                 := 8.0E-9;         -- seconds

      -- GTP Configurations
      GTP_RATE_G            : real;
      CLK_RATE_INT_G        : integer;
      -- MGT Configurations
      CLK_DIV_G             : integer;
      CLK25_DIV_G           : integer;
      PMA_RSV_G             : bit_vector           := x"00000333";  -- by wizard
      RX_OS_CFG_G           : bit_vector;
      RXCDR_CFG_G           : bit_vector;
      RXLPM_INCM_CFG_G      : bit;
      RXLPM_IPCM_CFG_G      : bit;
      -- Quad PLL Configurations
      QPLL_FBDIV_IN_G       : integer;
      QPLL_FBDIV_45_IN_G    : integer;
      QPLL_REFCLK_DIV_IN_G  : integer;
      -- MMCM Configurations
      MMCM_CLKFBOUT_MULT_G  : real;
      MMCM_GTCLK_DIVIDE_G   : real;
      MMCM_CLCLK_DIVIDE_G   : natural;
      MMCM_CLKIN_PERIOD_G   : real);
   port (
      -- Parallel Interface
      pciToCl    : in  PciToClType;
      clToPci    : out ClToPciType;
      evrToCl    : in  EvrToClArray(0 to 7);
      -- GT Pins
      clRefClkP : in  sl;
      clRefClkN : in  sl;
      clRxP     : in  slv(7 downto 0);
      clRxN     : in  slv(7 downto 0);
      clTxP     : out slv(7 downto 0);
      clTxN     : out slv(7 downto 0);
      -- Global Signals
      stableClk  : out sl;
      clClk      : out sl;
      clRst      : out sl;
      evrClk     : in  sl;
      evrRst     : in  sl;
      pciClk     : in  sl;
      pciRst     : in  sl);
end CLinkCore;

architecture mapping of CLinkCore is

   -- Component Declarations ---------------------------------------------------

   COMPONENT serial_decode_ila
   PORT (
      clk    : IN STD_LOGIC;
      probe0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
   );
   END COMPONENT;

   -----------------------------------------------------------------------------

   signal stableClock,
          locClk,
          locRst              : sl := '0';

   signal westQPllRefClk,
          westQPllClk,
          westQPllLock,
          westQPllRefClkLost,
          westQPllRst,
          eastQPllRefClk,
          eastQPllClk,
          eastQPllLock,
          eastQPllRefClkLost,
          eastQPllRst         : slv       (1 downto 0);

   signal westQPllReset,
          eastQPllReset       : Slv2Array (0 to 3);

   signal txReset,
          rxReset,
          txRstDly,
          rxRstDly            : slv       (0 to 7);

   signal rxChBondIn          : Slv4Array (0 to 7);
   signal rxChBondOut         : Slv4Array (0 to 7);

   signal rxResetDone         : slv       (0 to 7);
   signal rxUsrClk            : slv       (0 to 7);
   signal rxData              : Slv16Array(0 to 7);
   signal rxDataK             : Slv2Array (0 to 7);
   signal rxDecErr            : Slv2Array (0 to 7);
   signal rxDispErr           : Slv2Array (0 to 7);
   signal rxPolarity          : slv       (0 to 7);
   signal rxLoopback          : Slv3Array (0 to 7);

   signal txResetDone         : slv       (0 to 7);
   signal txUsrClk            : slv       (0 to 7);
   signal txData              : Slv16Array(0 to 7);
   signal txDataK             : Slv2Array (0 to 7);

   signal dmaStreamMaster     : AxiStreamMasterArray(0 to 7);
   signal dmaStreamSlave      : AxiStreamSlaveArray (0 to 7);

begin          

   stableClk             <= stableClock;
   clClk                 <= locClk;
   clRst                 <= locRst;
   rxReset               <= pciToCl.rxRst;
   txReset               <= pciToCl.txRst;
   rxPolarity            <= (others=>'0');
   rxLoopback            <= (others=>(others=>'0'));

   clToPci.txPllLock(0) <= westQPllLock(0);
   clToPci.txPllLock(1) <= eastQPllLock(0);
   clToPci.rxPllLock(0) <= westQPllLock(1);
   clToPci.rxPllLock(1) <= eastQPllLock(1);

   Synchronizer_westQTxPllRst : entity work.Synchronizer
      port map (
         clk     => locClk,
         dataIn  => pciToCl.txPllRst(0),
         dataOut => westQPllRst(0));

   Synchronizer_westQRxPllRst : entity work.Synchronizer
      port map (
         clk     => locClk,
         dataIn  => pciToCl.rxPllRst(0),
         dataOut => westQPllRst(1));

   Synchronizer_eastQTxPllRst : entity work.Synchronizer
      port map (
         clk     => locClk,
         dataIn  => pciToCl.txPllRst(1),
         dataOut => eastQPllRst(0));

   Synchronizer_eastQRxPllRst : entity work.Synchronizer
      port map (
         clk     => locClk,
         dataIn  => pciToCl.rxPllRst(1),
         dataOut => eastQPllRst(1));

   PgpClk_Inst : entity work.PgpClk
      generic map (
         -- Configurations
         PGP_RATE_G           => GTP_RATE_G,
         -- Quad PLL Configurations
         QPLL_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         QPLL_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         QPLL_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G,
         -- MMCM Configurations
         MMCM_CLKFBOUT_MULT_G => MMCM_CLKFBOUT_MULT_G,
         MMCM_GTCLK_DIVIDE_G  => MMCM_GTCLK_DIVIDE_G,
         MMCM_PGPCLK_DIVIDE_G => MMCM_CLCLK_DIVIDE_G,
         MMCM_CLKIN_PERIOD_G  => MMCM_CLKIN_PERIOD_G)
      port map (
         -- GT Clocking [3:0]
         westQPllRefClk     => westQPllRefClk,
         westQPllClk        => westQPllClk,
         westQPllLock       => westQPllLock,
         westQPllRefClkLost => westQPllRefClkLost,
         westQPllReset      => westQPllReset,
         westQPllRst        => westQPllRst,
         -- GT Clocking [7:4]
         eastQPllRefClk     => eastQPllRefClk,
         eastQPllClk        => eastQPllClk,
         eastQPllLock       => eastQPllLock,
         eastQPllRefClkLost => eastQPllRefClkLost,
         eastQPllReset      => eastQPllReset,
         eastQPllRst        => eastQPllRst,
         -- GT CLK Pins
         pgpRefClkP         => clRefClkP,
         pgpRefClkN         => clRefClkN,
         -- Global Signals
         evrClk             => evrClk,
         evrRst             => evrRst,
         stableClk          => stableClock,
         pgpClk             => locClk,
         pgpRst             => locRst);    

   GTP_WEST : for lane in 0 to 3 generate
      rxChBondIn(lane) <= "0000";

      Gtp7Core_Inst : entity work.Gtp7Core
         generic map (
            TPD_G                    => TPD_G,
            SIM_GTRESET_SPEEDUP_G    => SIM_GTRESET_SPEEDUP_G,
            SIM_VERSION_G            => SIM_VERSION_G,
            STABLE_CLOCK_PERIOD_G    => STABLE_CLOCK_PERIOD_G,
            RXOUT_DIV_G              => CLK_DIV_G,
            TXOUT_DIV_G              => CLK_DIV_G,
            RX_CLK25_DIV_G           => CLK25_DIV_G,
            TX_CLK25_DIV_G           => CLK25_DIV_G,
            PMA_RSV_G                => PMA_RSV_G,
            RX_OS_CFG_G              => RX_OS_CFG_G,
            RXCDR_CFG_G              => RXCDR_CFG_G,
            RXLPM_INCM_CFG_G         => RXLPM_INCM_CFG_G,
            RXLPM_IPCM_CFG_G         => RXLPM_IPCM_CFG_G,
            TX_PLL_G                 => "PLL0",
            RX_PLL_G                 => "PLL1",
            TX_EXT_DATA_WIDTH_G      => 16,
            TX_INT_DATA_WIDTH_G      => 20,
            TX_8B10B_EN_G            => true,
            RX_EXT_DATA_WIDTH_G      => 16,
            RX_INT_DATA_WIDTH_G      => 20,
            RX_8B10B_EN_G            => true,
            TX_BUF_EN_G              => false,
            TX_OUTCLK_SRC_G          => "PLLREFCLK",
            TX_DLY_BYPASS_G          => '0',
            TX_PHASE_ALIGN_G         => "MANUAL",
            TX_BUF_ADDR_MODE_G       => "FAST",
            RX_BUF_EN_G              => true,
            RX_OUTCLK_SRC_G          => "OUTCLKPMA",
            RX_USRCLK_SRC_G          => "RXOUTCLK",    -- Not 100% sure, doesn't really matter
            RX_DLY_BYPASS_G          => '1',
            RX_DDIEN_G               => '0',
            RX_BUF_ADDR_MODE_G       => "FULL",
            RX_ALIGN_MODE_G          => "GT",          -- Default
            ALIGN_COMMA_DOUBLE_G     => "FALSE",       -- Default
            ALIGN_COMMA_ENABLE_G     => "1111111111",  -- Default
            ALIGN_COMMA_WORD_G       => 2,             -- Default
            ALIGN_MCOMMA_DET_G       => "TRUE",
            ALIGN_MCOMMA_VALUE_G     => "1010000011",  -- Default
            ALIGN_MCOMMA_EN_G        => '1',
            ALIGN_PCOMMA_DET_G       => "TRUE",
            ALIGN_PCOMMA_VALUE_G     => "0101111100",  -- Default
            ALIGN_PCOMMA_EN_G        => '1',
            SHOW_REALIGN_COMMA_G     => "FALSE",
            RXSLIDE_MODE_G           => "AUTO",
            RX_DISPERR_SEQ_MATCH_G   => "TRUE",        -- Default
            DEC_MCOMMA_DETECT_G      => "TRUE",        -- Default
            DEC_PCOMMA_DETECT_G      => "TRUE",        -- Default
            DEC_VALID_COMMA_ONLY_G   => "FALSE",       -- Default
            CBCC_DATA_SOURCE_SEL_G   => "DECODED",     -- Default
            CLK_COR_SEQ_2_USE_G      => "FALSE",       -- Default
            CLK_COR_KEEP_IDLE_G      => "FALSE",       -- Default
            CLK_COR_MAX_LAT_G        => 21,
            CLK_COR_MIN_LAT_G        => 18,
            CLK_COR_PRECEDENCE_G     => "TRUE",        -- Default
            CLK_COR_REPEAT_WAIT_G    => 0,             -- Default
            CLK_COR_SEQ_LEN_G        => 4,
            CLK_COR_SEQ_1_ENABLE_G   => "1111",        -- Default
            CLK_COR_SEQ_1_1_G        => "0110111100",
            CLK_COR_SEQ_1_2_G        => "0100011100",
            CLK_COR_SEQ_1_3_G        => "0100011100",
            CLK_COR_SEQ_1_4_G        => "0100011100",
            CLK_CORRECT_USE_G        => "FALSE",
            CLK_COR_SEQ_2_ENABLE_G   => "0000",        -- Default
            CLK_COR_SEQ_2_1_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_2_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_3_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_4_G        => "0000000000",  -- Default
            RX_CHAN_BOND_EN_G        => true,
            RX_CHAN_BOND_MASTER_G    => true,
            CHAN_BOND_KEEP_ALIGN_G   => "FALSE",       -- Default
            CHAN_BOND_MAX_SKEW_G     => 10,
            CHAN_BOND_SEQ_LEN_G      => 1,             -- Default
            CHAN_BOND_SEQ_1_1_G      => "0110111100",
            CHAN_BOND_SEQ_1_2_G      => "0111011100",
            CHAN_BOND_SEQ_1_3_G      => "0111011100",
            CHAN_BOND_SEQ_1_4_G      => "0111011100",
            CHAN_BOND_SEQ_1_ENABLE_G => "1111",        -- Default
            CHAN_BOND_SEQ_2_1_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_2_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_3_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_4_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_ENABLE_G => "0000",        -- Default
            CHAN_BOND_SEQ_2_USE_G    => "FALSE",       -- Default
            FTS_DESKEW_SEQ_ENABLE_G  => "1111",        -- Default
            FTS_LANE_DESKEW_CFG_G    => "1111",        -- Default
            FTS_LANE_DESKEW_EN_G     => "FALSE")       -- Default
         port map (
            stableClkIn      => stableClock,
            gtRxRefClkBufg   => stableClock,
            qPllRefClkIn     => westQPllRefClk,
            qPllClkIn        => westQPllClk,
            qPllLockIn       => westQPllLock,
            qPllRefClkLostIn => westQPllRefClkLost,
            qPllResetOut     => westQPllReset(lane),
            gtTxP            => clTxP(lane),
            gtTxN            => clTxN(lane),
            gtRxP            => clRxP(lane),
            gtRxN            => clRxN(lane),
            rxOutClkOut      => rxUsrClk     (lane),
            rxUsrClkIn       => rxUsrClk     (lane),
            rxUsrClk2In      => rxUsrClk     (lane),
            rxUserRdyOut     => open,
            rxMmcmResetOut   => open,
            rxMmcmLockedIn   => '1',
            rxUserResetIn    => rxReset      (lane),
            rxResetDoneOut   => rxResetDone  (lane),
            rxDataValidIn    => '1',
            rxSlideIn        => '0',
            rxDataOut        => rxData       (lane),
            rxCharIsKOut     => rxDataK      (lane),
            rxDecErrOut      => rxDecErr     (lane),
            rxDispErrOut     => rxDispErr    (lane),
            rxPolarityIn     => rxPolarity   (lane),
            rxBufStatusOut   => open,
            rxChBondLevelIn  => slv(to_unsigned(0, 3)),
            rxChBondIn       => rxChBondIn   (lane),
            rxChBondOut      => rxChBondOut  (lane),
            txOutClkOut      => txUsrClk     (lane),
            txUsrClkIn       => locClk,
            txUsrClk2In      => locClk,
            txUserRdyOut     => open,
            txMmcmResetOut   => open,
            txMmcmLockedIn   => '1',
            txUserResetIn    => txReset      (lane),
            txResetDoneOut   => txResetDone  (lane),
            txDataIn         => txData       (lane),
            txCharIsKIn      => txDataK      (lane),
            txBufStatusOut   => open,
            loopbackIn       => rxLoopback   (lane));
   end generate GTP_WEST;

   GTP_EAST : for lane in 4 to 7 generate
      rxChBondIn(lane) <= "0000";

      Gtp7Core_Inst : entity work.Gtp7Core
         generic map (
            TPD_G                    => TPD_G,
            SIM_GTRESET_SPEEDUP_G    => SIM_GTRESET_SPEEDUP_G,
            SIM_VERSION_G            => SIM_VERSION_G,
            STABLE_CLOCK_PERIOD_G    => STABLE_CLOCK_PERIOD_G,
            RXOUT_DIV_G              => CLK_DIV_G,
            TXOUT_DIV_G              => CLK_DIV_G,
            RX_CLK25_DIV_G           => CLK25_DIV_G,
            TX_CLK25_DIV_G           => CLK25_DIV_G,
            PMA_RSV_G                => PMA_RSV_G,
            RX_OS_CFG_G              => RX_OS_CFG_G,
            RXCDR_CFG_G              => RXCDR_CFG_G,
            RXLPM_INCM_CFG_G         => RXLPM_INCM_CFG_G,
            RXLPM_IPCM_CFG_G         => RXLPM_IPCM_CFG_G,
            TX_PLL_G                 => "PLL0",
            RX_PLL_G                 => "PLL1",
            TX_EXT_DATA_WIDTH_G      => 16,
            TX_INT_DATA_WIDTH_G      => 20,
            TX_8B10B_EN_G            => true,
            RX_EXT_DATA_WIDTH_G      => 16,
            RX_INT_DATA_WIDTH_G      => 20,
            RX_8B10B_EN_G            => true,
            TX_BUF_EN_G              => false,
            TX_OUTCLK_SRC_G          => "PLLREFCLK",
            TX_DLY_BYPASS_G          => '0',
            TX_PHASE_ALIGN_G         => "MANUAL",
            TX_BUF_ADDR_MODE_G       => "FAST",
            RX_BUF_EN_G              => true,
            RX_OUTCLK_SRC_G          => "OUTCLKPMA",
            RX_USRCLK_SRC_G          => "RXOUTCLK",    -- Not 100% sure, doesn't really matter
            RX_DLY_BYPASS_G          => '1',
            RX_DDIEN_G               => '0',
            RX_BUF_ADDR_MODE_G       => "FULL",
            RX_ALIGN_MODE_G          => "GT",          -- Default
            ALIGN_COMMA_DOUBLE_G     => "FALSE",       -- Default
            ALIGN_COMMA_ENABLE_G     => "1111111111",  -- Default
            ALIGN_COMMA_WORD_G       => 2,             -- Default
            ALIGN_MCOMMA_DET_G       => "TRUE",
            ALIGN_MCOMMA_VALUE_G     => "1010000011",  -- Default
            ALIGN_MCOMMA_EN_G        => '1',
            ALIGN_PCOMMA_DET_G       => "TRUE",
            ALIGN_PCOMMA_VALUE_G     => "0101111100",  -- Default
            ALIGN_PCOMMA_EN_G        => '1',
            SHOW_REALIGN_COMMA_G     => "FALSE",
            RXSLIDE_MODE_G           => "AUTO",
            RX_DISPERR_SEQ_MATCH_G   => "TRUE",        -- Default
            DEC_MCOMMA_DETECT_G      => "TRUE",        -- Default
            DEC_PCOMMA_DETECT_G      => "TRUE",        -- Default
            DEC_VALID_COMMA_ONLY_G   => "FALSE",       -- Default
            CBCC_DATA_SOURCE_SEL_G   => "DECODED",     -- Default
            CLK_COR_SEQ_2_USE_G      => "FALSE",       -- Default
            CLK_COR_KEEP_IDLE_G      => "FALSE",       -- Default
            CLK_COR_MAX_LAT_G        => 21,
            CLK_COR_MIN_LAT_G        => 18,
            CLK_COR_PRECEDENCE_G     => "TRUE",        -- Default
            CLK_COR_REPEAT_WAIT_G    => 0,             -- Default
            CLK_COR_SEQ_LEN_G        => 4,
            CLK_COR_SEQ_1_ENABLE_G   => "1111",        -- Default
            CLK_COR_SEQ_1_1_G        => "0110111100",
            CLK_COR_SEQ_1_2_G        => "0100011100",
            CLK_COR_SEQ_1_3_G        => "0100011100",
            CLK_COR_SEQ_1_4_G        => "0100011100",
            CLK_CORRECT_USE_G        => "FALSE",
            CLK_COR_SEQ_2_ENABLE_G   => "0000",        -- Default
            CLK_COR_SEQ_2_1_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_2_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_3_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_4_G        => "0000000000",  -- Default
            RX_CHAN_BOND_EN_G        => true,
            RX_CHAN_BOND_MASTER_G    => true,
            CHAN_BOND_KEEP_ALIGN_G   => "FALSE",       -- Default
            CHAN_BOND_MAX_SKEW_G     => 10,
            CHAN_BOND_SEQ_LEN_G      => 1,             -- Default
            CHAN_BOND_SEQ_1_1_G      => "0110111100",
            CHAN_BOND_SEQ_1_2_G      => "0111011100",
            CHAN_BOND_SEQ_1_3_G      => "0111011100",
            CHAN_BOND_SEQ_1_4_G      => "0111011100",
            CHAN_BOND_SEQ_1_ENABLE_G => "1111",        -- Default
            CHAN_BOND_SEQ_2_1_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_2_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_3_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_4_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_ENABLE_G => "0000",        -- Default
            CHAN_BOND_SEQ_2_USE_G    => "FALSE",       -- Default
            FTS_DESKEW_SEQ_ENABLE_G  => "1111",        -- Default
            FTS_LANE_DESKEW_CFG_G    => "1111",        -- Default
            FTS_LANE_DESKEW_EN_G     => "FALSE")       -- Default
         port map (
            stableClkIn      => stableClock,
            gtRxRefClkBufg   => stableClock,
            qPllRefClkIn     => eastQPllRefClk,
            qPllClkIn        => eastQPllClk,
            qPllLockIn       => eastQPllLock,
            qPllRefClkLostIn => eastQPllRefClkLost,
            qPllResetOut     => eastQPllReset(lane-4),
            gtTxP            => clTxP(lane),
            gtTxN            => clTxN(lane),
            gtRxP            => clRxP(lane),
            gtRxN            => clRxN(lane),
            rxOutClkOut      => rxUsrClk     (lane),
            rxUsrClkIn       => rxUsrClk     (lane),
            rxUsrClk2In      => rxUsrClk     (lane),
            rxUserRdyOut     => open,
            rxMmcmResetOut   => open,
            rxMmcmLockedIn   => '1',
            rxUserResetIn    => rxReset      (lane),
            rxResetDoneOut   => rxResetDone  (lane),
            rxDataValidIn    => '1',
            rxSlideIn        => '0',
            rxDataOut        => rxData       (lane),
            rxCharIsKOut     => rxDataK      (lane),
            rxDecErrOut      => rxDecErr     (lane),
            rxDispErrOut     => rxDispErr    (lane),
            rxPolarityIn     => rxPolarity   (lane),
            rxBufStatusOut   => open,
            rxChBondLevelIn  => slv(to_unsigned(0, 3)),
            rxChBondIn       => rxChBondIn   (lane),
            rxChBondOut      => rxChBondOut  (lane),
            txOutClkOut      => txUsrClk     (lane),
            txUsrClkIn       => locClk,
            txUsrClk2In      => locClk,
            txUserRdyOut     => open,
            txMmcmResetOut   => open,
            txMmcmLockedIn   => '1',
            txUserResetIn    => txReset      (lane),
            txResetDoneOut   => txResetDone  (lane),
            txDataIn         => txData       (lane),
            txCharIsKIn      => txDataK      (lane),
            txBufStatusOut   => open,
            loopbackIn       => rxLoopback   (lane));
   end generate GTP_EAST;

   SYNC_LANES :
   for lane in 0 to 7 generate

      -- Add registers to help with timing
      process(locClk)
      begin
         if rising_edge(locClk) then
            txRstDly(lane) <= txReset(lane)  after TPD_G;
            rxRstDly(lane) <= rxReset(lane)  after TPD_G;
         end if;
      end process;
   end generate SYNC_LANES;

   GRABBER_TXRX : for lane in 0 to 7 generate
      -----------------------------
      -- Transmit
      -----------------------------

      U_CLinkTx : entity work.CLinkTx 
         generic map (
            CLK_RATE_INT_G => CLK_RATE_INT_G,
            LANE_G       => lane)
         port map (
            -- System Interface
            systemReset  => txRstDly(lane),
            pciClk       => pciClk,

            -- GTP Interface
            txClk        => locClk,
            txData       => txData  (lane),
            txCtrl       => txDataK (lane),

            -- Parallel Interface
            pciToCl      => pciToCl,
            evrToCl      => evrToCl(lane)
         );

      clToPci.dmaTxIbMaster(lane)  <= AXI_STREAM_MASTER_INIT_C;
      clToPci.dmaTxObSlave(lane)   <= AXI_STREAM_SLAVE_INIT_C;
      clToPci.dmaTxDescToPci(lane) <= DESC_TO_PCI_INIT_C;
      clToPci.locLinkReady(lane)   <= '0';
      clToPci.remLinkReady(lane)   <= '0';
      clToPci.cellErrorCnt(lane)   <= (others=>'0');
      clToPci.linkDownCnt(lane)    <= (others=>'0');
      clToPci.linkErrorCnt(lane)   <= (others=>'0');
      clToPci.fifoErrorCnt(lane)   <= (others=>'0');
      clToPci.rxCount(lane,0)      <= (others=>'0');
      clToPci.rxCount(lane,1)      <= (others=>'0');
      clToPci.rxCount(lane,2)      <= (others=>'0');
      clToPci.rxCount(lane,3)      <= (others=>'0');

      -----------------------------
      -- Receive
      -----------------------------

      U_CLinkRx : entity work.CLinkRx 
         generic map (
            TPD_G           => TPD_G,
            CLK_RATE_INT_G => CLK_RATE_INT_G,
            LANE_G          => lane)
         port map (
            -- System Interface
            systemReset     => rxRstDly                  (lane),
            pciClk          => pciClk,
            evrClk          => evrClk,

            -- GTP Interface
            rxClk           => rxUsrClk                  (lane),
            rxData          => rxData                    (lane),
            rxCtrl          => rxDataK                   (lane),
            rxDecErr        => rxDecErr                  (lane),
            rxDispErr       => rxDispErr                 (lane),

            -- Parallel Interface
            pciToCl         => pciToCl,
            evrToCl         => evrToCl                   (lane),

            linkStatus      => clToPci.linkUp            (lane),
            cLinkLock       => clToPci.camLock           (lane),

            trgCount        => clToPci.trgCount          (lane),
            trgToFrameDly   => clToPci.trgToFrameDly     (lane),
            frameCount      => clToPci.frameCount        (lane),
            frameRate       => clToPci.frameRate         (lane),

            serTfgByte      => clToPci.serFifoRd         (lane),
            serTfgValid     => clToPci.serFifoValid      (lane),

            dmaStreamMaster => dmaStreamMaster           (lane),
            dmaStreamSlave  => dmaStreamSlave            (lane)
         );

      U_PciRxDma : entity work.PciRxDma
         generic map (
            TPD_G => TPD_G)
         port map (
            -- 32-bit Streaming RX Interface
            sAxisClk       => rxUsrClk                   (lane),
            sAxisRst       => rxRstDly                   (lane),
            sAxisMaster    => dmaStreamMaster            (lane),
            sAxisSlave     => dmaStreamSlave             (lane),
            -- 128-bit Streaming TX Interface
            pciClk         => pciClk,
            pciRst         => pciRst,
            dmaIbMaster    => clToPci.dmaRxIbMaster    (lane),
            dmaIbSlave     => pciToCl.dmaRxIbSlave     (lane),
            dmaDescFromPci => pciToCl.dmaRxDescFromPci (lane),
            dmaDescToPci   => clToPci.dmaRxDescToPci   (lane),
            dmaTranFromPci => pciToCl.dmaRxTranFromPci (lane),
            dmaChannel     => toSlv(lane, 3));
   end generate;

end;

