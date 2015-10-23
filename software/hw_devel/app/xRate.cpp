
#include <sys/types.h>
#include <linux/types.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <fcntl.h>
#include <sstream>
#include <time.h>
#include <string>
#include <iomanip>
#include <iostream>
#include <string.h>
#include <stdlib.h>
#include <pthread.h>

#include "../include/PgpCardG3Mod.h"
#include "../include/PgpCardG3Wrap.h"

#define DEVNAME "/dev/PgpCardG3_0"

using namespace std;

#define TX_SIZE 500000
//#define TX_SIZE 5000
//#define TX_SIZE 500

//#define TX_SIZE 253// EOF.tKeep = 0xFFFF
//#define TX_SIZE 252// EOF.tKeep = 0xFFF
//#define TX_SIZE 251// EOF.tKeep = 0xFF
//#define TX_SIZE 250// EOF.tKeep = 0xF

//#define TX_SIZE 200
//#define TX_SIZE 18

//#define TX_SIZE 5// EOF.tKeep = 0xFFFF
//#define TX_SIZE 4// EOF.tKeep = 0xFFF
//#define TX_SIZE 3// EOF.tKeep = 0xFF
//#define TX_SIZE 2// EOF.tKeep = 0xF

//#define TX_SIZE 1

class RunData {
   public:
      int fd;
      unsigned long count;
      unsigned long total;
};


void *runWrite ( void *t ) {
   fd_set          fds;
   struct timeval  timeout;
   uint            error;
   int             ret;
   uint *          data;
   uint            size;
   uint            lane;
   uint            pntr;
   uint            vc;

   RunData *txData = (RunData *)t;

   size = TX_SIZE;
   data = (uint *)malloc(sizeof(uint)*size);
   lane = 0;
   vc   = 0;
   pntr = 0;

   cout << "Starting write thread" << endl;

   error = 0;
   while (error == 0) {

      // Setup fds for select call
      FD_ZERO(&fds);
      FD_SET(txData->fd,&fds);

      // Wait for write ready
      timeout.tv_sec=5;
      timeout.tv_usec=0;
      ret = select(txData->fd+1,NULL,&fds,NULL,&timeout);
      if ( ret <= 0 ) {
         cout << "Write timeout. Ret=" << ret << endl;
         error++;
      }
      else {
         ret = pgpcard_send (txData->fd,data,size,lane,vc);
         asm("nop");
         //cout << "Write Ret=" << ret << endl;
         if ( ret <= 0 ) {
            cout << "Write Error" << endl;
            error++;
         }
         else {
            txData->count++;
            txData->total += ret;
         }
         pntr++;         
         lane = (pntr>>0)&0x7;
         //vc   = (pntr>>3)&0x3;
      }
   }
   free(data);
   pthread_exit(NULL);
}


void *runRead ( void *t ) {
   fd_set          fds;
   struct timeval  timeout;
   uint            error;
   int             ret;
   uint *          data;
   uint            maxSize;
   uint            lane;
   uint            vc;
   uint            eofe;
   uint            eofeCnt = 0;
   uint            fifoErr;
   uint            fifoErrCnt = 0;
   uint            lengthErr;
   uint            lengthErrCnt = 0;

   RunData *rxData = (RunData *)t;

   maxSize = TX_SIZE*2;
   data = (uint *)malloc(sizeof(uint)*maxSize);

   cout << "Starting read thread" << endl;

   error = 0;
   while (error == 0) {

      // Setup fds for select call
      FD_ZERO(&fds);
      FD_SET(rxData->fd,&fds);

      // Wait for read ready
      timeout.tv_sec=5;
      timeout.tv_usec=0;
      ret = select(rxData->fd+1,&fds,NULL,NULL,&timeout);
      if ( ret <= 0 ) {
         cout << "Read timeout. Ret=" << ret << endl;
         error++;
      }
      else {
         ret = pgpcard_recv (rxData->fd,data,maxSize,&lane,&vc,&eofe,&fifoErr,&lengthErr);
         asm("nop");
         //cout << vc << "\t" << lane << endl;
         if ( ret != TX_SIZE ) {
            cout << "Read Error. Ret=" << dec << ret << endl;
            error++;
         }
         else {
            rxData->count++;
            rxData->total += ret;
         }
         if(eofe != 0){
            cout << endl << "Read Error. eofeCnt=" << dec << ++eofeCnt << endl << endl;
         }
         if(fifoErr != 0){
            cout << endl << "Read Error. fifoErrCnt=" << dec << ++fifoErrCnt << endl << endl;
         }
         if(lengthErr != 0){
            cout << endl << "Read Error. lengthErrCnt=" << dec << ++lengthErrCnt << endl << endl;
         }         
      }
   }
   free (data);
   pthread_exit(NULL);
}

