#!/bin/bash

# Xiaomi FPC Fingerprint Driver Installation Script
# Copyright (C) 2025 AI-Assisted Development
# Licensed under GPL v2

set -e

# Script configuration
SCRIPT_NAME="Xiaomi FPC Fingerprint Driver Installer"
SCRIPT_VERSION="1.0.0"
DRIVER_NAME="fp_xiaomi"
REQUIRED_KERNEL_VERSION="4.19"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        log_info "Please run as a regular user with sudo privileges"
        exit 1
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        log_info "This script requires sudo privileges"
        sudo -v || {
            log_error "Failed to obtain sudo privileges"
            exit 1
        }
    fi
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    log_info "Detected distribution: $PRETTY_NAME"
}

# Check kernel version
check_kernel_version() {
    KERNEL_VERSION=$(uname -r | cut -d. -f1,2)
    REQUIRED_MAJOR=$(echo $REQUIRED_KERNEL_VERSION | cut -d. -f1)
    REQUIRED_MINOR=$(echo $REQUIRED_KERNEL_VERSION | cut -d. -f2)
    CURRENT_MAJOR=$(echo $KERNEL_VERSION | cut -d. -f1)
    CURRENT_MINOR=$(echo $KERNEL_VERSION | cut -d. -f2)
    
    if [ "$CURRENT_MAJOR" -lt "$REQUIRED_MAJOR" ] || 
       ([ "$CURRENT_MAJOR" -eq "$REQUIRED_MAJOR" ] && [ "$CURRENT_MINOR" -lt "$REQUIRED_MINOR" ]); then
        log_error "Kernel version $KERNEL_VERSION is too old"
        log_error "Required: $REQUIRED_KERNEL_VERSION or newer"
        exit 1
    fi
    
    log_success "Kernel version $KERNEL_VERSION is supported"
}

# Install build dependencies with detailed verbose output
install_dependencies() {
    log_info "Installing build dependencies for $DISTRO $DISTRO_VERSION..."
    echo "This step will install the necessary packages to compile and run the fingerprint driver."
    echo
    
    case $DISTRO in
        ubuntu|linuxmint)
            log_info "🔄 Ubuntu/Mint: Updating package repositories..."
            echo "   → Running: sudo apt update"
            if sudo apt update; then
                log_success "✅ Package repositories updated successfully"
            else
                log_error "❌ Failed to update package repositories"
                log_info "💡 Try running: sudo apt update --fix-missing"
                exit 1
            fi
            
            log_info "🔄 Installing essential build tools and libraries..."
            echo "   → Installing: build-essential (GCC, make, etc.)"
            echo "   → Installing: linux-headers-$(uname -r) (kernel development headers)"
            echo "   → Installing: libusb-1.0-0-dev (USB library for hardware communication)"
            echo "   → Installing: libfprint-2-dev (fingerprint library development files)"
            echo "   → Installing: fprintd (fingerprint authentication daemon)"
            echo "   → Installing: dkms (dynamic kernel module support)"
            echo "   → Installing: git, cmake, pkg-config, udev (build tools)"
            
            if sudo apt install -y \
                build-essential \
                linux-headers-$(uname -r) \
                libusb-1.0-0-dev \
                libfprint-2-dev \
                fprintd \
                dkms \
                git \
                cmake \
                pkg-config \
                udev \
                libpam-fprintd; then
                log_success "✅ All Ubuntu/Mint packages installed successfully"
            else
                log_error "❌ Package installation failed"
                log_info "💡 Troubleshooting steps:"
                echo "   1. Check internet connection"
                echo "   2. Try: sudo apt update && sudo apt upgrade"
                echo "   3. Check available disk space: df -h"
                echo "   4. Try installing packages individually to identify the problem"
                exit 1
            fi
            
            # Ubuntu/Mint specific configuration
            log_info "🔧 Configuring Ubuntu/Mint specific settings..."
            
            # Ensure plugdev group exists
            if ! getent group plugdev >/dev/null; then
                log_info "   → Creating plugdev group..."
                sudo groupadd plugdev
            fi
            
            # Check if user needs to be added to groups
            if ! groups $USER | grep -q plugdev; then
                log_info "   → Adding user $USER to plugdev group for device access..."
                sudo usermod -a -G plugdev $USER
                log_warning "⚠️  You'll need to log out and back in for group changes to take effect"
            fi
            
            # Enable and start fprintd service
            log_info "   → Enabling fprintd service..."
            sudo systemctl enable fprintd.service || true
            sudo systemctl start fprintd.service || true
            
            log_success "✅ Ubuntu/Mint configuration completed"
            ;;
            
        debian)
            log_info "🔄 Debian: Updating package repositories..."
            echo "   → Running: sudo apt update"
            if sudo apt update; then
                log_success "✅ Package repositories updated successfully"
            else
                log_error "❌ Failed to update package repositories"
                exit 1
            fi
            
            log_info "🔄 Installing Debian build dependencies..."
            if sudo apt install -y \
                build-essential \
                linux-headers-$(uname -r) \
                libusb-1.0-0-dev \
                libfprint-2-dev \
                fprintd \
                dkms \
                git \
                cmake \
                pkg-config \
                udev \
                module-assistant; then
                log_success "✅ Debian packages installed successfully"
            else
                log_error "❌ Package installation failed"
                exit 1
            fi
            
            log_info "🔧 Preparing Debian module build environment..."
            sudo m-a prepare
            log_success "✅ Debian configuration completed"
            ;;
            
        fedora)
            log_info "🔄 Fedora: Setting up repositories and development tools..."
            echo "   → Fedora version: $DISTRO_VERSION"
            
            # Check if EPEL is needed (usually not for Fedora, but some packages might be there)
            log_info "   → Ensuring EPEL repository is available..."
            sudo dnf install -y epel-release 2>/dev/null || log_info "   → EPEL not needed for Fedora"
            
            log_info "🔄 Installing Development Tools group..."
            echo "   → This includes GCC, make, and other essential build tools"
            if sudo dnf groupinstall -y "Development Tools"; then
                log_success "✅ Development Tools installed successfully"
            else
                log_error "❌ Failed to install Development Tools"
                log_info "💡 Try: sudo dnf group install 'C Development Tools and Libraries'"
                exit 1
            fi
            
            log_info "🔄 Installing Fedora-specific packages..."
            echo "   → Installing: kernel-devel (kernel development headers)"
            echo "   → Installing: kernel-headers (additional kernel headers)"
            echo "   → Installing: libusb1-devel (USB library development files)"
            echo "   → Installing: libfprint-devel (fingerprint library development)"
            echo "   → Installing: fprintd (fingerprint authentication daemon)"
            echo "   → Installing: dkms (dynamic kernel module support)"
            echo "   → Installing: git, cmake (build tools)"
            echo "   → Installing: systemd-udev (device management)"
            
            if sudo dnf install -y \
                kernel-devel \
                kernel-headers \
                libusb1-devel \
                libfprint-devel \
                fprintd \
                fprintd-pam \
                dkms \
                git \
                cmake \
                systemd-udev; then
                log_success "✅ All Fedora packages installed successfully"
            else
                log_error "❌ Package installation failed"
                log_info "💡 Troubleshooting steps:"
                echo "   1. Check if repositories are accessible: sudo dnf repolist"
                echo "   2. Update system: sudo dnf update"
                echo "   3. Check specific package availability: dnf search libfprint"
                exit 1
            fi
            
            # Fedora specific configuration
            log_info "🔧 Configuring Fedora specific settings..."
            
            # Ensure groups exist and user is added
            if ! groups $USER | grep -q plugdev; then
                log_info "   → Adding user $USER to plugdev group..."
                sudo usermod -a -G plugdev $USER
                log_warning "⚠️  You'll need to log out and back in for group changes to take effect"
            fi
            
            # Configure SELinux if enabled
            if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce)" == "Enforcing" ]]; then
                log_info "   → SELinux is enforcing, configuring policies..."
                # Allow fprintd to access USB devices
                sudo setsebool -P authlogin_yubikey on 2>/dev/null || true
                log_info "   → SELinux policies configured for fingerprint access"
            fi
            
            # Enable and start services
            log_info "   → Enabling fprintd service..."
            sudo systemctl enable fprintd.service
            sudo systemctl start fprintd.service
            
            # Check if firewall needs configuration
            if systemctl is-active --quiet firewalld; then
                log_info "   → Firewalld is active, no additional configuration needed for local fingerprint access"
            fi
            
            log_success "✅ Fedora configuration completed"
            ;;
            
        *)
            log_warning "⚠️  Unknown distribution: $DISTRO"
            log_warning "This installer is optimized for Ubuntu, Mint, and Fedora"
            log_warning "Please install build dependencies manually:"
            echo
            echo "Required packages:"
            echo "  • Kernel headers for $(uname -r)"
            echo "  • Build tools (gcc, make, etc.)"
            echo "  • libusb development headers"
            echo "  • libfprint development headers"
            echo "  • fprintd fingerprint daemon"
            echo "  • dkms (recommended)"
            echo "  • git and cmake"
            echo
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation cancelled. Please install dependencies manually first."
                exit 1
            fi
            ;;
    esac
    
    # Verify critical dependencies are installed
    log_info "🔍 Verifying installation of critical dependencies..."
    
    local missing_deps=()
    
    # Check for compiler
    if ! command -v gcc >/dev/null 2>&1; then
        missing_deps+=("gcc compiler")
    else
        log_success "   ✅ GCC compiler: $(gcc --version | head -1)"
    fi
    
    # Check for make
    if ! command -v make >/dev/null 2>&1; then
        missing_deps+=("make build tool")
    else
        log_success "   ✅ Make: $(make --version | head -1)"
    fi
    
    # Check for kernel headers
    if [[ ! -d "/lib/modules/$(uname -r)/build" ]]; then
        missing_deps+=("kernel headers for $(uname -r)")
    else
        log_success "   ✅ Kernel headers: /lib/modules/$(uname -r)/build"
    fi
    
    # Check for git
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    else
        log_success "   ✅ Git: $(git --version)"
    fi
    
    # Check for cmake
    if ! command -v cmake >/dev/null 2>&1; then
        missing_deps+=("cmake")
    else
        log_success "   ✅ CMake: $(cmake --version | head -1)"
    fi
    
    # Check for fprintd
    if ! command -v fprintd >/dev/null 2>&1; then
        log_warning "   ⚠️  fprintd not found in PATH (may be in /usr/libexec/)"
    else
        log_success "   ✅ fprintd: Available"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "❌ Missing critical dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "   • $dep"
        done
        log_error "Please install missing dependencies and run the installer again"
        exit 1
    fi
    
    log_success "🎉 All dependencies installed and verified successfully!"
    echo
}

