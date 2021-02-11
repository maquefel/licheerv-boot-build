# -*- Makefile -*-

TARGET_ARCH ?= arm
TARGET_ARCH_AUX ?= arm32
TARGET_ARCH_AUX2 ?= armv7-a
TARGET_CPU ?= cortex-a9
TARGET_ARCH_EXTRA_FLAGS ?= -march=${TARGET_ARCH_AUX2} -mtune=${TARGET_CPU}
TARGET_OS ?= ${TARGET_ARCH}-none-linux-gnueabihf
TARGET_CROSS ?= ${TARGET_OS}

TARGET_BUILD_CC_CONFIG ?= --with-arch=${TARGET_ARCH_AUX2} --with-tune=${TARGET_CPU}
