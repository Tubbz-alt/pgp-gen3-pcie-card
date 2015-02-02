//---------------------------------------------------------------------------------
// Title         : Kernel Module For PGP To PCI Bridge Card
// Project       : PGP To PCI-E Bridge Card
//---------------------------------------------------------------------------------
// File          : PgpCardG3Mod.h
// Author        : Ryan Herbst, rherbst@slac.stanford.edu
// Created       : 09/20/2013
//---------------------------------------------------------------------------------
//
//---------------------------------------------------------------------------------
// Copyright (c) 2013 by SLAC National Accelerator Laboratory. All rights reserved.
//---------------------------------------------------------------------------------
// Modification history:
// 09/20/2013: created.
//---------------------------------------------------------------------------------

#ifndef __PGP_CARD_G3_MOD_H__
#define __PGP_CARD_G3_MOD_H__

#include <linux/types.h>

// Return values
#define SUCCESS 0
#define ERROR   -1

// Scratchpad write value
#define SPAD_WRITE 0x55441122

// TX Structure
typedef struct {

   __u32  model; // large=8, small=4
   __u32  cmd; // ioctl commands
   __u32* data;
   // Lane & VC
   __u32  pgpLane;
   __u32  pgpVc;

   // Data
   __u32   size;  // dwords

} PgpCardTx;

// RX Structure
typedef struct {
    __u32   model; // large=8, small=4
    __u32   maxSize; // dwords
    __u32*  data;

   // Lane & VC
   __u32    pgpLane;
   __u32    pgpVc;

   // Data
   __u32   rxSize;  // dwords

   // Error flags
   __u32   eofe;
   __u32   fifoErr;
   __u32   lengthErr;

} PgpCardRx;

// Status Structure
typedef struct {

   // General Status
   __u32 Version;
   __u32 SerialNumber[2];
   __u32 ScratchPad;
   __u32 BuildStamp[64];
   __u32 CountReset;
   __u32 CardReset;

   // PCI Status & Control Registers
   __u32 PciCommand;
   __u32 PciStatus;
   __u32 PciDCommand;
   __u32 PciDStatus;
   __u32 PciLCommand;
   __u32 PciLStatus;
   __u32 PciLinkState;
   __u32 PciFunction;
   __u32 PciDevice;
   __u32 PciBus;
   __u32 PciBaseHdwr;
   __u32 PciBaseLen;   

   // PGP Status
   __u32 PpgRate;
   __u32 PgpLoopBack[8];
   __u32 PgpTxReset[8];
   __u32 PgpRxReset[8];
   __u32 PgpTxPllRst[2];
   __u32 PgpRxPllRst[2];
   __u32 PgpTxPllRdy[2];
   __u32 PgpRxPllRdy[2];   
   __u32 PgpLocLinkReady[8];
   __u32 PgpRemLinkReady[8];
   __u32 PgpRxCount[8][4];
   __u32 PgpCellErrCnt[8];
   __u32 PgpLinkDownCnt[8];
   __u32 PgpLinkErrCnt[8];
   __u32 PgpFifoErrCnt[8];
   
   // EVR Status & Control Registers   
   __u32 EvrRunCode;   
   __u32 EvrAcceptCode;   
   __u32 EvrEnHdrCheck[8][4];   
   __u32 EvrEnable;   
   __u32 EvrReady;   
   __u32 EvrReset;   
   __u32 EvrPllRst;   
   __u32 EvrErrCnt;   

   // RX Descriptor Status
   __u32 RxFreeFull[8];
   __u32 RxFreeValid[8];
   __u32 RxFreeFifoCount[8];
   __u32 RxReadReady;
   __u32 RxRetFifoCount;   
   __u32 RxCount;
   __u32 RxWrite;
   __u32 RxRead;
 
   // TX Descriptor Status
   __u32 TxDmaAFull[8];
   __u32 TxReadReady;
   __u32 TxRetFifoCount;
   __u32 TxCount;
   __u32 TxWrite;
   __u32 TxRead;

} PgpCardStatus;

//////////////////////
// IO Control Commands
//////////////////////

// Normal Write command
#define IOCTL_Normal_Write 0x00

// Read Status, Pass PgpCardStatus as arg
#define IOCTL_Read_Status 0x01

// Reset counters
#define IOCTL_Count_Reset 0x02

// Set Loopback, Pass PGP Channel As Arg
#define IOCTL_Set_Loop 0x10
#define IOCTL_Clr_Loop 0x11

// Set RX Reset, Pass PGP Channel As Arg
#define IOCTL_Set_Rx_Reset 0x12
#define IOCTL_Clr_Rx_Reset 0x13

// Set TX Reset, Pass PGP Channel As Arg
#define IOCTL_Set_Tx_Reset 0x14
#define IOCTL_Clr_Tx_Reset 0x15

// Set EVR configuration
#define IOCTL_Evr_RunCode     0x20
#define IOCTL_Evr_AcceptCode  0x21
#define IOCTL_Evr_Enable      0x22
#define IOCTL_Evr_Disable     0x23
#define IOCTL_Evr_Set_Reset   0x24
#define IOCTL_Evr_Clr_Reset   0x25
#define IOCTL_Evr_Set_PLL_RST 0x26
#define IOCTL_Evr_Clr_PLL_RST 0x27
#define IOCTL_Evr_Mask        0x28

// Set Debug, Pass Debug Value As Arg
#define IOCTL_Set_Debug 0xFE

// Dump debug
#define IOCTL_Dump_Debug 0xFF

#endif
