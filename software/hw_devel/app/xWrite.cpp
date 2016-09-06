//////////////////////////////////////////////////////////////////////////////
// This file is part of 'SLAC PGP Gen3 Card'.
// It is subject to the license terms in the LICENSE.txt file found in the 
// top-level directory of this distribution and at: 
//    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
// No part of 'SLAC PGP Gen3 Card', including this file, 
// may be copied, modified, propagated, or distributed except according to 
// the terms contained in the LICENSE.txt file.
//////////////////////////////////////////////////////////////////////////////

#include <sys/types.h>
#include <linux/types.h>
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

#include "../include/PgpCardG3Mod.h"
#include "../include/PgpCardG3Wrap.h"

#define DEVNAME "/dev/PgpCardG3_0"

#define LOOPBACK true
#define PRINT_DATA false

using namespace std;

int main (int argc, char **argv) {
   int           s;
   uint          x;
   int           ret;
   time_t        t;
   uint          lane;
   uint          vc;
   uint          size;
   uint          *txData;
   uint          *rxData;

   if (argc != 4) {
      cout << "Usage: xwrite lane vc size" << endl;
      return(1);
   }

   // Get args
   lane  = atoi(argv[1]);
   vc    = atoi(argv[2]);
   size  = atoi(argv[3]);

   // Check ranges
   if ( size == 0 || lane > 7 || vc > 3 ) {
      cout << "Invalid size, lane or vc value" << endl;
      return(1);
   }

   if ( (s = open(DEVNAME, O_RDWR)) <= 0 ) {
      cout << "Error opening file" << endl;
      return(1);
   }

   time(&t);
   srandom(t); 

   txData = (uint *)malloc(sizeof(uint)*size);

   // DMA Write
   cout << endl;
   cout << "Sending:";
   cout << " Lane=" << dec << lane;
   cout << ", Vc=" << dec << vc << endl;  
      
   for (x=0; x<size; x++) {
      txData[x] = random();
      if(PRINT_DATA){
         cout << " 0x" << setw(8) << setfill('0') << hex << txData[x];
         if ( ((x+1)%10) == 0 ) cout << endl << "   ";
      }
   }
   cout << endl;
   ret = pgpcard_send (s,txData,size,lane,vc);
   cout << "Ret=" << dec << ret << endl << endl;
  
#if LOOPBACK
   sleep(1);
   uint          maxSize;
   uint          eofe;
   uint          fifoErr;
   uint          lengthErr;  
   uint          error;  
   maxSize = 1024*1024*2;
   rxData = (uint *)malloc(sizeof(uint)*maxSize);

   ret = pgpcard_recv(s,rxData,maxSize,&lane,&vc,&eofe,&fifoErr,&lengthErr);

   if ( ret != 0 ) {
      cout << "Receiving:";
      cout << " Lane=" << dec << lane;
      cout << ", Vc=" << dec << vc;
      cout << ", Eofe=" << dec << eofe;
      cout << ", FifoErr=" << dec << fifoErr;
      cout << ", LengthErr=" << dec << lengthErr << endl;
      if(PRINT_DATA){
         for (x=0; x<(uint)ret; x++) {
            cout << " 0x" << setw(8) << setfill('0') << hex << rxData[x];
            if ( ((x+1)%10) == 0 ) cout << endl << "   ";
         }
      }
      cout << endl;
      cout << "Ret=" << dec << ret << endl;
      cout << endl;
      
      if((uint)ret == size){
         error = 0;
         for (x=0; x<(uint)ret; x++) {
            if(rxData[x]!=txData[x]) error++;
         }
         if(error!=0){
            cout << "Error Count = " << dec << error << endl;
         }else{
            cout << "No Errors detected" << endl;  
         }
      } else{
         cout << "Error: RX size != TX size" << endl;
      }
   }
   free(rxData);   
#endif
   
   free(txData);   
   close(s);
   return(0);
}
