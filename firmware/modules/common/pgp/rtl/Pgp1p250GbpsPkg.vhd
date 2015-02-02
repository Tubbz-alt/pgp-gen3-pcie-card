-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp1p250GbpsPkg.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-03-28
-- Last update: 2014-07-31
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;

package Pgp1p250GbpsPkg is

   -- PGP Configurations
   constant PGP_RATE_C : real := 1.250E+9;  -- 1.25 Gbps

   -- MGT Configurations
   constant CLK_DIV_C        : integer    := 4;
   constant CLK25_DIV_C      : integer    := 5;                         -- Set by wizard   
   constant RX_OS_CFG_C      : bit_vector := "0000010000000";           -- Set by wizard
   constant RXCDR_CFG_C      : bit_vector := x"0000107FE106001041010";  -- Set by wizard
   constant RXLPM_INCM_CFG_C : bit        := '0';                       -- Set by wizard
   constant RXLPM_IPCM_CFG_C : bit        := '1';                       -- Set by wizard       

   -- Quad PLL Configurations
   constant QPLL_FBDIV_IN_C      : integer := 4;
   constant QPLL_FBDIV_45_IN_C   : integer := 5;
   constant QPLL_REFCLK_DIV_IN_C : integer := 1;

   -- MMCM Configurations
   constant MMCM_CLKIN_PERIOD_C  : real    := 8.000;
   constant MMCM_CLKFBOUT_MULT_C : real    := 8.000;
   constant MMCM_DIVCLK_DIVIDE_C : natural := 1;
   constant MMCM_GTCLK_DIVIDE_C  : real    := 8.000;
   constant MMCM_PGPCLK_DIVIDE_C : natural := 16;
   
end package Pgp1p250GbpsPkg;
