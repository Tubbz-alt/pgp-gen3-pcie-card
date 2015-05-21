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

// Address Map, offset from base
struct PgpCardReg {
   //PciApp.vhd  
   __u32 version;       // Software_Addr = 0x000,        Firmware_Addr(13 downto 2) = 0x000
   __u32 serNumLower;   // Software_Addr = 0x004,        Firmware_Addr(13 downto 2) = 0x001
   __u32 serNumUpper;   // Software_Addr = 0x008,        Firmware_Addr(13 downto 2) = 0x002
   __u32 scratch;       // Software_Addr = 0x00C,        Firmware_Addr(13 downto 2) = 0x003
   __u32 cardRstStat;   // Software_Addr = 0x010,        Firmware_Addr(13 downto 2) = 0x004
   __u32 irq;           // Software_Addr = 0x014,        Firmware_Addr(13 downto 2) = 0x005 
   __u32 pgpRate;       // Software_Addr = 0x018,        Firmware_Addr(13 downto 2) = 0x006
   __u32 reboot;        // Software_Addr = 0x01C,        Firmware_Addr(13 downto 2) = 0x007
   __u32 pgpOpCode;     // Software_Addr = 0x020,        Firmware_Addr(13 downto 2) = 0x008
   __u32 sysSpare0[2];  // Software_Addr = 0x028:0x024,  Firmware_Addr(13 downto 2) = 0x00A:0x009
   __u32 pciStat[4];    // Software_Addr = 0x038:0x02C,  Firmware_Addr(13 downto 2) = 0x00E:0x00B
   __u32 sysSpare1;     // Software_Addr = 0x03C,        Firmware_Addr(13 downto 2) = 0x00F 
   
   __u32 evrCardStat[3];// Software_Addr = 0x048:0x040,  Firmware_Addr(13 downto 2) = 0x012:0x010  
   __u32 evrSpare0[13]; // Software_Addr = 0x07C:0x04C,  Firmware_Addr(13 downto 2) = 0x01F:0x013
   
   __u32 pgpCardStat[2];// Software_Addr = 0x084:0x080,  Firmware_Addr(13 downto 2) = 0x021:0x020       
   __u32 pgpSpare0[62]; // Software_Addr = 0x17C:0x088,  Firmware_Addr(13 downto 2) = 0x05F:0x022
   
   __u32 runCode[8];   // Software_Addr = 0x19C:0x180,  Firmware_Addr(13 downto 2) = 0x067:0x060       
   __u32 acceptCode[8];// Software_Addr = 0x1BC:0x1A0,  Firmware_Addr(13 downto 2) = 0x06F:0x068         
      
   __u32 runDelay[8];   // Software_Addr = 0x1DC:0x1C0,  Firmware_Addr(13 downto 2) = 0x077:0x070       
   __u32 acceptDelay[8];// Software_Addr = 0x1FC:0x1E0,  Firmware_Addr(13 downto 2) = 0x07F:0x078       

   __u32 pgpLaneStat[8];// Software_Addr = 0x21C:0x200,  Firmware_Addr(13 downto 2) = 0x087:0x080       
   __u32 pgpSpare1[56]; // Software_Addr = 0x2FC:0x220,  Firmware_Addr(13 downto 2) = 0x0BF:0x088
   __u32 BuildStamp[64];// Software_Addr = 0x3FC:0x300,  Firmware_Addr(13 downto 2) = 0x0FF:0x0C0
   
   //PciRxDesc.vhd   
   __u32 rxFree[8];     // Software_Addr = 0x41C:0x400,  Firmware_Addr(13 downto 2) = 0x107:0x100   
   __u32 rxSpare0[24];  // Software_Addr = 0x47C:0x420,  Firmware_Addr(13 downto 2) = 0x11F:0x108
   __u32 rxFreeStat[8]; // Software_Addr = 0x49C:0x480,  Firmware_Addr(13 downto 2) = 0x127:0x120      
   __u32 rxSpare1[24];  // Software_Addr = 0x4FC:0x4A0,  Firmware_Addr(13 downto 2) = 0x13F:0x128
   __u32 rxMaxFrame;    // Software_Addr = 0x500,        Firmware_Addr(13 downto 2) = 0x140 
   __u32 rxCount;       // Software_Addr = 0x504,        Firmware_Addr(13 downto 2) = 0x141 
   __u32 rxStatus;      // Software_Addr = 0x508,        Firmware_Addr(13 downto 2) = 0x142
   __u32 rxRead[2];     // Software_Addr = 0x510:0x50C,  Firmware_Addr(13 downto 2) = 0x144:0x143      
   __u32 rxSpare2[187]; // Software_Addr = 0x77C:0x514,  Firmware_Addr(13 downto 2) = 0x1FF:0x145
   
   //PciTxDesc.vhd
   __u32 txWrA[8];      // Software_Addr = 0x81C:0x800,  Firmware_Addr(13 downto 2) = 0x207:0x200   
   __u32 txSpare0[24];  // Software_Addr = 0x87C:0x820,  Firmware_Addr(13 downto 2) = 0x21F:0x208
   __u32 txWrB[8];      // Software_Addr = 0x89C:0x880,  Firmware_Addr(13 downto 2) = 0x227:0x220      
   __u32 txSpare1[24];  // Software_Addr = 0x8FC:0x8A0,  Firmware_Addr(13 downto 2) = 0x23F:0x228   
   __u32 txStat[2];     // Software_Addr = 0x904:0x900,  Firmware_Addr(13 downto 2) = 0x241:0x240      
   __u32 txCount;       // Software_Addr = 0x908,        Firmware_Addr(13 downto 2) = 0x242  
   __u32 txRead;        // Software_Addr = 0x90C,        Firmware_Addr(13 downto 2) = 0x243  
};

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