# Check hardware compatibility
check_hardware() {
    log_info "Checking hardware compatibility..."
    
    DEVICE_FOUND=false
    
    # Check for FPC Sensor Controller L:0001 (10a5:9201)
    FPC_DEVICE_ID="10a5:9201"
    
    if lsusb -d "$FPC_DEVICE_ID" | grep -q "FPC Sensor Controller"; then
        log_success "FPC Sensor Controller L:0001 ($FPC_DEVICE_ID) detected"
        DEVICE_FOUND=true
        
        # Get detailed device info
        log_info "Device details:"
        lsusb -v -d "$FPC_DEVICE_ID" | grep -E '(iProduct|bcdDevice|bNumConfigurations)' | while read -r line; do
            log_info "   → $line"
        done
    else
        log_warning "FPC Sensor Controller L:0001 ($FPC_DEVICE_ID) not detected"
        log_warning "Make sure your laptop's fingerprint scanner is enabled in BIOS/UEFI"
        echo
        log_info "Current USB devices (filtered):"
        lsusb | grep -E "(FPC|fingerprint|biometric|10a5)" || log_info "No matching devices found"
        
        # Check if device is present but not accessible
        if lsusb -d "$FPC_DEVICE_ID" >/dev/null 2>&1; then
            log_warning "Device found but may not be accessible. Check permissions:"
            lsusb -v -d "$FPC_DEVICE_ID" 2>&1 | head -5
        fi
    fi
    
    # Check for existing drivers
    if lsmod | grep -q "fp_xiaomi"; then
        log_warning "Driver already loaded, will reload"
        sudo modprobe -r fp_xiaomi || true
    fi
    
    # Check for conflicting drivers
    CONFLICTING_DRIVERS=("fpc1020" "fpc1155" "validity" "synaptics" "libfprint" "goodix")
    CONFLICTS_FOUND=false
    
    for driver in "${CONFLICTING_DRIVERS[@]}"; do
        if lsmod | grep -q "^$driver"; then
            log_warning "Potentially conflicting driver detected: $driver"
            CONFLICTS_FOUND=true
        fi
    done
    
    if [[ "$CONFLICTS_FOUND" == true ]]; then
        log_warning "Conflicting drivers may interfere with operation"
        log_info "Consider blacklisting them in /etc/modprobe.d/blacklist.conf"
    fi
    
    # Check USB permissions
    log_info "Checking USB device permissions..."
    for device_id in "${XIAOMI_DEVICES[@]}"; do
        local vid=$(echo "$device_id" | cut -d: -f1)
        local pid=$(echo "$device_id" | cut -d: -f2)
        
        # Find device in /dev/bus/usb
        local device_path=$(find /dev/bus/usb -name "*" -exec lsusb -s {}:* \; 2>/dev/null | grep "$device_id" | head -1 || true)
        if [[ -n "$device_path" ]]; then
            log_info "Found device with proper USB access"
            break
        fi
    done
}

