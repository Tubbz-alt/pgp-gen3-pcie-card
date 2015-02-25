
#include <sys/types.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <fcntl.h>
#include <sstream>
#include <string>
#include <iomanip>
#include <iostream>
#include <string.h>
#include <stdlib.h>

#include "../include_old/PgpCardG3Mod.h"
#include "../include_old/PgpCardG3Wrap.h"

#define DEVNAME "/dev/PgpCardG3_0"//need to pass to main

using namespace std;

int main (int argc, char **argv) {
   PgpCardStatus status;
   int           s;
   int           ret;
   int           x;
   int           y;

   if ( (s = open(DEVNAME, O_RDWR)) <= 0 ) {
      cout << "Error opening file" << endl;
      return(1);
   }

   cout << "Setting debug level" << endl;
   pgpcard_setDebug(s, 5);

   memset(&status,0,sizeof(PgpCardStatus));
   ret = pgpcard_status(s, &status);   
   
   cout << endl;
   cout << "Read PGP Card Status:" << hex << uppercase << endl << endl;
   
   __u64 SerialNumber = status.SerialNumber[0];
   SerialNumber = SerialNumber << 32;
   SerialNumber |= status.SerialNumber[1];  
   
   cout << "           Version: 0x" << setw(8) << setfill('0') << status.Version << endl;
   cout << "      SerialNumber: 0x" << setw(16)<< setfill('0') << SerialNumber << endl;
   cout << "        BuildStamp: "   << string((char *)status.BuildStamp)  << endl;  
   cout << "        CountReset: 0x" << setw(1) << setfill('0') << status.CountReset << endl;   
   cout << "         CardReset: 0x" << setw(1) << setfill('0') << status.CardReset << endl;   
   cout << "        ScratchPad: 0x" << setw(8) << setfill('0') << status.ScratchPad << endl;
   cout << endl;
   
   cout << "            PgpRate(Gbps): " << setprecision(3) << fixed  << ((double)status.PpgRate)*1.0E-3 << endl;
   cout << "         PgpLoopBack[7:0]: ";        
   for(x=0;x<8;x++){
      cout <<  setw(1) << setfill('0') << status.PgpLoopBack[7-x];             
      if(x!=7) cout << ", "; else cout << endl;
   } 
   
    cout << "          PgpTxReset[7:0]: ";        
   for(x=0;x<8;x++){
      cout <<  setw(1) << setfill('0') << status.PgpTxReset[7-x];            
      if(x!=7) cout << ", "; else cout << endl;
   } 
   
    cout << "          PgpRxReset[7:0]: ";        
   for(x=0;x<8;x++){
      cout <<  setw(1) << setfill('0') << status.PgpRxReset[7-x];            
      if(x!=7) cout << ", "; else cout << endl;
   } 
   
  
  cout << " PgpTxCommonPllReset[3:0]: 0x" <<  setw(1) << setfill('0') << status.PgpTxPllRst[0] << endl;   
  cout << " PgpTxCommonPllReset[7:4]: 0x" <<  setw(1) << setfill('0') << status.PgpTxPllRst[1] << endl;   


  cout << " PgpRxCommonPllReset[3:0]: 0x" <<  setw(1) << setfill('0') << status.PgpRxPllRst[0] << endl;   
  cout << " PgpRxCommonPllReset[7:4]: 0x" <<  setw(1) << setfill('0') << status.PgpRxPllRst[1] << endl;   


  cout << "PgpTxCommonPllLocked[3:0]: 0x" <<  setw(1) << setfill('0') << status.PgpTxPllRdy[0] << endl;   
  cout << "PgpTxCommonPllLocked[7:4]: 0x" <<  setw(1) << setfill('0') << status.PgpTxPllRdy[1] << endl;   


  cout << "PgpRxCommonPllLocked[3:0]: 0x" <<  setw(1) << setfill('0') << status.PgpRxPllRdy[0] << endl;   
  cout << "PgpRxCommonPllLocked[7:4]: 0x" <<  setw(1) << setfill('0') << status.PgpRxPllRdy[1] << endl;   
  
   cout << "     PgpLocLinkReady[7:0]: ";        
   for(x=0;x<8;x++){
      cout <<  setw(1) << setfill('0') << status.PgpLocLinkReady[7-x];          
      if(x!=7) cout << ", "; else cout << endl;
   } 
   
   cout << "     PgpRemLinkReady[7:0]: ";        
   for(x=0;x<8;x++){
      cout <<  setw(1) << setfill('0') << status.PgpRemLinkReady[7-x];           
      if(x!=7) cout << ", "; else cout << endl;
   } 
   
   for(x=0;x<8;x++){ 
      cout << "       PgpRxCount["<<  setw(1) << setfill('0') << 7-x <<"][3:0]: ";        
      for(y=0;y<4;y++){   
         cout << "0x" <<  setw(1) << setfill('0') << status.PgpRxCount[7-x][3-y];            
         if(y!=3) cout << ", "; else cout << endl;
      }
   }  
   
   cout << "       PgpCellErrCnt[7:0]: ";
   for(x=0;x<8;x++){
      cout << "0x" <<  setw(1) << setfill('0') << status.PgpCellErrCnt[7-x];           
      if(x!=7) cout << ", "; else cout << endl;
   } 
   
   cout << "      PgpLinkDownCnt[7:0]: ";
   for(x=0;x<8;x++){
      cout << "0x" <<  setw(1) << setfill('0') << status.PgpLinkDownCnt[7-x];            
      if(x!=7) cout << ", "; else cout << endl;
   } 
   
   cout << "       PgpLinkErrCnt[7:0]: ";
   for(x=0;x<8;x++){
      cout << "0x" <<  setw(1) << setfill('0') << status.PgpLinkErrCnt[7-x];           
      if(x!=7) cout << ", "; else cout << endl;
   } 
   
   cout << "       PgpFifoErrCnt[7:0]: ";
   for(x=0;x<8;x++){
      cout << "0x" <<  setw(1) << setfill('0') << status.PgpFifoErrCnt[7-x];            
      if(x!=7) cout << ", "; else cout << endl;
   } 
   cout << endl;     
   
   cout << "             EvrRunCode: 0x" << setw(2) << setfill('0') << status.EvrRunCode << endl;   
   cout << "          EvrAcceptCode: 0x" << setw(2) << setfill('0') << status.EvrAcceptCode << endl;   
   cout << "            EvrRunDelay: 0x" << setw(8) << setfill('0') << status.EvrRunDelay << endl;
   cout << "         EvrAcceptDelay: 0x" << setw(8) << setfill('0') << status.EvrAcceptDelay << endl;   
   cout << "              EvrEnable: 0x" << setw(1) << setfill('0') << status.EvrEnable << endl;   
   cout << "               EvrReady: 0x" << setw(1) << setfill('0') << status.EvrReady << endl;   
   cout << "               EvrReset: 0x" << setw(1) << setfill('0') << status.EvrReset << endl;   
   cout << "              EvrPllRst: 0x" << setw(1) << setfill('0') << status.EvrPllRst << endl;   
   cout << "              EvrErrCnt: 0x" << setw(1) << setfill('0') << status.EvrErrCnt << endl;   
   for(x=0;x<8;x++){ 
      cout << "  EvrEnHdrCheck["<<  setw(1) << setfill('0') << 7-x <<"][3:0]: ";        
      for(y=0;y<4;y++){   
         cout <<  setw(1) << setfill('0') << status.EvrEnHdrCheck[7-x][3-y];            
         if(y!=3) cout << ", "; else cout << endl;
      }
   }
   cout << endl; 
   
   cout << "        TxDmaAFull[7:0]: ";        
   for(x=0;x<8;x++){
      cout << setw(1) << setfill('0') << status.TxDmaAFull[7-x];            
      if(x!=7) cout << ", "; else cout << endl;
   }
   cout << "         TxDmaReadReady: 0x" << setw(1) << setfill('0') << status.TxReadReady << endl;
   cout << "      TxDmaRetFifoCount: 0x" << setw(3) << setfill('0') << status.TxRetFifoCount << endl;
   cout << "             TxDmaCount: 0x" << setw(8) << setfill('0') << status.TxCount << endl;
   cout << "             TxDmaWrite: 0x" << setw(2) << setfill('0') << status.TxWrite << endl;
   cout << "              TxDmaRead: 0x" << setw(2) << setfill('0') << status.TxRead  << endl;
   cout << endl;   
   
   cout << "     RxDmaFreeFull[7:0]: ";
   for(x=0;x<8;x++){
      cout << setw(1) << setfill('0') << status.RxFreeFull[7-x];           
      if(x!=7) cout << ", "; else cout << endl;
   }
   
   cout << "    RxDmaFreeValid[7:0]: ";
   for(x=0;x<8;x++){
      cout << setw(1) << setfill('0') << status.RxFreeValid[7-x];             
      if(x!=7) cout << ", "; else cout << endl;
   }
   
   cout << "RxDmaFreeFifoCount[7:0]: ";
   for(x=0;x<8;x++){
      cout << "0x" << setw(1) << setfill('0') << status.RxFreeFifoCount[7-x];            
      if(x!=7) cout << ", "; else cout << endl;
   }       
   cout << "         RxDmaReadReady: 0x" << setw(1) << setfill('0') << status.RxReadReady << endl;
   cout << "      RxDmaRetFifoCount: 0x" << setw(3) << setfill('0') << status.RxRetFifoCount << endl;   
   cout << "             RxDmaCount: 0x" <<  setw(8) << setfill('0') << status.RxCount << endl;
   cout << "             RxDmaWrite: 0x" <<  setw(2) << setfill('0') << status.RxWrite << endl;
   cout << "              RxDmaRead: 0x" <<  setw(2) << setfill('0') << status.RxRead  << endl;   
   cout << endl;   
   
   // cout << "          PciCommand: 0x" << setw(4) << setfill('0') << status.PciCommand << endl;
   // cout << "           PciStatus: 0x" << setw(4) << setfill('0') << status.PciStatus << endl;
   // cout << "         PciDCommand: 0x" << setw(4) << setfill('0') << status.PciDCommand << endl;
   // cout << "          PciDStatus: 0x" << setw(4) << setfill('0') << status.PciDStatus << endl;
   // cout << "         PciLCommand: 0x" << setw(4) << setfill('0') << status.PciLCommand << endl;
   // cout << "          PciLStatus: 0x" << setw(4) << setfill('0') << status.PciLStatus << endl;
   // cout << "        PciLinkState: 0x" << setw(1) << setfill('0') << status.PciLinkState << endl;
   // cout << "         PciFunction: 0x" << setw(1) << setfill('0') << status.PciFunction << endl;
   // cout << "           PciDevice: 0x" << setw(1) << setfill('0') << status.PciDevice << endl;
   // cout << "              PciBus: 0x" << setw(2) << setfill('0') << status.PciBus << endl;
   // cout << "         PciBaseAddr: 0x" << setw(8) << setfill('0') << status.PciBaseHdwr << endl;
   // cout << "       PciBaseLength: 0x" << setw(8) << setfill('0') << status.PciBaseLen << endl;     
   // cout << endl;   
   
   pgpcard_dumpDebug(s);

   cout << "Clearing debug level" << endl;
   pgpcard_setDebug(s, 0);

   close(s);
}
