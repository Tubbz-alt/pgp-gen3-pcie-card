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
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <fcntl.h>
#include <sstream>
#include <string>
#include <iomanip>
#include <iostream>

#include "../include/PgpCardG3Mod.h"
#include "../include/PgpCardG3Wrap.h"

#define DEVNAME "/dev/PgpCardG3_0"

using namespace std;

int main (int argc, char **argv) {
   int       fd;
   __u32     x;

   if ( (fd = open(DEVNAME, O_RDWR)) <= 0 ) {
      cout << "Error opening file" << endl;
      return(1);
   }

   for (x=0; x<8; x++) {
      cout << "PGP: TX Reset " << dec << x << endl;
      pgpcard_setTxReset(fd,x);
      pgpcard_clrTxReset(fd,x);
   }

   for (x=0; x<8; x++) {
      cout << "PGP: RX Reset " << dec << x << endl;
      pgpcard_setRxReset(fd,x);
      pgpcard_clrRxReset(fd,x);
   }
   
   cout << "EVR: Reset " << endl;
   
   pgpcard_setEvrPllRst(fd);
   pgpcard_clrEvrPllRst(fd);   
   
   pgpcard_setEvrRst(fd);
   pgpcard_clrEvrRst(fd);
   
   cout << "Resetting status counters" << endl;
   pgpcard_rstCount(fd);

   close(fd);
}
