
library ieee;
use ieee.std_logic_1164.all;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"CEC83007"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "PgpCardG3_3p125Gbps: Vivado v2015.1 (x86_64) Built Thu May 14 17:57:29 PDT 2015 by kurtisn";

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
-- 02/26/2015 (0xCEC83004): Dedicating one runDelay/acceptDelay register pair per lane
--
-- 03/24/2015 (0xCEC83005): Dedicating one runCode/acceptCode register pair per lane
--
-- 05/20/2015 (0xCEC83007): Registers added to access counters of valid runCodes
--                          Registers added for per-lane enables of EVR functionality
--
-------------------------------------------------------------------------------

