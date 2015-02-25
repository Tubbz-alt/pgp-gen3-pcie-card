
library ieee;
use ieee.std_logic_1164.all;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"CEC83003"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "PgpCardG3_4p760Gbps: Vivado v2014.1 (x86_64) Built Tue Feb 24 15:55:42 PST 2015 by ruckman";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 01/06/2015 (0xCEC83000): Initial Build
--
-- 01/30/2015 (0xCEC83001): Fixed the MGT RX reset forcing the whole QUAD to reset
--
-- 02/19/2015 (0xCEC83002): Fixed a bug in the EVR mask triggering 
--
-- 02/24/2015 (0xCEC83003): Added runDelay and acceptDelay registers
--
-------------------------------------------------------------------------------

