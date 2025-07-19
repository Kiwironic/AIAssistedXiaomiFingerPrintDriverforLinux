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

# Install build dependencies
install_dependencies() {
    log_info "Installing build dependencies..."
    
    case $DISTRO in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y \
                build-essential \
                linux-headers-$(uname -r) \
                dkms \
                git \
                wget \
                curl
            ;;
        fedora)
            sudo dnf install -y \
                kernel-devel \
                kernel-headers \
                gcc \
                make \
                dkms \
                git \
                wget \
                curl
            ;;
        centos|rhel)
            sudo yum install -y \
                kernel-devel \
                kernel-headers \
                gcc \
                make \
                dkms \
                git \
                wget \
                curl
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm \
                linux-headers \
                base-devel \
                dkms \
                git \
                wget \
                curl
            ;;
        opensuse*)
            sudo zypper install -y \
                kernel-devel \
                gcc \
                make \
                dkms \
                git \
                wget \
                curl
            ;;
        *)
            log_warning "Unknown distribution: $DISTRO"
            log_warning "Please install build dependencies manually:"
            log_warning "- kernel headers"
            log_warning "- build-essential/gcc/make"
            log_warning "- dkms (optional)"
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
    
    log_success "Dependencies installed successfully"
}

# Check hardware compatibility
check_hardware() {
    log_info "Checking hardware compatibility..."
    
    # Check for FPC device
    if lsusb | grep -q "10a5:9201"; then
        log_success "FPC Fingerprint Reader (10a5:9201) detected"
        DEVICE_FOUND=true
    else
        log_warning "FPC Fingerprint Reader not detected"
        log_warning "Make sure your Xiaomi laptop has the fingerprint scanner enabled"
        DEVICE_FOUND=false
    fi
    
    # Check for existing drivers
    if lsmod | grep -q "fp_xiaomi"; then
        log_warning "Driver already loaded, will reload"
        sudo modprobe -r fp_xiaomi || true
    fi
    
    # Check for conflicting drivers
    CONFLICTING_DRIVERS=("fpc1020" "fpc1155" "validity" "synaptics")
    for driver in "${CONFLICTING_DRIVERS[@]}"; do
        if lsmod | grep -q "$driver"; then
            log_warning "Conflicting driver detected: $driver"
            log_warning "You may need to blacklist it"
        fi
    done
}

# Build and install driver
build_driver() {
    log_info "Building Xiaomi FPC Fingerprint Driver..."
    
    # Navigate to source directory
    cd "$(dirname "$0")/../src"
    
    # Clean previous builds
    make clean >/dev/null 2>&1 || true
    
    # Build the driver
    if make modules; then
        log_success "Driver built successfully"
    else
        log_error "Driver build failed"
        log_error "Check the error messages above"
        exit 1
    fi
    
    # Install the driver
    log_info "Installing driver..."
    if sudo make install; then
        log_success "Driver installed successfully"
    else
        log_error "Driver installation failed"
        exit 1
    fi
}

# Configure udev rules
setup_udev_rules() {
    log_info "Setting up udev rules..."
    
    cat << 'EOF' | sudo tee /etc/udev/rules.d/99-xiaomi-fingerprint.rules >/dev/null
# Xiaomi FPC Fingerprint Scanner udev rules
# Allow users in plugdev group to access the device

SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", MODE="0664", GROUP="plugdev"
KERNEL=="fp_xiaomi*", MODE="0664", GROUP="plugdev"

# Auto-load driver when device is connected
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", RUN+="/sbin/modprobe fp_xiaomi"
EOF
    
    # Reload udev rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    
    log_success "Udev rules configured"
}

# Configure module loading
setup_module_loading() {
    log_info "Configuring automatic module loading..."
    
    # Add module to load at boot
    echo "fp_xiaomi" | sudo tee /etc/modules-load.d/fp_xiaomi.conf >/dev/null
    
    # Create modprobe configuration
    cat << 'EOF' | sudo tee /etc/modprobe.d/fp_xiaomi.conf >/dev/null
# Xiaomi FPC Fingerprint Driver configuration
# Prevent conflicting drivers from loading
blacklist fpc1020
blacklist fpc1155

# Driver options (uncomment and modify as needed)
# options fp_xiaomi debug=1
EOF
    
    log_success "Module loading configured"
}

# Load and test driver
test_driver() {
    log_info "Loading and testing driver..."
    
    # Load the driver
    if sudo modprobe fp_xiaomi; then
        log_success "Driver loaded successfully"
    else
        log_error "Failed to load driver"
        log_info "Check dmesg for error messages:"
        dmesg | grep -i "fp_xiaomi" | tail -10
        exit 1
    fi
    
    # Wait for device initialization
    sleep 2
    
    # Check if device node was created
    if [ -c /dev/fp_xiaomi0 ]; then
        log_success "Device node created: /dev/fp_xiaomi0"
        ls -la /dev/fp_xiaomi0
    else
        log_warning "Device node not found"
        log_info "This may be normal if no hardware is connected"
    fi
    
    # Show driver status
    log_info "Driver status:"
    lsmod | grep fp_xiaomi || log_warning "Driver not in lsmod output"
    
    # Show recent kernel messages
    log_info "Recent kernel messages:"
    dmesg | grep -i "fp_xiaomi" | tail -5
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
    log_success "Installation completed successfully!"
    echo "========================================"
    echo
    log_info "Next steps:"
    echo "1. Reboot your system (recommended)"
    echo "2. Test the fingerprint scanner with your desktop environment"
    echo "3. If using libfprint, configure fingerprints with:"
    echo "   - GNOME: Settings > Users > Add fingerprint"
    echo "   - KDE: System Settings > Users > Add fingerprint"
    echo "   - Command line: fprintd-enroll"
    echo
    log_info "Troubleshooting:"
    echo "- Check kernel messages: dmesg | grep fp_xiaomi"
    echo "- Check device status: ls -la /dev/fp_xiaomi*"
    echo "- View driver info: modinfo fp_xiaomi"
    echo "- Uninstall: /usr/local/bin/uninstall-xiaomi-fp.sh"
    echo
    
    if [ "$DEVICE_FOUND" = false ]; then
        log_warning "Hardware not detected during installation"
        log_warning "Make sure your Xiaomi laptop fingerprint scanner is enabled in BIOS"
    fi
}

# Run main function
main "$@"