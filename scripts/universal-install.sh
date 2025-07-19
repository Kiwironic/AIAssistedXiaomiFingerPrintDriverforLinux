#!/bin/bash

# Universal Installation Script for Xiaomi Fingerprint Scanner Driver
# Automatically detects Linux distribution and installs appropriate packages

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/fp_xiaomi_universal_install.log"
TEMP_DIR="/tmp/fp_xiaomi_install_$$"
GITHUB_REPO="https://github.com/your-repo/xiaomi-fingerprint-driver.git"

# Installation options
FORCE_INSTALL=false
SKIP_TESTS=false
ENABLE_DEBUG=false
INSTALL_FALLBACK=true
AUTO_CONFIGURE=true

# Distribution detection variables
DISTRO=""
DISTRO_VERSION=""
PACKAGE_MANAGER=""
INIT_SYSTEM=""

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
    log "$message"
}

# Print section header
print_section() {
    local title=$1
    echo ""
    print_status "$CYAN" "═══════════════════════════════════════════════════════════════"
    print_status "$CYAN" "  $title"
    print_status "$CYAN" "═══════════════════════════════════════════════════════════════"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Universal Installation Script for Xiaomi Fingerprint Scanner Driver

OPTIONS:
    -f, --force         Force installation even if incompatible
    -s, --skip-tests    Skip hardware compatibility tests
    -d, --debug         Enable debug mode
    --no-fallback       Don't install fallback system
    --no-configure      Don't auto-configure services
    -h, --help          Show this help message

EXAMPLES:
    $0                  # Standard installation
    $0 -f -d            # Force install with debug
    $0 --skip-tests     # Skip compatibility checks

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_INSTALL=true
            shift
            ;;
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -d|--debug)
            ENABLE_DEBUG=true
            shift
            ;;
        --no-fallback)
            INSTALL_FALLBACK=false
            shift
            ;;
        --no-configure)
            AUTO_CONFIGURE=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Initialize log
echo "=== Xiaomi Fingerprint Scanner Universal Installation ===" > "$LOG_FILE"
log "Starting universal installation at $(date)"
log "Options: Force=$FORCE_INSTALL, Skip Tests=$SKIP_TESTS, Debug=$ENABLE_DEBUG"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_status "$RED" "❌ This script must be run as root or with sudo"
        print_status "$YELLOW" "💡 Try: sudo $0"
        exit 1
    fi
}

# Detect Linux distribution
detect_distribution() {
    print_section "DETECTING LINUX DISTRIBUTION"
    
    # Check for systemd
    if command -v systemctl >/dev/null 2>&1; then
        INIT_SYSTEM="systemd"
    elif command -v service >/dev/null 2>&1; then
        INIT_SYSTEM="sysv"
    else
        INIT_SYSTEM="unknown"
    fi
    
    # Detect distribution
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO="$ID"
        DISTRO_VERSION="$VERSION_ID"
        
        print_status "$GREEN" "✅ Detected: $PRETTY_NAME"
        log "Distribution: $DISTRO $DISTRO_VERSION"
        log "Init system: $INIT_SYSTEM"
        
    elif [[ -f /etc/redhat-release ]]; then
        if grep -q "CentOS" /etc/redhat-release; then
            DISTRO="centos"
        elif grep -q "Red Hat" /etc/redhat-release; then
            DISTRO="rhel"
        elif grep -q "Fedora" /etc/redhat-release; then
            DISTRO="fedora"
        fi
        DISTRO_VERSION=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
        
    elif [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
        DISTRO_VERSION=$(cat /etc/debian_version)
        
    else
        print_status "$RED" "❌ Unable to detect Linux distribution"
        if [[ $FORCE_INSTALL == false ]]; then
            exit 1
        else
            print_status "$YELLOW" "⚠️  Continuing with force install..."
            DISTRO="unknown"
        fi
    fi
    
    # Detect package manager
    if command -v apt >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
    elif command -v zypper >/dev/null 2>&1; then
        PACKAGE_MANAGER="zypper"
    elif command -v pacman >/dev/null 2>&1; then
        PACKAGE_MANAGER="pacman"
    elif command -v emerge >/dev/null 2>&1; then
        PACKAGE_MANAGER="emerge"
    elif command -v apk >/dev/null 2>&1; then
        PACKAGE_MANAGER="apk"
    elif command -v xbps-install >/dev/null 2>&1; then
        PACKAGE_MANAGER="xbps"
    else
        print_status "$RED" "❌ Unable to detect package manager"
        if [[ $FORCE_INSTALL == false ]]; then
            exit 1
        fi
    fi
    
    print_status "$BLUE" "📦 Package Manager: $PACKAGE_MANAGER"
    print_status "$BLUE" "🔧 Init System: $INIT_SYSTEM"
}

# Install dependencies based on distribution
install_dependencies() {
    print_section "INSTALLING DEPENDENCIES"
    
    case "$PACKAGE_MANAGER" in
        apt)
            install_apt_dependencies
            ;;
        dnf)
            install_dnf_dependencies
            ;;
        yum)
            install_yum_dependencies
            ;;
        zypper)
            install_zypper_dependencies
            ;;
        pacman)
            install_pacman_dependencies
            ;;
        emerge)
            install_emerge_dependencies
            ;;
        apk)
            install_apk_dependencies
            ;;
        xbps)
            install_xbps_dependencies
            ;;
        *)
            print_status "$RED" "❌ Unsupported package manager: $PACKAGE_MANAGER"
            exit 1
            ;;
    esac
}

