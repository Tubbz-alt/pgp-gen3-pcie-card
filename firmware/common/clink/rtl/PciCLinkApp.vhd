-------------------------------------------------------------------------------
-- File       : PciCLinkApp.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-08-23
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
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
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;
use work.CLinkPkg.all;
use work.PgpCardG3Pkg.all;

entity PciCLinkApp is
   generic (
      BUILD_INFO_G   : BuildInfoType;     
      GTP_RATE_G     : real);
   port (
      -- FLASH Interface 
      flashAddr        : out   slv(25 downto 0);
      flashData        : inout slv(15 downto 0);
      flashAdv         : out   sl;
      flashCe          : out   sl;
      flashOe          : out   sl;
      flashWe          : out   sl;
      -- System Signals
      serNumber        : out   slv(63 downto 0);
      cardReset        : out   sl;
      -- Register Interface
      regTranFromPci   : in    TranFromPciType;
      regObMaster      : in    AxiStreamMasterType;
      regObSlave       : out   AxiStreamSlaveType;
      regIbMaster      : out   AxiStreamMasterType;
      regIbSlave       : in    AxiStreamSlaveType;
      -- DMA Interface      
      dmaTxTranFromPci : in    TranFromPciArray    (0 to 7);
      dmaRxTranFromPci : in    TranFromPciArray    (0 to 7);
      dmaTxObMaster    : in    AxiStreamMasterArray(0 to 7);
      dmaTxObSlave     : out   AxiStreamSlaveArray (0 to 7);
      dmaTxIbMaster    : out   AxiStreamMasterArray(0 to 7);
      dmaTxIbSlave     : in    AxiStreamSlaveArray (0 to 7);
      dmaRxIbMaster    : out   AxiStreamMasterArray(0 to 7);
      dmaRxIbSlave     : in    AxiStreamSlaveArray (0 to 7);
      -- PCIe Interface
      cfgOut           : in    CfgOutType;
      irqIn            : out   IrqInType;
      irqOut           : in    IrqOutType;
      -- Parallel Interface
      clToPci          : in    ClToPciType;
      pciToCl          : inout PciToClType;
      evrToPci         : in    EvrToPciType;
      pciToEvr         : out   PciToEvrType;
      --Global Signals
      clClk            : in    sl;
      clRst            : in    sl;
      evrClk           : in    sl;
      evrRst           : in    sl;
      pciClk           : in    sl;
      pciRst           : in    sl;
      -- User LEDs
      led_r            : out   slv(5 downto 0);
      led_b            : out   slv(5 downto 0);
      led_g            : out   slv(5 downto 0));

end PciCLinkApp;