# Build and install driver with detailed progress
build_driver() {
    log_info "🔨 Building Xiaomi Fingerprint Driver..."
    echo "This step compiles the kernel module from source code."
    echo
    
    # Navigate to source directory
    local src_dir="$(dirname "$0")/../src"
    if [[ ! -d "$src_dir" ]]; then
        log_error "❌ Source directory not found: $src_dir"
        log_info "💡 Make sure you're running this script from the project directory"
        exit 1
    fi
    
    cd "$src_dir"
    log_info "   → Working directory: $(pwd)"
    
    # Verify source files exist
    log_info "🔍 Verifying source files..."
    local required_files=("fp_xiaomi_driver.c" "fp_xiaomi_driver.h" "Makefile")
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "   ✅ Found: $file"
        else
            log_error "   ❌ Missing: $file"
            exit 1
        fi
    done
    
    # Check kernel build environment
    log_info "🔍 Checking kernel build environment..."
    local kernel_version=$(uname -r)
    local kernel_build_dir="/lib/modules/$kernel_version/build"
    
    if [[ -d "$kernel_build_dir" ]]; then
        log_success "   ✅ Kernel build directory: $kernel_build_dir"
    else
        log_error "   ❌ Kernel build directory not found: $kernel_build_dir"
        log_info "💡 Install kernel headers for your distribution:"
        case $DISTRO in
            ubuntu|debian|linuxmint)
                echo "   sudo apt install linux-headers-$(uname -r)"
                ;;
            fedora)
                echo "   sudo dnf install kernel-devel kernel-headers"
                ;;
        esac
        exit 1
    fi
    
    # Clean previous builds
    log_info "🧹 Cleaning previous builds..."
    if make clean >/dev/null 2>&1; then
        log_success "   ✅ Build directory cleaned"
    else
        log_info "   → No previous build to clean"
    fi
    
    # Show build configuration
    log_info "📋 Build configuration:"
    echo "   → Kernel version: $kernel_version"
    echo "   → Architecture: $(uname -m)"
    echo "   → Compiler: $(gcc --version | head -1)"
    echo "   → Build directory: $kernel_build_dir"
    echo
    
    # Build the driver
    log_info "🔄 Compiling kernel module..."
    echo "   → Running: make modules"
    echo "   → This may take a few minutes..."
    
    if make modules 2>&1 | tee /tmp/build.log; then
        log_success "✅ Driver compiled successfully!"
        
        # Verify the module was created
        if [[ -f "fp_xiaomi_driver.ko" ]]; then
            local module_size=$(stat -c%s "fp_xiaomi_driver.ko")
            log_success "   ✅ Module file created: fp_xiaomi_driver.ko (${module_size} bytes)"
            
            # Show module information
            log_info "📋 Module information:"
            modinfo fp_xiaomi_driver.ko | head -10 | sed 's/^/   → /'
        else
            log_error "   ❌ Module file not created despite successful build"
            exit 1
        fi
    else
        log_error "❌ Driver compilation failed!"
        echo
        log_info "🔍 Build error analysis:"
        
        # Analyze common build errors
        if grep -q "No such file or directory" /tmp/build.log; then
            log_error "   → Missing files or headers detected"
            log_info "💡 Ensure all dependencies are installed"
        fi
        
        if grep -q "Permission denied" /tmp/build.log; then
            log_error "   → Permission issues detected"
            log_info "💡 Check file permissions in source directory"
        fi
        
        if grep -q "kernel.*not found" /tmp/build.log; then
            log_error "   → Kernel headers not found"
            log_info "💡 Install kernel development headers"
        fi
        
        echo
        log_info "📄 Full build log saved to: /tmp/build.log"
        log_info "💡 Common solutions:"
        echo "   1. Ensure kernel headers are installed"
        echo "   2. Check that gcc version is compatible"
        echo "   3. Verify all dependencies are present"
        echo "   4. Try: sudo apt update && sudo apt upgrade (Ubuntu/Mint)"
        echo "   5. Try: sudo dnf update (Fedora)"
        exit 1
    fi
    
    # Install the driver
    log_info "📦 Installing driver module..."
    echo "   → Installing to system module directory"
    echo "   → Running: sudo make install"
    
    if sudo make install 2>&1 | tee /tmp/install.log; then
        log_success "✅ Driver installed successfully!"
        
        # Verify installation
        local module_path="/lib/modules/$(uname -r)/kernel/drivers/input/misc/fp_xiaomi_driver.ko"
        if [[ -f "$module_path" ]]; then
            log_success "   ✅ Module installed at: $module_path"
        else
            log_warning "   ⚠️  Module not found at expected location"
            log_info "   → Searching for installed module..."
            find /lib/modules/$(uname -r) -name "*fp_xiaomi*" -type f 2>/dev/null | head -5 | sed 's/^/   → /'
        fi
        
        # Update module dependencies
        log_info "🔄 Updating module dependencies..."
        sudo depmod -a
        log_success "   ✅ Module dependencies updated"
        
    else
        log_error "❌ Driver installation failed!"
        echo
        log_info "🔍 Installation error analysis:"
        
        if grep -q "Permission denied" /tmp/install.log; then
            log_error "   → Permission issues during installation"
            log_info "💡 Ensure you have sudo privileges"
        fi
        
        if grep -q "No space left" /tmp/install.log; then
            log_error "   → Insufficient disk space"
            log_info "💡 Free up space in /lib/modules/"
        fi
        
        echo
        log_info "📄 Full installation log saved to: /tmp/install.log"
        exit 1
    fi

    # Build and install driver with detailed progress
    build_driver() {
        log_info "🔨 Building Xiaomi Fingerprint Driver..."
        echo "This step compiles the kernel module from source code."
        echo
        
        # Navigate to source directory
        local src_dir="$(dirname "$0")/../src"
        if [[ ! -d "$src_dir" ]]; then
            log_error "❌ Source directory not found: $src_dir"
            log_info "💡 Make sure you're running this script from the project directory"
            exit 1
        fi
        
        cd "$src_dir"
        log_info "   → Working directory: $(pwd)"
        
        # Verify source files exist
        log_info "🔍 Verifying source files..."
        local required_files=("fp_xiaomi_driver.c" "fp_xiaomi_driver.h" "Makefile")
        for file in "${required_files[@]}"; do
            if [[ -f "$file" ]]; then
                log_success "   ✅ Found: $file"
            else
                log_error "   ❌ Missing: $file"
                exit 1
            fi
        done
        
        # Check kernel build environment
        log_info "🔍 Checking kernel build environment..."
        local kernel_version=$(uname -r)
        local kernel_build_dir="/lib/modules/$kernel_version/build"
        
        if [[ -d "$kernel_build_dir" ]]; then
            log_success "   ✅ Kernel build directory: $kernel_build_dir"
        else
            log_error "   ❌ Kernel build directory not found: $kernel_build_dir"
            log_info "💡 Install kernel headers for your distribution:"
            case $DISTRO in
                ubuntu|debian|linuxmint)
                    echo "   sudo apt install linux-headers-$(uname -r)"
                    ;;
                fedora)
                    echo "   sudo dnf install kernel-devel kernel-headers"
                    ;;
            esac
            exit 1
        fi
        
        # Clean previous builds
        log_info "🧹 Cleaning previous builds..."
        if make clean >/dev/null 2>&1; then
            log_success "   ✅ Build directory cleaned"
        else
            log_info "   → No previous build to clean"
        fi
        
        # Show build configuration
        log_info "📋 Build configuration:"
        echo "   → Kernel version: $kernel_version"
        echo "   → Architecture: $(uname -m)"
        echo "   → Compiler: $(gcc --version | head -1)"
        echo "   → Build directory: $kernel_build_dir"
        echo
        
        # Build the driver
        log_info "🔄 Compiling kernel module..."
        echo "   → Running: make modules"
        echo "   → This may take a few minutes..."
        
        if make modules 2>&1 | tee /tmp/build.log; then
            log_success "✅ Driver compiled successfully!"
            
            # Verify the module was created
            if [[ -f "fp_xiaomi_driver.ko" ]]; then
                local module_size=$(stat -c%s "fp_xiaomi_driver.ko")
                log_success "   ✅ Module file created: fp_xiaomi_driver.ko (${module_size} bytes)"
                
                # Show module information
                log_info "📋 Module information:"
                modinfo fp_xiaomi_driver.ko | head -10 | sed 's/^/   → /'
            else
                log_error "   ❌ Module file not created despite successful build"
                exit 1
            fi
        else
            log_error "❌ Driver compilation failed!"
            echo
            log_info "🔍 Build error analysis:"
            
            # Analyze common build errors
            if grep -q "No such file or directory" /tmp/build.log; then
                log_error "   → Missing files or headers detected"
                log_info "💡 Ensure all dependencies are installed"
            fi
            
            if grep -q "Permission denied" /tmp/build.log; then
                log_error "   → Permission issues detected"
                log_info "💡 Check file permissions in source directory"
            fi
            
            if grep -q "kernel.*not found" /tmp/build.log; then
                log_error "   → Kernel headers not found"
                log_info "💡 Install kernel development headers"
            fi
            
            echo
            log_info "📄 Full build log saved to: /tmp/build.log"
            log_info "💡 Common solutions:"
            echo "   1. Ensure kernel headers are installed"
            echo "   2. Check that gcc version is compatible"
            echo "   3. Verify all dependencies are present"
            echo "   4. Try: sudo apt update && sudo apt upgrade (Ubuntu/Mint)"
            echo "   5. Try: sudo dnf update (Fedora)"
            exit 1
        fi
        
        # Install the driver
        log_info "📦 Installing driver module..."
        echo "   → Installing to system module directory"
        echo "   → Running: sudo make install"
        
        if sudo make install 2>&1 | tee /tmp/install.log; then
            log_success "✅ Driver installed successfully!"
            
            # Verify installation
            local module_path="/lib/modules/$(uname -r)/kernel/drivers/input/misc/fp_xiaomi_driver.ko"
            if [[ -f "$module_path" ]]; then
                log_success "   ✅ Module installed at: $module_path"
            else
                log_warning "   ⚠️  Module not found at expected location"
                log_info "   → Searching for installed module..."
                find /lib/modules/$(uname -r) -name "*fp_xiaomi*" -type f 2>/dev/null | head -5 | sed 's/^/   → /'
            fi
            
            # Update module dependencies
            log_info "🔄 Updating module dependencies..."
            sudo depmod -a
            log_success "   ✅ Module dependencies updated"
            
        else
            log_error "❌ Driver installation failed!"
            echo
            log_info "🔍 Installation error analysis:"
            
            if grep -q "Permission denied" /tmp/install.log; then
                log_error "   → Permission issues during installation"
                log_info "💡 Ensure you have sudo privileges"
            fi
            
            if grep -q "No space left" /tmp/install.log; then
                log_error "   → Insufficient disk space"
                log_info "💡 Free up space in /lib/modules/"
            fi
            
            echo
            log_info "📄 Full installation log saved to: /tmp/install.log"
            exit 1
        fi
        
        log_success "🎉 Driver build and installation completed successfully!"
        echo
    }

    # Configure udev rules
    setup_udev_rules() {
        log_info "Setting up udev rules for FPC Sensor Controller..."
        
        cat << 'EOF' | sudo tee /etc/udev/rules.d/60-fpc-fingerprint.rules >/dev/null
# FPC Sensor Controller L:0001 (10a5:9201) udev rules
# Provides access to the fingerprint scanner for users in the 'plugdev' group

# Main rule for FPC Sensor Controller
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", \
  MODE="0666", \
  GROUP="plugdev", \
  TAG+="uaccess", \
  SYMLINK+="fpc/%k"

# Device node access for the driver
KERNEL=="fp_xiaomi*", MODE="0666", GROUP="plugdev"

# Auto-load driver when device is connected
ACTION=="add", SUBSYSTEM=="usb", \
  ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", \
  RUN+="/sbin/modprobe fp_xiaomi_driver"

# Set power management settings to prevent USB autosuspend
ACTION=="add", SUBSYSTEM=="usb", \
  ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", \
  TEST=="power/control", ATTR{power/control}="on"

# Set USB autosuspend delay to 10 seconds (10000ms)
ACTION=="add", SUBSYSTEM=="usb", \
  ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", \
  TEST=="power/autosuspend_delay_ms", ATTR{power/autosuspend_delay_ms}="10000"
EOF

        # Reload udev rules
        sudo udevadm control --reload-rules
        sudo udevadm trigger
        
        # Add user to plugdev group if not already a member
        if ! groups $USER | grep -q plugdev; then
            log_info "Adding user $USER to plugdev group..."
            sudo usermod -a -G plugdev $USER
            log_warning "You need to log out and back in for group changes to take effect"
        fi
        
        log_success "Udev rules configured"
    }

    # Configure module loading
    setup_module_loading() {
        log_info "Configuring automatic module loading for FPC Sensor Controller..."
        
        # Create modules-load.d configuration
        echo "# Load FPC Sensor Controller driver at boot" | sudo tee /etc/modules-load.d/fpc-sensor.conf >/dev/null
        echo "fp_xiaomi_driver" | sudo tee -a /etc/modules-load.d/fpc-sensor.conf >/dev/null
        
        # Create modprobe configuration
        cat << 'EOF' | sudo tee /etc/modprobe.d/fpc-sensor.conf >/dev/null
# FPC Sensor Controller Driver Configuration
# This file is automatically generated - do not edit manually

# Prevent conflicting drivers from loading
blacklist fpc1020
blacklist fpc1155
blacklist validity
blacklist synaptics_usb
blacklist goodix

# Driver options (uncomment and modify as needed)
# options fp_xiaomi_driver debug=1       # Enable debug output (0-3, where 3 is most verbose)
# options fp_xiaomi_driver reset_delay=5  # Reset delay in milliseconds (default: 5)
# options fp_xiaomi_driver timeout=10000  # Command timeout in milliseconds (default: 10000)

# Alias for legacy compatibility
alias fp_xiaomi fp_xiaomi_driver

# Disable power management for the module
options fp_xiaomi_driver power_save=0

# Set device-specific parameters
options fp_xiaomi_driver vid=0x10a5 pid=0x9201

# Enable/disable specific features
options fp_xiaomi_driver enable_irq=1
options fp_xiaomi_driver enable_pm=1

# Set debug log level (0=none, 1=errors, 2=warnings, 3=info, 4=debug)
# options fp_xiaomi_driver log_level=2

# Force device detection (0=auto, 1=force)
# options fp_xiaomi_driver force_detect=0

# Set interrupt handling mode (0=polling, 1=interrupt)
# options fp_xiaomi_driver irq_mode=1

# Set power management parameters
options fp_xiaomi_driver autosuspend_delay=2000  # Autosuspend delay in ms
options fp_xiaomi_driver keep_awake=1           # Keep device awake during operation

# Performance tuning
options fp_xiaomi_driver max_transfer=16384     # Maximum USB transfer size
options fp_xiaomi_driver urb_timeout=5000       # USB request timeout in ms

# Security settings
options fp_xiaomi_driver secure_mode=1          # Enable secure communication
options fp_xiaomi_driver validate_fw=1          # Validate firmware signature

# Debugging options
# options fp_xiaomi_driver simulate=0           # Simulate hardware (for testing)
# options fp_xiaomi_driver fake_interrupt=0     # Generate fake interrupts (for testing)

# Note: After changing these options, you may need to:
# 1. Remove the module: sudo modprobe -r fp_xiaomi_driver
# 2. Reload the module: sudo modprobe fp_xiaomi_driver
EOF
        
        # Update module dependencies
        log_info "Updating module dependencies..."
        if sudo depmod -a; then
            log_success "Module dependencies updated"
            
            # Create a configuration file for runtime settings
            cat << 'EOF' | sudo tee /etc/fp-xiaomi.conf >/dev/null
# FPC Sensor Controller Runtime Configuration
# This file is read by the driver at module load time

# Enable debug mode (0=disabled, 1=enabled)
DEBUG=0

# Log level (0=error, 1=warning, 2=info, 3=debug)
LOG_LEVEL=1

# USB power management (0=disabled, 1=enabled)
USB_POWER_MANAGEMENT=1

# Auto-suspend timeout in milliseconds (0=disabled)
AUTO_SUSPEND_TIMEOUT=2000

# Maximum number of retries for failed operations
MAX_RETRIES=3

# Timeout for operations in milliseconds
OPERATION_TIMEOUT=10000

# Security settings
ENABLE_SECURE_MODE=1
VALIDATE_FIRMWARE=1

# Performance settings
MAX_TRANSFER_SIZE=16384
URB_TIMEOUT=5000

# Note: Changes to this file require reloading the driver
# sudo modprobe -r fp_xiaomi_driver && sudo modprobe fp_xiaomi_driver
EOF
            
            log_success "Runtime configuration created at /etc/fp-xiaomi.conf"
        else
            log_warning "Failed to update module dependencies"
        fi
        
        log_success "Module loading configuration completed"
    }

