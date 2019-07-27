# -*- GNUMakefile -*-

# Requirements:
#  /bin/bash as SHELL

export SHELL = /bin/bash

all:    world

#  GNU Make >= 3.82
#  GCC ;)

TARGET_ARCH ?= x86_64

ifndef PARALLEL
ifndef NOPARALLEL
PARALLEL := -j$(shell echo $$((`nproc` + 2)))
endif
endif

KERNEL_TREE ?= ${CURDIR}/linux

build-kernel/arch/x86/configs:
	mkdir -p $@

.PHONY: kernel

build-kernel/arch/x86/configs/x86_64_qemu_defconfig: | build-kernel/arch/x86/configs configs/x86_64_qemu_defconfig
	cp configs/x86_64_qemu_defconfig $@

build-kernel/.config:   | build-kernel/arch/x86/configs/x86_64_qemu_defconfig
	make ARCH=${TARGET_ARCH} -C ${KERNEL_TREE} O=${CURDIR}/build-kernel x86_64_qemu_defconfig

kernel: build-kernel/.config
	make ${PARALLEL} -C ${KERNEL_TREE} O=${CURDIR}/build-kernel ARCH=${TARGET_ARCH}

clean::
	-make ${PARALLEL} -C build-kernel clean
	-make ${PARALLEL} -C ${KERNEL_TREE} mrproper

distclean::
	-rm -rf build-kernel
