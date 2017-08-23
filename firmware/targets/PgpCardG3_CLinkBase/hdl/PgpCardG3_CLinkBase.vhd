
library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.PgpCardG3ClinkPkg.all;
use work.Clink2p500GbpsPkg.all;

entity PgpCardG3_CLinkBase is
   generic (
      DEBUG_G              : boolean    := true;

      -- Configurations
      LINE_RATE_G          : real       := LINE_RATE_C;
      -- MGT Configurations
      CLK_DIV_G            : integer    := CLK_DIV_C;
      CLK25_DIV_G          : integer    := CLK25_DIV_C;
      RX_OS_CFG_G          : bit_vector := RX_OS_CFG_C;
      RXCDR_CFG_G          : bit_vector := RXCDR_CFG_C;
      RXLPM_INCM_CFG_G     : bit        := RXLPM_INCM_CFG_C;
      RXLPM_IPCM_CFG_G     : bit        := RXLPM_IPCM_CFG_C;
      -- Quad PLL Configurations
      QPLL_FBDIV_IN_G      : integer    := QPLL_FBDIV_IN_C;
      QPLL_FBDIV_45_IN_G   : integer    := QPLL_FBDIV_45_IN_C;
      QPLL_REFCLK_DIV_IN_G : integer    := QPLL_REFCLK_DIV_IN_C;
      -- MMCM Configurations
      MMCM_DIVCLK_DIVIDE_G : natural    := MMCM_DIVCLK_DIVIDE_C;
      MMCM_CLKFBOUT_MULT_G : real       := MMCM_CLKFBOUT_MULT_C;
      MMCM_GTCLK_DIVIDE_G  : real       := MMCM_GTCLK_DIVIDE_C;
      MMCM_CLCLK_DIVIDE_G  : natural    := MMCM_CLCLK_DIVIDE_C;
      MMCM_CLKIN_PERIOD_G  : real       := MMCM_CLKIN_PERIOD_C);
   port (
      -- FLASH Interface
      flashAddr  : out   slv(25 downto 0);
      flashData  : inout slv(15 downto 0);
      flashAdv   : out   sl;
      flashCe    : out   sl;
      flashOe    : out   sl;
      flashWe    : out   sl;
      -- System Signals
      sysClk     : in    sl;            --  32 MHz
      led        : out   slv(7 downto 0);
      tieToGnd   : out   slv(3 downto 0);
      tieToVdd   : out   slv(0 downto 0);
      -- PCIe Ports
      pciRstL    : in    sl;
      pciRefClkP : in    sl;            -- 100 MHz
      pciRefClkN : in    sl;            -- 100 MHz
      pciRxP     : in    slv(3 downto 0);
      pciRxN     : in    slv(3 downto 0);
      pciTxP     : out   slv(3 downto 0);
      pciTxN     : out   slv(3 downto 0);
      -- EVR Ports
      evrRefClkP : in    sl;            -- 238 MHz
      evrRefClkN : in    sl;            -- 238 MHz
      evrRxP     : in    sl;
      evrRxN     : in    sl;
      evrTxP     : out   sl;
      evrTxN     : out   sl;
      -- Ports
      clRefClkP  : in    sl;            -- 250 MHz
      clRefClkN  : in    sl;            -- 250 MHz
      clRxP      : in    slv(7 downto 0);
      clRxN      : in    slv(7 downto 0);
      clTxP      : out   slv(7 downto 0);
      clTxN      : out   slv(7 downto 0);
      -- User LEDs
      led_r      : out   slv(5 downto 0);
      led_b      : out   slv(5 downto 0);
      led_g      : out   slv(5 downto 0));
end PgpCardG3_CLinkBase;

architecture top_level of PgpCardG3_CLinkBase is

   signal clClk,
          clRst,
          evrClk,
          evrRst,
          pciClk,
          pciRst,
          pciLinkUp : sl;
   signal clToPci   : ClToPciType;
   signal pciToCl   : PciToClType;
   signal evrToPci  : EvrToPciType;
   signal pciToEvr  : PciToEvrType;
   signal evrToCl   : EvrToClArray(0 to 7);

begin

   led(1)   <= evrToPci.linkUp;
   led(7)   <= pciToEvr.errCntRst;
   led(2)   <= pciToEvr.pllRst;
   led(3)   <= pciToEvr.reset;