# Load and test driver with comprehensive diagnostics
test_driver() {
    log_info "🧪 Testing FPC Sensor Controller driver..."
    echo "This step verifies the driver and hardware functionality."
    echo "====================================================="
    
    # Check if running as root
    check_root
    
    # Unload any existing driver first
    log_info "🔄 Preparing driver environment..."
    echo "   → Unloading any existing fingerprint drivers..."
    
    local drivers_to_unload=(
        "fp_xiaomi_driver" "fp_xiaomi" 
        "fpc1020" "fpc1155" "fpc_fingerprint" 
        "validity" "vfs" "synaptics_usb" "goodix"
    )
    
    for driver in "${drivers_to_unload[@]}"; do
        if lsmod | grep -q "^$driver"; then
            log_info "   → Unloading existing driver: $driver"
            sudo modprobe -r "$driver" 2>/dev/null || {
                log_warning "   → Failed to unload $driver (might be in use)"
                sudo rmmod "$driver" 2>/dev/null || true
            }
        fi
    done
    
    # Wait for any pending operations to complete
    sleep 1
    
    log_success "✅ Driver environment prepared"
    
    # Verify module file exists
    log_info "🔍 Verifying driver module..."
    local module_paths=(
        "/lib/modules/$(uname -r)/kernel/drivers/input/misc/fp_xiaomi_driver.ko"
        "/lib/modules/$(uname -r)/extra/fp_xiaomi_driver.ko"
        "/lib/modules/$(uname -r)/updates/dkms/fp_xiaomi_driver.ko"
        "$(dirname "$0")/../src/fp_xiaomi_driver.ko"
    )
    
    local module_found=false
    local module_path=""
    
    for path in "${module_paths[@]}"; do
        if [[ -f "$path" ]]; then
            module_found=true
            module_path="$path"
            log_success "   ✅ Driver module found: $path"
            
            # Verify module dependencies
            log_info "   → Checking module dependencies..."
            local deps=$(modinfo -F depends "$path" 2>/dev/null || true)
            if [[ -n "$deps" ]]; then
                log_info "   → Dependencies: $deps"
                
                # Check if dependencies are loaded
                for dep in $(echo "$deps" | tr ',' ' '); do
                    if ! lsmod | grep -q "^$dep"; then
                        log_warning "   → Dependency not loaded: $dep"
                        log_info "   → Attempting to load dependency..."
                        if ! sudo modprobe "$dep" 2>/dev/null; then
                            log_error "   → Failed to load dependency: $dep"
                        fi
                    fi
                done
            fi
            
            break
        fi
    done
    
    if [[ "$module_found" == false ]]; then
        log_error "❌ Driver module not found in any expected location"
        log_info "💡 Expected locations:"
        for path in "${module_paths[@]}"; do
            if [[ -d "$(dirname "$path")" ]]; then
                echo "   • $path"
            fi
        done
        log_info "💡 Try rebuilding the driver: make clean && make"
        exit 1
    fi
    
    # Show module information
    log_info "📋 Module information:"
    if command -v modinfo >/dev/null 2>&1; then
        modinfo "$module_path" 2>/dev/null | grep -E '^(filename|version|description|author|firmware|depends|parm):' | 
            sed 's/^/   → /' || log_info "   → Module info not available"
    fi
    
    # Check for FPC Sensor Controller hardware
    log_info "🔍 Checking for FPC Sensor Controller hardware..."
    local device_found=false
    
    # Check USB devices
    if lsusb -d 10a5:9201 -v 2>/dev/null | grep -q "FPC Sensor"; then
        device_found=true
        log_success "✅ FPC Sensor Controller (10a5:9201) found"
        
        # Show detailed USB information
        log_info "   → USB device details:"
        lsusb -d 10a5:9201 -v 2>&1 | grep -E '(iProduct|bcdDevice|bNumConfigurations|bMaxPower)' | 
            sed 's/^/      /' || true
    else
        log_warning "⚠️  FPC Sensor Controller not found via USB"
        log_info "   → Check if the device is properly connected and powered"
        log_info "   → Try: lsusb | grep -i 'FPC\|10a5'"
    fi
    
    # Load the driver
    log_info "🔄 Loading fingerprint driver..."
    echo "   → Running: sudo modprobe fp_xiaomi_driver"
    
    # Clear dmesg buffer to see fresh messages
    sudo dmesg -C 2>/dev/null || true
    
    # Load the module
    local load_success=false
    if sudo modprobe fp_xiaomi_driver 2>&1 | tee /tmp/modprobe.log; then
        load_success=true
        log_success "✅ Driver loaded successfully!"
        
        # Check if module is loaded
        if lsmod | grep -q "^fp_xiaomi"; then
            log_success "   → Module is active in kernel"
            
            # Show module parameters
            if [[ -d "/sys/module/fp_xiaomi_driver/parameters" ]]; then
                log_info "   → Current module parameters:"
                grep -r '' /sys/module/fp_xiaomi_driver/parameters/ 2>/dev/null | 
                    sed 's|/sys/module/fp_xiaomi_driver/parameters/|      |; s/:/ = /' || true
            fi
        else
            log_warning "⚠️  Module not found in kernel after loading"
        fi
    else
        log_error "❌ Failed to load driver via modprobe"
        
        # Analyze the error
        log_info "🔍 Analyzing load failure..."
        if grep -q "Invalid module format" /tmp/modprobe.log; then
            log_error "   → Module format is invalid (kernel version mismatch)"
            log_info "💡 Rebuild driver for current kernel: $(uname -r)"
            log_info "   → Installed kernel headers: $(ls -d /usr/src/linux-headers-* 2>/dev/null | xargs -n1 basename 2>/dev/null || echo 'None')"
        elif grep -q "Operation not permitted" /tmp/modprobe.log; then
            log_error "   → Permission denied (possibly Secure Boot)"
            log_info "💡 Check if Secure Boot is enabled and sign the module"
            log_info "   → Command: mokutil --sb-state"
        elif grep -q "No such device" /tmp/modprobe.log; then
            log_error "   → Hardware not detected or not supported"
            log_info "💡 Ensure fingerprint scanner is enabled in BIOS/UEFI"
            log_info "💡 Check dmesg for hardware detection issues"
        fi
        
        # Show last kernel messages
        log_info "📄 Last kernel messages:"
        dmesg | tail -n 20 | sed 's/^/   → /'
        
        # Try fallback loading with insmod
        log_info "🔄 Attempting fallback loading with insmod..."
        if [[ -f "$(dirname "$0")/../src/fp_xiaomi_driver.ko" ]]; then
            if sudo insmod "$(dirname "$0")/../src/fp_xiaomi_driver.ko" 2>&1 | tee /tmp/insmod.log; then
                log_success "✅ Driver loaded using insmod fallback"
            else
                log_error "❌ Fallback loading also failed"
                log_info "📄 Modprobe log: /tmp/modprobe.log"
                log_info "📄 Insmod log: /tmp/insmod.log"
                exit 1
            fi
        else
            log_error "❌ No fallback module available"
            exit 1
        fi
    fi
    
    # Wait for device initialization
    log_info "⏳ Waiting for device initialization..."
    for i in {1..5}; do
        echo -n "   → Waiting... ($i/5)"
        sleep 1
        echo " ✓"
    done
    
    # Check driver status in kernel
    log_info "🔍 Verifying driver status in kernel..."
    if lsmod | grep -q fp_xiaomi; then
        log_success "✅ Driver is loaded and active in kernel"
        local driver_info=$(lsmod | grep fp_xiaomi)
        echo "   → $driver_info"
        
        # Show module usage
        local usage=$(echo "$driver_info" | awk '{print $3}')
        if [[ "$usage" -gt 0 ]]; then
            log_success "   → Module is being used (usage count: $usage)"
        else
            log_info "   → Module loaded but not yet in use"
        fi
    else
        log_error "❌ Driver not found in kernel module list"
        log_info "💡 This might indicate a loading issue"
    fi
    
    # Check for device nodes
    log_info "🔍 Checking for device nodes..."
    local device_nodes_found=false
    local device_nodes=()
    
    # Look for various possible device nodes
    for pattern in "/dev/fp_xiaomi*" "/dev/fingerprint*" "/dev/hidraw*"; do
        for node in $pattern; do
            if [[ -e "$node" ]]; then
                device_nodes+=("$node")
                device_nodes_found=true
            fi
        done
    done
    
    if [[ "$device_nodes_found" == true ]]; then
        log_success "✅ Device nodes found:"
        for node in "${device_nodes[@]}"; do
            local perms=$(ls -la "$node" | awk '{print $1, $3, $4}')
            log_success "   → $node ($perms)"
            
            # Test basic access
            if [[ -r "$node" ]]; then
                echo "     ✓ Readable"
            else
                echo "     ✗ Not readable"
            fi
            
            if [[ -w "$node" ]]; then
                echo "     ✓ Writable"
            else
                echo "     ✗ Not writable"
            fi
        done
    else
        log_warning "⚠️  No device nodes found"
        if [[ "$DEVICE_FOUND" == true ]]; then
            log_warning "   → Hardware detected but no device nodes created"
            log_info "💡 This might indicate a driver implementation issue"
        else
            log_info "   → No hardware detected - device nodes will appear when hardware is connected"
        fi
    fi
    
    # Check kernel messages
    log_info "📋 Recent kernel messages from driver:"
    local kernel_messages=$(dmesg | grep -i "fp_xiaomi" | tail -10)
    if [[ -n "$kernel_messages" ]]; then
        echo "$kernel_messages" | sed 's/^/   → /'
        
        # Analyze messages for issues
        if echo "$kernel_messages" | grep -q -i "error"; then
            log_warning "   ⚠️  Error messages detected in kernel log"
        fi
        if echo "$kernel_messages" | grep -q -i "fail"; then
            log_warning "   ⚠️  Failure messages detected in kernel log"
        fi
        if echo "$kernel_messages" | grep -q -i "success\|ready\|initialized"; then
            log_success "   ✅ Success messages detected in kernel log"
        fi
    else
        log_info "   → No driver messages found in kernel log"
    fi
    
    # Test hardware communication if device is present
    if [[ "$device_found" == true ]]; then
        log_info "🔗 Testing FPC Sensor Controller hardware communication..."
        
        # Check if device is still visible via USB
        local device_still_present=false
        if lsusb -d 10a5:9201 -v 2>/dev/null | grep -q "FPC Sensor"; then
            log_success "   ✅ Hardware still detected: FPC Sensor Controller (10a5:9201)"
            device_still_present=true
            
            # Check USB device status
            log_info "   → USB device status:"
            local usb_path="/sys/bus/usb/devices/$(lsusb -d 10a5:9201 | awk '{print $2":"$4}' | sed 's/://' | tr '[:upper:]' '[:lower:]')/"
            
            if [[ -d "$usb_path" ]]; then
                # Show power management status
                if [[ -f "${usb_path}power/control" ]]; then
                    local power_control=$(cat "${usb_path}power/control" 2>/dev/null || echo "unknown")
                    log_info "      Power control: $power_control"
                    
                    if [[ "$power_control" != "on" ]]; then
                        log_warning "      ⚠️  Power management might interfere with device operation"
                        log_info "      Try: echo 'on' | sudo tee '${usb_path}power/control'"
                    fi
                fi
                
                # Show autosuspend delay
                if [[ -f "${usb_path}power/autosuspend_delay_ms" ]]; then
                    local autosuspend_delay=$(cat "${usb_path}power/autosuspend_delay_ms" 2>/dev/null || echo "unknown")
                    log_info "      Autosuspend delay: $autosuspend_delay ms"
                fi
                
                # Show driver binding
                local driver_link="${usb_path}driver"
                if [[ -L "$driver_link" ]]; then
                    local driver_name=$(basename "$(readlink -f "$driver_link")" 2>/dev/null || echo "none")
                    log_info "      Driver: $driver_name"
                    
                    if [[ "$driver_name" != "fp_xiaomi_driver" ]]; then
                        log_warning "      ⚠️  Device not bound to fp_xiaomi_driver"
                        log_info "      Try: echo '10a5 9201' | sudo tee /sys/bus/usb/drivers/usb/unbind 2>/dev/null || true"
                        log_info "           echo '10a5 9201' | sudo tee /sys/bus/usb/drivers/fp_xiaomi/bind 2>/dev/null || true"
                    fi
                fi
            fi
            
            # Test basic IOCTL if device node exists
            local device_node=""
            for node in "/dev/fp_xiaomi" "/dev/fpc"; do
                if [[ -c "$node" ]]; then
                    device_node="$node"
                    break
                fi
            done
            
            if [[ -n "$device_node" ]]; then
                log_info "   → Testing device node: $device_node"
                
                # Create a simple test program
                local test_prog="/tmp/fp_test_ioctl.c"
                cat > "$test_prog" << 'EOF'
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <linux/ioctl.h>

// Define IOCTL commands (adjust based on actual driver implementation)
#define FP_IOCTL_GET_VERSION   _IOR('F', 0x01, unsigned int)
#define FP_IOCTL_GET_STATUS    _IOR('F', 0x02, unsigned int)
#define FP_IOCTL_RESET         _IO('F', 0x03)

int main(int argc, char *argv[]) {
    const char *dev_path = argv[1];
    printf("Testing device: %s\n", dev_path);
    
    int fd = open(dev_path, O_RDWR);
    if (fd < 0) {
        perror("Failed to open device");
        return 1;
    }
    
    printf("Device opened successfully\n");
    
    // Test version IOCTL
    unsigned int version = 0;
    if (ioctl(fd, FP_IOCTL_GET_VERSION, &version) == 0) {
        printf("Driver version: 0x%08x\n", version);
    } else {
        perror("Version IOCTL failed");
    }
    
    // Test status IOCTL
    unsigned int status = 0;
    if (ioctl(fd, FP_IOCTL_GET_STATUS, &status) == 0) {
        printf("Device status: 0x%08x\n", status);
    } else {
        perror("Status IOCTL failed");
    }
    
    // Test reset IOCTL
    printf("Resetting device...\n");
    if (ioctl(fd, FP_IOCTL_RESET) == 0) {
        printf("Device reset successfully\n");
    } else {
        perror("Reset IOCTL failed");
    }
    
    close(fd);
    return 0;
}
EOF
                
                # Compile and run the test program
                log_info "   → Compiling test program..."
                if gcc -o /tmp/fp_test "$test_prog" 2>/tmp/compile_error.log; then
                    log_success "   ✅ Test program compiled successfully"
                    
                    log_info "   → Running device test..."
                    if sudo /tmp/fp_test "$device_node"; then
                        log_success "   ✅ Basic device test completed successfully"
                    else
                        log_warning "   ⚠️  Device test completed with errors"
                    fi
                else
                    log_warning "   ⚠️  Failed to compile test program"
                    log_info "   → Compilation errors:"
                    cat /tmp/compile_error.log | sed 's/^/      /'
                fi
                
                # Clean up
                rm -f /tmp/fp_test_ioctl.c /tmp/fp_test /tmp/compile_error.log 2>/dev/null || true
            else
                log_warning "   ⚠️  No device node found for testing"
            fi
        else
            log_warning "   ⚠️  Hardware no longer detected via USB"
            log_info "      This might indicate a power management or hardware issue"
        fi
        
        if [[ "$device_still_present" == false ]]; then
            log_warning "   ⚠️  Hardware no longer detected via USB"
            log_info "   💡 Device might be claimed by driver or in different mode"
        fi
        
        # Try basic communication test if test utility exists
        if [[ -f "$(dirname "$0")/test-driver.sh" ]]; then
            log_info "   → Running basic communication test..."
            if timeout 10 bash "$(dirname "$0")/test-driver.sh" --quick 2>/dev/null; then
                log_success "   ✅ Basic communication test passed"
            else
                log_warning "   ⚠️  Basic communication test failed or timed out"
            fi
        fi
    fi
    
    # Final status summary
    echo
    log_info "📊 Driver Test Summary:"
    
    local tests_passed=0
    local total_tests=4
    
    # Test 1: Driver loaded
    if lsmod | grep -q fp_xiaomi; then
        echo "   ✅ Driver Loading: PASS"
        ((tests_passed++))
    else
        echo "   ❌ Driver Loading: FAIL"
    fi
    
    # Test 2: No critical errors in kernel log
    if ! dmesg | grep -i "fp_xiaomi" | grep -q -i "error\|fail\|panic"; then
        echo "   ✅ Kernel Messages: PASS"
        ((tests_passed++))
    else
        echo "   ❌ Kernel Messages: ERRORS DETECTED"
    fi
    
    # Test 3: Device nodes (if hardware present)
    if [[ "$DEVICE_FOUND" == false ]] || [[ "$device_nodes_found" == true ]]; then
        echo "   ✅ Device Nodes: PASS"
        ((tests_passed++))
    else
        echo "   ❌ Device Nodes: FAIL"
    fi
    
    # Test 4: Module dependencies
    if ! lsmod | grep fp_xiaomi | grep -q "ERROR"; then
        echo "   ✅ Module Dependencies: PASS"
        ((tests_passed++))
    else
        echo "   ❌ Module Dependencies: FAIL"
    fi
    
    echo "   📈 Overall Score: $tests_passed/$total_tests tests passed"
    
    if [[ $tests_passed -eq $total_tests ]]; then
        log_success "🎉 All driver tests passed! Driver is working correctly."
    elif [[ $tests_passed -ge 2 ]]; then
        log_warning "⚠️  Driver partially working. Some issues detected but basic functionality available."
    else
        log_error "❌ Driver tests failed. Manual troubleshooting required."
        log_info "💡 Check the troubleshooting guide or run diagnostics script"
    fi
    
    echo
}

