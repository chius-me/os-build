obj-m := nodevfs.o

KERNEL_DIR := /home/chius/repo/forgejo/embedded/os-build/linux
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) clean

install:
	cp nodevfs.ko /home/chius/repo/forgejo/embedded/os-build/rootfs/lib/modules/
