-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : PciFrontEnd.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-07-02
-- Last update: 2014-08-18
-- Platform   : Vivado 2014.1
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.PciPkg.all;

library unisim;
use unisim.vcomponents.all;

entity PciFrontEnd is
   generic (
      TPD_G      : time     := 1 ns;
      DMA_SIZE_G : positive := 8);
   port (
      -- Parallel Interface
      cfgOut           : out CfgOutType;
      irqIn            : in  IrqInType;
      irqOut           : out IrqOutType;
      -- Register Interface
      regTranFromPci   : out TranFromPciType;
      regObMaster      : out AxiStreamMasterType;
      regObSlave       : in  AxiStreamSlaveType;
      regIbMaster      : in  AxiStreamMasterType;
      regIbSlave       : out AxiStreamSlaveType;
      -- DMA Interface      
      dmaTxTranFromPci : out TranFromPciArray(0 to DMA_SIZE_G-1);
      dmaRxTranFromPci : out TranFromPciArray(0 to DMA_SIZE_G-1);
      dmaTxObMaster    : out AxiStreamMasterArray(0 to DMA_SIZE_G-1);
      dmaTxObSlave     : in  AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      dmaTxIbMaster    : in  AxiStreamMasterArray(0 to DMA_SIZE_G-1);
      dmaTxIbSlave     : out AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      dmaRxIbMaster    : in  AxiStreamMasterArray(0 to DMA_SIZE_G-1);
      dmaRxIbSlave     : out AxiStreamSlaveArray(0 to DMA_SIZE_G-1);
      -- PCIe Ports 
      pciRstL          : in  sl;
      pciRefClkP       : in  sl;
      pciRefClkN       : in  sl;
      pciRxP           : in  slv(3 downto 0);
      pciRxN           : in  slv(3 downto 0);
      pciTxP           : out slv(3 downto 0);
      pciTxN           : out slv(3 downto 0);
      pciLinkUp        : out sl;
      -- System Signals
      serNumber        : in  slv(63 downto 0);
      -- Global Signals
      pciClk           : out sl;        --125 MHz
      pciRst           : out sl);       
end PciFrontEnd;