-- led(4)   <= pciToEvr.enable;

   tieToGnd <= (others => '0');
   tieToVdd <= (others => '1');

   -----------
   -- Camera Link Core
   -----------
   CLinkCore_Inst : entity work.CLinkCore
      generic map (
         DEBUG_G              => DEBUG_G,

         -- Configurations
         LINE_RATE_G          => LINE_RATE_G,
         -- MGT Configurations
         CLK_DIV_G            => CLK_DIV_G,
         CLK25_DIV_G          => CLK25_DIV_G,
         RX_OS_CFG_G          => RX_OS_CFG_G,
         RXCDR_CFG_G          => RXCDR_CFG_G,
         RXLPM_INCM_CFG_G     => RXLPM_INCM_CFG_G,
         RXLPM_IPCM_CFG_G     => RXLPM_IPCM_CFG_G,
         -- Quad PLL Configurations
         QPLL_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         QPLL_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         QPLL_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G,
         -- MMCM Configurations
         MMCM_DIVCLK_DIVIDE_G => MMCM_DIVCLK_DIVIDE_G,
         MMCM_CLKFBOUT_MULT_G => MMCM_CLKFBOUT_MULT_G,
         MMCM_GTCLK_DIVIDE_G  => MMCM_GTCLK_DIVIDE_G,
         MMCM_CLCLK_DIVIDE_G  => MMCM_CLCLK_DIVIDE_G,
         MMCM_CLKIN_PERIOD_G  => MMCM_CLKIN_PERIOD_G)
      port map (
         -- Parallel Interface
         evrToCl    => evrToCl,
         pciToCl    => pciToCl,
         clToPci    => clToPci,
         -- Camera Link Fiber Links
         clRefClkP  => clRefClkP,
         clRefClkN  => clRefClkN,
         clRxP      => clRxP,
         clRxN      => clRxN,
         clTxP      => clTxP,
         clTxN      => clTxN,
         -- Global Signals
         clClk      => clClk,
         clRst      => clRst,
         evrClk     => evrClk,
         evrRst     => evrRst,
         pciClk     => pciClk,
         pciRst     => pciRst);

   -----------
   -- EVR Core
   -----------
   EvrCore_Inst : entity work.EvrCLinkCore
      port map (
         -- External Interfaces
         pciToEvr   => pciToEvr,
         evrToPci   => evrToPci,
         evrToCl    => evrToCl,
         -- EVR Ports
         evrRefClkP => evrRefClkP,
         evrRefClkN => evrRefClkN,
         evrRxP     => evrRxP,
         evrRxN     => evrRxN,
         evrTxP     => evrTxP,
         evrTxN     => evrTxN,
         -- Global Signals
         clClk      => clClk,
         clRst      => clRst,
         evrClk     => evrClk,
         evrRst     => evrRst,
         pciClk     => pciClk,
         pciRst     => pciRst);

   ------------
   -- PCIe Core
   ------------
   PciCore_Inst : entity work.PciCore
      generic map (
         DEBUG_G    => DEBUG_G,

         -- Configurations
         LINE_RATE_G => LINE_RATE_G)
      port map (
         -- FLASH Interface
         flashAddr  => flashAddr,
         flashData  => flashData,
         flashAdv   => flashAdv,
         flashCe    => flashCe,
         flashOe    => flashOe,
         flashWe    => flashWe,
         -- Parallel Interface
         clToPci    => clToPci,
         pciToCl    => pciToCl,
         pciToEvr   => pciToEvr,
         evrToPci   => evrToPci,
         -- PCIe Ports
         pciRstL    => pciRstL,
         pciRefClkP => pciRefClkP,
         pciRefClkN => pciRefClkN,
         pciRxP     => pciRxP,
         pciRxN     => pciRxN,
         pciTxP     => pciTxP,
         pciTxN     => pciTxN,
         pciLinkUp  => pciLinkUp,
         -- Global Signals
         clClk      => clClk,
         clRst      => clRst,
         evrClk     => evrClk,
         evrRst     => evrRst,
         pciClk     => pciClk,
         pciRst     => pciRst,
         -- User LEDs
         led_r      => led_r,
         led_b      => led_b,
         led_g      => led_g);

end top_level;