# APT-based distributions (Ubuntu, Debian, Mint)
install_apt_dependencies() {
    print_status "$BLUE" "📦 Installing APT packages..."
    
    # Update package list
    apt update
    
    # Install build dependencies
    apt install -y build-essential linux-headers-$(uname -r) git cmake
    apt install -y libusb-1.0-0-dev libfprint-2-dev fprintd
    apt install -y dkms udev pkg-config
    
    # Distribution-specific packages
    case "$DISTRO" in
        ubuntu)
            apt install -y software-properties-common
            ;;
        debian)
            apt install -y module-assistant
            m-a prepare
            ;;
        linuxmint)
            apt install -y mintupdate
            ;;
    esac
    
    print_status "$GREEN" "✅ APT dependencies installed"
}

# DNF-based distributions (Fedora, RHEL 8+, Rocky, Alma)
install_dnf_dependencies() {
    print_status "$BLUE" "📦 Installing DNF packages..."
    
    # Enable EPEL for RHEL-based distributions
    if [[ "$DISTRO" =~ ^(rhel|centos|rocky|almalinux)$ ]]; then
        dnf install -y epel-release
        
        # Enable CRB/PowerTools for RHEL 9+
        if [[ "$DISTRO_VERSION" -ge 9 ]]; then
            dnf config-manager --set-enabled crb 2>/dev/null || \
            dnf config-manager --set-enabled powertools 2>/dev/null || true
        fi
    fi
    
    # Install development tools
    dnf groupinstall -y "Development Tools"
    dnf install -y kernel-devel kernel-headers git cmake
    dnf install -y libusb1-devel libfprint-devel fprintd
    dnf install -y dkms systemd-udev
    
    print_status "$GREEN" "✅ DNF dependencies installed"
}

# YUM-based distributions (CentOS 7, older RHEL)
install_yum_dependencies() {
    print_status "$BLUE" "📦 Installing YUM packages..."
    
    # Enable EPEL
    yum install -y epel-release
    
    # Install development tools
    yum groupinstall -y "Development Tools"
    yum install -y kernel-devel-$(uname -r) git cmake3
    yum install -y libusb1-devel libfprint-devel fprintd
    
    # Create cmake symlink for cmake3
    if [[ ! -f /usr/bin/cmake && -f /usr/bin/cmake3 ]]; then
        ln -sf /usr/bin/cmake3 /usr/bin/cmake
    fi
    
    print_status "$GREEN" "✅ YUM dependencies installed"
}

# Zypper-based distributions (openSUSE)
install_zypper_dependencies() {
    print_status "$BLUE" "📦 Installing Zypper packages..."
    
    # Install development pattern
    zypper install -y -t pattern devel_basis
    zypper install -y kernel-default-devel git cmake
    zypper install -y libusb-1_0-devel libfprint-devel fprintd
    zypper install -y dkms udev
    
    print_status "$GREEN" "✅ Zypper dependencies installed"
}

# Pacman-based distributions (Arch, Manjaro)
install_pacman_dependencies() {
    print_status "$BLUE" "📦 Installing Pacman packages..."
    
    # Update system
    pacman -Syu --noconfirm
    
    # Install base development packages
    pacman -S --needed --noconfirm base-devel linux-headers git cmake
    pacman -S --noconfirm libusb libfprint fprintd
    pacman -S --noconfirm dkms
    
    print_status "$GREEN" "✅ Pacman dependencies installed"
}

