//---------------------------------------------------------------------------------
// Title         : Kernel Module For PGP To PCI Bridge Card
// Project       : PGP To PCI-E Bridge Card
//---------------------------------------------------------------------------------
// File          : PgpCardG3.h
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
#include <linux/cdev.h>
#include <asm/uaccess.h>
#include <linux/types.h>

// DMA Buffer Size, Bytes
#define DEF_RX_BUF_SIZE 2097152//0x200000
#define DEF_TX_BUF_SIZE 2097152//0x200000

// Number of RX & TX Buffers
#define DEF_RX_BUF_CNT 32
#define DEF_TX_BUF_CNT 32

// PCI IDs
#define PCI_VENDOR_ID_SLAC           0x1A4A
#define PCI_DEVICE_ID_SLAC_PGPCARD   0x2020

// Max number of devices to support
#define MAX_PCI_DEVICES 8

// Module Name
#define MOD_NAME "PgpCardG3"

enum MODELS {SmallMemoryModel=4, LargeMemoryModel=8};

// Structure for TX buffers
struct TxBuffer {
   dma_addr_t dma;
   unchar*     buffer;
   __u32       lane;
   __u32       vc;
   __u32       length;
};

// Structure for RX buffers
struct RxBuffer {
   dma_addr_t dma;
   unchar*     buffer;
   __u32       lengthError;
   __u32       fifoError;
   __u32       eofe;
   __u32       lane;
   __u32       vc;
   __u32       length;
};

// Device structure
struct PgpDevice {

   // PCI address regions
   ulong             baseHdwr;
   ulong             baseLen;
   struct PgpCardReg *reg;

   // Device structure
   int         major;
   struct cdev cdev;
   
   // Async queue
   struct fasync_struct *async_queue;     

   // Device is already open
   __u32 isOpen;

   // Debug flag
   __u32 debug;

   // IRQ
   int irq;

   // RX/TX Buffer Structures
   __u32            rxBuffCnt;
   __u32            rxBuffSize;
   struct RxBuffer **rxBuffer;
   __u32            txBuffCnt;
   __u32            txBuffSize;
   struct TxBuffer **txBuffer;

   // Top pointer for rx queue, 2 entries larger than rxBuffCnt
   struct RxBuffer **rxQueue;
   __u32            rxRead;
   __u32            rxWrite;

   // Top pointer for tx queue, 2 entries larger than txBuffCnt
   struct TxBuffer **txQueue;
   __u32            txRead;
   __u32            txWrite;

   // Queues
   wait_queue_head_t inq;
   wait_queue_head_t outq;
};

// TX32 Structure
typedef struct {
    // Data
    __u32 model; // large=8, small=4
    __u32 cmd; // ioctl commands
    __u32 data;

    // Lane & VC
   __u32 pgpLane;
   __u32 pgpVc;

   __u32   size;  // dwords

} PgpCardTx32;

// RX32 Structure
typedef struct {
    __u32   model; // large=8, small=4
    __u32   maxSize; // dwords
    __u32   data;

   // Lane & VC
   __u32    pgpLane;
   __u32    pgpVc;

   // Data
   __u32    rxSize;  // dwords

   // Error flags
   __u32   eofe;
   __u32   fifoErr;
   __u32   lengthErr;

} PgpCardRx32;

// Function prototypes
int PgpCard_Open(struct inode *inode, struct file *filp);
int PgpCard_Release(struct inode *inode, struct file *filp);
ssize_t PgpCard_Write(struct file *filp, const char *buf, size_t count, loff_t *f_pos);
ssize_t PgpCard_Read(struct file *filp, char *buf, size_t count, loff_t *f_pos);
int PgpCard_Ioctl(struct inode *inode, struct file *filp, unsigned int cmd, unsigned long arg);
int my_Ioctl(struct file *filp, __u32 cmd, __u64 argument);
static irqreturn_t PgpCard_IRQHandler(int irq, void *dev_id, struct pt_regs *regs);
static unsigned int PgpCard_Poll(struct file *filp, poll_table *wait );
static int PgpCard_Probe(struct pci_dev *pcidev, const struct pci_device_id *dev_id);
static void PgpCard_Remove(struct pci_dev *pcidev);
static int PgpCard_Init(void);
static void PgpCard_Exit(void);
int PgpCard_Mmap(struct file *filp, struct vm_area_struct *vma);
int PgpCard_Fasync(int fd, struct file *filp, int mode);
void PgpCard_VmOpen(struct vm_area_struct *vma);
void PgpCard_VmClose(struct vm_area_struct *vma);

// PCI device IDs
static struct pci_device_id PgpCard_Ids[] = {
   { PCI_DEVICE(PCI_VENDOR_ID_SLAC,   PCI_DEVICE_ID_SLAC_PGPCARD)   },
   { 0, }
};

// PCI driver structure
static struct pci_driver PgpCardDriver = {
  .name     = MOD_NAME,
  .id_table = PgpCard_Ids,
  .probe    = PgpCard_Probe,
  .remove   = PgpCard_Remove,
};

// Define interface routines
struct file_operations PgpCard_Intf = {
   read:    PgpCard_Read,
   write:   PgpCard_Write,
   ioctl:   PgpCard_Ioctl,
   open:    PgpCard_Open,
   release: PgpCard_Release,
   poll:    PgpCard_Poll,
   fasync:  PgpCard_Fasync,
   mmap:    PgpCard_Mmap,      
};

// Virtual memory operations
static struct vm_operations_struct PgpCard_VmOps = {
  open:  PgpCard_VmOpen,
  close: PgpCard_VmClose,
};
