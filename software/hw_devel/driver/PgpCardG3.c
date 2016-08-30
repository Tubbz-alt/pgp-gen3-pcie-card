//---------------------------------------------------------------------------------
// Title         : Kernel Module For PGP To PCI Bridge Card
// Project       : PGP To PCI-E Bridge Card
//---------------------------------------------------------------------------------
// File          : PgpCardG3.c
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
#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/fs.h>
#include <linux/poll.h>
#include <linux/compat.h>
#include <asm/uaccess.h>
#include <linux/cdev.h>
#include "../include/PgpCardG3Mod.h"
#include "PgpCardG3.h"
#include <linux/types.h>

MODULE_LICENSE("GPL");
MODULE_DEVICE_TABLE(pci, PgpCard_Ids);
module_init(PgpCard_Init);
module_exit(PgpCard_Exit);

// Global Variable
struct PgpDevice gPgpDevices[MAX_PCI_DEVICES];


// Open Returns 0 on success, error code on failure
int PgpCard_Open(struct inode *inode, struct file *filp) {
   struct PgpDevice *pgpDevice;

   // Extract structure for card
   pgpDevice = container_of(inode->i_cdev, struct PgpDevice, cdev);
   filp->private_data = pgpDevice;

   // File is already open
   if ( pgpDevice->isOpen != 0 ) {
      printk(KERN_WARNING"%s: Open: module open failed. Device is already open. Maj=%i\n",MOD_NAME,pgpDevice->major);
      return ERROR;
   } else {
      pgpDevice->isOpen = 1;
      return SUCCESS;
   }
}


// PgpCard_Release
// Called when the device is closed
// Returns 0 on success, error code on failure
int PgpCard_Release(struct inode *inode, struct file *filp) {
   struct PgpDevice *pgpDevice = (struct PgpDevice *)filp->private_data;

   // File is not open
   if ( pgpDevice->isOpen == 0 ) {
      printk(KERN_WARNING"%s: Release: module close failed. Device is not open. Maj=%i\n",MOD_NAME,pgpDevice->major);
      return ERROR;
   } else {
      pgpDevice->isOpen = 0;
      return SUCCESS;
   }
}


// PgpCard_Write
// Called when the device is written to
// Returns write count on success. Error code on failure.
ssize_t PgpCard_Write(struct file *filp, const char* buffer, size_t count, loff_t* f_pos) {
   __u32       descA;
   __u32       descB;
   PgpCardTx*  pgpCardTx;
   PgpCardTx   myPgpCardTx;
   __u32        buf[count / sizeof(__u32)];
   __u32       theRightWriteSize = sizeof(PgpCardTx);
   __u32       largeMemoryModel;

   struct PgpDevice* pgpDevice = (struct PgpDevice *)filp->private_data;

   // Copy command structure from user space
   if ( copy_from_user(buf, buffer, count) ) {
     printk(KERN_WARNING "%s: Write: failed to copy command structure from user(%p) space. Maj=%i\n",
         MOD_NAME,
         buffer,
         pgpDevice->major);
     return ERROR;
   }

   largeMemoryModel = buf[0] == LargeMemoryModel;

   if (!largeMemoryModel) {
     PgpCardTx32* p = (PgpCardTx32*)buf;
     pgpCardTx      = &myPgpCardTx;
     pgpCardTx->cmd     = p->cmd;
     pgpCardTx->pgpLane = p->pgpLane;
     pgpCardTx->pgpVc   = p->pgpVc;
     pgpCardTx->size    = p->size;
     pgpCardTx->data    = (__u32*)(0LL | p->data);
     theRightWriteSize  = sizeof(PgpCardTx32);
//       printk(KERN_WARNING "%s: Write: diddling 32->64 (0x%x)->(0x%p)\n", MOD_NAME, p->data, pgpCardTx->data);
   } else {
     pgpCardTx = (PgpCardTx *)buf;
   }

   switch (pgpCardTx->cmd) {
     case IOCTL_Normal_Write :
       if (count != theRightWriteSize) {
         printk(KERN_WARNING "%s: Write(%u) passed size is not expected(%u) size(%u). Maj=%i\n",
                    MOD_NAME,
                    pgpCardTx->cmd,
                    (unsigned)sizeof(PgpCardTx),
                    (unsigned)count, pgpDevice->major);
       }
       if ( (pgpCardTx->size*4) > pgpDevice->txBuffSize ) {
         printk(KERN_WARNING"%s: Write: passed size is too large for TX buffer. Maj=%i\n",MOD_NAME,pgpDevice->major);
         return(ERROR);
       }

       // No buffers are available
       while ( pgpDevice->txRead == pgpDevice->txWrite ) {
         if ( filp->f_flags & O_NONBLOCK ) return(-EAGAIN);
         if ( pgpDevice->debug > 2 ) printk(KERN_DEBUG"%s: Write: going to sleep. Maj=%i\n",MOD_NAME,pgpDevice->major);
         if (wait_event_interruptible(pgpDevice->outq,(pgpDevice->txRead != pgpDevice->txWrite))) return (-ERESTARTSYS);
         if ( pgpDevice->debug > 2 ) printk(KERN_DEBUG"%s: Write: woke up. Maj=%i\n",MOD_NAME,pgpDevice->major);
       }

       // Copy data from user space
       if ( copy_from_user(pgpDevice->txQueue[pgpDevice->txRead]->buffer,pgpCardTx->data,(pgpCardTx->size*4)) ) {
         printk(KERN_WARNING "%s: Write: failed to copy from user(%p) space. Maj=%i\n",
             MOD_NAME,
             pgpCardTx->data,
             pgpDevice->major);
         return ERROR;
       }

       // Fields for tracking purpose
       pgpDevice->txQueue[pgpDevice->txRead]->lane   = pgpCardTx->pgpLane;
       pgpDevice->txQueue[pgpDevice->txRead]->vc     = pgpCardTx->pgpVc;
       pgpDevice->txQueue[pgpDevice->txRead]->length = pgpCardTx->size;

       // Generate Tx descriptor
       descA  = (pgpCardTx->pgpLane << 27) & 0xF8000000; // Bits 31:27 = Lane
       descA += (pgpCardTx->pgpVc   << 24) & 0x07000000; // Bits 26:24 = VC
       descA += (pgpCardTx->size         ) & 0x00FFFFFF; // Bits 23:00 = Length
       descB = pgpDevice->txQueue[pgpDevice->txRead]->dma;
      
       // Debug
       if ( pgpDevice->debug > 1 ) {
         printk(KERN_DEBUG"%s: Write: Words=%i, Lane=%i, VC=%i, Addr=%p, Map=%p. Maj=%d\n",
             MOD_NAME, pgpCardTx->size, pgpCardTx->pgpLane, pgpCardTx->pgpVc,
             (pgpDevice->txQueue[pgpDevice->txRead]->buffer), (void*)(pgpDevice->txQueue[pgpDevice->txRead]->dma),
             pgpDevice->major);
       }

       // Write descriptor
       if(pgpCardTx->pgpLane < 8) {
         iowrite32(descA,&(pgpDevice->reg->txWrA[pgpCardTx->pgpLane]));
         asm("nop");
         iowrite32(descB,&(pgpDevice->reg->txWrB[pgpCardTx->pgpLane]));
         asm("nop");          
       } else {
         printk(KERN_DEBUG "%s: Write: Invalid pgpCardTx->pgpLane: %i\n", MOD_NAME, pgpCardTx->pgpLane);
       }

       // Increment read pointer
       pgpDevice->txRead = (pgpDevice->txRead + 1) % (pgpDevice->txBuffCnt+2);
       return(pgpCardTx->size);
       break;
     default :
//       printk(KERN_DEBUG "%s: destination 0x%p\n", MOD_NAME, pgpCardTx->data);
       return my_Ioctl(filp, pgpCardTx->cmd, (__u64)pgpCardTx->data);
       break;
   }
}


