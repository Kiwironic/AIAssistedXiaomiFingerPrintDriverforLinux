# Makefile for Xiaomi FPC Fingerprint Scanner Linux Driver
# Copyright (C) 2025 AI-Assisted Development
# Licensed under GPL v2

# Module name
MODULE_NAME := fp_xiaomi

# Library name
LIB_NAME := libfp_xiaomi

# Test application name
TEST_APP := fp_test

# Source files
obj-m += $(MODULE_NAME).o
$(MODULE_NAME)-objs := fp_xiaomi_driver.o

# Library files
LIB_SOURCES := libfp_xiaomi.c
LIB_OBJECTS := $(LIB_SOURCES:.c=.o)
LIB_SHARED := $(LIB_NAME).so.1.0.0
LIB_STATIC := $(LIB_NAME).a

# Test application files
TEST_SOURCES := fp_test.c
TEST_OBJECTS := $(TEST_SOURCES:.c=.o)

# Kernel build directory
KERNEL_DIR ?= /lib/modules/$(shell uname -r)/build

# Build directory
BUILD_DIR := $(PWD)

# Installation directories
INSTALL_DIR := /lib/modules/$(shell uname -r)/kernel/drivers/input/misc
LIB_INSTALL_DIR := /usr/local/lib
HEADER_INSTALL_DIR := /usr/local/include
BIN_INSTALL_DIR := /usr/local/bin

# Compiler flags
CFLAGS := -Wall -Wextra -O2 -fPIC -std=c99
LDFLAGS := -shared -Wl,-soname,$(LIB_NAME).so.1
LIBS := -lpthread

# Default target
all: modules library test

# Build kernel module
modules:
	@echo "Building Xiaomi FPC Fingerprint Driver..."
	$(MAKE) -C $(KERNEL_DIR) M=$(BUILD_DIR) modules
	@echo "Kernel module build completed successfully"

# Build user-space library
library: $(LIB_SHARED) $(LIB_STATIC)

$(LIB_SHARED): $(LIB_OBJECTS)
	@echo "Building shared library..."
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)
	ln -sf $(LIB_SHARED) $(LIB_NAME).so.1
	ln -sf $(LIB_SHARED) $(LIB_NAME).so

$(LIB_STATIC): $(LIB_OBJECTS)
	@echo "Building static library..."
	$(AR) rcs $@ $^

$(LIB_OBJECTS): %.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Build test application
test: $(TEST_APP)

$(TEST_APP): $(TEST_OBJECTS) $(LIB_STATIC)
	@echo "Building test application..."
	$(CC) -o $@ $^ $(LIBS)

$(TEST_OBJECTS): %.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	$(MAKE) -C $(KERNEL_DIR) M=$(BUILD_DIR) clean
	rm -f *.o *.ko *.mod.c *.mod *.order *.symvers
	rm -f $(LIB_OBJECTS) $(LIB_SHARED) $(LIB_STATIC) $(LIB_NAME).so* 
	rm -f $(TEST_OBJECTS) $(TEST_APP)
	rm -f fingerprint_image.raw
	@echo "Clean completed"

# Install module and library
install: modules library
	@echo "Installing Xiaomi FPC Fingerprint Driver..."
	sudo mkdir -p $(INSTALL_DIR)
	sudo cp $(MODULE_NAME).ko $(INSTALL_DIR)/
	sudo depmod -a
	@echo "Installing user-space library..."
	sudo mkdir -p $(LIB_INSTALL_DIR) $(HEADER_INSTALL_DIR) $(BIN_INSTALL_DIR)
	sudo cp $(LIB_SHARED) $(LIB_INSTALL_DIR)/
	sudo cp $(LIB_STATIC) $(LIB_INSTALL_DIR)/
	sudo ln -sf $(LIB_SHARED) $(LIB_INSTALL_DIR)/$(LIB_NAME).so.1
	sudo ln -sf $(LIB_SHARED) $(LIB_INSTALL_DIR)/$(LIB_NAME).so
	sudo cp libfp_xiaomi.h $(HEADER_INSTALL_DIR)/
	sudo cp $(TEST_APP) $(BIN_INSTALL_DIR)/
	sudo ldconfig
	@echo "Installation completed"