architecture rtl of PciFrontEnd is

   component PcieCore4xA7
      port (
         -------------------------------------
         -- PCI Express (pci_exp) Interface --
         -------------------------------------
         pci_exp_txp      : out std_logic_vector(3 downto 0);
         pci_exp_txn      : out std_logic_vector(3 downto 0);
         pci_exp_rxp      : in  std_logic_vector(3 downto 0);
         pci_exp_rxn      : in  std_logic_vector(3 downto 0);
         ---------------------
         -- AXI-S Interface --
         ---------------------
         -- Common
         user_clk_out     : out std_logic;
         user_reset_out   : out std_logic;
         user_lnk_up      : out std_logic;
         user_app_rdy     : out std_logic;
         -- TX
         s_axis_tx_tready : out std_logic;
         s_axis_tx_tdata  : in  std_logic_vector(127 downto 0);
         s_axis_tx_tkeep  : in  std_logic_vector(15 downto 0);
         s_axis_tx_tlast  : in  std_logic;
         s_axis_tx_tvalid : in  std_logic;
         s_axis_tx_tuser  : in  std_logic_vector(3 downto 0);
         -- RX
         m_axis_rx_tdata  : out std_logic_vector(127 downto 0);
         m_axis_rx_tkeep  : out std_logic_vector(15 downto 0);
         m_axis_rx_tlast  : out std_logic;
         m_axis_rx_tvalid : out std_logic;
         m_axis_rx_tready : in  std_logic;
         m_axis_rx_tuser  : out std_logic_vector(21 downto 0);

         tx_cfg_gnt             : in std_logic;
         rx_np_ok               : in std_logic;
         rx_np_req              : in std_logic;
         cfg_trn_pending        : in std_logic;
         cfg_pm_halt_aspm_l0s   : in std_logic;
         cfg_pm_halt_aspm_l1    : in std_logic;
         cfg_pm_force_state_en  : in std_logic;
         cfg_pm_force_state     : in std_logic_vector(1 downto 0);
         cfg_dsn                : in std_logic_vector(63 downto 0);
         cfg_turnoff_ok         : in std_logic;
         cfg_pm_wake            : in std_logic;
         cfg_pm_send_pme_to     : in std_logic;
         cfg_ds_bus_number      : in std_logic_vector(7 downto 0);
         cfg_ds_device_number   : in std_logic_vector(4 downto 0);
         cfg_ds_function_number : in std_logic_vector(2 downto 0);

         cfg_device_number         : out std_logic_vector(4 downto 0);
         cfg_dcommand2             : out std_logic_vector(15 downto 0);
         cfg_pmcsr_pme_status      : out std_logic;
         cfg_status                : out std_logic_vector(15 downto 0);
         cfg_to_turnoff            : out std_logic;
         cfg_received_func_lvl_rst : out std_logic;
         cfg_dcommand              : out std_logic_vector(15 downto 0);
         cfg_bus_number            : out std_logic_vector(7 downto 0);
         cfg_function_number       : out std_logic_vector(2 downto 0);
         cfg_command               : out std_logic_vector(15 downto 0);
         cfg_dstatus               : out std_logic_vector(15 downto 0);
         cfg_lstatus               : out std_logic_vector(15 downto 0);
         cfg_pcie_link_state       : out std_logic_vector(2 downto 0);
         cfg_lcommand              : out std_logic_vector(15 downto 0);
         cfg_pmcsr_pme_en          : out std_logic;
         cfg_pmcsr_powerstate      : out std_logic_vector(1 downto 0);
         tx_buf_av                 : out std_logic_vector(5 downto 0);
         tx_err_drop               : out std_logic;
         tx_cfg_req                : out std_logic;

         cfg_bridge_serr_en                         : out std_logic;
         cfg_slot_control_electromech_il_ctl_pulse  : out std_logic;
         cfg_root_control_syserr_corr_err_en        : out std_logic;
         cfg_root_control_syserr_non_fatal_err_en   : out std_logic;
         cfg_root_control_syserr_fatal_err_en       : out std_logic;
         cfg_root_control_pme_int_en                : out std_logic;
         cfg_aer_rooterr_corr_err_reporting_en      : out std_logic;
         cfg_aer_rooterr_non_fatal_err_reporting_en : out std_logic;
         cfg_aer_rooterr_fatal_err_reporting_en     : out std_logic;
         cfg_aer_rooterr_corr_err_received          : out std_logic;
         cfg_aer_rooterr_non_fatal_err_received     : out std_logic;
         cfg_aer_rooterr_fatal_err_received         : out std_logic;
         cfg_vc_tcvc_map                            : out std_logic_vector(6 downto 0);
         -- EP Only
         cfg_interrupt                              : in  std_logic;
         cfg_interrupt_rdy                          : out std_logic;
         cfg_interrupt_assert                       : in  std_logic;
         cfg_interrupt_di                           : in  std_logic_vector(7 downto 0);
         cfg_interrupt_do                           : out std_logic_vector(7 downto 0);
         cfg_interrupt_mmenable                     : out std_logic_vector(2 downto 0);
         cfg_interrupt_msienable                    : out std_logic;
         cfg_interrupt_msixenable                   : out std_logic;
         cfg_interrupt_msixfm                       : out std_logic;
         cfg_interrupt_stat                         : in  std_logic;
         cfg_pciecap_interrupt_msgnum               : in  std_logic_vector(4 downto 0);
         ---------------------------
         -- System(SYS) Interface --
         ---------------------------
         sys_clk                                    : in  std_logic;
         sys_rst_n                                  : in  std_logic);
   end component;

   signal pciRefClk,
      sysRstL,
      locClk,
      userRst,
      locRst,
      userLink,
      cfgTurnoffOk,
      cfgToTurnOff,
      irqReq,
      irqEnable,
      irqActive : sl := '0';
   signal pciTxInUser  : slv(3 downto 0);
   signal plState      : slv(5 downto 0);
   signal rxBarHit     : slv(7 downto 0);
   signal locId        : slv(15 downto 0);
   signal pciRxOutUser : slv(21 downto 0);

   signal cfgIn     : CfgInType  := CFG_IN_INIT_C;
   signal locCfgOut : CfgOutType := CFG_OUT_INIT_C;

   signal txMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal txSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   signal rxMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal rxSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_INIT_C;

   -- PCI IRQ 
   type IrqStateType is (
      SI_IDLE,
      SI_SET,
      SI_SERV,
      SI_CLR);         
   signal irqState : IrqStateType := SI_IDLE;

   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of
      PcieCore_Inst,
      PciTlpCtrl_Inst : label is "TRUE";

   -- attribute dont_touch                 : string;
   -- attribute dont_touch of pciRxOutUser : signal is "true";
   