// PgpCard_Read
// Called when the device is read from
// Returns read count on success. Error code on failure.
ssize_t PgpCard_Read(struct file *filp, char *buffer, size_t count, loff_t *f_pos) {
   int        ret;
   __u32        buf[count / sizeof(__u32)];
   PgpCardRx*    p64 = (PgpCardRx *)buf;
   PgpCardRx32*  p32 = (PgpCardRx32*)buf;
   __u32   __user *     dp;
   __u32       maxSize;
   __u32       copyLength;
   __u32       largeMemoryModel;

   struct PgpDevice *pgpDevice = (struct PgpDevice *)filp->private_data;

   // Copy command structure from user space
   if ( copy_from_user(buf, buffer, count) ) {
     printk(KERN_WARNING "%s: Write: failed to copy command structure from user(%p) space. Maj=%i\n",
         MOD_NAME,
         buffer,
         pgpDevice->major);
     return ERROR;
   }

   largeMemoryModel = buf[0] == LargeMemoryModel;

   // Verify that size of passed structure and get variables from the correct structure.
   if ( !largeMemoryModel ) {
     // small memory model
     if ( count != sizeof(PgpCardRx32) ) {
       printk(KERN_WARNING"%s: Read: passed size is not expected(%u) size(%u). Maj=%i\n",MOD_NAME, (unsigned)sizeof(PgpCardRx32), (unsigned)count, pgpDevice->major);
       return(ERROR);
     } else {
       dp      = (__u32*)(0LL | p32->data);
       maxSize = p32->maxSize;
     }
   } else {
     // large memory model
     if ( count != sizeof(PgpCardRx) ) {
       printk(KERN_WARNING"%s: Read: passed size is not expected(%u) size(%u). Maj=%i\n",MOD_NAME, (unsigned)sizeof(PgpCardRx), (unsigned)count, pgpDevice->major);
       return(ERROR);
     } else {
       dp      = p64->data;
       maxSize = p64->maxSize;
     }
   }

   // No data is ready
   while ( pgpDevice->rxRead == pgpDevice->rxWrite ) {
      if ( filp->f_flags & O_NONBLOCK ) return(-EAGAIN);
      if ( pgpDevice->debug > 2 ) printk(KERN_DEBUG"%s: Read: going to sleep. Maj=%i\n",MOD_NAME,pgpDevice->major);
      if (wait_event_interruptible(pgpDevice->inq,(pgpDevice->rxRead != pgpDevice->rxWrite))) return (-ERESTARTSYS);
      if ( pgpDevice->debug > 2 ) printk(KERN_DEBUG"%s: Read: woke up. Maj=%i\n",MOD_NAME,pgpDevice->major);
   }

   // Report frame error
   if (pgpDevice->rxQueue[pgpDevice->rxRead]->eofe |
       pgpDevice->rxQueue[pgpDevice->rxRead]->fifoError |
       pgpDevice->rxQueue[pgpDevice->rxRead]->lengthError) {
     printk(KERN_WARNING "%s: Read: error encountered  eofe(%u), fifoError(%u), lengthError(%u)\n",
         MOD_NAME,
         pgpDevice->rxQueue[pgpDevice->rxRead]->eofe,
         pgpDevice->rxQueue[pgpDevice->rxRead]->fifoError,
         pgpDevice->rxQueue[pgpDevice->rxRead]->lengthError);
   }

   // User buffer is short
   if ( maxSize < pgpDevice->rxQueue[pgpDevice->rxRead]->length ) {
      printk(KERN_WARNING"%s: Read: user buffer is too small. Rx=%i, User=%i. Maj=%i\n",
         MOD_NAME, pgpDevice->rxQueue[pgpDevice->rxRead]->length, maxSize, pgpDevice->major);
      copyLength = maxSize;
      pgpDevice->rxQueue[pgpDevice->rxRead]->lengthError |= 1;
   }
   else copyLength = pgpDevice->rxQueue[pgpDevice->rxRead]->length;

   // Copy to user
   if ( copy_to_user(dp, pgpDevice->rxQueue[pgpDevice->rxRead]->buffer, copyLength*4) ) {
      printk(KERN_WARNING"%s: Read: failed to copy to user. Maj=%i\n",MOD_NAME,pgpDevice->major);
      ret = ERROR;
   }
   else ret = copyLength;

   // Copy associated data
   if (largeMemoryModel) {
     p64->rxSize    = pgpDevice->rxQueue[pgpDevice->rxRead]->length;
     p64->eofe      = pgpDevice->rxQueue[pgpDevice->rxRead]->eofe;
     p64->fifoErr   = pgpDevice->rxQueue[pgpDevice->rxRead]->fifoError;
     p64->lengthErr = pgpDevice->rxQueue[pgpDevice->rxRead]->lengthError;
     p64->pgpLane   = pgpDevice->rxQueue[pgpDevice->rxRead]->lane;
     p64->pgpVc     = pgpDevice->rxQueue[pgpDevice->rxRead]->vc;
     if ( pgpDevice->debug > 1 ) {
       printk(KERN_DEBUG"%s: Read: Words=%i, Lane=%i, VC=%i, Eofe=%i, FifoErr=%i, LengthErr=%i, Addr=%p, Map=%p, Maj=%i\n",
           MOD_NAME, p64->rxSize, p64->pgpLane, p64->pgpVc, p64->eofe,
           p64->fifoErr, p64->lengthErr, (pgpDevice->rxQueue[pgpDevice->rxRead]->buffer),
           (void*)(pgpDevice->rxQueue[pgpDevice->rxRead]->dma),(unsigned)pgpDevice->major);
     }
   } else {
     p32->rxSize    = pgpDevice->rxQueue[pgpDevice->rxRead]->length;
     p32->eofe      = pgpDevice->rxQueue[pgpDevice->rxRead]->eofe;
     p32->fifoErr   = pgpDevice->rxQueue[pgpDevice->rxRead]->fifoError;
     p32->lengthErr = pgpDevice->rxQueue[pgpDevice->rxRead]->lengthError;
     p32->pgpLane   = pgpDevice->rxQueue[pgpDevice->rxRead]->lane;
     p32->pgpVc     = pgpDevice->rxQueue[pgpDevice->rxRead]->vc;
     if ( pgpDevice->debug > 1 ) {
       printk(KERN_DEBUG"%s: Read: Words=%i, Lane=%i, VC=%i, Eofe=%i, FifoErr=%i, LengthErr=%i, Addr=%p, Map=%p, Maj=%i\n",
           MOD_NAME, p32->rxSize, p32->pgpLane, p32->pgpVc, p32->eofe,
           p32->fifoErr, p32->lengthErr, (pgpDevice->rxQueue[pgpDevice->rxRead]->buffer),
           (void*)(pgpDevice->rxQueue[pgpDevice->rxRead]->dma),(unsigned)pgpDevice->major);
     }
   }

   // Copy command structure to user space
   if ( copy_to_user(buffer, buf, count) ) {
     printk(KERN_WARNING "%s: Write: failed to copy command structure to user(%p) space. Maj=%i\n",
         MOD_NAME,
         buffer,
         pgpDevice->major);
     return ERROR;
   }

   // Return entry to RX queue
   iowrite32(pgpDevice->rxQueue[pgpDevice->rxRead]->dma,&(pgpDevice->reg->rxFree[pgpDevice->rxQueue[pgpDevice->rxRead]->lane]));
   asm("nop");

   if ( pgpDevice->debug > 1 ) printk(KERN_DEBUG"%s: Read: Added buffer %.8x to RX queue. Maj=%i\n",
      MOD_NAME,(__u32)(pgpDevice->rxQueue[pgpDevice->rxRead]->dma),pgpDevice->major);

   // Increment read pointer
   pgpDevice->rxRead = (pgpDevice->rxRead + 1) % (pgpDevice->rxBuffCnt+2);

   return(ret);
}