architecture rtl of PciCLinkApp is

   constant DMA_SIZE_C : natural := 8;
   constant BUILD_INFO_C       : BuildInfoRetType    := toBuildInfo(BUILD_INFO_G);
   constant BUILD_STRING_ROM_C : Slv32Array(0 to 63) := BUILD_INFO_C.buildString;   

   signal ledOff            : sl;

   -- Descriptor Signals
   signal dmaRxDescToPci,
          dmaTxDescToPci    : DescToPciArray  (0 to (DMA_SIZE_C-1));
   signal dmaRxDescFromPci,
          dmaTxDescFromPci  : DescFromPciArray(0 to (DMA_SIZE_C-1));

   -- Register Controller
   signal cardRst,
          counterRst,
          reboot,
          rebootEn,
          regWrEn,
          regRdEn,
          regRxCs,
          regTxCs,
          regLocCs,
          regFlashCs,
          flashBusy,
          regBusy           : sl;
   signal regBar            : slv( 2 downto 0);
   signal regAddr           : slv(31 downto 2);

   signal regWrData,
          regRdData,
          regRxRdData,
          regTxRdData,
          regFlashRdData,
          rebootTimer,
          scratchPad        : slv(31 downto 0);

   signal serialNumber      : slv(127 downto 0);

   -- Interrupt Signals
   signal irqEnable         : sl;
   signal rxDmaIrqReq       : sl;
   signal txDmaIrqReq       : sl;

   --EVR Signals     
   signal evrLinkUp,
          evrEvt140,
          evrReset,
          evrPllRst,
          evrErrCntRst      : sl;
   signal evrErrorCnt       : slv(31 downto 0);

   signal preScale,
          trgCode           : Slv8Array (0 to 7);

   signal trgDelay,
          trgWidth          : Slv32Array(0 to 7);

   --GTP Signals
   signal rxPllLock,
          txPllLock,
          rxPllRst,
          txPllRst          : slv(1 downto 0);

   signal rxCount           : Slv4VectorArray(0 to 7, 0 to 3);
   signal cellErrorCnt,
          linkDownCnt,
          linkErrorCnt,
          fifoErrorCnt      : Slv4Array(0 to 7);
   signal locLinkReady,
          remLinkReady,
          extLinkUp,
          camLock,
          rxRst,
          txRst,
          countRst,
          pack16,
          trgPolarity,
          enable            : slv       (0 to 7);

   signal trgCC             : Slv2Array (0 to 7);

   signal numBits           : Slv8Array (0 to 7);
   signal numTrains,
          numCycles,
          serBaud,
          trgCount,
          trgToFrameDly,
          frameCount,
          frameRate         : Slv32Array(0 to 7);

   signal pci_read_en       : slv( 0 DOWNTO 0);
   signal pci_read_addr     : slv(11 DOWNTO 0);
   signal serFifoRdEn       : slv( 0 DOWNTO 0);
   signal serFifoValid      : slv( 0 DOWNTO 0);
   signal serFifoRd         : slv( 7 DOWNTO 0);

   signal ledCycles         : slv(26 downto 0) := (others => '0');

