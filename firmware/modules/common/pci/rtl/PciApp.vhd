-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciApp.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2014-07-31
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;
use work.PgpCardG3Pkg.all;
use work.Version.all;

entity PciApp is
   generic (
      -- PGP Configurations
      PGP_RATE_G : real);
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
      dmaTxTranFromPci : in    TranFromPciArray(0 to 7);
      dmaRxTranFromPci : in    TranFromPciArray(0 to 7);
      dmaTxObMaster    : in    AxiStreamMasterArray(0 to 7);
      dmaTxObSlave     : out   AxiStreamSlaveArray(0 to 7);
      dmaTxIbMaster    : out   AxiStreamMasterArray(0 to 7);
      dmaTxIbSlave     : in    AxiStreamSlaveArray(0 to 7);
      dmaRxIbMaster    : out   AxiStreamMasterArray(0 to 7);
      dmaRxIbSlave     : in    AxiStreamSlaveArray(0 to 7);
      -- PCIe Interface
      cfgOut           : in    CfgOutType;
      irqIn            : out   IrqInType;
      irqOut           : in    IrqOutType;
      -- Parallel Interface
      pgpToPci         : in    PgpToPciType;
      pciToPgp         : out   PciToPgpType;
      evrToPci         : in    EvrToPciType;
      pciToEvr         : out   PciToEvrType;
      --Global Signals
      pgpClk           : in    sl;
      pgpRst           : in    sl;
      evrClk           : in    sl;
      evrRst           : in    sl;
      pciClk           : in    sl;
      pciRst           : in    sl);       
end PciApp;