# Emerge-based distributions (Gentoo)
install_emerge_dependencies() {
    print_status "$BLUE" "📦 Installing Emerge packages..."
    
    # Ensure kernel sources are available
    emerge --ask=n sys-kernel/gentoo-sources
    
    # Install dependencies
    emerge --ask=n dev-vcs/git dev-util/cmake
    emerge --ask=n dev-libs/libusb sys-auth/libfprint sys-auth/fprintd
    
    print_status "$GREEN" "✅ Emerge dependencies installed"
}

# APK-based distributions (Alpine)
install_apk_dependencies() {
    print_status "$BLUE" "📦 Installing APK packages..."
    
    # Install development packages
    apk add build-base linux-headers git cmake
    apk add libusb-dev libfprint-dev fprintd
    apk add eudev
    
    print_status "$GREEN" "✅ APK dependencies installed"
}

# XBPS-based distributions (Void Linux)
install_xbps_dependencies() {
    print_status "$BLUE" "📦 Installing XBPS packages..."
    
    # Install development packages
    xbps-install -S base-devel linux-headers git cmake
    xbps-install -S libusb-devel libfprint-devel fprintd
    
    print_status "$GREEN" "✅ XBPS dependencies installed"
}

# Download or use existing source code
prepare_source_code() {
    print_section "PREPARING SOURCE CODE"
    
    if [[ -d "$PROJECT_ROOT/src" && -f "$PROJECT_ROOT/src/fp_xiaomi_driver.c" ]]; then
        print_status "$GREEN" "✅ Using existing source code"
        cd "$PROJECT_ROOT"
    else
        print_status "$BLUE" "📥 Downloading source code..."
        
        # Create temporary directory
        mkdir -p "$TEMP_DIR"
        cd "$TEMP_DIR"
        
        # Clone repository
        git clone "$GITHUB_REPO" xiaomi-fingerprint-driver
        cd xiaomi-fingerprint-driver
        
        PROJECT_ROOT="$(pwd)"
    fi
    
    log "Source code location: $PROJECT_ROOT"
}

# Run hardware compatibility check
run_compatibility_check() {
    if [[ $SKIP_TESTS == true ]]; then
        print_status "$YELLOW" "⚠️  Skipping hardware compatibility check"
        return 0
    fi
    
    print_section "HARDWARE COMPATIBILITY CHECK"
    
    if [[ -f "$PROJECT_ROOT/scripts/hardware-compatibility-check.sh" ]]; then
        bash "$PROJECT_ROOT/scripts/hardware-compatibility-check.sh" -v
        local check_result=$?
        
        if [[ $check_result -ne 0 && $FORCE_INSTALL == false ]]; then
            print_status "$RED" "❌ Hardware compatibility check failed"
            print_status "$YELLOW" "💡 Use --force to install anyway"
            exit 1
        elif [[ $check_result -ne 0 ]]; then
            print_status "$YELLOW" "⚠️  Hardware compatibility issues detected, but continuing with force install"
        fi
    else
        print_status "$YELLOW" "⚠️  Compatibility check script not found, skipping"
    fi
}

# Compile and install driver
compile_and_install_driver() {
    print_section "COMPILING AND INSTALLING DRIVER"
    
    cd "$PROJECT_ROOT/src"
    
    # Clean previous builds
    make clean 2>/dev/null || true
    
    # Compile driver
    print_status "$BLUE" "🔨 Compiling driver..."
    if [[ $ENABLE_DEBUG == true ]]; then
        make DEBUG=1
    else
        make
    fi
    
    # Install driver
    print_status "$BLUE" "📦 Installing driver..."
    make install
    
    # Update module dependencies
    depmod -a
    
    print_status "$GREEN" "✅ Driver compiled and installed"
}

