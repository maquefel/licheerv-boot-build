# -*- GNUMakefile -*-

# Requirements:
#  /bin/bash as SHELL

export SHELL = /bin/bash

all:    world

TOOLCHAIN ?= toolchain

include ${TOOLCHAIN}/target.mak

ifndef TOOLCHAIN_PREFIX
TOOLCHAIN_PREFIX := ${CURDIR}/toolchain/${TARGET_CROSS}
endif

ifndef TARGET_CROSS_PREFIX
TARGET_CROSS_PREFIX = ${TOOLCHAIN_PREFIX}/bin/${TARGET_CROSS}
endif

ifndef PARALLEL
ifndef NOPARALLEL
PARALLEL := -j$(shell echo $$((`nproc` + 2)))
endif
endif

KERNEL_TREE ?= ${CURDIR}/linux
SYSROOT ?= ${CURDIR}/initramfs

export PATH := ${TOOLCHAIN_PREFIX}/bin:${PATH}

${SYSROOT}:
	mkdir -p $@

${SYSROOT}/.mount-stamp:	| ${SYSROOT}
	touch $@

.PHONY: world

world: \
	build-linux/arch/${TARGET_ARCH}/boot/zImage \
	${SYSROOT}/lib/modules

# --- kernel

build-linux/arch/${TARGET_ARCH}/configs:
	mkdir -p $@

.PHONY: kernel

build-linux/arch/${TARGET_ARCH}/configs/${TARGET_ARCH}_qemu_defconfig: | build-linux/arch/${TARGET_ARCH}/configs configs/${TARGET_ARCH}_qemu_defconfig
	cp configs/${TARGET_ARCH}_qemu_defconfig $@

build-linux/.config:   | build-linux/arch/${TARGET_ARCH}/configs/${TARGET_ARCH}_qemu_defconfig
	make ARCH=${TARGET_ARCH} -C ${KERNEL_TREE} O=${CURDIR}/build-linux ${TARGET_ARCH}_qemu_defconfig

build-linux/arch/${TARGET_ARCH}/boot/zImage: build-linux/.config
	make ${PARALLEL} -C build-linux ARCH=${TARGET_ARCH} CROSS_COMPILE=${TARGET_CROSS}- V=1

.PHONY: .install-modules

${SYSROOT}/lib/modules:	build-linux/arch/${TARGET_ARCH}/boot/zImage
	make ${PARALLEL} -C build-linux INSTALL_MOD_PATH=${SYSROOT} modules_install

.install-modules: ${SYSROOT}/lib/modules ${SYSROOT}/.mount-stamp

clean::
	-make ${PARALLEL} -C build-linux clean
	-make ${PARALLEL} -C ${KERNEL_TREE} mrproper
	-rm -rf ${SYSROOT}/lib/modules

distclean::
	-rm -rf build-linux