architecture rtl of PciApp is

   constant DMA_SIZE_C : natural := 8;

   type RomType is array (0 to 63) of slv(31 downto 0);
   function makeStringRom return RomType is
      variable ret : RomType := (others => (others => '0'));
      variable c   : character;
   begin
      for i in BUILD_STAMP_C'range loop
         c                                                      := BUILD_STAMP_C(i);
         ret((i-1)/4)(8*((i-1) mod 4)+7 downto 8*((i-1) mod 4)) := toSlv(character'pos(c), 8);
      end loop;
      return ret;
   end function makeStringRom;
   signal buildStampString : RomType := makeStringRom;

   -- Descriptor Signals
   signal dmaRxDescToPci,
      dmaTxDescToPci : DescToPciArray(0 to (DMA_SIZE_C-1));
   signal dmaRxDescFromPci,
      dmaTxDescFromPci : DescFromPciArray(0 to (DMA_SIZE_C-1));

   -- Register Controller
   signal cardRst,
      countRst,
      reboot,
      rebootEn,
      regWrEn,
      regRdEn,
      regRxCs,
      regTxCs,
      regLocCs,
      regFlashCs,
      flashBusy,
      regBusy : sl;
   signal regBar  : slv(2 downto 0);
   signal regAddr : slv(31 downto 2);

   signal regWrData,
      regRdData,
      regRxRdData,
      regTxRdData,
      regLocRdData,
      regFlashRdData,
      rebootTimer,
      scratchPad : slv(31 downto 0);

   signal serialNumber : slv(63 downto 0);

   -- Interrupt Signals
   signal irqEnable   : sl;
   signal rxDmaIrqReq : sl;
   signal txDmaIrqReq : sl;

   --PGP Signals
   signal enHeaderCheck : SlVectorArray(0 to 7, 0 to 3);
   signal rxCount       : Slv4VectorArray(0 to 7, 0 to 3);
   signal cellErrorCnt,
      linkDownCnt,
      linkErrorCnt,
      fifoErrorCnt : Slv4Array(0 to 7);
   signal locLinkReady,
      remLinkReady,
      loopback,
      pgpTxRst,
      pgpRxRst : slv(7 downto 0);
   signal pllTxReady,
      pllRxReady,
      pllTxRst,
      pllRxRst : slv(1 downto 0);

   --EVR Signals     
   signal evrPllRst,
      evrReset,
      evrLinkUp,
      evrEnable : sl;
   signal evrErrorCnt : slv(3 downto 0);
   signal runCode,
      acceptCode : slv(7 downto 0);
   
   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of
      PciRegCtrl_Inst,
      PciRxDesc_Inst,
      PciTxDesc_Inst,
      PciFlashBpi_Inst : label is "TRUE";
   
begin
   
   cardReset <= cardRst;

   -------------------------------
   -- Input/Output mapping
   -------------------------------    
   irqIn.req    <= rxDmaIrqReq or txDmaIrqReq;
   irqIn.enable <= irqEnable;
   serNumber    <= serialNumber;

   -- Add registers to help with timing
   process (pciClk)
      variable i : integer;
   begin
      if rising_edge(pciClk) then
         
         PciToPgp.pllRxRst(0)   <= pllRxRst(0) or cardRst;
         PciToPgp.pllRxRst(1)   <= pllRxRst(1) or cardRst;
         PciToPgp.pllTxRst(0)   <= pllTxRst(0) or cardRst;
         PciToPgp.pllTxRst(1)   <= pllTxRst(1) or cardRst;
         PciToPgp.countRst      <= countRst or cardRst;
         PciToPgp.loopBack      <= loopBack;
         PciToPgp.enHeaderCheck <= enHeaderCheck;

         PciToEvr.countRst   <= countRst or cardRst;
         PciToEvr.pllRst     <= evrPllRst or cardRst;
         PciToEvr.evrReset   <= evrReset or cardRst;
         PciToEvr.enable     <= evrEnable;
         PciToEvr.runCode    <= runCode;
         PciToEvr.acceptCode <= acceptCode;

         for i in 0 to DMA_SIZE_C-1 loop
            PciToPgp.pgpRxRst(i) <= pgpRxRst(i) or cardRst;
            PciToPgp.pgpTxRst(i) <= pgpTxRst(i) or cardRst;
         end loop;
      end if;
   end process;

   MAP_PGP_DMA_LANES :
   for lane in 0 to DMA_SIZE_C-1 generate

      -- Input buses
      dmaTxIbMaster(lane) <= PgpToPci.dmaTxIbMaster(lane);
      dmaTxObSlave(lane)  <= PgpToPci.dmaTxObSlave(lane);
      dmaRxIbMaster(lane) <= PgpToPci.dmaRxIbMaster(lane);

      dmaTxDescToPci(lane) <= PgpToPci.dmaTxDescToPci(lane);
      dmaRxDescToPci(lane) <= PgpToPci.dmaRxDescToPci(lane);

      -- Output buses
      PciToPgp.dmaTxTranFromPci(lane) <= dmaTxTranFromPci(lane);
      PciToPgp.dmaRxTranFromPci(lane) <= dmaRxTranFromPci(lane);

      PciToPgp.dmaTxDescFromPci(lane) <= dmaTxDescFromPci(lane);
      PciToPgp.dmaRxDescFromPci(lane) <= dmaRxDescFromPci(lane);

      PciToPgp.dmaTxIbSlave(lane)  <= dmaTxIbSlave(lane);
      PciToPgp.dmaTxObMaster(lane) <= dmaTxObMaster(lane);
      PciToPgp.dmaRxIbSlave(lane)  <= dmaRxIbSlave(lane);

   end generate MAP_PGP_DMA_LANES;

   -------------------------------
   -- Synchronization
   ------------------------------- 
   SynchronizerVector_0 : entity work.SynchronizerVector
      generic map (
         WIDTH_G => 2)
      port map (
         clk     => pciClk,
         dataIn  => pgpToPci.pllTxReady,
         dataOut => pllTxReady);

   SynchronizerVector_1 : entity work.SynchronizerVector
      generic map (
         WIDTH_G => 2)
      port map (
         clk     => pciClk,
         dataIn  => pgpToPci.pllRxReady,
         dataOut => pllRxReady);  

   SynchronizerVector_2 : entity work.SynchronizerVector
      generic map (
         WIDTH_G => 8)
      port map (
         clk     => pciClk,
         dataIn  => pgpToPci.locLinkReady,
         dataOut => locLinkReady);

   SynchronizerVector_3 : entity work.SynchronizerVector
      generic map (
         WIDTH_G => 8)
      port map (
         clk     => pciClk,
         dataIn  => pgpToPci.remLinkReady,
         dataOut => remLinkReady);          

   GEN_SYNC_LANE :
   for lane in 0 to 7 generate
      
      SynchronizerFifo_0 : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 4)
         port map(
            wr_clk => pgpClk,
            din    => pgpToPci.cellErrorCnt(lane),
            rd_clk => pciClk,
            dout   => cellErrorCnt(lane));

      SynchronizerFifo_1 : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 4)
         port map(
            wr_clk => pgpClk,
            din    => pgpToPci.linkDownCnt(lane),
            rd_clk => pciClk,
            dout   => linkDownCnt(lane));

      SynchronizerFifo_2 : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 4)
         port map(
            wr_clk => pgpClk,
            din    => pgpToPci.linkErrorCnt(lane),
            rd_clk => pciClk,
            dout   => linkErrorCnt(lane));             

      SynchronizerFifo_3 : entity work.SynchronizerFifo
         generic map(
            DATA_WIDTH_G => 4)
         port map(
            wr_clk => pgpClk,
            din    => pgpToPci.fifoErrorCnt(lane),
            rd_clk => pciClk,
            dout   => fifoErrorCnt(lane)); 

      GEN_SYNC_VC :
      for vc in 0 to 3 generate
         SynchronizerFifo_4 : entity work.SynchronizerFifo
            generic map(
               DATA_WIDTH_G => 4)
            port map(
               wr_clk => pgpClk,
               din    => pgpToPci.rxCount(lane, vc),
               rd_clk => pciClk,
               dout   => rxCount(lane, vc));          
      end generate GEN_SYNC_VC;
   end generate GEN_SYNC_LANE;

   Synchronizer_Inst : entity work.Synchronizer
      port map (
         clk     => pciClk,
         dataIn  => EvrToPci.linkUp,
         dataOut => evrLinkUp);   

   SynchronizerFifo_5 : entity work.SynchronizerFifo
      generic map(
         DATA_WIDTH_G => 4)
      port map(
         wr_clk => evrClk,
         din    => EvrToPci.errorCnt,
         rd_clk => pciClk,
         dout   => evrErrorCnt);    

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
         --Global Signals
         pciClk         => pciClk,
         pciRst         => pciRst);

   -- RX Descriptor Controller
   PciRxDesc_Inst : entity work.PciRxDesc
      generic map (
         DMA_SIZE_G => DMA_SIZE_C)
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
         countReset     => countRst,
         --Global Signals
         pciClk         => pciClk,
         pciRst         => cardRst);

   -- TX Descriptor Controller
   PciTxDesc_Inst : entity work.PciTxDesc
      generic map (
         DMA_SIZE_G => DMA_SIZE_C)
      port map (
         -- TX DMA Interface
         dmaDescToPci   => dmaTxDescToPci,
         dmaDescFromPci => dmaTxDescFromPci,
         -- Register Signals
         regCs          => regTxCs,
         regAddr        => regAddr(9 downto 2),
         regWrEn        => regWrEn,
         regWrData      => regWrData,
         regRdEn        => regRdEn,
         regRdData      => regTxRdData,
         -- IRQ Request
         irqReq         => txDmaIrqReq,
         -- Counter reset
         countReset     => countRst,
         --Global Signals
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
         --Global Signals
         pciClk    => pciClk,
         pciRst    => pciRst);                  

   -------------------------
   -- Register space
   -------------------------
   -- Decode address space
   regLocCs   <= '1' when ((regBar = 0) and (regAddr(11 downto 10) = "00")) else '0';
   regRxCs    <= '1' when ((regBar = 0) and (regAddr(11 downto 10) = "01")) else '0';
   regTxCs    <= '1' when ((regBar = 0) and (regAddr(11 downto 10) = "10")) else '0';
   regFlashCs <= '1' when ((regBar = 0) and (regAddr(11 downto 10) = "11")) else '0';

   -- Select read data
   regRdData <= regLocRdData when ((regBar = 0) and (regAddr(11 downto 10) = "00")) else
                regRxRdData    when ((regBar = 0) and (regAddr(11 downto 10) = "01")) else
                regTxRdData    when ((regBar = 0) and (regAddr(11 downto 10) = "10")) else
                regFlashRdData when ((regBar = 0) and (regAddr(11 downto 10) = "11")) else
                (others => '0');

   regBusy <= flashBusy;

   Iprog7Series_Inst : entity work.Iprog7Series
      port map (
         clk         => pciClk,
         rst         => pciRst,
         start       => reboot,
         bootAddress => X"00000000");   

   -- Local register space
   process (pciClk)
      variable lane : integer;
      variable vc   : integer;
   begin
      if rising_edge(pciClk) then
         if pciRst = '1' then
            regLocRdData  <= (others => '0');
            scratchPad    <= (others => '0');
            irqEnable     <= '0';
            countRst      <= '0';
            cardRst       <= '1';
            loopBack      <= (others => '0');
            pgpRxRst      <= (others => '0');
            pgpTxRst      <= (others => '0');
            pllRxRst      <= (others => '0');
            pllTxRst      <= (others => '0');
            runCode       <= (others => '0');
            acceptCode    <= (others => '0');
            evrEnable     <= '0';
            evrReset      <= '0';
            evrPllRst     <= '0';
            enHeaderCheck <= (others => (others => '0'));
            reboot        <= '0';
            rebootEn      <= '0';
            rebootTimer   <= (others => '0');
         else
            -- Check for enabled timer
            if rebootEn = '1' then
               if rebootTimer = toSlv(getTimeRatio(125.0E+6, 1.0), 32) then
                  reboot <= '1';
               else
                  rebootTimer <= rebootTimer + 1;
               end if;
            end if;
            -- Write
            if regLocCs = '1' then
               regLocRdData <= (others => '0');
               case regAddr(9 downto 2) is
                  -------------------------------
                  -- System Registers
                  -------------------------------
                  when x"00" =>
                     -- Firmware Version
                     regLocRdData <= FPGA_VERSION_C;
                  when x"01" =>
                     -- Serial Number Version (lower word)
                     regLocRdData <= serialNumber(31 downto 0);
                  when x"02" =>
                     -- Serial Number Version (upper word)
                     regLocRdData <= serialNumber(63 downto 32);
                  when x"03" =>
                     -- Scratch Pad
                     regLocRdData <= scratchPad;
                     if regWrEn = '1' then
                        scratchPad <= regWrData;
                     end if;
                  when x"04" =>
                     -- Reset Counters
                     regLocRdData(0) <= countRst;
                     regLocRdData(1) <= cardRst;
                     if regWrEn = '1' then
                        countRst <= regWrData(0);
                        cardRst  <= regWrData(1);
                     end if;
                  when x"05" =>
                     -- IRQ Enable
                     regLocRdData(1) <= irqOut.activeFlag;
                     regLocRdData(0) <= irqEnable;
                     if regWrEn = '1' then
                        irqEnable <= regWrData(0);
                     end if;
                  when x"06" =>
                     -- PGP baud rate in units of Mbps
                     regLocRdData <= toSlv(getTimeRatio(PGP_RATE_G, 1.0E+6), 32);
                  when x"07" =>
                     -- Reboot Enable
                     regLocRdData(0) <= rebootEn;
                     if (regWrEn = '1') and (regWrData = x"BABECAFE") then
                        rebootEn <= '1';
                     end if;
                  when x"0B" =>
                     regLocRdData(31 downto 16) <= cfgOut.command;
                     regLocRdData(15 downto 0)  <= cfgOut.Status;
                  when x"0C" =>
                     regLocRdData(31 downto 16) <= cfgOut.dCommand;
                     regLocRdData(15 downto 0)  <= cfgOut.dStatus;
                  when x"0D" =>
                     regLocRdData(31 downto 16) <= cfgOut.lCommand;
                     regLocRdData(15 downto 0)  <= cfgOut.lStatus;
                  when x"0E" =>
                     regLocRdData(26 downto 24) <= cfgOut.linkState;
                     regLocRdData(18 downto 16) <= cfgOut.functionNumber;
                     regLocRdData(12 downto 8)  <= cfgOut.deviceNumber;
                     regLocRdData(7 downto 0)   <= cfgOut.busNumber;
                  -------------------------------
                  -- EVR Registers
                  -------------------------------                        
                  when x"10" =>
                     -- EVR's Link Status and Error counter
                     regLocRdData(3 downto 0) <= evrErrorCnt;
                     regLocRdData(4)          <= evrLinkUp;
                  when x"11" =>
                     -- EVR's Enable, trigger codes, and Resets
                     regLocRdData(7 downto 0)  <= runCode;
                     regLocRdData(15 downto 8) <= acceptCode;
                     regLocRdData(16)          <= evrEnable;
                     regLocRdData(17)          <= evrReset;
                     regLocRdData(18)          <= evrPllRst;
                     if regWrEn = '1' then
                        runCode    <= regWrData(7 downto 0);
                        acceptCode <= regWrData(15 downto 8);
                        evrEnable  <= regWrData(16);
                        evrReset   <= regWrData(17);
                        evrPllRst  <= regWrData(18);
                     end if;
                  when x"12" =>
                     --EVR's Lanes Masks
                     for lane in 0 to 7 loop
                        --EVR's VC Masks
                        for vc in 0 to 3 loop
                           regLocRdData((4*lane)+vc) <= enHeaderCheck(lane, vc);
                           if regWrEn = '1' then
                              enHeaderCheck(lane, vc) <= regWrData((4*lane)+vc);
                           end if;
                        end loop;
                     end loop;
                  -------------------------------
                  -- PGP Registers
                  -------------------------------   
                  when x"20" =>
                     -- PGP's Loop Back Testing and Resets
                     regLocRdData(7 downto 0)   <= loopBack;
                     regLocRdData(15 downto 8)  <= pgpRxRst;
                     regLocRdData(23 downto 16) <= pgpTxRst;
                     regLocRdData(25 downto 24) <= pllRxRst;
                     regLocRdData(27 downto 26) <= pllTxRst;
                     regLocRdData(29 downto 28) <= pllRxReady;
                     regLocRdData(31 downto 30) <= pllTxReady;
                     if regWrEn = '1' then
                        loopBack <= regWrData(7 downto 0);
                        pgpRxRst <= regWrData(15 downto 8);
                        pgpTxRst <= regWrData(23 downto 16);
                        pllRxRst <= regWrData(25 downto 24);
                        pllTxRst <= regWrData(27 downto 26);
                     end if;
                  when x"21" =>
                     -- PGP's Link Status
                     regLocRdData(7 downto 0)  <= locLinkReady;
                     regLocRdData(15 downto 8) <= remLinkReady;
                  when others =>
                     --regAddr: 0xC0-0xFF
                     if regAddr(9 downto 8) = "11" then
                        regLocRdData <= buildStampString(conv_integer(regAddr(7 downto 2)));
                     else
                        -------------------------------
                        -- More PGP Registers
                        -------------------------------   
                        --PGP DMA channels
                        for lane in 0 to 7 loop
                           --regAddr: 0x80-0x87 
                           if (regAddr(9 downto 2) = (128+lane)) then
                              regLocRdData(3 downto 0)   <= rxCount(lane, 0);
                              regLocRdData(7 downto 4)   <= rxCount(lane, 1);
                              regLocRdData(11 downto 8)  <= rxCount(lane, 2);
                              regLocRdData(15 downto 12) <= rxCount(lane, 3);
                              regLocRdData(19 downto 16) <= fifoErrorCnt(lane);
                              regLocRdData(23 downto 20) <= cellErrorCnt(lane);
                              regLocRdData(27 downto 24) <= linkDownCnt(lane);
                              regLocRdData(31 downto 28) <= linkErrorCnt(lane);
                           end if;
                        end loop;
                     end if;
               end case;
            end if;
         end if;
      end if;
   end process;
   
end rtl;