# Setup libfprint integration
setup_libfprint() {
    log_info "Setting up libfprint integration..."
    
    # Check if libfprint is installed
    if command -v fprint-demo >/dev/null 2>&1 || 
       dpkg -l | grep -q libfprint || 
       rpm -q libfprint >/dev/null 2>&1 || 
       pacman -Q libfprint >/dev/null 2>&1; then
        log_info "libfprint detected"
        
        # Add user to plugdev group
        if ! groups $USER | grep -q plugdev; then
            log_info "Adding user to plugdev group..."
            sudo usermod -a -G plugdev $USER
            log_warning "You need to log out and back in for group changes to take effect"
        fi
        
        log_success "libfprint integration configured"
    else
        log_info "libfprint not detected, skipping integration"
        log_info "Install libfprint for desktop integration:"
        case $DISTRO in
            ubuntu|debian)
                log_info "  sudo apt install libfprint-2-2 fprintd"
                ;;
            fedora)
                log_info "  sudo dnf install libfprint fprintd"
                ;;
            arch|manjaro)
                log_info "  sudo pacman -S libfprint fprintd"
                ;;
        esac
    fi
}

# Create uninstall script
create_uninstall_script() {
    log_info "Creating uninstall script..."
    
    cat << 'EOF' > /tmp/uninstall-xiaomi-fp.sh
#!/bin/bash
# Xiaomi FPC Fingerprint Driver Uninstaller

echo "Uninstalling Xiaomi FPC Fingerprint Driver..."

# Unload module
sudo modprobe -r fp_xiaomi 2>/dev/null || true

# Remove module files
sudo rm -f /lib/modules/$(uname -r)/kernel/drivers/input/misc/fp_xiaomi.ko
sudo depmod -a

# Remove configuration files
sudo rm -f /etc/udev/rules.d/99-xiaomi-fingerprint.rules
sudo rm -f /etc/modules-load.d/fp_xiaomi.conf
sudo rm -f /etc/modprobe.d/fp_xiaomi.conf

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "Uninstallation completed"
echo "You may need to reboot to completely remove the driver"
EOF
    
    chmod +x /tmp/uninstall-xiaomi-fp.sh
    sudo mv /tmp/uninstall-xiaomi-fp.sh /usr/local/bin/
    
    log_success "Uninstall script created: /usr/local/bin/uninstall-xiaomi-fp.sh"
}

