all:
	g++ -Wall -m32 -I "../PGP card G3 driver" xStatus.cpp -o xStatus
	g++ -Wall -m32 -I "../PGP card G3 driver" xReset.cpp -o xReset
	g++ -Wall -m32 -I "../PGP card G3 driver" xLoop.cpp -o xLoop
	g++ -Wall -m32 -I "../PGP card G3 driver" xWrite.cpp -o xWrite
	g++ -Wall -m32 -I "../PGP card G3 driver" xRead.cpp -o xRead
	g++ -Wall -m32 -I "../PGP card G3 driver" xRate.cpp -o xRate -lpthread
	g++ -c -Wall -m32 -I$(PWD) McsRead.cpp -o McsRead.o
	g++ -c -Wall -m32 -I$(PWD) PgpCardG3Prom.cpp -o PgpCardG3Prom.o
	g++ -Wall -m32 -I "../PGP card driver" McsRead.o PgpCardG3Prom.o xPromLoad.cpp -o xPromLoad -lrt -lm
	g++ -Wall -m32 -I "../PGP card driver" McsRead.o PgpCardG3Prom.o xPromVerify.cpp -o xPromVerify -lrt -lm

clean:
	rm -f xStatus
	rm -f xReset
	rm -f xLoop
	rm -f xWrite
	rm -f xRead
	rm -f xRate
	rm -f McsRead.o
	rm -f PgpCardG3Prom.o
	rm -f xPromLoad
	rm -f xPromVerify
