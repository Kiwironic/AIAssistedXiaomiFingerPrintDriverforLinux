#!/bin/bash

# Distribution-Specific Troubleshooting Script
# Optimized for Ubuntu, Linux Mint, and Fedora

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/fp_xiaomi_troubleshoot.log"

# Print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Print section header
print_section() {
    local title=$1
    echo ""
    print_status "$CYAN" "═══════════════════════════════════════════════════════════════"
    print_status "$CYAN" "  $title"
    print_status "$CYAN" "═══════════════════════════════════════════════════════════════"
}

# Detect distribution
detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO="$ID"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_NAME="$PRETTY_NAME"
    else
        print_status "$RED" "❌ Cannot detect Linux distribution"
        exit 1
    fi
}

# Ubuntu/Mint specific troubleshooting
troubleshoot_ubuntu_mint() {
    print_section "UBUNTU/MINT SPECIFIC TROUBLESHOOTING"
    
    print_status "$BLUE" "🔍 Checking Ubuntu/Mint specific issues..."
    
    # Check repositories
    print_status "$BLUE" "📦 Checking package repositories..."
    
    if apt-cache policy | grep -q "universe"; then
        print_status "$GREEN" "   ✅ Universe repository is enabled"
    else
        print_status "$YELLOW" "   ⚠️  Universe repository not enabled"
        print_status "$BLUE" "   💡 Fix: sudo add-apt-repository universe"
    fi
    
    if apt-cache policy | grep -q "multiverse"; then
        print_status "$GREEN" "   ✅ Multiverse repository is enabled"
    else
        print_status "$YELLOW" "   ⚠️  Multiverse repository not enabled (optional)"
    fi
    
    # Check for broken packages
    print_status "$BLUE" "🔍 Checking for broken packages..."
    local broken_packages=$(dpkg -l | grep "^..r" | wc -l)
    if [[ $broken_packages -eq 0 ]]; then
        print_status "$GREEN" "   ✅ No broken packages found"
    else
        print_status "$RED" "   ❌ Found $broken_packages broken packages"
        print_status "$BLUE" "   💡 Fix: sudo apt --fix-broken install"
    fi
    
    # Check kernel headers
    print_status "$BLUE" "🔍 Checking kernel headers..."
    local current_kernel=$(uname -r)
    if dpkg -l | grep -q "linux-headers-$current_kernel"; then
        print_status "$GREEN" "   ✅ Kernel headers for $current_kernel are installed"
    else
        print_status "$RED" "   ❌ Kernel headers for $current_kernel are missing"
        print_status "$BLUE" "   💡 Fix: sudo apt install linux-headers-$current_kernel"
    fi
    
    # Check build tools
    print_status "$BLUE" "🔍 Checking build tools..."
    local build_tools=("build-essential" "dkms" "git" "cmake")
    for tool in "${build_tools[@]}"; do
        if dpkg -l | grep -q "^ii.*$tool"; then
            print_status "$GREEN" "   ✅ $tool is installed"
        else
            print_status "$RED" "   ❌ $tool is missing"
            print_status "$BLUE" "   💡 Fix: sudo apt install $tool"
        fi
    done
    
    # Check fingerprint packages
    print_status "$BLUE" "🔍 Checking fingerprint packages..."
    local fp_packages=("libfprint-2-2" "fprintd" "libpam-fprintd")
    for package in "${fp_packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$package"; then
            print_status "$GREEN" "   ✅ $package is installed"
        else
            print_status "$YELLOW" "   ⚠️  $package is missing"
            print_status "$BLUE" "   💡 Fix: sudo apt install $package"
        fi
    done
    
    # Check Secure Boot
    print_status "$BLUE" "🔍 Checking Secure Boot status..."
    if command -v mokutil >/dev/null 2>&1; then
        local sb_state=$(mokutil --sb-state 2>/dev/null || echo "unknown")
        if [[ "$sb_state" == *"SecureBoot enabled"* ]]; then
            print_status "$YELLOW" "   ⚠️  Secure Boot is enabled"
            print_status "$BLUE" "   💡 This may prevent unsigned kernel modules from loading"
            print_status "$BLUE" "   💡 Consider disabling Secure Boot or signing the module"
        else
            print_status "$GREEN" "   ✅ Secure Boot is disabled or not supported"
        fi
    else
        print_status "$BLUE" "   → mokutil not available, cannot check Secure Boot status"
    fi
    
    # Check AppArmor
    print_status "$BLUE" "🔍 Checking AppArmor status..."
    if command -v aa-status >/dev/null 2>&1; then
        if aa-status --enabled 2>/dev/null; then
            print_status "$BLUE" "   → AppArmor is enabled"
            local fprintd_profile=$(aa-status | grep fprintd || echo "")
            if [[ -n "$fprintd_profile" ]]; then
                print_status "$BLUE" "   → fprintd AppArmor profile: $fprintd_profile"
            fi
        else
            print_status "$GREEN" "   ✅ AppArmor is disabled"
        fi
    else
        print_status "$BLUE" "   → AppArmor not installed"
    fi
    
    # Ubuntu/Mint specific fixes
    print_status "$BLUE" "🔧 Ubuntu/Mint specific recommendations..."
    
    echo "   Recommended commands to fix common issues:"
    echo "   1. Update package lists: sudo apt update"
    echo "   2. Fix broken packages: sudo apt --fix-broken install"
    echo "   3. Install missing headers: sudo apt install linux-headers-\$(uname -r)"
    echo "   4. Install build tools: sudo apt install build-essential dkms"
    echo "   5. Install fingerprint packages: sudo apt install libfprint-2-2 fprintd libpam-fprintd"
    echo "   6. Configure PAM: sudo pam-auth-update"
    echo
}

