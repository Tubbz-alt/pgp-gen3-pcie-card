PGPCARD_HOME := $(shell pwd)
PGPCARD_KVER := $(shell uname -r)

obj-m := PgpCardG3.o

all:
	make -C /lib/modules/$(PGPCARD_KVER)/build M=$(PGPCARD_HOME) modules

clean:
	make -C /lib/modules/$(PGPCARD_KVER)/build M=$(PGPCARD_HOME) clean
