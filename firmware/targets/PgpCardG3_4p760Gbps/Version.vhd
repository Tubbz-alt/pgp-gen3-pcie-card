
library ieee;
use ieee.std_logic_1164.all;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"CEC8301E"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "PgpCardG3_4p760Gbps: Vivado v2016.1 (x86_64) Built Mon Jun 27 12:41:02 PDT 2016 by ruckman";

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
-- 04/25/2016 (0xCEC83015): In PgpOpCode.vhd, changed to "pgpTxIn.opCodeEn <= fromEvr.run or opCodeEn;"
-- 
-- 04/26/2016 (0xCEC83016): Added evrOpCodeMask register
-- 
-- 04/26/2016 (0xCEC83017): Fixed bug of PGP RX reset causing the PCI RX DMA engine to hang
-- 
-- 05/11/2016 (0xCEC83018): Prevent soft reload of firmware because it sometimes crashes the Linux kernel
-- 
-- 06/09/2016 (0xCEC83019): Upgraded PCIe IP core to v3.3 (Vivado 2016.1)
-- 
-- 06/10/2016 (0xCEC8301A): Fixed a bug when recovering from a RX packet that's too big
--
-- 06/13/2016 (0xCEC8301B): In PgpDmaLane, changed CASCADE_SIZE_G from 1 to 4
--
-- 06/14/2016 (0xCEC8301C): Added pipelining to improve performance for 5.0 Gbps PGP build
--
-- 06/24/2016 (0xCEC8301D): Setting VC_INTERLEAVE_G = 0 (no VC interleaving)
--
-- 06/27/2016 (0xCEC8301E): Fixed a bug where EvrReady shows 0x1 when cable disconnected
--                          Driving EVR_SEL[1:0] to "00"
-- 
-------------------------------------------------------------------------------