# Install udev rules
install_udev_rules() {
    print_section "INSTALLING UDEV RULES"
    
    local udev_rules_file="$PROJECT_ROOT/udev/60-fp-xiaomi.rules"
    
    if [[ -f "$udev_rules_file" ]]; then
        cp "$udev_rules_file" /etc/udev/rules.d/
        
        # Reload udev rules
        udevadm control --reload-rules
        udevadm trigger
        
        print_status "$GREEN" "✅ Udev rules installed"
    else
        print_status "$YELLOW" "⚠️  Udev rules file not found, creating basic rules"
        
        cat > /etc/udev/rules.d/60-fp-xiaomi.rules << 'EOF'
# Xiaomi Fingerprint Scanner
SUBSYSTEM=="usb", ATTRS{idVendor}=="2717", ATTRS{idProduct}=="0368", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="2717", ATTRS{idProduct}=="0369", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="2717", ATTRS{idProduct}=="036a", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="2717", ATTRS{idProduct}=="036b", MODE="0666", GROUP="plugdev"
EOF
        
        udevadm control --reload-rules
        udevadm trigger
        
        print_status "$GREEN" "✅ Basic udev rules created"
    fi
}

# Load driver module
load_driver_module() {
    print_section "LOADING DRIVER MODULE"
    
    # Unload existing module if loaded
    rmmod fp_xiaomi_driver 2>/dev/null || true
    
    # Load new module
    if [[ $ENABLE_DEBUG == true ]]; then
        modprobe fp_xiaomi_driver debug=1
    else
        modprobe fp_xiaomi_driver
    fi
    
    # Verify module is loaded
    if lsmod | grep -q fp_xiaomi_driver; then
        print_status "$GREEN" "✅ Driver module loaded successfully"
    else
        print_status "$RED" "❌ Failed to load driver module"
        
        # Show kernel messages for debugging
        print_status "$BLUE" "📋 Recent kernel messages:"
        dmesg | tail -20 | grep -E "(fp_xiaomi|usb|fingerprint)" || true
        
        if [[ $FORCE_INSTALL == false ]]; then
            exit 1
        fi
    fi
}

# Configure services
configure_services() {
    if [[ $AUTO_CONFIGURE == false ]]; then
        print_status "$YELLOW" "⚠️  Skipping service configuration"
        return 0
    fi
    
    print_section "CONFIGURING SERVICES"
    
    # Configure fprintd
    if [[ -f "$PROJECT_ROOT/scripts/configure-fprintd.sh" ]]; then
        bash "$PROJECT_ROOT/scripts/configure-fprintd.sh"
    else
        print_status "$BLUE" "🔧 Basic fprintd configuration..."
        
        # Enable and start fprintd service
        if [[ "$INIT_SYSTEM" == "systemd" ]]; then
            systemctl enable fprintd.service
            systemctl start fprintd.service
            
            # Check service status
            if systemctl is-active --quiet fprintd.service; then
                print_status "$GREEN" "✅ fprintd service is running"
            else
                print_status "$YELLOW" "⚠️  fprintd service is not running"
            fi
        fi
    fi
    
    # Configure PAM (basic configuration)
    print_status "$BLUE" "🔐 Configuring PAM authentication..."
    
    case "$DISTRO" in
        ubuntu|debian|linuxmint)
            if command -v pam-auth-update >/dev/null 2>&1; then
                print_status "$BLUE" "💡 Run 'sudo pam-auth-update' to configure fingerprint authentication"
            fi
            ;;
        fedora|rhel|centos|rocky|almalinux)
            if command -v authselect >/dev/null 2>&1; then
                print_status "$BLUE" "💡 Run 'sudo authselect select sssd with-fingerprint' to configure authentication"
            fi
            ;;
    esac
}

# Install fallback system
install_fallback_system() {
    if [[ $INSTALL_FALLBACK == false ]]; then
        print_status "$YELLOW" "⚠️  Skipping fallback system installation"
        return 0
    fi
    
    print_section "INSTALLING FALLBACK SYSTEM"
    
    if [[ -f "$PROJECT_ROOT/scripts/fallback-driver.sh" ]]; then
        bash "$PROJECT_ROOT/scripts/fallback-driver.sh" install
        print_status "$GREEN" "✅ Fallback system installed"
    else
        print_status "$YELLOW" "⚠️  Fallback system script not found"
    fi
}