begin
   
   cardReset            <= cardRst;

   -------------------------------
   -- Input/Output mapping
   -------------------------------    
   irqIn.req            <= rxDmaIrqReq  or txDmaIrqReq;
   irqIn.enable         <= irqEnable;
   serNumber            <= serialNumber(63 downto 0);

   pciToEvr.evrReset    <=                 evrReset or cardRst;
   pciToEvr.pllRst      <= evrPllRst    or evrReset or cardRst;
   pciToEvr.countRst    <= evrErrCntRst or evrReset or cardRst;

   pciToEvr.enable      <= enable;
   pciToEvr.preScale    <= preScale;
   pciToEvr.trgCode     <= trgCode ;
   pciToEvr.trgDelay    <= trgDelay;
   pciToEvr.trgWidth    <= trgWidth;

   pciToEvr.runCode    <= (others=>(others=>'0'));
   pciToEvr.acceptCode <= (others=>(others=>'0'));

   pciToCl.rxPllRst(1) <= rxPllRst(1) or cardRst;
   pciToCl.rxPllRst(0) <= rxPllRst(0) or cardRst;
   pciToCl.txPllRst(1) <= txPllRst(1) or cardRst;
   pciToCl.txPllRst(0) <= txPllRst(0) or cardRst;

   pciToCl.enable      <= enable;
   pciToCl.trgPolarity <= trgPolarity;
   pciToCl.trgCC       <= trgCC;
   pciToCl.pack16      <= pack16;

   pciToCl.numBits     <= numBits;
   pciToCl.numTrains   <= numTrains;
   pciToCl.numCycles   <= numCycles;
   pciToCl.serBaud     <= serBaud;

   MAP_GTP_DMA_LANES :
   for lane in 0 to DMA_SIZE_C-1 generate
      -- Input buses
      dmaTxIbMaster            (lane) <= clToPci.dmaTxIbMaster (lane);
      dmaTxObSlave             (lane) <= clToPci.dmaTxObSlave  (lane);
      dmaRxIbMaster            (lane) <= clToPci.dmaRxIbMaster (lane);

      dmaTxDescToPci           (lane) <= clToPci.dmaTxDescToPci(lane);
      dmaRxDescToPci           (lane) <= clToPci.dmaRxDescToPci(lane);

      -- Output buses
      pciToCl.dmaTxTranFromPci(lane) <= dmaTxTranFromPci       (lane);
      pciToCl.dmaRxTranFromPci(lane) <= dmaRxTranFromPci       (lane);

      pciToCl.dmaTxDescFromPci(lane) <= dmaTxDescFromPci       (lane);
      pciToCl.dmaRxDescFromPci(lane) <= dmaRxDescFromPci       (lane);

      pciToCl.dmaTxIbSlave    (lane) <= dmaTxIbSlave           (lane);
      pciToCl.dmaTxObMaster   (lane) <= dmaTxObMaster          (lane);
      pciToCl.dmaRxIbSlave    (lane) <= dmaRxIbSlave           (lane);
   end generate MAP_GTP_DMA_LANES;

   -------------------------------
   -- Synchronization
   ------------------------------- 
   Synchronizer_evrLinkUp       : entity work.Synchronizer
      port map (
         clk     => pciClk,
         dataIn  => evrToPci.linkUp,
         dataOut => evrLinkUp);   

   Synchronizer_evrEvt140       : entity work.Synchronizer
      port map (
         clk     => pciClk,
         dataIn  => evrToPci.evt140,
         dataOut => evrEvt140);   

   SynchronizerFifo_evrErrorCnt : entity work.SynchronizerFifo
      generic map(
         DATA_WIDTH_G => 32)
      port map(
         wr_clk  => evrClk,
         din     => evrToPci.errorCnt,
         rd_clk  => pciClk,
         dout    => evrErrorCnt);             

   SynchronizerVector_txPllLock : entity work.SynchronizerVector
      generic map (
         WIDTH_G => 2)
      port map (
         clk     => pciClk,
         dataIn  => clToPci.txPllLock,
         dataOut => txPllLock);

   SynchronizerVector_rxPllLock : entity work.SynchronizerVector
      generic map (
         WIDTH_G => 2)
      port map (
         clk     => pciClk,
         dataIn  => clToPci.rxPllLock,
         dataOut => rxPllLock);  

   SynchronizerVector_extLinkUp : entity work.SynchronizerVector
      generic map (
         WIDTH_G => 8)
      port map (
         clk     => pciClk,
         dataIn  => clToPci.linkUp,
         dataOut => extLinkUp);

   SynchronizerVector_camLock   : entity work.SynchronizerVector
      generic map (
         WIDTH_G => 8)
      port map (
         clk     => pciClk,
         dataIn  => clToPci.camLock,
         dataOut => camLock);

   GEN_SYNC_LANE :
   for lane in 0 to 7 generate
      pciToCl.rxRst   (lane) <= rxRst   (lane) or cardRst;
      pciToCl.txRst   (lane) <= txRst   (lane) or cardRst;
      pciToCl.countRst(lane) <= countRst(lane) or cardRst;

      SynchronizerFifo_linkDownCnt   : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 4)
         port map(
            wr_clk => clClk,
            din    => clToPci.linkDownCnt(lane),
            rd_clk => pciClk,
            dout   => linkDownCnt(lane));

      SynchronizerFifo_linkErrorCnt  : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 4)
         port map(
            wr_clk => clClk,
            din    => clToPci.linkErrorCnt(lane),
            rd_clk => pciClk,
            dout   => linkErrorCnt(lane));             

      SynchronizerFifo_fifoErrorCnt  : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 4)
         port map(
            wr_clk => clClk,
            din    => clToPci.fifoErrorCnt(lane),
            rd_clk => pciClk,
            dout   => fifoErrorCnt(lane)); 

      SynchronizerFifo_trgCount      : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 32)
         port map(
            wr_clk => clClk,
            din    => clToPci.trgCount(lane),
            rd_clk => pciClk,
            dout   => trgCount(lane)); 

      SynchronizerFifo_frameCount    : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 32)
         port map(
            wr_clk => clClk,
            din    => clToPci.frameCount(lane),
            rd_clk => pciClk,
            dout   => frameCount(lane)); 

      SynchronizerFifo_trgToFrameDly : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 32)
         port map(
            wr_clk => clClk,
            din    => clToPci.trgToFrameDly(lane),
            rd_clk => pciClk,
            dout   => trgToFrameDly(lane)); 

      SynchronizerFifo_frameRate     : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 32)
         port map(
            wr_clk => clClk,
            din    => clToPci.frameRate(lane),
            rd_clk => pciClk,
            dout   => frameRate(lane)); 

   end generate GEN_SYNC_LANE;

   -------------------------------
   -- Controller Modules
   ------------------------------- 
   DeviceDna_Inst : entity work.DeviceDna
      port map (
         clk      => pciClk,
         rst      => pciRst,
         dnaValue => serialNumber,
         dnaValid => open);   

   -- Register Controller
   PciRegCtrl_Inst : entity work.PciRegCtrl
      port map (
         -- PCI Interface         
         regTranFromPci => regTranFromPci,
         regObMaster    => regObMaster,
         regObSlave     => regObSlave,
         regIbMaster    => regIbMaster,
         regIbSlave     => regIbSlave,
         -- Register Signals
         regBar         => regBar,
         regAddr        => regAddr,
         regWrEn        => regWrEn,
         regWrData      => regWrData,
         regRdEn        => regRdEn,
         regRdData      => regRdData,
         regBusy        => regBusy,
         -- Global Signals
         pciClk         => pciClk,
         pciRst         => pciRst);

   -- RX Descriptor Controller
   PciRxDesc_Inst : entity work.PciRxDesc
      generic map (
         DMA_SIZE_G     => DMA_SIZE_C)
      port map (
         -- RX DMA Interface
         dmaDescToPci   => dmaRxDescToPci,
         dmaDescFromPci => dmaRxDescFromPci,
         -- Register Signals
         regCs          => regRxCs,
         regAddr        => regAddr(9 downto 2),
         regWrEn        => regWrEn,
         regWrData      => regWrData,
         regRdEn        => regRdEn,
         regRdData      => regRxRdData,
         -- IRQ Request
         irqReq         => rxDmaIrqReq,
         -- Counter reset
         countReset     => counterRst,
         -- Global Signals
         pciClk         => pciClk,
         pciRst         => cardRst);

   -- FLASH Controller
   PciFlashBpi_Inst : entity work.PciFlashBpi
      port map (
         -- FLASH Interface 
         flashAddr => flashAddr,
         flashData => flashData,
         flashAdv  => flashAdv,
         flashCe   => flashCe,
         flashOe   => flashOe,
         flashWe   => flashWe,
         -- Register Signals
         regCs     => regFlashCs,
         regAddr   => regAddr(9 downto 2),
         regWrEn   => regWrEn,
         regWrData => regWrData,
         regRdEn   => regRdEn,
         regRdData => regFlashRdData,
         regBusy   => flashBusy,
         -- Global Signals
         pciClk    => pciClk,
         pciRst    => pciRst);

   -------------------------
   -- Register space
   -------------------------
   -- Decode address space
   regLocCs   <= '1' when (regAddr(11 downto 10) = "00") else '0';
   regRxCs    <= '1' when (regAddr(11 downto 10) = "01") else '0';
   regTxCs    <= '1' when (regAddr(11 downto 10) = "10") else '0';
   regFlashCs <= '1' when (regAddr(11 downto 10) = "11") else '0';

   Iprog7Series_Inst : entity work.Iprog7Series
      port map (
         clk         => pciClk,
         rst         => pciRst,
         start       => reboot,
         bootAddress => X"00000000");   

   -- Local register space
   process (pciClk)
      variable lane : integer;
   begin
      if rising_edge(pciClk) then
         -- Reset the strobes
         if (pciRst = '1') then
            cardRst                   <= '1';
            counterRst                <= '0';
            ledOff                    <= '0';
            irqEnable                 <= '0';
            reboot                    <= '0';
            rebootEn                  <= '0';
            rebootTimer               <= (others => '0');

            scratchPad                <= (others => '0');

            evrReset                  <= '0';
            evrPllRst                 <= '0';
            evrErrCntRst              <= '0';

            txPllRst                  <= (others => '0');
            rxPllRst                  <= (others => '0');

            txRst                     <= (others => '0');
            rxRst                     <= (others => '0');
            countRst                  <= (others => '0');
            pack16                    <= (others => '0');
            trgCC                     <= (others => (others => '0'));
            trgPolarity               <= (others => '0');
            enable                    <= (others => '0');

            numBits                   <= (others => toSlv(   12,  8));
            numTrains                 <= (others => toSlv(  512, 32));
            numCycles                 <= (others => toSlv( 1536, 32));
            serBaud                   <= (others => toSlv(57600, 32));

            preScale                  <= (others => toSlv(  119,  8));
            trgCode                   <= (others => toSlv(  145,  8));
            trgDelay                  <= (others => toSlv(  880, 32));
            trgWidth                  <= (others => toSlv(   80, 32));

            pciToCl.serFifoWrEn      <= (others => '0');
         else
            -- Check for enabled timer
            if (rebootEn = '1') then
               if (rebootTimer = toSlv(getTimeRatio(125.0E+6, 1.0), 32)) then
                  reboot      <= '1';
               else
                  rebootTimer <= rebootTimer + 1;
               end if;
            end if;

            pciToCl.serFifoWrEn       <= (others => '0');
            pciToCl.serFifoRdEn       <= (others => '0');

            regBusy                    <= '0';

            if (regAddr(11 downto 10) = "00") then
               if (regAddr(9 downto 8) = "11" ) then
                  regRdData <= BUILD_STRING_ROM_C(conv_integer(regAddr(7 downto 2)));
               else
                  case regAddr(9 downto 2) is
                     -------------------------------
                     -- System Registers
                     -------------------------------
                     when x"00" =>                           -- Firmware Version
                        regRdData <= BUILD_INFO_C.fwVersion;
                     when x"01" =>                    -- Serial # (lower 32-bit)
                        regRdData <= serialNumber(31 downto  0);
                     when x"02" =>                    -- Serial # (upper 32-bit)
                        regRdData <= serialNumber(63 downto 32);
                     when x"03" =>                       -- Extender baud (Mbps)
                        regRdData <= toSlv(getTimeRatio(GTP_RATE_G, 1.0E6), 32);
                     when x"04" =>                           -- Control & Status
                        regRdData(31)           <= evrLinkUp;
                        regRdData(30)           <= evrEvt140;
                        regRdData(29 downto 28) <= rxPllLock;
                        regRdData(27 downto 26) <= txPllLock;
                        regRdData(25)           <= irqOut.activeFlag;
                        regRdData(24 downto 10) <= (others => '0');
                        regRdData( 9)           <= irqEnable;
                        regRdData( 8)           <= ledOff;
                        regRdData( 7)           <= counterRst;
                        regRdData( 6 downto  5) <= rxPllRst;
                        regRdData( 4 downto  3) <= txPllRst;
                        regRdData( 2)           <= evrPllRst;
                        regRdData( 1)           <= evrReset;
                        regRdData( 0)           <= cardRst;

                        if (regWrEn = '1') then
                           irqEnable  <= regWrData(9);
                           ledOff     <= regWrData(8);
                           counterRst <= regWrData(7);
                           rxPllRst   <= regWrData(6 downto 5);
                           txPllRst   <= regWrData(4 downto 3);
                           evrPllRst  <= regWrData(2);
                           evrReset   <= regWrData(1);
                           cardRst    <= regWrData(0);
                        end if;
                     when x"06" =>                                -- Scratch Pad
                        regRdData <= scratchPad;

                        if (regWrEn = '1') then
                           scratchPad <= regWrData;
                        end if;
                     when x"07" =>                              -- Reboot Enable
                        regRdData(0) <= rebootEn;

                        if (regWrEn = '1') and (regWrData = x"BABECAFE") then
                           rebootEn <= '1';
                        end if;
                     when x"08" =>
                        regRdData(31 downto 16) <= cfgOut.command;
                        regRdData(15 downto  0) <= cfgOut.Status;
                     when x"09" =>
                        regRdData(31 downto 16) <= cfgOut.dCommand;
                        regRdData(15 downto  0) <= cfgOut.dStatus;
                     when x"0A" =>
                        regRdData(31 downto 16) <= cfgOut.lCommand;
                        regRdData(15 downto  0) <= cfgOut.lStatus;
                     when x"0B" =>
                        regRdData(26 downto 24) <= cfgOut.linkState;
                        regRdData(18 downto 16) <= cfgOut.functionNumber;
                        regRdData(12 downto  8) <= cfgOut.deviceNumber;
                        regRdData( 7 downto  0) <= cfgOut.busNumber;
                     when x"0C" =>                          -- EVR Error Counter
                        regRdData <= evrErrorCnt;
                     when others =>
                        -------------------------------
                        -- Array Registers
                        -------------------------------                     
                        lane := to_integer( unsigned( regAddr(4 downto 2) ) );
                        -- regAddr: 0x40 - 0x47    Grabber CSRs
                        if    (regAddr(9 downto 5) =  8) then
                           regRdData <= evrLinkUp         &
                                        evrEvt140         &
                                        extLinkUp  (lane) &
                                        camLock    (lane) & X"00000" &
                                        enable     (lane) &
                                        trgPolarity(lane) &
                                        trgCC      (lane) &
                                        pack16     (lane) & "000";

                           if (regWrEn = '1') then
                              enable     (lane) <= regWrData(7);
                              trgPolarity(lane) <= regWrData(6);
                              trgCC      (lane) <= regWrData(5 downto 4);
                              pack16     (lane) <= regWrData(3);
                              countRst   (lane) <= regWrData(2);
                              rxRst      (lane) <= regWrData(1);
                              txRst      (lane) <= regWrData(0);
                           end if;

                        -- regAddr: 0x48 - 0x4F
                        elsif (regAddr(9 downto 5) =  9) then
                           regRdData(7 downto 0) <= numBits(lane);

                           if (regWrEn = '1') then
                              numBits(lane) <= regWrData(7 downto 0);
                           end if;

                        -- regAddr: 0x50 - 0x57
                        elsif (regAddr(9 downto 5) = 10) then
                           regRdData <= numTrains(lane);

                           if (regWrEn = '1') then
                              numTrains(lane) <= regWrData;
                           end if;

                        -- regAddr: 0x58 - 0x5F
                        elsif (regAddr(9 downto 5) = 11) then
                           regRdData <= numCycles(lane);

                           if (regWrEn = '1') then
                              numCycles(lane) <= regWrData;
                           end if;

                        -- regAddr: 0x60 - 0x67
                        elsif (regAddr(9 downto 5) = 12) then
                           regRdData <= serBaud(lane);

                           if (regWrEn = '1') then
                              serBaud(lane) <= regWrData;
                           end if;

                        -- regAddr: 0x68 - 0x6F    sertc bytes
                        elsif (regAddr(9 downto 5) = 13) then
                           if (regWrEn = '1') then
                              pciToCl.serFifoWr  (lane) <= regWrData(7 downto 0);
                              pciToCl.serFifoWrEn(lane) <= '1';
                           end if;

                        -- regAddr: 0x70 - 0x77    sertfg bytes
                        elsif (regAddr(9 downto 5) = 14) then
                           if (regRdEn = '1') then
                              pciToCl.serFifoRdEn(lane) <= '1';

                              if (clToPci.serFifoValid(lane) = '1') then
                                 regRdData(7 downto 0) <= clToPci.serFifoRd(lane);
                              else
                                 regRdData(7 downto 0) <= X"FF";
                              end if;
                           end if;

                        -- regAddr: 0x78 - 0x7F
                        elsif (regAddr(9 downto 5) = 15) then
                           regRdData(7 downto 0) <= preScale(lane);

                           if (regWrEn = '1') then
                              preScale(lane) <= regWrData(7 downto 0);
                           end if;

                        -- regAddr: 0x80 - 0x87
                        elsif (regAddr(9 downto 5) = 16) then
                           regRdData(7 downto 0) <= trgCode (lane);

                           if (regWrEn = '1') then
                              trgCode(lane)  <= regWrData(7 downto 0);
                           end if;

                        -- regAddr: 0x88 - 0x8F
                        elsif (regAddr(9 downto 5) = 17) then
                           regRdData <= trgDelay     (lane);

                           if (regWrEn = '1') then
                              trgDelay(lane) <= regWrData;
                           end if;

                        -- regAddr: 0x90 - 0x97
                        elsif (regAddr(9 downto 5) = 18) then
                           regRdData <= trgWidth     (lane);

                           if (regWrEn = '1') then
                              trgWidth(lane) <= regWrData;
                           end if;

                        -- regAddr: 0x98 - 0x9F
                        elsif (regAddr(9 downto 5) = 19) then
                           regRdData <= trgCount     (lane);

                        -- regAddr: 0xA0 - 0xA7
                        elsif (regAddr(9 downto 5) = 20) then
                           regRdData <= trgToFrameDly(lane);

                        -- regAddr: 0xA8 - 0xAF
                        elsif (regAddr(9 downto 5) = 21) then
                           regRdData <= frameCount   (lane);

                        -- regAddr: 0xB0 - 0xB7
                        elsif (regAddr(9 downto 5) = 22) then
                           regRdData <= frameRate    (lane);

                        -- regAddr: 0xB8 - 0xBF            ?????????????????????
                        elsif (regAddr(9 downto 5) = 23) then
