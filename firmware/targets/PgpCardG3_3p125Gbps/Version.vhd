
library ieee;
use ieee.std_logic_1164.all;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"CEC83014"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "PgpCardG3_3p125Gbps: Vivado v2015.2 (x86_64) Built Tue Apr 19 20:38:08 PDT 2016 by ruckman";

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
-- 05/26/2015 (0xCEC83008): Added PgpOpCode register and fixed a bug in the DMA
--
-- 06/03/2015 (0xCEC83009): Added registers to the output of the LUT to help with timing
--                          Fixed the non-fatal kernel error messaging
--
-- 06/08/2015 (0xCEC8300A): Fixed a bug that inserts an extra word into the RX DMA when 
--                          at the transition from not being back pressured to being
--                          back pressured.
--
-- 06/15/2015 (0xCEC8300B): For evr.offset, pre-set to 0x2 when OP-Code 0x7D is detected
--
-- 06/16/2015 (0xCEC8300C): For evr.offset, pre-set to 0xFFFFFFFE when OP-Code 0x7D is detected
--
-- 08/24/2015 (0xCEC8300E): Added EVR Display mode feature (modified register @ 0x044)
--
-- 11/09/2015 (0xCEC8300F): Added AcceptCntRst Registers
--                          Added LutDropCnt Registers
--                          Prevent EvrLinkUp=0x0 from reseting EVR Link Error counter
--
-- 11/12/2015 (0xCEC83010): Added AcceptCnt Registers
--                          Prevent AcceptCnt from counting if EVR lane is not enabled
--
-- 11/16/2015 (0xCEC83011): In EvrGtp7.vhd, mask off the eventcodes when the link is down
--                          In PciApp.vhd, increased evrErrorCnt from 4-bits to 32-bits
--                          and moved evrErrorCnt from 0x40 to 0x4C base address
-- 
-- 03/16/2016 (0xCEC83012): Changed BPI from ASYNC to SYNC mode (TYPE2) and config clock from 9 MHz to 50 MHz 
-- 
-- 04/18/2016 (0xCEC83013): Added EvrSecond (A.K.A. "EvrStat[4]" or "Fiducial") register
-- 
-- 04/19/2016 (0xCEC83014): Fixed bug in PgpOpCode.vhd for using evrSyncWord with (evrSyncSel = '1')
-- 
-------------------------------------------------------------------------------
