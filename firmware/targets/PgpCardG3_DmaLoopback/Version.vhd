
library ieee;
use ieee.std_logic_1164.all;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"CEC83008"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "PgpCardG3_DmaLoopback: Vivado v2015.1 (x86_64) Built Tue May 26 13:11:41 PDT 2015 by ruckman";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 05/26/2015 (0xCEC83008): Initial Build
--
-------------------------------------------------------------------------------
