# -*- Makefile -*-

TARGET_ARCH ?= riscv
TARGET_ARCH_AUX ?= riscv64
TARGET_ARCH_AUX2 ?= rv64gc
TARGET_CPU ?= sifive-7-series
TARGET_ARCH_EXTRA_FLAGS ?= -march=${TARGET_ARCH_AUX2} -mtune=${TARGET_CPU}
TARGET_FLOAT_ABI ?= lp64d
# riscv64-unknown-linux-gnu
TARGET_OS ?= ${TARGET_ARCH_AUX}-unknown-linux-gnu
TARGET_CROSS ?= ${TARGET_OS}

TARGET_BUILD_CC_CONFIG ?= --with-arch=${TARGET_ARCH_AUX2} --with-tune=${TARGET_CPU}