# Fedora specific troubleshooting
troubleshoot_fedora() {
    print_section "FEDORA SPECIFIC TROUBLESHOOTING"
    
    print_status "$BLUE" "🔍 Checking Fedora specific issues..."
    
    # Check repositories
    print_status "$BLUE" "📦 Checking package repositories..."
    
    if dnf repolist enabled | grep -q "fedora"; then
        print_status "$GREEN" "   ✅ Fedora repository is enabled"
    else
        print_status "$RED" "   ❌ Fedora repository not found"
    fi
    
    if dnf repolist enabled | grep -q "updates"; then
        print_status "$GREEN" "   ✅ Updates repository is enabled"
    else
        print_status "$YELLOW" "   ⚠️  Updates repository not enabled"
    fi
    
    if dnf repolist enabled | grep -q "rpmfusion"; then
        print_status "$GREEN" "   ✅ RPM Fusion repositories are available"
    else
        print_status "$BLUE" "   → RPM Fusion not enabled (optional for this driver)"
    fi
    
    # Check for package conflicts
    print_status "$BLUE" "🔍 Checking for package conflicts..."
    local conflicts=$(dnf check 2>&1 | grep -i conflict | wc -l)
    if [[ $conflicts -eq 0 ]]; then
        print_status "$GREEN" "   ✅ No package conflicts found"
    else
        print_status "$RED" "   ❌ Found $conflicts package conflicts"
        print_status "$BLUE" "   💡 Fix: sudo dnf check && sudo dnf distro-sync"
    fi
    
    # Check kernel and headers
    print_status "$BLUE" "🔍 Checking kernel and development packages..."
    local current_kernel=$(uname -r)
    
    if rpm -q "kernel-devel-$current_kernel" >/dev/null 2>&1; then
        print_status "$GREEN" "   ✅ Kernel development headers for $current_kernel are installed"
    else
        print_status "$RED" "   ❌ Kernel development headers for $current_kernel are missing"
        print_status "$BLUE" "   💡 Fix: sudo dnf install kernel-devel-$current_kernel"
    fi
    
    if rpm -q kernel-headers >/dev/null 2>&1; then
        print_status "$GREEN" "   ✅ Kernel headers package is installed"
    else
        print_status "$YELLOW" "   ⚠️  Kernel headers package is missing"
        print_status "$BLUE" "   💡 Fix: sudo dnf install kernel-headers"
    fi
    
    # Check development tools
    print_status "$BLUE" "🔍 Checking development tools..."
    if dnf group list installed | grep -q "Development Tools"; then
        print_status "$GREEN" "   ✅ Development Tools group is installed"
    else
        print_status "$RED" "   ❌ Development Tools group is missing"
        print_status "$BLUE" "   💡 Fix: sudo dnf groupinstall 'Development Tools'"
    fi
    
    # Check fingerprint packages
    print_status "$BLUE" "🔍 Checking fingerprint packages..."
    local fp_packages=("libfprint" "fprintd" "fprintd-pam")
    for package in "${fp_packages[@]}"; do
        if rpm -q "$package" >/dev/null 2>&1; then
            print_status "$GREEN" "   ✅ $package is installed"
        else
            print_status "$YELLOW" "   ⚠️  $package is missing"
            print_status "$BLUE" "   💡 Fix: sudo dnf install $package"
        fi
    done
    
    # Check SELinux
    print_status "$BLUE" "🔍 Checking SELinux status..."
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status=$(getenforce)
        case "$selinux_status" in
            "Enforcing")
                print_status "$YELLOW" "   ⚠️  SELinux is enforcing"
                print_status "$BLUE" "   💡 This may block fingerprint access"
                
                # Check for fingerprint-related booleans
                if getsebool authlogin_yubikey 2>/dev/null | grep -q "on"; then
                    print_status "$GREEN" "   ✅ authlogin_yubikey boolean is enabled"
                else
                    print_status "$RED" "   ❌ authlogin_yubikey boolean is disabled"
                    print_status "$BLUE" "   💡 Fix: sudo setsebool -P authlogin_yubikey on"
                fi
                
                # Check for recent denials
                local recent_denials=$(ausearch -m avc -ts recent 2>/dev/null | grep fprintd | wc -l)
                if [[ $recent_denials -gt 0 ]]; then
                    print_status "$RED" "   ❌ Found $recent_denials recent SELinux denials for fprintd"
                    print_status "$BLUE" "   💡 Check: sudo ausearch -m avc -ts recent | grep fprintd"
                else
                    print_status "$GREEN" "   ✅ No recent SELinux denials for fprintd"
                fi
                ;;
            "Permissive")
                print_status "$BLUE" "   → SELinux is in permissive mode"
                ;;
            "Disabled")
                print_status "$GREEN" "   ✅ SELinux is disabled"
                ;;
        esac
    else
        print_status "$BLUE" "   → SELinux tools not available"
    fi
    
    # Check firewall
    print_status "$BLUE" "🔍 Checking firewall status..."
    if systemctl is-active --quiet firewalld; then
        print_status "$BLUE" "   → Firewalld is active"
        print_status "$GREEN" "   ✅ No firewall changes needed for local fingerprint access"
    else
        print_status "$GREEN" "   ✅ Firewalld is not active"
    fi
    
    # Fedora specific fixes
    print_status "$BLUE" "🔧 Fedora specific recommendations..."
    
    echo "   Recommended commands to fix common issues:"
    echo "   1. Update system: sudo dnf update"
    echo "   2. Install development tools: sudo dnf groupinstall 'Development Tools'"
    echo "   3. Install kernel headers: sudo dnf install kernel-devel kernel-headers"
    echo "   4. Install fingerprint packages: sudo dnf install libfprint fprintd fprintd-pam"
    echo "   5. Configure SELinux: sudo setsebool -P authlogin_yubikey on"
    echo "   6. Configure authentication: sudo authselect select sssd with-fingerprint"
    echo
}

