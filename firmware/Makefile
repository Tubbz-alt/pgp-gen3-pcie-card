
# Default
all: prom

# Clean all firmware builds
clean:
	cd targets/PgpCardG3_1p250Gbps/;   make clean
	cd targets/PgpCardG3_2p380Gbps/;   make clean
	cd targets/PgpCardG3_2p500Gbps/;   make clean
	cd targets/PgpCardG3_3p125Gbps/;   make clean
	cd targets/PgpCardG3_4p760Gbps/;   make clean
	cd targets/PgpCardG3_5p000Gbps/;   make clean
	cd targets/PgpCardG3_DmaLoopback/; make clean

# Build all firmware
# Note: Builds happen in clusters of up to 5x builds at a time 
#       to prevent over subscribing the server
prom:
	cd targets/PgpCardG3_1p250Gbps/;   xterm -hold -e "make" &
	cd targets/PgpCardG3_2p380Gbps/;   xterm -hold -e "make" &
	cd targets/PgpCardG3_2p500Gbps/;   xterm -hold -e "make" &
	cd targets/PgpCardG3_3p125Gbps/;   make
	cd targets/PgpCardG3_4p760Gbps/;   xterm -hold -e "make" &
	cd targets/PgpCardG3_5p000Gbps/;   xterm -hold -e "make" &
	cd targets/PgpCardG3_DmaLoopback/; make

# Synthesis  all firmware (no place and route)
# Note: Builds happen in clusters of up to 5x builds at a time 
#       to prevent over subscribing the server
syn:
	cd targets/PgpCardG3_1p250Gbps/;   xterm -hold -e "make syn" &
	cd targets/PgpCardG3_2p380Gbps/;   xterm -hold -e "make syn" &
	cd targets/PgpCardG3_2p500Gbps/;   xterm -hold -e "make syn" &
	cd targets/PgpCardG3_3p125Gbps/;   make syn
	cd targets/PgpCardG3_4p760Gbps/;   xterm -hold -e "make syn" &
	cd targets/PgpCardG3_5p000Gbps/;   xterm -hold -e "make syn" &
	cd targets/PgpCardG3_DmaLoopback/; make syn