# Run post-installation tests
run_post_install_tests() {
    if [[ $SKIP_TESTS == true ]]; then
        print_status "$YELLOW" "⚠️  Skipping post-installation tests"
        return 0
    fi
    
    print_section "POST-INSTALLATION TESTS"
    
    # Test driver functionality
    if [[ -f "$PROJECT_ROOT/scripts/test-driver.sh" ]]; then
        bash "$PROJECT_ROOT/scripts/test-driver.sh"
    else
        print_status "$BLUE" "🧪 Basic functionality test..."
        
        # Check if device is detected
        if lsusb | grep -q "2717:"; then
            print_status "$GREEN" "✅ Device detection: PASS"
        else
            print_status "$YELLOW" "⚠️  Device detection: No device found"
        fi
        
        # Check if driver is loaded
        if lsmod | grep -q fp_xiaomi; then
            print_status "$GREEN" "✅ Driver loading: PASS"
        else
            print_status "$RED" "❌ Driver loading: FAIL"
        fi
        
        # Check device node
        if [[ -c /dev/fp_xiaomi0 ]]; then
            print_status "$GREEN" "✅ Device node: PASS"
        else
            print_status "$YELLOW" "⚠️  Device node: Not found"
        fi
    fi
}

# Generate installation report
generate_installation_report() {
    print_section "INSTALLATION REPORT"
    
    local report_file="/tmp/xiaomi_fp_installation_report.txt"
    
    cat > "$report_file" << EOF
=== Xiaomi Fingerprint Scanner Installation Report ===
Installation Date: $(date)
Distribution: $DISTRO $DISTRO_VERSION
Package Manager: $PACKAGE_MANAGER
Init System: $INIT_SYSTEM

Installation Options:
- Force Install: $FORCE_INSTALL
- Skip Tests: $SKIP_TESTS
- Debug Mode: $ENABLE_DEBUG
- Install Fallback: $INSTALL_FALLBACK
- Auto Configure: $AUTO_CONFIGURE

Hardware Status:
$(lsusb | grep "2717:" || echo "No Xiaomi devices detected")

Driver Status:
$(lsmod | grep fp_xiaomi || echo "Driver not loaded")

Service Status:
$(systemctl is-active fprintd.service 2>/dev/null || echo "fprintd status unknown")

Next Steps:
1. Test fingerprint enrollment: fprintd-enroll
2. Test fingerprint verification: fprintd-verify
3. Configure PAM for login authentication
4. Check documentation for advanced configuration

Troubleshooting:
- Full installation log: $LOG_FILE
- Run diagnostics: sudo bash $PROJECT_ROOT/scripts/diagnostics.sh
- Check hardware compatibility: sudo bash $PROJECT_ROOT/scripts/hardware-compatibility-check.sh

EOF
    
    print_status "$GREEN" "✅ Installation report generated: $report_file"
    
    # Display summary
    echo ""
    print_status "$CYAN" "📋 INSTALLATION SUMMARY"
    echo "  Distribution: $DISTRO $DISTRO_VERSION"
    echo "  Package Manager: $PACKAGE_MANAGER"
    echo "  Driver Status: $(lsmod | grep -q fp_xiaomi && echo "Loaded" || echo "Not Loaded")"
    echo "  Device Status: $(lsusb | grep -q "2717:" && echo "Detected" || echo "Not Detected")"
    echo "  Report File: $report_file"
    echo "  Log File: $LOG_FILE"
}

# Cleanup temporary files
cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log "Cleaned up temporary directory: $TEMP_DIR"
    fi
}

# Main installation function
main() {
    print_status "$PURPLE" "🚀 Starting Xiaomi Fingerprint Scanner Universal Installation"
    
    # Trap cleanup on exit
    trap cleanup EXIT
    
    # Check prerequisites
    check_root
    
    # Detect system
    detect_distribution
    
    # Prepare source code
    prepare_source_code
    
    # Run compatibility check
    run_compatibility_check
    
    # Install dependencies
    install_dependencies
    
    # Compile and install driver
    compile_and_install_driver
    
    # Install udev rules
    install_udev_rules
    
    # Load driver module
    load_driver_module
    
    # Configure services
    configure_services
    
    # Install fallback system
    install_fallback_system
    
    # Run tests
    run_post_install_tests
    
    # Generate report
    generate_installation_report
    
    print_status "$GREEN" "🎉 Installation completed successfully!"
    print_status "$BLUE" "💡 Next steps:"
    echo "  1. Enroll your fingerprint: fprintd-enroll"
    echo "  2. Test verification: fprintd-verify"
    echo "  3. Configure login authentication (see installation guide)"
    echo "  4. Read the documentation for advanced features"
}

# Run main function
main "$@"