# Common troubleshooting for all distributions
troubleshoot_common() {
    print_section "COMMON TROUBLESHOOTING"
    
    # Check hardware
    print_status "$BLUE" "🔍 Checking hardware detection..."
    local xiaomi_devices=("2717:0368" "2717:0369" "2717:036a" "2717:036b" "10a5:9201")
    local device_found=false
    
    for device_id in "${xiaomi_devices[@]}"; do
        if lsusb | grep -q "$device_id"; then
            print_status "$GREEN" "   ✅ Xiaomi device detected: $device_id"
            device_found=true
            
            # Get detailed device info
            local device_info=$(lsusb -d "$device_id" -v 2>/dev/null | head -20)
            if [[ -n "$device_info" ]]; then
                print_status "$BLUE" "   → Device details:"
                echo "$device_info" | grep -E "(Bus|Device|idVendor|idProduct|bcdUSB|MaxPower)" | sed 's/^/     /'
            fi
            break
        fi
    done
    
    if [[ "$device_found" == false ]]; then
        print_status "$RED" "   ❌ No Xiaomi fingerprint devices detected"
        print_status "$BLUE" "   💡 Troubleshooting steps:"
        echo "     1. Ensure device is enabled in BIOS/UEFI"
        echo "     2. Try different USB ports"
        echo "     3. Check if device works in Windows"
        echo "     4. Verify device is not disabled in Device Manager"
    fi
    
    # Check driver status
    print_status "$BLUE" "🔍 Checking driver status..."
    if lsmod | grep -q fp_xiaomi; then
        print_status "$GREEN" "   ✅ Xiaomi fingerprint driver is loaded"
        local driver_info=$(lsmod | grep fp_xiaomi)
        print_status "$BLUE" "   → Driver info: $driver_info"
    else
        print_status "$RED" "   ❌ Xiaomi fingerprint driver is not loaded"
        print_status "$BLUE" "   💡 Try: sudo modprobe fp_xiaomi_driver"
    fi
    
    # Check services
    print_status "$BLUE" "🔍 Checking fingerprint services..."
    if systemctl is-active --quiet fprintd; then
        print_status "$GREEN" "   ✅ fprintd service is active"
    else
        print_status "$RED" "   ❌ fprintd service is not active"
        print_status "$BLUE" "   💡 Try: sudo systemctl start fprintd"
    fi
    
    if systemctl is-enabled --quiet fprintd; then
        print_status "$GREEN" "   ✅ fprintd service is enabled"
    else
        print_status "$YELLOW" "   ⚠️  fprintd service is not enabled"
        print_status "$BLUE" "   💡 Try: sudo systemctl enable fprintd"
    fi
    
    # Check device nodes
    print_status "$BLUE" "🔍 Checking device nodes..."
    local device_nodes_found=false
    for node in /dev/fp_xiaomi* /dev/fingerprint*; do
        if [[ -e "$node" ]]; then
            print_status "$GREEN" "   ✅ Device node found: $node"
            local perms=$(ls -la "$node" | awk '{print $1, $3, $4}')
            print_status "$BLUE" "   → Permissions: $perms"
            device_nodes_found=true
        fi
    done
    
    if [[ "$device_nodes_found" == false ]]; then
        print_status "$YELLOW" "   ⚠️  No device nodes found"
        if [[ "$device_found" == true ]]; then
            print_status "$BLUE" "   💡 Hardware detected but no device nodes - driver issue"
        else
            print_status "$BLUE" "   💡 No hardware detected - check hardware connection"
        fi
    fi
    
    # Check user permissions
    print_status "$BLUE" "🔍 Checking user permissions..."
    local current_user=$(whoami)
    local user_groups=$(groups "$current_user")
    
    if echo "$user_groups" | grep -q plugdev; then
        print_status "$GREEN" "   ✅ User $current_user is in plugdev group"
    else
        print_status "$RED" "   ❌ User $current_user is not in plugdev group"
        print_status "$BLUE" "   💡 Fix: sudo usermod -a -G plugdev $current_user"
    fi
    
    if echo "$user_groups" | grep -q input; then
        print_status "$GREEN" "   ✅ User $current_user is in input group"
    else
        print_status "$YELLOW" "   ⚠️  User $current_user is not in input group"
        print_status "$BLUE" "   💡 Fix: sudo usermod -a -G input $current_user"
    fi
    
    # Check conflicting drivers
    print_status "$BLUE" "🔍 Checking for conflicting drivers..."
    local conflicting_drivers=("validity" "synaptics_usb" "fpc1020" "goodix")
    local conflicts_found=false
    
    for driver in "${conflicting_drivers[@]}"; do
        if lsmod | grep -q "^$driver"; then
            print_status "$YELLOW" "   ⚠️  Potentially conflicting driver: $driver"
            conflicts_found=true
        fi
    done
    
    if [[ "$conflicts_found" == false ]]; then
        print_status "$GREEN" "   ✅ No conflicting drivers detected"
    else
        print_status "$BLUE" "   💡 Consider blacklisting conflicting drivers"
    fi
}