--                         regRdData(31 downto 28) <= linkErrorCnt(lane);
--                         regRdData(27 downto 24) <= linkDownCnt (lane);
--                         regRdData(23 downto 20) <= cellErrorCnt(lane);
--                         regRdData(19 downto 16) <= fifoErrorCnt(lane);
--                         regRdData(15 downto 12) <= rxCount(lane, 3);
--                         regRdData(11 downto  8) <= rxCount(lane, 2);
--                         regRdData( 7 downto  4) <= rxCount(lane, 1);
--                         regRdData( 3 downto  0) <= rxCount(lane, 0);
                        end if;
                  end case;
               end if;
            elsif (regAddr(11 downto 10) = "01") then
               regRdData <= regRxRdData;
            elsif (regAddr(11 downto 10) = "10") then
               regRdData <= regTxRdData;
            else
               regBusy   <= flashBusy;
               regRdData <= regFlashRdData;
            end if;
         end if;
      end if;
   end process;

   -- Deal with the LEDs
   process (pciClk) is
      variable we : natural;
   begin
      if rising_edge(pciClk) then
         ledCycles <= ledCycles + 1;

         -- PCIe
         if (ledOff = '1') then                                       -- all off
            led_r(0) <= '1';
            led_b(0) <= '1';
            led_g(0) <= '1';
         elsif (cardRst = '1') then                                       -- red
            led_r(0) <= '0';
            led_b(0) <= '1';
            led_g(0) <= '1';
         else                                                   -- more checks !
            led_r(0) <= '1';
            led_b(0) <= '1';
            led_g(0) <= '0';
         end if;

         -- EVR
         if (ledOff = '1') then                                       -- all off
            led_r(1) <= '1';
            led_b(1) <= '1';
            led_g(1) <= '1';
         elsif (cardRst = '1') then                                       -- red
            led_r(1) <= '0';
            led_b(1) <= '1';
            led_g(1) <= '1';
         elsif (evrReset = '1') or (evrPllRst = '1') then              -- purple
            led_r(1) <= '0';
            led_b(1) <= '0';
            led_g(1) <= '1';
         elsif (evrLinkUp = '0') then                                  -- yellow
            led_r(1) <= '0';
            led_b(1) <= '1';
            led_g(1) <= '0';
         elsif (evrErrorCnt > 0) then                         -- yellow flashing
            led_b(1) <= '1';

            led_r(1) <= ledCycles(26);
            led_g(1) <= ledCycles(26);
         elsif (evrEvt140 = '0') then                          -- green flashing
            led_r(1) <= '1';
            led_b(1) <= '1';
            led_g(1) <= ledCycles(26);
         else                                            -- green, everything ok
            led_r(1) <= '1';
            led_b(1) <= '1';
            led_g(1) <= '0';
         end if;

         -- Grabbers
         for we in 0 to 1 loop
            if (ledOff = '1') then                                    -- all off
               led_r(2+we*2) <= '1';
               led_b(2+we*2) <= '1';
               led_g(2+we*2) <= '1';

               led_r(3+we*2) <= '1';
               led_b(3+we*2) <= '1';
               led_g(3+we*2) <= '1';
            elsif (cardRst = '1') then                                    -- red
               led_r(2+we*2) <= '0';
               led_b(2+we*2) <= '1';
               led_g(2+we*2) <= '1';

               led_r(3+we*2) <= '0';
               led_b(3+we*2) <= '1';
               led_g(3+we*2) <= '1';
            elsif (txPllRst(we) = '1') then                            -- purple
               led_r(2+we*2) <= '0';
               led_b(2+we*2) <= '0';
               led_g(2+we*2) <= '1';

               led_r(3+we*2) <= '1';
               led_b(3+we*2) <= '1';
               led_g(3+we*2) <= '1';
            elsif (rxPllRst(we) = '1') then                            -- purple
               led_r(2+we*2) <= '1';
               led_b(2+we*2) <= '1';
               led_g(2+we*2) <= '1';

               led_r(3+we*2) <= '0';
               led_b(3+we*2) <= '0';
               led_g(3+we*2) <= '1';
            elsif (txPllLock(we) = '0') then                           -- yellow
               led_r(2+we*2) <= '0';
               led_b(2+we*2) <= '1';
               led_g(2+we*2) <= '0';

               led_r(3+we*2) <= '1';
               led_b(3+we*2) <= '1';
               led_g(3+we*2) <= '1';
            elsif (rxPllLock(we) = '0') then                           -- yellow
               led_r(2+we*2) <= '1';
               led_b(2+we*2) <= '1';
               led_g(2+we*2) <= '1';

               led_r(3+we*2) <= '0';
               led_b(3+we*2) <= '1';
               led_g(3+we*2) <= '0';
            else
               led_r(2+we*2) <= '1';
               led_r(3+we*2) <= '1';

               led_b(2+we*2) <= (not extLinkUp(0+we*4)) or
                                ((not camLock(0+we*4)) and ledCycles(26));
               led_g(2+we*2) <= (not extLinkUp(1+we*4)) or
                                ((not camLock(1+we*4)) and ledCycles(26));
               led_b(3+we*2) <= (not extLinkUp(2+we*4)) or
                                ((not camLock(2+we*4)) and ledCycles(26));
               led_g(3+we*2) <= (not extLinkUp(3+we*4)) or
                                ((not camLock(3+we*4)) and ledCycles(26));
            end if;
         end loop;
      end if;
   end process;

end rtl;