// PgpCard_Ioctl
// Called when ioctl is called on the device
// Returns success.
int PgpCard_Ioctl(struct inode *inode, struct file *filp, __u32 cmd, unsigned long arg) {
  printk(KERN_WARNING "%s: warning Ioctl is deprecated and no longer supported\n", MOD_NAME);
  return SUCCESS;
}

int my_Ioctl(struct file *filp, __u32 cmd, __u64 argument) {
   PgpCardStatus  status;
   PgpCardStatus *stat = &status;
   __u32          tmp;
   __u32          mask;
   __u32          x, y;
   __u32          found;
   __u32          bcnt;
   __u32          read;
   __u32          arg = argument & 0xffffffffLL;

   struct PgpDevice *pgpDevice = (struct PgpDevice *)filp->private_data;
   if (pgpDevice->debug > 1) printk(KERN_DEBUG "%s: entering my_Ioctl, arg(%llu)\n", MOD_NAME, argument);

   // Determine command
   switch ( cmd ) {

      // Status read
      case IOCTL_Read_Status:
        if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s IOCTL_ReadStatus\n", MOD_NAME);

         // Write scratchpad
         pgpDevice->reg->scratch = SPAD_WRITE;

         // Read Values
         stat->Version = pgpDevice->reg->version;
         stat->ScratchPad = pgpDevice->reg->scratch;
         
         stat->SerialNumber[0] = pgpDevice->reg->serNumUpper;
         stat->SerialNumber[1] = pgpDevice->reg->serNumLower;
         
         for (x=0; x < 64; x++) {
            stat->BuildStamp[x] = pgpDevice->reg->BuildStamp[x];
         }          
         
         stat->CountReset = (pgpDevice->reg->cardRstStat >> 0) & 0x1;
         stat->CardReset  = (pgpDevice->reg->cardRstStat >> 1) & 0x1;
         
         stat->PpgRate = pgpDevice->reg->pgpRate;
         
         tmp = pgpDevice->reg->pciStat[0];
         stat->PciCommand = (tmp >> 16)&0xFFFF;
         stat->PciStatus  = tmp & 0xFFFF;

         tmp = pgpDevice->reg->pciStat[1];
         stat->PciDCommand = (tmp >> 16)&0xFFFF;
         stat->PciDStatus  = tmp & 0xFFFF;

         tmp = pgpDevice->reg->pciStat[2];
         stat->PciLCommand = (tmp >> 16)&0xFFFF;
         stat->PciLStatus  = tmp & 0xFFFF;

         tmp = pgpDevice->reg->pciStat[3];
         stat->PciLinkState = (tmp >> 24)&0x7;
         stat->PciFunction  = (tmp >> 16)&0x3;
         stat->PciDevice    = (tmp >>  8)&0x1F;
         stat->PciBus       = tmp&0xFF;   

         stat->PciBaseHdwr  = pgpDevice->baseHdwr;
         stat->PciBaseLen   = pgpDevice->baseLen;         
         
         tmp = pgpDevice->reg->evrCardStat[0];
         stat->EvrReady  = (tmp >>  4) & 0x1;
         stat->EvrErrCnt = (tmp >>  0) & 0xF;
         
         tmp = pgpDevice->reg->evrCardStat[1];
         stat->EvrPllRst     = (tmp >>  2) & 0x1;
         stat->EvrReset      = (tmp >>  1) & 0x1;
         stat->EvrEnable     = (tmp >>  0) & 0x1;
         
         tmp = pgpDevice->reg->evrCardStat[2];
         for (x=0; x < 8; x++) {
            for (y=0; y < 4; y++) {
               stat->EvrEnHdrCheck[x][y] = (tmp >> ((4*x)+y)) & 0x1;
            }
            stat->EvrRunCode[x]     = pgpDevice->reg->runCode[x] & 0xFF;
            stat->EvrAcceptCode[x]  = pgpDevice->reg->acceptCode[x] & 0xFF;
            stat->EvrRunDelay[x]    = pgpDevice->reg->runDelay[x];
            stat->EvrAcceptDelay[x] = pgpDevice->reg->acceptDelay[x];            
         }
         
         tmp = pgpDevice->reg->pgpCardStat[0];
         for (x=0; x < 8; x++) {
            if ( x<2 ) {
               stat->PgpTxPllRdy[x]  = (tmp >> (x+30)) & 0x1;
               stat->PgpRxPllRdy[x]  = (tmp >> (x+28)) & 0x1;
               stat->PgpTxPllRst[x]  = (tmp >> (x+26)) & 0x1;
               stat->PgpRxPllRst[x]  = (tmp >> (x+24)) & 0x1;
            }
            stat->PgpTxReset[x]  = (tmp >> (x+16)) & 0x1;
            stat->PgpRxReset[x]  = (tmp >> (x+8))  & 0x1;
            stat->PgpLoopBack[x] = (tmp >> (x+0))  & 0x1;
         }             

         tmp = pgpDevice->reg->pgpCardStat[1];
         for (x=0; x < 8; x++) {
            stat->PgpRemLinkReady[x] = (tmp >> (x+8))  & 0x1;
            stat->PgpLocLinkReady[x] = (tmp >> (x+0))  & 0x1;
         }             
         
         for (x=0; x < 8; x++) {   
            tmp = pgpDevice->reg->pgpLaneStat[x];
            stat->PgpLinkErrCnt[x]  = (tmp >> 28) & 0xF;
            stat->PgpLinkDownCnt[x] = (tmp >> 24) & 0xF;
            stat->PgpCellErrCnt[x]  = (tmp >> 20) & 0xF;
            stat->PgpFifoErrCnt[x]  = (tmp >> 16) & 0xF;
            stat->PgpRxCount[x][3]  = (tmp >> 12) & 0xF;
            stat->PgpRxCount[x][2]  = (tmp >> 8)  & 0xF;
            stat->PgpRxCount[x][1]  = (tmp >> 4)  & 0xF;
            stat->PgpRxCount[x][0]  = (tmp >> 0)  & 0xF;
         }

         for (x=0; x < 8; x++) { 
            tmp = pgpDevice->reg->rxFreeStat[x];
            stat->RxFreeFull[x]      = (tmp >> 31) & 0x1;
            stat->RxFreeValid[x]     = (tmp >> 30) & 0x1;
            stat->RxFreeFifoCount[x] = (tmp >> 0)  & 0x3FF;         
         }         
         
         stat->RxCount = pgpDevice->reg->rxCount;
         stat->RxWrite = pgpDevice->rxWrite;
         stat->RxRead  = pgpDevice->rxRead;
         
         tmp = pgpDevice->reg->rxStatus;
         stat->RxReadReady    = (tmp >> 31) & 0x1;
         stat->RxRetFifoCount = (tmp >> 0)  & 0x3FF;         
         
         tmp = pgpDevice->reg->txStat[0];
         for (x=0; x < 8; x++) {
            stat->TxDmaAFull[x] = (tmp >> x) & 0x1;
         }          
         
         tmp = pgpDevice->reg->txStat[1];
         stat->TxReadReady    = (tmp >> 31) & 0x1;
         stat->TxRetFifoCount = (tmp >> 0)  & 0x3FF;

         stat->TxCount = pgpDevice->reg->txCount;
         stat->TxWrite = pgpDevice->txWrite;
         stat->TxRead  = pgpDevice->txRead;
         
         for (x=0; x < 8; x++) {
            stat->TxFifoCnt[x] = pgpDevice->reg->txFifoCnt[x];
         }           

         // Copy to user
         if ((read = copy_to_user((__u32*)argument, stat, sizeof(PgpCardStatus)))) {
            printk(KERN_WARNING "%s: Read Status: failed to copy %u to user. Maj=%i\n",
                MOD_NAME,
                read,
                pgpDevice->major);
            return ERROR;
         }

         return(SUCCESS);
         break;   
         
      // Send PGP OP-Code
      case IOCTL_Pgp_OpCode:
         pgpDevice->reg->pgpOpCode = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Send OP-Code: %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;         
         
      // Count Reset
      case IOCTL_Count_Reset:         
         pgpDevice->reg->cardRstStat |= 0x1;//set the reset counter bit
         pgpDevice->reg->cardRstStat &= 0xFFFFFFFE;//clear the reset counter bit
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Count reset\n", MOD_NAME);
         return(SUCCESS);
         break;         

      // Set Loopback
      case IOCTL_Set_Loop:
         pgpDevice->reg->pgpCardStat[0] |= (0x1 << ((arg&0x7) + 0));         
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set loopback for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;

      // Clr Loopback
      case IOCTL_Clr_Loop:
         mask = 0xFFFFFFFF ^ (0x1 << ((arg&0x7) + 0));  
         pgpDevice->reg->pgpCardStat[0] &= mask;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Clr loopback for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;

      // Set RX reset
      case IOCTL_Set_Rx_Reset:
         pgpDevice->reg->pgpCardStat[0] |= (0x1 << ((arg&0x7) + 8));    
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Rx reset set for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;

      // Clr RX reset
      case IOCTL_Clr_Rx_Reset:
         mask = 0xFFFFFFFF ^ (0x1 << ((arg&0x7) + 8)); 
         pgpDevice->reg->pgpCardStat[0] &= mask;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Rx reset clr for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;

      // Set TX reset
      case IOCTL_Set_Tx_Reset:
         pgpDevice->reg->pgpCardStat[0] |= (0x1 << ((arg&0x7) + 16)); 
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Tx reset set for %u\n", MOD_NAME, arg);
        return(SUCCESS);
         break;

      // Clr TX reset
      case IOCTL_Clr_Tx_Reset:
         mask = 0xFFFFFFFF ^ (0x1 << ((arg&0x7) + 16)); 
         pgpDevice->reg->pgpCardStat[0] &= mask;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Tx reset clr for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;        
         
      // Enable EVR
      case IOCTL_Evr_Enable:
         pgpDevice->reg->evrCardStat[1] |= 0x1;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Enable EVR\n", MOD_NAME);
         return(SUCCESS);
         break;

      // Disable EVR
      case IOCTL_Evr_Disable:
         pgpDevice->reg->evrCardStat[1] &= 0xFFFFFFFE;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Disable EVR\n", MOD_NAME);
         return(SUCCESS);
         break;  

      // Set Reset EVR
      case IOCTL_Evr_Set_Reset:
         pgpDevice->reg->evrCardStat[1] |= 0x2;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set Reset EVR\n", MOD_NAME);
         return(SUCCESS);
         break;

      // Clear Reset EVR
      case IOCTL_Evr_Clr_Reset:
         pgpDevice->reg->evrCardStat[1] &= 0xFFFFFFFD;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Clear Reset EVR\n", MOD_NAME);
         return(SUCCESS);
         break; 

      // Set PLL Reset EVR
      case IOCTL_Evr_Set_PLL_RST:
         pgpDevice->reg->evrCardStat[1] |= 0x4;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set Reset EVR\n", MOD_NAME);
         return(SUCCESS);
         break;

      // Clear PLL Reset EVR
      case IOCTL_Evr_Clr_PLL_RST:
         pgpDevice->reg->evrCardStat[1] &= 0xFFFFFFFB;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Clear Reset EVR\n", MOD_NAME);
         return(SUCCESS);
         break;          

      // Set EVR Virtual channel masking
      case IOCTL_Evr_Mask:
         pgpDevice->reg->evrCardStat[2] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Virtual channel masking for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;      

      // Set EVR's Run Trigger OP-Code[0]
      case IOCTL_Evr_RunCode0:      
         pgpDevice->reg->runCode[0] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Trigger OP-Code[0] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;
         
      // Set EVR's Run Trigger OP-Code[1]
      case IOCTL_Evr_RunCode1:      
         pgpDevice->reg->runCode[1] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Trigger OP-Code[1] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;    

      // Set EVR's Run Trigger OP-Code[2]
      case IOCTL_Evr_RunCode2:      
         pgpDevice->reg->runCode[2] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Trigger OP-Code[2] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;
         
      // Set EVR's Run Trigger OP-Code[3]
      case IOCTL_Evr_RunCode3:      
         pgpDevice->reg->runCode[3] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Trigger OP-Code[3] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;    

      // Set EVR's Run Trigger OP-Code[4]
      case IOCTL_Evr_RunCode4:      
         pgpDevice->reg->runCode[4] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Trigger OP-Code[4] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;
         
      // Set EVR's Run Trigger OP-Code[5]
      case IOCTL_Evr_RunCode5:      
         pgpDevice->reg->runCode[5] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Trigger OP-Code[5] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;    

      // Set EVR's Run Trigger OP-Code[6]
      case IOCTL_Evr_RunCode6:      
         pgpDevice->reg->runCode[6] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Trigger OP-Code[6] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;
         
      // Set EVR's Run Trigger OP-Code[7]
      case IOCTL_Evr_RunCode7:      
         pgpDevice->reg->runCode[7] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Trigger OP-Code[7] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;             
         
      // Set EVR's Accept Trigger OP-Code[0]
      case IOCTL_Evr_AcceptCode0:
         pgpDevice->reg->acceptCode[0] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Trigger OP-Code[0] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;  

      // Set EVR's Accept Trigger OP-Code[1]
      case IOCTL_Evr_AcceptCode1:
         pgpDevice->reg->acceptCode[1] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Trigger OP-Code[1] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;     

      // Set EVR's Accept Trigger OP-Code[2]
      case IOCTL_Evr_AcceptCode2:
         pgpDevice->reg->acceptCode[2] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Trigger OP-Code[2] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;  

      // Set EVR's Accept Trigger OP-Code[3]
      case IOCTL_Evr_AcceptCode3:
         pgpDevice->reg->acceptCode[3] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Trigger OP-Code[3] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;  

      // Set EVR's Accept Trigger OP-Code[4]
      case IOCTL_Evr_AcceptCode4:
         pgpDevice->reg->acceptCode[4] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Trigger OP-Code[4] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;  

      // Set EVR's Accept Trigger OP-Code[5]
      case IOCTL_Evr_AcceptCode5:
         pgpDevice->reg->acceptCode[5] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Trigger OP-Code[5] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;     

      // Set EVR's Accept Trigger OP-Code[6]
      case IOCTL_Evr_AcceptCode6:
         pgpDevice->reg->acceptCode[6] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Trigger OP-Code[6] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;  

      // Set EVR's Accept Trigger OP-Code[7]
      case IOCTL_Evr_AcceptCode7:
         pgpDevice->reg->acceptCode[7] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Trigger OP-Code[7] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;           

      // Set EVR's Run Delay[0]
      case IOCTL_Evr_RunDelay0:      
         pgpDevice->reg->runDelay[0] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Delay[0] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;
         
      // Set EVR's Run Delay[1]
      case IOCTL_Evr_RunDelay1:      
         pgpDevice->reg->runDelay[1] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Delay[1] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;    

      // Set EVR's Run Delay[2]
      case IOCTL_Evr_RunDelay2:      
         pgpDevice->reg->runDelay[2] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Delay[2] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;
         
      // Set EVR's Run Delay[3]
      case IOCTL_Evr_RunDelay3:      
         pgpDevice->reg->runDelay[3] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Delay[3] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;    

      // Set EVR's Run Delay[4]
      case IOCTL_Evr_RunDelay4:      
         pgpDevice->reg->runDelay[4] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Delay[4] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;
         
      // Set EVR's Run Delay[5]
      case IOCTL_Evr_RunDelay5:      
         pgpDevice->reg->runDelay[5] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Delay[5] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;    

      // Set EVR's Run Delay[6]
      case IOCTL_Evr_RunDelay6:      
         pgpDevice->reg->runDelay[6] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Delay[6] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;
         
      // Set EVR's Run Delay[7]
      case IOCTL_Evr_RunDelay7:      
         pgpDevice->reg->runDelay[7] = arg;
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Run Delay[7] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;             
         
      // Set EVR's Accept Delay[0]
      case IOCTL_Evr_AcceptDelay0:
         pgpDevice->reg->acceptDelay[0] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Delay[0] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;  

      // Set EVR's Accept Delay[1]
      case IOCTL_Evr_AcceptDelay1:
         pgpDevice->reg->acceptDelay[1] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Delay[1] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;     

      // Set EVR's Accept Delay[2]
      case IOCTL_Evr_AcceptDelay2:
         pgpDevice->reg->acceptDelay[2] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Delay[2] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;  

      // Set EVR's Accept Delay[3]
      case IOCTL_Evr_AcceptDelay3:
         pgpDevice->reg->acceptDelay[3] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Delay[3] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;  

      // Set EVR's Accept Delay[4]
      case IOCTL_Evr_AcceptDelay4:
         pgpDevice->reg->acceptDelay[4] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Delay[4] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;  

      // Set EVR's Accept Delay[5]
      case IOCTL_Evr_AcceptDelay5:
         pgpDevice->reg->acceptDelay[5] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Delay[5] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;     

      // Set EVR's Accept Delay[6]
      case IOCTL_Evr_AcceptDelay6:
         pgpDevice->reg->acceptDelay[6] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Delay[6] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;  

      // Set EVR's Accept Delay[7]
      case IOCTL_Evr_AcceptDelay7:
         pgpDevice->reg->acceptDelay[7] = arg;  
         if (pgpDevice->debug > 0) printk(KERN_DEBUG "%s: Set EVR Accept Delay[7] for %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;           
         
      // No Operation
      case IOCTL_NOP:
         asm("nop");//no operation function
         printk(KERN_WARNING "%s: NOP to %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;          
         
      // Set Debug
      case IOCTL_Set_Debug:
         pgpDevice->debug = arg;
         printk(KERN_WARNING "%s: debug set to %u\n", MOD_NAME, arg);
         return(SUCCESS);
         break;         

      // Dump Debug
      case IOCTL_Dump_Debug:

        if (pgpDevice->debug > 0) {
          printk(KERN_DEBUG "%s IOCTL_Dump_Debug\n", MOD_NAME);

          // Rx Buffers
          if ( pgpDevice->rxRead > pgpDevice->rxWrite )
            bcnt = (__u32)((int)(pgpDevice->rxWrite - pgpDevice->rxRead) + pgpDevice->rxBuffCnt + 2);
          else bcnt = (pgpDevice->rxWrite - pgpDevice->rxRead);
          printk(KERN_DEBUG"%s: Ioctl: Rx Queue contains %i out of %i buffers. Maj=%i.\n",MOD_NAME,bcnt,pgpDevice->rxBuffCnt,pgpDevice->major);

         // Rx Fifo 
         bcnt = 0;
         for (x=0; x < 8; x++) { 
            // Get the register
            tmp = pgpDevice->reg->rxFreeStat[x];
            // Check for FWFT valid
            if( ((tmp >> 30) & 0x1) == 0x1) bcnt++;
            // Check the FIFO fill count
            bcnt += ((tmp >> 0) & 0x3FF);       
         }           
         printk(KERN_DEBUG"%s: Ioctl: Rx Fifo contains %i out of %i buffers. Maj=%i.\n",MOD_NAME,bcnt,pgpDevice->rxBuffCnt,pgpDevice->major);

          // Tx Buffers
          if ( pgpDevice->txRead > pgpDevice->txWrite )
            bcnt = (__u32)((int)(pgpDevice->txWrite - pgpDevice->txRead) + pgpDevice->txBuffCnt + 2);
          else bcnt = (pgpDevice->txWrite - pgpDevice->txRead);
          printk(KERN_DEBUG"%s: Ioctl: Tx Queue contains %i out of %i buffers. Maj=%i.\n",MOD_NAME,bcnt,pgpDevice->txBuffCnt,pgpDevice->major);

          // Attempt to find missing tx buffers
          for (x=0; x < pgpDevice->txBuffCnt; x++) {
            found = 0;
            read  = pgpDevice->txRead;
            for (y=0; y < bcnt && read != pgpDevice->txWrite; y++) {
              if ( pgpDevice->txQueue[read] == pgpDevice->txBuffer[x] ) {
                found = 1;
                break;
              }
              read = (read+1)%(pgpDevice->txBuffCnt+2);
            }
            if ( ! found ) 
              printk(KERN_DEBUG"%s: Ioctl: Tx Buffer %p is missing! Lane=%i, Vc=%i, Length=%i, Maj=%i\n",MOD_NAME,
                  pgpDevice->txBuffer[x]->buffer, pgpDevice->txBuffer[x]->lane, pgpDevice->txBuffer[x]->vc,
                  pgpDevice->txBuffer[x]->length, pgpDevice->major);
            else
              printk(KERN_DEBUG"%s: Ioctl: Tx Buffer %p found. Maj=%i\n",MOD_NAME,pgpDevice->txBuffer[x]->buffer,pgpDevice->major);
          }

          // Queue dump
          read  = pgpDevice->txRead;
          for (y=0; y < bcnt && read != pgpDevice->txWrite; y++) {
            printk(KERN_DEBUG"%s: Ioctl: Tx Queue Entry %p. Maj=%i\n",MOD_NAME, pgpDevice->txQueue[y]->buffer,pgpDevice->major);
            read = (read+1)%(pgpDevice->txBuffCnt+2);
          }
        } else {
          printk(KERN_WARNING "%s: attempt to dump debug with debug level of zero\n", MOD_NAME);
        }
        return(SUCCESS);
         break;

      default:
         return(ERROR);
         break;
   }
}

// IRQ Handler
static irqreturn_t PgpCard_IRQHandler(int irq, void *dev_id, struct pt_regs *regs) {
   __u32        stat;
   __u32        descA;
   __u32        descB;
   __u32        idx;
   __u32        next;
   irqreturn_t ret;

   struct PgpDevice *pgpDevice = (struct PgpDevice *)dev_id;

   // Read IRQ Status
   stat = ioread32(&(pgpDevice->reg->irq));
   asm("nop");   

   // Is this the source
   if ( (stat & 0x2) != 0 ) {

      if ( pgpDevice->debug > 0 ) printk(KERN_DEBUG"%s: Irq: IRQ Called. Maj=%i\n", MOD_NAME,pgpDevice->major);

      // Disable interrupts
      iowrite32(0,&(pgpDevice->reg->irq));
      asm("nop");

      // Read Tx completion status
      stat = ioread32(&(pgpDevice->reg->txStat[1]));
      asm("nop");       

      // Tx Data is ready
      if ( (stat & 0x80000000) != 0 ) {

         do {

            // Read dma value
            stat = ioread32(&(pgpDevice->reg->txRead));
            asm("nop");            
            
            if( (stat & 0x1) == 0x1 ) {

               if ( pgpDevice->debug > 0 ) printk(KERN_DEBUG"%s: Irq: Return TX Status Value %.8x. Maj=%i\n",MOD_NAME,stat,pgpDevice->major);
            
               // Find TX buffer entry
               for ( idx=0; idx < pgpDevice->txBuffCnt; idx++ ) {
                  if ( pgpDevice->txBuffer[idx]->dma == (stat & 0xFFFFFFFC) ) break;
               }

               // Entry was found
               if ( idx < pgpDevice->txBuffCnt ) {

                  // Return to queue
                  next = (pgpDevice->txWrite+1) % (pgpDevice->txBuffCnt+2);
                  if ( next == pgpDevice->txRead ) printk(KERN_WARNING"%s: Irq: Tx queue pointer collision. Maj=%i\n",MOD_NAME,pgpDevice->major);
                  pgpDevice->txQueue[pgpDevice->txWrite] = pgpDevice->txBuffer[idx];
                  //printk(KERN_WARNING"%s: Irq: pgpDevice->txWrite = next=%i\n",MOD_NAME,next);
                  pgpDevice->txWrite = next;

                  // Wake up any writers
                  wake_up_interruptible(&(pgpDevice->outq));
               }
               else printk(KERN_WARNING"%s: Irq: Failed to locate TX descriptor %.8x. Maj=%i\n",MOD_NAME,(__u32)(stat&0xFFFFFFFC),pgpDevice->major);
            }
            
         // Repeat while next valid flag is set
         } while ( (stat & 0x1) == 0x1 );
      }

      // Read Rx completion status
      stat = ioread32(&(pgpDevice->reg->rxStatus));
      asm("nop");

      // Data is ready
      if ( (stat & 0x80000000) != 0 ) {

         do {
            
            // Read descriptor
            descA = ioread32(&(pgpDevice->reg->rxRead[0]));
            asm("nop");
            descB = ioread32(&(pgpDevice->reg->rxRead[1]));
            asm("nop");
            
            if( (descB & 0x1) == 0x1 ) {            
            
               // Find RX buffer entry
               for ( idx=0; idx < pgpDevice->rxBuffCnt; idx++ ) {
                  if ( pgpDevice->rxBuffer[idx]->dma == (descB & 0xFFFFFFFC) ) break;
               }

               // Entry was found
               if ( idx < pgpDevice->rxBuffCnt ) {

                  // Drop data if device is not open
                  if ( pgpDevice->isOpen ) {

                     // Setup descriptor
                     pgpDevice->rxBuffer[idx]->fifoError   = (descA & 0x80000000) >> 31;// Bits 31    = fifoError
                     pgpDevice->rxBuffer[idx]->eofe        = (descA & 0x40000000) >> 30;// Bits 30    = EOFE
                     pgpDevice->rxBuffer[idx]->lane        = (descA & 0x1C000000) >> 26;// Bits 28:26 = Lane
                     pgpDevice->rxBuffer[idx]->vc          = (descA & 0x03000000) >> 24;// Bits 25:24 = VC
                     pgpDevice->rxBuffer[idx]->length      = (descA & 0x00FFFFFF) >> 0; // Bits 23:00 = Length
                     pgpDevice->rxBuffer[idx]->lengthError = (descB & 0x00000002) >> 1; // Legacy Unused bit
                     
                     if ( pgpDevice->debug > 0 ) {
                        printk(KERN_DEBUG "%s: Irq: Rx Words=%i, Lane=%i, VC=%i, Eofe=%i, FifoErr=%i, LengthErr=%i, Addr=%p, Map=%p\n",
                           MOD_NAME, pgpDevice->rxBuffer[idx]->length, pgpDevice->rxBuffer[idx]->lane, pgpDevice->rxBuffer[idx]->vc, 
                           pgpDevice->rxBuffer[idx]->eofe, pgpDevice->rxBuffer[idx]->fifoError, pgpDevice->rxBuffer[idx]->lengthError, 
                           (pgpDevice->rxBuffer[idx]->buffer), (void*)(pgpDevice->rxBuffer[idx]->dma));
                     }

                     // Return to Queue
                     next = (pgpDevice->rxWrite+1) % (pgpDevice->rxBuffCnt+2);
                     if ( next == pgpDevice->rxRead ) printk(KERN_WARNING"%s: Irq: Rx queue pointer collision. Maj=%i\n",MOD_NAME,pgpDevice->major);
                     pgpDevice->rxQueue[pgpDevice->rxWrite] = pgpDevice->rxBuffer[idx];
                     pgpDevice->rxWrite = next;

                     // Wake up any readers
                     wake_up_interruptible(&(pgpDevice->inq));
                  }
                  
                  // Return entry to FPGA if device is not open
                  else {
                     iowrite32((descB & 0xFFFFFFFC), &(pgpDevice->reg->rxFree[(descA >> 26) & 0x7]));
                     asm("nop");
                  }

               } else printk(KERN_WARNING "%s: Irq: Failed to locate RX descriptor %.8x. Maj=%i\n",MOD_NAME,(__u32)(descA&0xFFFFFFFC),pgpDevice->major);
            }
         // Repeat while next valid flag is set
         } while ( (descB & 0x1) == 0x1 );
      }

      // Enable interrupts
      if ( pgpDevice->debug > 0 ) printk(KERN_DEBUG"%s: Irq: Done. Maj=%i\n", MOD_NAME,pgpDevice->major);
      iowrite32(1,&(pgpDevice->reg->irq));
      asm("nop");      
      ret = IRQ_HANDLED;
   }
   else ret = IRQ_NONE;
   return(ret);
}

// Poll/Select
static __u32 PgpCard_Poll(struct file *filp, poll_table *wait ) {
   __u32 mask    = 0;
   __u32 readOk  = 0;
   __u32 writeOk = 0;

   struct PgpDevice *pgpDevice = (struct PgpDevice *)filp->private_data;

   poll_wait(filp,&(pgpDevice->inq),wait);
   poll_wait(filp,&(pgpDevice->outq),wait);

   if ( pgpDevice->rxWrite != pgpDevice->rxRead ) {
      mask |= POLLIN | POLLRDNORM; // Readable
      readOk = 1;
   }
   if ( pgpDevice->txWrite != pgpDevice->txRead ) {
      mask |= POLLOUT | POLLWRNORM; // Writable
      writeOk = 1;
   }

   //if ( pgpDevice->debug > 3 ) printk(KERN_DEBUG"%s: Poll: ReadOk=%i, WriteOk=%i Maj=%i\n", MOD_NAME,readOk,writeOk,pgpDevice->major);
   return(mask);
}

// Probe device
static int PgpCard_Probe(struct pci_dev *pcidev, const struct pci_device_id *dev_id) {
   int i, res, idx;
   dev_t chrdev = 0;
   struct PgpDevice *pgpDevice;
   struct pci_device_id *id = (struct pci_device_id *) dev_id;

   // We keep device instance number in id->driver_data
   id->driver_data = -1;

   // Find empty structure
   for (i = 0; i < MAX_PCI_DEVICES; i++) {
      if (gPgpDevices[i].baseHdwr == 0) {
         id->driver_data = i;
         break;
      }
   }

   // Overflow
   if (id->driver_data < 0) {
      printk(KERN_WARNING "%s: Probe: Too Many Devices.\n", MOD_NAME);
      return -EMFILE;
   }
   pgpDevice = &gPgpDevices[id->driver_data];

   // Allocate device numbers for character device.
   res = alloc_chrdev_region(&chrdev, 0, 1, MOD_NAME);
   if (res < 0) {
      printk(KERN_WARNING "%s: Probe: Cannot register char device\n", MOD_NAME);
      return res;
   }

   // Init device
   cdev_init(&pgpDevice->cdev, &PgpCard_Intf);

   // Initialize device structure
   pgpDevice->major         = MAJOR(chrdev);
   pgpDevice->cdev.owner    = THIS_MODULE;
   pgpDevice->cdev.ops      = &PgpCard_Intf;
   pgpDevice->debug         = 0;
   pgpDevice->isOpen        = 0;

   // Add device
   if ( cdev_add(&pgpDevice->cdev, chrdev, 1) ) 
      printk(KERN_WARNING "%s: Probe: Error adding device Maj=%i\n", MOD_NAME,pgpDevice->major);

   // Enable devices
   pci_enable_device(pcidev);

   // Get Base Address of registers from pci structure.
   pgpDevice->baseHdwr = pci_resource_start (pcidev, 0);
   pgpDevice->baseLen  = pci_resource_len (pcidev, 0);

   // Remap the I/O register block so that it can be safely accessed.
   pgpDevice->reg = (struct PgpCardReg *)ioremap_nocache(pgpDevice->baseHdwr, pgpDevice->baseLen);
   if (! pgpDevice->reg ) {
      printk(KERN_WARNING"%s: Init: Could not remap memory Maj=%i.\n", MOD_NAME,pgpDevice->major);
      return (ERROR);
   }

   // Try to gain exclusive control of memory
   if (check_mem_region(pgpDevice->baseHdwr, pgpDevice->baseLen) < 0 ) {
      printk(KERN_WARNING"%s: Init: Memory in use Maj=%i.\n", MOD_NAME,pgpDevice->major);
      return (ERROR);
   }

   // Remove card reset, bit 1 of cardRstStat register
   pgpDevice->reg->cardRstStat &= 0xFFFFFFFD;

   request_mem_region(pgpDevice->baseHdwr, pgpDevice->baseLen, MOD_NAME);
   printk(KERN_INFO "%s: Probe: Found card. Version=0x%x, Maj=%i\n", MOD_NAME,pgpDevice->reg->version,pgpDevice->major);

   // Get IRQ from pci_dev structure. 
   pgpDevice->irq = pcidev->irq;
   printk(KERN_INFO "%s: Init: IRQ %d Maj=%i\n", MOD_NAME, pgpDevice->irq,pgpDevice->major);

   // Request IRQ from OS.
   if (request_irq(
       pgpDevice->irq,
       PgpCard_IRQHandler,
       IRQF_SHARED,
       MOD_NAME,
       (void*)pgpDevice) < 0 ) {
      printk(KERN_WARNING"%s: Init: Unable to allocate IRQ. Maj=%i",MOD_NAME,pgpDevice->major);
      return (ERROR);
   }

   // Init TX Buffers
   pgpDevice->txBuffSize = DEF_TX_BUF_SIZE;
   pgpDevice->txBuffCnt  = DEF_TX_BUF_CNT;
   pgpDevice->txBuffer   = (struct TxBuffer **)kmalloc(pgpDevice->txBuffCnt * sizeof(struct TxBuffer *),GFP_KERNEL);
   pgpDevice->txQueue    = (struct TxBuffer **)kmalloc((pgpDevice->txBuffCnt+2) * sizeof(struct TxBuffer *),GFP_KERNEL);

   for ( idx=0; idx < pgpDevice->txBuffCnt; idx++ ) {
      pgpDevice->txBuffer[idx] = (struct TxBuffer *)kmalloc(sizeof(struct TxBuffer ),GFP_KERNEL);
      if ((pgpDevice->txBuffer[idx]->buffer = pci_alloc_consistent(pcidev,pgpDevice->txBuffSize,&(pgpDevice->txBuffer[idx]->dma))) == NULL ) {
         printk(KERN_WARNING"%s: Init: unable to allocate tx buffer. Maj=%i\n",MOD_NAME,pgpDevice->major);
         return ERROR;
      }
      pgpDevice->txQueue[idx] = pgpDevice->txBuffer[idx];
   }
   pgpDevice->txWrite = pgpDevice->txBuffCnt;
   pgpDevice->txRead  = 0;

   // Set max frame size, clear rx buffer reset
   pgpDevice->rxBuffSize = DEF_RX_BUF_SIZE;
   pgpDevice->reg->rxMaxFrame = pgpDevice->rxBuffSize | 0x80000000;

   // Init RX Buffers
   pgpDevice->rxBuffCnt  = DEF_RX_BUF_CNT;
   pgpDevice->rxBuffer   = (struct RxBuffer **)kmalloc(pgpDevice->rxBuffCnt * sizeof(struct RxBuffer *),GFP_KERNEL);
   pgpDevice->rxQueue    = (struct RxBuffer **)kmalloc((pgpDevice->rxBuffCnt+2) * sizeof(struct RxBuffer *),GFP_KERNEL);

   for ( idx=0; idx < pgpDevice->rxBuffCnt; idx++ ) {
      pgpDevice->rxBuffer[idx] = (struct RxBuffer *)kmalloc(sizeof(struct RxBuffer ),GFP_KERNEL);
      if ((pgpDevice->rxBuffer[idx]->buffer = pci_alloc_consistent(pcidev,pgpDevice->rxBuffSize,&(pgpDevice->rxBuffer[idx]->dma))) == NULL ) {
         printk(KERN_WARNING"%s: Init: unable to allocate tx buffer. Maj=%i\n",MOD_NAME,pgpDevice->major);
         return ERROR;
      };

      // Add to RX queue (evenly distributed to all free list RX FIFOs)
      iowrite32(pgpDevice->rxBuffer[idx]->dma,&(pgpDevice->reg->rxFree[idx % 8]));
      asm("nop");
   }
   pgpDevice->rxRead  = 0;
   pgpDevice->rxWrite = 0;

   // Init queues
   init_waitqueue_head(&pgpDevice->inq);
   init_waitqueue_head(&pgpDevice->outq);

   // Enable interrupts
   iowrite32(1,&(pgpDevice->reg->irq));
   asm("nop");

   printk(KERN_INFO"%s: Init: Driver is loaded. Maj=%i\n", MOD_NAME,pgpDevice->major);
   return SUCCESS;
}

// Remove
static void PgpCard_Remove(struct pci_dev *pcidev) {
   __u32 idx;
   int  i;
   struct PgpDevice *pgpDevice = NULL;

   // Look for matching device
   for (i = 0; i < MAX_PCI_DEVICES; i++) {
      if ( gPgpDevices[i].baseHdwr == pci_resource_start(pcidev, 0)) {
         pgpDevice = &gPgpDevices[i];
         break;
      }
   }

   // Device not found
   if (pgpDevice == NULL) {
      printk(KERN_WARNING "%s: Remove: Device Not Found.\n", MOD_NAME);
   }
   else {

      // Disable interrupts
      pgpDevice->reg->irq = 0;

      // Clear RX buffer
      pgpDevice->reg->rxMaxFrame = 0;

      // Free TX Buffers
      for ( idx=0; idx < pgpDevice->txBuffCnt; idx++ ) {
         pci_free_consistent(pcidev,pgpDevice->txBuffSize,pgpDevice->txBuffer[idx]->buffer,pgpDevice->txBuffer[idx]->dma);
         kfree(pgpDevice->txBuffer[idx]);
      }
      kfree(pgpDevice->txBuffer);
      kfree(pgpDevice->txQueue);

      // Free RX Buffers
      for ( idx=0; idx < pgpDevice->rxBuffCnt; idx++ ) {
         pci_free_consistent(pcidev,pgpDevice->rxBuffSize,pgpDevice->rxBuffer[idx]->buffer,pgpDevice->rxBuffer[idx]->dma);
         kfree(pgpDevice->rxBuffer[idx]);
      }
      kfree(pgpDevice->rxBuffer);
      kfree(pgpDevice->rxQueue);

      // Set card reset, bit 1 of cardRstStat register
      pgpDevice->reg->cardRstStat |= 0x00000002;

      // Release memory region
      release_mem_region(pgpDevice->baseHdwr, pgpDevice->baseLen);

      // Release IRQ
      free_irq(pgpDevice->irq, pgpDevice);

      // Unmap
      iounmap(pgpDevice->reg);

      // Unregister Device Driver
      cdev_del(&pgpDevice->cdev);
      unregister_chrdev_region(MKDEV(pgpDevice->major,0), 1);

      // Disable device
      pci_disable_device(pcidev);
      pgpDevice->baseHdwr = 0;
      printk(KERN_INFO"%s: Remove: Driver is unloaded. Maj=%i\n", MOD_NAME,pgpDevice->major);
   }
}

// Init Kernel Module
static int PgpCard_Init(void) {

   /* Allocate and clear memory for all devices. */
   memset(gPgpDevices, 0, sizeof(struct PgpDevice)*MAX_PCI_DEVICES);

   printk(KERN_INFO"%s: Init: PgpCard Init.\n", MOD_NAME);

   // Register driver
   return(pci_register_driver(&PgpCardDriver));
}


// Exit Kernel Module
static void PgpCard_Exit(void) {
   printk(KERN_INFO"%s: Exit: PgpCard Exit.\n", MOD_NAME);
   pci_unregister_driver(&PgpCardDriver);
}


// Memory map
int PgpCard_Mmap(struct file *filp, struct vm_area_struct *vma) {

   struct PgpDevice *pgpDevice = (struct PgpDevice *)filp->private_data;

   unsigned long offset = vma->vm_pgoff << PAGE_SHIFT;
   unsigned long physical = ((unsigned long) pgpDevice->baseHdwr) + offset;
   unsigned long vsize = vma->vm_end - vma->vm_start;
   int result;

   // Check bounds of memory map
   if (vsize > pgpDevice->baseLen) {
      printk(KERN_WARNING"%s: Mmap: mmap vsize %08x, baseLen %08x. Maj=%i\n", MOD_NAME,
         (unsigned int) vsize, (unsigned int) pgpDevice->baseLen,pgpDevice->major);
      return -EINVAL;
   }

   result = io_remap_pfn_range(vma, vma->vm_start, physical >> PAGE_SHIFT,
            vsize, vma->vm_page_prot);
//   result = io_remap_page_range(vma, vma->vm_start, physical, vsize, 
//            vma->vm_page_prot);

   if (result) return -EAGAIN;
  
   vma->vm_ops = &PgpCard_VmOps;
   PgpCard_VmOpen(vma);
   return 0;  
}


void PgpCard_VmOpen(struct vm_area_struct *vma) { }


void PgpCard_VmClose(struct vm_area_struct *vma) { }


// Flush queue
int PgpCard_Fasync(int fd, struct file *filp, int mode) {
   struct PgpDevice *pgpDevice = (struct PgpDevice *)filp->private_data;
   return fasync_helper(fd, filp, mode, &(pgpDevice->async_queue));
}