# Generate troubleshooting report
generate_report() {
    print_section "GENERATING TROUBLESHOOTING REPORT"
    
    local report_file="/tmp/xiaomi_fp_troubleshoot_report.txt"
    
    cat > "$report_file" << EOF
=== Xiaomi Fingerprint Scanner Troubleshooting Report ===
Generated: $(date)
Distribution: $DISTRO_NAME
Kernel: $(uname -r)
Architecture: $(uname -m)

Hardware Detection:
$(lsusb | grep -E "(2717|10a5)" || echo "No Xiaomi devices found")

Driver Status:
$(lsmod | grep fp_xiaomi || echo "Driver not loaded")

Service Status:
fprintd: $(systemctl is-active fprintd 2>/dev/null || echo "unknown")

Device Nodes:
$(ls -la /dev/fp_xiaomi* /dev/fingerprint* 2>/dev/null || echo "No device nodes found")

User Groups:
$(groups $(whoami))

Recent Kernel Messages:
$(dmesg | grep -i -E "(fp_xiaomi|fingerprint|usb)" | tail -10 || echo "No relevant messages")

Distribution-Specific Information:
EOF
    
    case "$DISTRO" in
        ubuntu|linuxmint)
            cat >> "$report_file" << EOF

Ubuntu/Mint Specific:
- Secure Boot: $(mokutil --sb-state 2>/dev/null || echo "unknown")
- AppArmor: $(aa-status --enabled 2>/dev/null && echo "enabled" || echo "disabled")
- Kernel Headers: $(dpkg -l | grep linux-headers-$(uname -r) | awk '{print $2}' || echo "not found")
EOF
            ;;
        fedora)
            cat >> "$report_file" << EOF