# Uninstall module and library
uninstall:
	@echo "Uninstalling Xiaomi FPC Fingerprint Driver..."
	sudo rm -f $(INSTALL_DIR)/$(MODULE_NAME).ko
	sudo depmod -a
	@echo "Uninstalling user-space library..."
	sudo rm -f $(LIB_INSTALL_DIR)/$(LIB_NAME).*
	sudo rm -f $(HEADER_INSTALL_DIR)/libfp_xiaomi.h
	sudo rm -f $(BIN_INSTALL_DIR)/$(TEST_APP)
	sudo ldconfig
	@echo "Uninstallation completed"

# Load module
load: install
	@echo "Loading Xiaomi FPC Fingerprint Driver..."
	sudo modprobe $(MODULE_NAME)
	@echo "Module loaded successfully"

# Unload module
unload:
	@echo "Unloading Xiaomi FPC Fingerprint Driver..."
	sudo modprobe -r $(MODULE_NAME) || true
	@echo "Module unloaded"

# Reload module (unload + load)
reload: unload load

# Check module status
status:
	@echo "Checking module status..."
	@lsmod | grep $(MODULE_NAME) || echo "Module not loaded"
	@echo "USB devices:"
	@lsusb | grep "10a5:9201" || echo "No FPC devices found"
	@echo "Device nodes:"
	@ls -la /dev/fp_xiaomi* 2>/dev/null || echo "No device nodes found"

# Show kernel messages
dmesg:
	@echo "Recent kernel messages for FP_XIAOMI:"
	@dmesg | grep -i "FP_XIAOMI" | tail -20 || echo "No messages found"

# Test basic functionality
test: status
	@echo "Testing basic functionality..."
	@if [ -c /dev/fp_xiaomi0 ]; then \
		echo "Device node exists: /dev/fp_xiaomi0"; \
		ls -la /dev/fp_xiaomi0; \
	else \
		echo "ERROR: Device node not found"; \
	fi

# Development targets
dev-install: unload clean modules load status

# Create package for distribution
package: clean modules
	@echo "Creating distribution package..."
	mkdir -p xiaomi-fp-driver-1.0.0
	cp $(MODULE_NAME).ko xiaomi-fp-driver-1.0.0/
	cp Makefile xiaomi-fp-driver-1.0.0/
	cp fp_xiaomi_driver.c xiaomi-fp-driver-1.0.0/
	cp fp_xiaomi_driver.h xiaomi-fp-driver-1.0.0/
	cp ../README.md xiaomi-fp-driver-1.0.0/
	cp ../LICENSE xiaomi-fp-driver-1.0.0/
	tar -czf xiaomi-fp-driver-1.0.0.tar.gz xiaomi-fp-driver-1.0.0/
	rm -rf xiaomi-fp-driver-1.0.0/
	@echo "Package created: xiaomi-fp-driver-1.0.0.tar.gz"

# Help target
help:
	@echo "Xiaomi FPC Fingerprint Driver Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  all        - Build the kernel module (default)"
	@echo "  modules    - Build the kernel module"
	@echo "  clean      - Clean build artifacts"
	@echo "  install    - Install the module to system"
	@echo "  uninstall  - Remove the module from system"
	@echo "  load       - Load the module into kernel"
	@echo "  unload     - Unload the module from kernel"
	@echo "  reload     - Unload and reload the module"
	@echo "  status     - Check module and device status"
	@echo "  dmesg      - Show recent kernel messages"
	@echo "  test       - Test basic functionality"
	@echo "  package    - Create distribution package"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Development targets:"
	@echo "  dev-install - Quick development cycle (unload, build, load)"
	@echo ""
	@echo "Examples:"
	@echo "  make                    # Build the module"
	@echo "  make install            # Build and install"
	@echo "  make load               # Install and load module"
	@echo "  make status             # Check if everything is working"
	@echo "  make dmesg              # Check kernel messages"
	@echo "  make dev-install        # Quick development cycle"

# Check build requirements
check-deps:
	@echo "Checking build dependencies..."
	@if [ ! -d "$(KERNEL_DIR)" ]; then \
		echo "ERROR: Kernel headers not found at $(KERNEL_DIR)"; \
		echo "Install kernel headers:"; \
		echo "  Ubuntu/Debian: sudo apt install linux-headers-\$$(uname -r)"; \
		echo "  Fedora/RHEL:   sudo dnf install kernel-devel"; \
		echo "  Arch Linux:    sudo pacman -S linux-headers"; \
		exit 1; \
	fi
	@echo "Build dependencies OK"

# Phony targets
.PHONY: all modules clean install uninstall load unload reload status dmesg test dev-install package help check-deps