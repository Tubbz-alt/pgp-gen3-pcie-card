
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

#include "../include_old/PgpCardG3Mod.h"
#include "../include_old/PgpCardG3Wrap.h"

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