Fedora Specific:
- SELinux: $(getenforce 2>/dev/null || echo "unknown")
- Firewall: $(systemctl is-active firewalld 2>/dev/null || echo "unknown")
- Kernel Devel: $(rpm -q kernel-devel-$(uname -r) 2>/dev/null || echo "not found")
EOF
            ;;
    esac
    
    cat >> "$report_file" << EOF

Recommended Actions:
1. Check hardware connection and BIOS settings
2. Ensure all required packages are installed
3. Verify driver is loaded: sudo modprobe fp_xiaomi_driver
4. Check service status: systemctl status fprintd
5. Test enrollment: fprintd-enroll
6. Check permissions: add user to plugdev group

Log Files:
- Full troubleshooting log: $LOG_FILE
- System logs: journalctl -u fprintd
- Kernel messages: dmesg | grep fp_xiaomi

EOF
    
    print_status "$GREEN" "✅ Troubleshooting report generated: $report_file"
    print_status "$BLUE" "📄 Full log available at: $LOG_FILE"
}

# Main troubleshooting function
main() {
    echo "=== Xiaomi Fingerprint Scanner Troubleshooting ===" > "$LOG_FILE"
    echo "Started at: $(date)" >> "$LOG_FILE"
    
    print_status "$PURPLE" "🔧 Starting Distribution-Specific Troubleshooting"
    
    detect_distribution
    print_status "$BLUE" "📋 Detected: $DISTRO_NAME"
    
    # Run common troubleshooting first
    troubleshoot_common
    
    # Run distribution-specific troubleshooting
    case "$DISTRO" in
        ubuntu|linuxmint)
            troubleshoot_ubuntu_mint
            ;;
        fedora)
            troubleshoot_fedora
            ;;
        *)
            print_status "$YELLOW" "⚠️  Distribution-specific troubleshooting not available for $DISTRO"
            print_status "$BLUE" "💡 Running common troubleshooting only"
            ;;
    esac
    
    # Generate report
    generate_report
    
    print_status "$GREEN" "🎉 Troubleshooting completed!"
    print_status "$BLUE" "💡 Check the generated report for detailed information and recommendations"
}

# Run main function
main "$@"