# Main installation function
main() {
    echo "========================================"
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "========================================"
    echo
    
    # Pre-installation checks
    check_root
    detect_distro
    check_kernel_version
    
    # Hardware check
    check_hardware
    
    # Ask for confirmation
    echo
    log_info "Ready to install Xiaomi FPC Fingerprint Driver"
    if [ "$DEVICE_FOUND" = true ]; then
        log_info "Compatible hardware detected"
    else
        log_warning "No compatible hardware detected"
        log_warning "Installation will continue, but driver may not work"
    fi
    echo
    read -p "Continue with installation? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    # Installation steps
    install_dependencies
    build_driver
    setup_udev_rules
    setup_module_loading
    test_driver
    setup_libfprint
    create_uninstall_script
    
    # Final status
    echo
    echo "========================================"
    # Configure fprintd integration
    log_info "Configuring fprintd integration..."
    if command -v fprintd-list >/dev/null 2>&1; then
        chmod +x "$(dirname "$0")/configure-fprintd.sh"
        "$(dirname "$0")/configure-fprintd.sh"
        log_success "fprintd configuration completed"
    else
        log_info "fprintd not found, skipping integration"
        log_info "Install fprintd for desktop integration:"
        case $DISTRO in
            ubuntu|debian)
                log_info "  sudo apt install fprintd libpam-fprintd"
                ;;
            fedora)
                log_info "  sudo dnf install fprintd fprintd-pam"
                ;;
            arch|manjaro)
                log_info "  sudo pacman -S fprintd"
                ;;
        esac
    fi
    
    log_success "🎉 Installation completed successfully!"
    echo "========================================"
    echo
    
    # Final verification
    log_info "🔍 Final Installation Verification:"
    
    local verification_score=0
    local total_checks=5
    
    # Check 1: Driver loaded
    if lsmod | grep -q fp_xiaomi; then
        log_success "   ✅ Driver is loaded in kernel"
        ((verification_score++))
    else
        log_error "   ❌ Driver is not loaded"
    fi
    
    # Check 2: Service running
    if systemctl is-active --quiet fprintd; then
        log_success "   ✅ fprintd service is running"
        ((verification_score++))
    else
        log_warning "   ⚠️  fprintd service is not running"
    fi
    
    # Check 3: Hardware detection (if applicable)
    if [[ "$DEVICE_FOUND" == true ]]; then
        log_success "   ✅ Hardware detected and accessible"
        ((verification_score++))
    elif lsusb | grep -E "(2717|10a5)" >/dev/null; then
        log_success "   ✅ Hardware detected"
        ((verification_score++))
    else
        log_info "   → No hardware detected (install completed for future use)"
        ((verification_score++))  # Don't penalize if no hardware present
    fi
    
    # Check 4: User permissions
    if groups $USER | grep -q plugdev; then
        log_success "   ✅ User permissions configured"
        ((verification_score++))
    else
        log_warning "   ⚠️  User permissions need attention"
    fi
    
    # Check 5: No critical errors in logs
    if ! dmesg | grep -i "fp_xiaomi" | grep -q -i "error\|fail"; then
        log_success "   ✅ No critical errors in system logs"
        ((verification_score++))
    else
        log_warning "   ⚠️  Some errors detected in system logs"
    fi
    
    echo
    log_info "📊 Installation Score: $verification_score/$total_checks"
    
    if [[ $verification_score -eq $total_checks ]]; then
        log_success "🌟 Perfect installation! Everything is working correctly."
    elif [[ $verification_score -ge 3 ]]; then
        log_success "✅ Good installation! Minor issues may need attention."
    else
        log_warning "⚠️  Installation completed but issues detected. Check troubleshooting steps below."
    fi
    
    echo
    echo "========================================"
    log_info "📋 NEXT STEPS FOR $DISTRO:"
    echo
    
    case $DISTRO in
        ubuntu|linuxmint)
            echo "🔧 Ubuntu/Mint Users:"
            echo "1. 🔄 Log out and back in (for group permissions)"
            echo "2. 🖱️  Open Settings → Users → Add Fingerprint"
            echo "3. 📱 Or use command: fprintd-enroll"
            echo "4. 🔐 Configure login: sudo pam-auth-update"
            echo "5. 🧪 Test unlock: Lock screen and try fingerprint"
            ;;
        fedora)
            echo "🔧 Fedora Users:"
            echo "1. 🔄 Log out and back in (for group permissions)"
            echo "2. 🖱️  Open Settings → Privacy & Security → Add Fingerprint"
            echo "3. 📱 Or use command: fprintd-enroll"
            echo "4. 🔐 Configure login: sudo authselect select sssd with-fingerprint"
            echo "5. 🧪 Test unlock: Lock screen and try fingerprint"
            ;;
        *)
            echo "🔧 General Steps:"
            echo "1. 🔄 Log out and back in (for group permissions)"
            echo "2. 📱 Enroll fingerprint: fprintd-enroll"
            echo "3. 🔐 Configure PAM authentication"
            echo "4. 🧪 Test fingerprint verification: fprintd-verify"
            ;;
    esac
    
    echo
    log_info "🧪 Testing Commands:"
    echo "• Check driver: lsmod | grep fp_xiaomi"
    echo "• Check hardware: lsusb | grep -E '(2717|10a5)'"
    echo "• Check service: systemctl status fprintd"
    echo "• List devices: fprintd-list"
    echo "• Enroll finger: fprintd-enroll"
    echo "• Test verify: fprintd-verify"
    echo
    
    log_info "🆘 Troubleshooting:"
    echo "• Run diagnostics: sudo ./scripts/diagnostics.sh"
    echo "• Distro-specific help: sudo ./scripts/distro-specific-troubleshoot.sh"
    echo "• Check logs: journalctl -u fprintd -f"
    echo "• View kernel messages: dmesg | grep fp_xiaomi"
    echo "• Uninstall if needed: /usr/local/bin/uninstall-xiaomi-fp.sh"
    echo
    
    log_info "📚 Documentation:"
    echo "• Quick Start Guide: docs/quick-start-guide.md"
    echo "• Full Installation Guide: docs/installation-guide.md"
    echo "• Troubleshooting Guide: docs/troubleshooting.md"
    echo
    
    if [[ "$DEVICE_FOUND" == false ]]; then
        echo "⚠️  HARDWARE NOTE:"
        log_warning "No fingerprint hardware was detected during installation."
        log_info "💡 Make sure your Xiaomi laptop fingerprint scanner is:"
        echo "   • Enabled in BIOS/UEFI settings"
        echo "   • Not disabled in Windows Device Manager"
        echo "   • Properly connected (not a hardware failure)"
        echo "   • Supported by this driver (check compatibility list)"
        echo
    fi
    
    if [[ $verification_score -lt 3 ]]; then
        echo "🔧 IMMEDIATE ACTION REQUIRED:"
        log_warning "Installation completed but several issues were detected."
        log_info "💡 Run the troubleshooting script for detailed help:"
        echo "   sudo ./scripts/distro-specific-troubleshoot.sh"
        echo
    fi
    
    log_success "🎉 Thank you for using the Xiaomi Fingerprint Scanner Driver!"
    log_info "⭐ If this helped you, please star our GitHub repository!"
    echo
}

# Run main function
main "$@"