int main (int argc, char **argv) {
   RunData *txData = new RunData;
   RunData *rxData = new RunData;
   pthread_t rxThread;
   pthread_t txThread;
   int fd;
   int seconds;
   int x,y;
   time_t c_tme;
   time_t l_tme;
   uint lastRx;
   uint lastTx;
   PgpCardStatus status;

   if ( (fd = open(DEVNAME, O_RDWR )) < 0 ) {
      cout << "Error opening File" << endl;
      return(1);
   }
   seconds       = 0;
   txData->fd    = fd;
   txData->count = 0;
   txData->total = 0;
   rxData->fd    = fd;
   rxData->count = 0;
   rxData->total = 0;
   
   //pgpcard_setDebug(fd, 5);   

   time(&c_tme);    
   time(&l_tme);    

   if ( pthread_create(&txThread,NULL,runWrite,txData) ) {
      cout << "Error creating write thread" << endl;
      return(2);
   }
   if ( pthread_create(&rxThread,NULL,runRead,rxData) ) {
      cout << "Error creating read thread" << endl;
      return(2);
   }

   lastRx = 0;
   lastTx = 0;
   while (1) {
      sleep(1);
      time(&c_tme);
      cout << "Seconds=" << dec << seconds;
      cout << ", Rx Count=" << dec << rxData->count;
      cout << ", Rx Total=" << dec << rxData->total;
      cout << ", Rx Rate=" << ((double)(rxData->count-lastRx) * 32.0 * (double)TX_SIZE) / (double)(c_tme-l_tme);
      cout << ", Tx Count=" << dec << txData->count;
      cout << ", Tx Total=" << dec << txData->total;
      cout << ", Tx Rate=" << ((double)(txData->count-lastTx) * 32.0 * (double)TX_SIZE) / (double)(c_tme-l_tme);
      cout << hex << endl;
      if ( seconds++ % 10 == 0 ) {
         pgpcard_status(fd, &status);
         
         cout << endl;  
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
   
         cout << "          TxDmaAFull[7:0]: ";        
         for(x=0;x<8;x++){
            cout << setw(1) << setfill('0') << status.TxDmaAFull[7-x];            
            if(x!=7) cout << ", "; else cout << endl;
         }
         cout << "           TxDmaReadReady: 0x" << setw(1) << setfill('0') << status.TxReadReady << endl;
         cout << "        TxDmaRetFifoCount: 0x" << setw(3) << setfill('0') << status.TxRetFifoCount << endl;
         cout << "               TxDmaCount: 0x" << setw(8) << setfill('0') << status.TxCount << endl;
         cout << "               TxDmaWrite: 0x" << setw(2) << setfill('0') << status.TxWrite << endl;
         cout << "                TxDmaRead: 0x" << setw(2) << setfill('0') << status.TxRead  << endl;
         cout << endl;   
         
         cout << "       RxDmaFreeFull[7:0]: ";
         for(x=0;x<8;x++){
            cout << setw(1) << setfill('0') << status.RxFreeFull[7-x];           
            if(x!=7) cout << ", "; else cout << endl;
         }
         
         cout << "      RxDmaFreeValid[7:0]: ";
         for(x=0;x<8;x++){
            cout << setw(1) << setfill('0') << status.RxFreeValid[7-x];             
            if(x!=7) cout << ", "; else cout << endl;
         }
         
         cout << "  RxDmaFreeFifoCount[7:0]: ";
         for(x=0;x<8;x++){
            cout << "0x" << setw(1) << setfill('0') << status.RxFreeFifoCount[7-x];            
            if(x!=7) cout << ", "; else cout << endl;
         }       

         cout << "           RxDmaReadReady: 0x" << setw(1) << setfill('0') << status.RxReadReady << endl;
         cout << "        RxDmaRetFifoCount: 0x" << setw(3) << setfill('0') << status.RxRetFifoCount << endl;            
         cout << "               RxDmaCount: 0x" <<  setw(8) << setfill('0') << status.RxCount << endl;
         cout << "               RxDmaWrite: 0x" <<  setw(2) << setfill('0') << status.RxWrite << endl;
         cout << "                RxDmaRead: 0x" <<  setw(2) << setfill('0') << status.RxRead  << endl;            
         cout << endl;   
      }
      lastRx = rxData->count;
      lastTx = txData->count;
      l_tme = c_tme;
   }

   // Wait for thread to stop
   pthread_join(txThread, NULL);
   pthread_join(rxThread, NULL);

   close(fd);
   return(0);
}