begin

   pciClk <= locClk;
   pciRst <= locRst;
   cfgOut <= locCfgOut;

   Synchronizer_userRst : entity work.Synchronizer
      port map (
         clk     => locClk,
         dataIn  => userRst,
         dataOut => locRst);     

   Synchronizer_userLink : entity work.Synchronizer
      port map (
         clk     => locClk,
         dataIn  => userLink,
         dataOut => pciLinkUp); 

   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map(
         I     => pciRefClkP,
         IB    => pciRefClkN,
         CEB   => '0',
         O     => pciRefClk,
         ODIV2 => open);        

   IBUF_Inst : IBUF
      port map(
         I => pciRstL,
         O => sysRstL);          

   PcieCore_Inst : PcieCore4xA7
      port map(
         -------------------------------------
         -- PCI Express (pci_exp) Interface --
         -------------------------------------
         -- TX
         pci_exp_txp      => pciTxP,
         pci_exp_txn      => pciTxN,
         -- RX
         pci_exp_rxp      => pciRxP,
         pci_exp_rxn      => pciRxN,
         ---------------------
         -- AXI-S Interface --
         ---------------------
         -- Common
         user_clk_out     => locClk,
         user_reset_out   => userRst,
         user_lnk_up      => userLink,
         user_app_rdy     => open,
         -- TX
         s_axis_tx_tready => txSlave.tReady,
         s_axis_tx_tdata  => txMaster.tData,
         s_axis_tx_tkeep  => txMaster.tKeep,
         s_axis_tx_tlast  => txMaster.tLast,
         s_axis_tx_tvalid => txMaster.tValid,
         s_axis_tx_tuser  => pciTxInUser,
         -- RX
         m_axis_rx_tdata  => rxMaster.tData,
         m_axis_rx_tkeep  => open,      -- rxMaster.tKeep port not valid in 128 bit mode
         m_axis_rx_tlast  => open,      -- rx.tLast gets sent via pciRxOutUser when in 128 bit mode
         m_axis_rx_tvalid => rxMaster.tValid,
         m_axis_rx_tready => rxSlave.tReady,
         m_axis_rx_tuser  => pciRxOutUser,

         tx_cfg_gnt             => '1',  -- Always allow transmission of Config traffic within block
         rx_np_ok               => '1',  -- Allow Reception of Non-posted Traffic
         rx_np_req              => '1',  -- Always request Non-posted Traffic if available
         cfg_trn_pending        => cfgIn.TrnPending,
         cfg_pm_halt_aspm_l0s   => '0',  -- Allow entry into L0s
         cfg_pm_halt_aspm_l1    => '0',  -- Allow entry into L1
         cfg_pm_force_state_en  => '0',  -- Do not qualify cfg_pm_force_state
         cfg_pm_force_state     => "00",  -- Do not move force core into specific PM state
         cfg_dsn                => serNumber,
         cfg_turnoff_ok         => cfgTurnoffOk,
         cfg_pm_wake            => '0',  -- Never direct the core to send a PM_PME Message
         cfg_pm_send_pme_to     => '0',
         cfg_ds_bus_number      => x"00",
         cfg_ds_device_number   => "00000",
         cfg_ds_function_number => "000",

         cfg_device_number         => locCfgOut.deviceNumber,
         cfg_dcommand2             => open,
         cfg_pmcsr_pme_status      => open,
         cfg_status                => locCfgOut.status,
         cfg_to_turnoff            => cfgToTurnOff,
         cfg_received_func_lvl_rst => open,
         cfg_dcommand              => locCfgOut.dCommand,
         cfg_bus_number            => locCfgOut.busNumber,
         cfg_function_number       => locCfgOut.functionNumber,
         cfg_command               => locCfgOut.command,
         cfg_dstatus               => locCfgOut.dStatus,
         cfg_lstatus               => locCfgOut.lStatus,
         cfg_pcie_link_state       => locCfgOut.linkState,
         cfg_lcommand              => locCfgOut.lCommand,
         cfg_pmcsr_pme_en          => open,
         cfg_pmcsr_powerstate      => open,
         tx_buf_av                 => open,
         tx_err_drop               => open,
         tx_cfg_req                => open,

         cfg_bridge_serr_en                         => open,
         cfg_slot_control_electromech_il_ctl_pulse  => open,
         cfg_root_control_syserr_corr_err_en        => open,
         cfg_root_control_syserr_non_fatal_err_en   => open,
         cfg_root_control_syserr_fatal_err_en       => open,
         cfg_root_control_pme_int_en                => open,
         cfg_aer_rooterr_corr_err_reporting_en      => open,
         cfg_aer_rooterr_non_fatal_err_reporting_en => open,
         cfg_aer_rooterr_fatal_err_reporting_en     => open,
         cfg_aer_rooterr_corr_err_received          => open,
         cfg_aer_rooterr_non_fatal_err_received     => open,
         cfg_aer_rooterr_fatal_err_received         => open,
         cfg_vc_tcvc_map                            => open,
         -- EP Only
         cfg_interrupt                              => cfgIn.irqReq,
         cfg_interrupt_rdy                          => locCfgOut.irqAck,
         cfg_interrupt_assert                       => cfgIn.irqAssert,
         cfg_interrupt_di                           => (others => '0'),  -- Do not set interrupt fields
         cfg_interrupt_do                           => open,
         cfg_interrupt_mmenable                     => open,
         cfg_interrupt_msienable                    => open,
         cfg_interrupt_msixenable                   => open,
         cfg_interrupt_msixfm                       => open,
         cfg_interrupt_stat                         => '0',  -- Never set the Interrupt Status bit
         cfg_pciecap_interrupt_msgnum               => "00000",  -- Zero out Interrupt Message Number             
         ---------------------------
         -- System(SYS) Interface --
         ---------------------------
         sys_clk                                    => pciRefClk,
         sys_rst_n                                  => sysRstL);       

   -- Receive ECRC Error: Indicates the current packet has an 
   -- ECRC error. Asserted at the packet EOF.
   pciTxInUser(0) <= '0';

   -- Receive Error Forward: When asserted, marks the packet in 
   -- progress as error-poisoned. Asserted by the core for the 
   -- entire length of the packet.
   pciTxInUser(1) <= '0';

   -- Transmit Streamed: Indicates a packet is presented on consecutive
   -- clock cycles and transmission on the link can begin before the entire 
   -- packet has been written to the core. Commonly referred as transmit cut-through mode
   pciTxInUser(2) <= '0';

   -- Transmit SourceDiscontinue: Can be asserted any time starting 
   -- on the first cycle after SOF. Assert s_axis_tx_tlast simultaneously 
   -- with (tx_src_dsc)s_axis_tx_tuser[3].
   pciTxInUser(3) <= '0';

   -- pciRxOut_user[21:17] (rx_is_eof[4:0]) only used in 128 bit interface
   -- Bit 4: Asserted when a packet is ending
   -- Bit 0-3: Indicates byte location of end of the packet, binary encoded  
   rxMaster.tLast <= pciRxOutUser(21);
   process(pciRxOutUser)
   begin
      if pciRxOutUser(21) = '0' then
         rxMaster.tKeep <= x"FFFF";
      elsif pciRxOutUser(20 downto 17) = x"B" then
         rxMaster.tKeep <= x"0FFF";
      elsif pciRxOutUser(20 downto 17) = x"7" then
         rxMaster.tKeep <= x"00FF";
      elsif pciRxOutUser(20 downto 17) = x"3" then
         rxMaster.tKeep <= x"000F";
      else
         rxMaster.tKeep <= x"FFFF";
      end if;
   end process;

   -- pciRxOut_user[16:15] -- IP Core Reserved

   -- pciRxOut_user[14:10] (rx_is_sof[4:0]) only used in 128 bit interface
   -- Bit 4: Asserted when a new packet is present
   -- Bit 0-3: Indicates byte location of start of new packet, binary encoded
   rxMaster.tUser(0)          <= '0';
   rxMaster.tUser(1)          <= pciRxOutUser(14);
   rxMaster.tUser(3 downto 2) <= (others => '0');

   -- Pass the EOF and SOF buses to the receiver
   rxMaster.tUser(7 downto 4)  <= pciRxOutUser(13 downto 10);  -- SOF[3:0]
   rxMaster.tUser(11 downto 8) <= pciRxOutUser(20 downto 17);  -- EOF[3:0]

   -- Unused tUser bits
   rxMaster.tUser(127 downto 12) <= (others => '0');

   -- Receive BAR Hit: Indicates BAR(s) targeted by the current 
   -- receive transaction. Asserted from the beginning of the 
   -- packet to m_axis_rx_tlast.
   rxBarHit(7 downto 0) <= pciRxOutUser(9 downto 2);
   process(rxBarHit)
   begin
      -- Encode bar hit value
      if rxBarHit(0) = '1' then
         rxMaster.tDest <= x"00";
      elsif rxBarHit(1) = '1' then
         rxMaster.tDest <= x"01";
      elsif rxBarHit(2) = '1' then
         rxMaster.tDest <= x"02";
      elsif rxBarHit(3) = '1' then
         rxMaster.tDest <= x"03";
      elsif rxBarHit(4) = '1' then
         rxMaster.tDest <= x"04";
      elsif rxBarHit(5) = '1' then
         rxMaster.tDest <= x"05";
      elsif rxBarHit(6) = '1' then
         rxMaster.tDest <= x"06";
      else
         rxMaster.tDest <= x"07";
      end if;
   end process;

   -- Receive Error Forward: When asserted, marks the packet in progress as
   -- error-poisoned. Asserted by the core for the entire length of the packet.
   -- pciRxOutUser(1);-- Unused

   -- Receive ECRC Error: Indicates the current packet has an ECRC error. 
   -- Asserted at the packet EOF
   -- pciRxOutUser(0);-- Unused

   -- Terminate unused rxMaster signals
   rxMaster.tStrb <= (others => '0');
   rxMaster.tId   <= (others => '0');

   --  Turn-off OK if requested and no transaction is pending
   process (locClk)
   begin
      if rising_edge(locClk) then
         if locRst = '1' then
            cfgTurnoffOk <= '0';
         else
            if ((cfgToTurnOff = '1') and (cfgIn.TrnPending = '0')) then
               cfgTurnoffOk <= '1';
            else
               cfgTurnoffOk <= '0';
            end if;
         end if;
      end if;
   end process;

   -------------------------------
   -- IRQ Control
   -------------------------------
   irqReq            <= irqIn.req;
   irqEnable         <= irqIn.enable;
   irqOut.activeFlag <= irqActive;

   --------------------------------------------
   -- NOTE:
   -- cfg_interrupt        => cfgIn.irqReq,
   -- cfg_interrupt_rdy    => locCfgOut.irqAck,
   -- cfg_interrupt_assert => cfgIn.irqAssert,
   --------------------------------------------
   process (locClk)
   begin
      if rising_edge(locClk) then
         if locRst = '1' then
            cfgIn.irqReq    <= '0';
            cfgIn.irqAssert <= '0';
            irqActive       <= '0';
            irqState        <= SI_IDLE;
         else
            ----------------------------------------------
            case irqState is
               ----------------------------------------------
               when SI_IDLE =>
                  if (irqReq = '1') and (irqEnable = '1') then
                     cfgIn.irqReq    <= '1';
                     cfgIn.irqAssert <= '1';
                     irqState        <= SI_SET;
                  end if;
               ----------------------------------------------
               when SI_SET =>
                  if locCfgOut.irqAck = '1' then
                     cfgIn.irqReq <= '0';
                     irqActive    <= '1';
                     irqState     <= SI_SERV;
                  end if;
               ----------------------------------------------
               when SI_SERV =>
                  if (irqReq = '0') or (irqEnable = '0') then
                     cfgIn.irqReq    <= '1';
                     cfgIn.irqAssert <= '0';
                     irqState        <= SI_CLR;
                  end if;
               ----------------------------------------------
               when SI_CLR =>
                  if locCfgOut.irqAck = '1' then
                     cfgIn.irqReq <= '0';
                     irqActive    <= '0';
                     irqState     <= SI_IDLE;
                  end if;
            ----------------------------------------------
            end case;
         end if;
      end if;
   end process;


   -- TLP Interface
   -------------------------------
   locId <= locCfgOut.busNumber & locCfgOut.deviceNumber & locCfgOut.functionNumber;

   PciTlpCtrl_Inst : entity work.PciTlpCtrl
      generic map (
         DMA_SIZE_G => DMA_SIZE_G)
      port map (
         -- PCIe Interface
         locId            => locId,
         trnPending       => cfgIn.TrnPending,
         sAxisMaster      => rxMaster,
         sAxisSlave       => rxSlave,
         mAxisMaster      => txMaster,
         mAxisSlave       => txSlave,
         -- Register Interface
         regTranFromPci   => regTranFromPci,
         regObMaster      => regObMaster,
         regObSlave       => regObSlave,
         regIbMaster      => regIbMaster,
         regIbSlave       => regIbSlave,
         -- DMA Interface      
         dmaTxTranFromPci => dmaTxTranFromPci,
         dmaRxTranFromPci => dmaRxTranFromPci,
         dmaTxObMaster    => dmaTxObMaster,
         dmaTxObSlave     => dmaTxObSlave,
         dmaTxIbMaster    => dmaTxIbMaster,
         dmaTxIbSlave     => dmaTxIbSlave,
         dmaRxIbMaster    => dmaRxIbMaster,
         dmaRxIbSlave     => dmaRxIbSlave,
         -- Global Signals
         pciClk           => locClk,
         pciRst           => locRst);
end rtl;
