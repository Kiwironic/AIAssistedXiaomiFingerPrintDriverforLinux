#!/bin/bash

# Hardware Compatibility Check Script for Xiaomi Fingerprint Scanner
# This script performs comprehensive hardware detection and compatibility verification

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
XIAOMI_VID="2717"
SUPPORTED_PIDS=("0368" "0369" "036A" "036B")
LOG_FILE="/tmp/fp_xiaomi_compatibility.log"
VERBOSE=false

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

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Hardware Compatibility Check for Xiaomi Fingerprint Scanner

OPTIONS:
    -v, --verbose       Enable verbose output
    -h, --help         Show this help message
    -l, --log FILE     Specify log file (default: $LOG_FILE)

EXAMPLES:
    $0                 # Basic compatibility check
    $0 -v              # Verbose compatibility check
    $0 -l /var/log/fp_check.log  # Custom log file

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
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

# Initialize log file
echo "=== Xiaomi Fingerprint Scanner Compatibility Check ===" > "$LOG_FILE"
log "Starting compatibility check at $(date)"

print_status "$BLUE" "🔍 Starting Xiaomi Fingerprint Scanner Compatibility Check"

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_status "$YELLOW" "⚠️  Running as root - this is recommended for hardware access"
        return 0
    else
        print_status "$YELLOW" "⚠️  Not running as root - some checks may be limited"
        return 1
    fi
}

# Check system requirements
check_system_requirements() {
    print_status "$BLUE" "📋 Checking system requirements..."
    
    local requirements_met=true
    
    # Check kernel version
    local kernel_version=$(uname -r)
    local kernel_major=$(echo "$kernel_version" | cut -d. -f1)
    local kernel_minor=$(echo "$kernel_version" | cut -d. -f2)
    
    log "Kernel version: $kernel_version"
    
    if [[ $kernel_major -lt 4 ]] || [[ $kernel_major -eq 4 && $kernel_minor -lt 15 ]]; then
        print_status "$RED" "❌ Kernel version $kernel_version is too old (minimum: 4.15)"
        requirements_met=false
    else
        print_status "$GREEN" "✅ Kernel version $kernel_version is supported"
    fi
    
    # Check for required tools
    local tools=("lsusb" "dmesg" "modprobe" "udevadm")
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            print_status "$GREEN" "✅ $tool is available"
            log "$tool: $(which $tool)"
        else
            print_status "$RED" "❌ $tool is not available"
            requirements_met=false
        fi
    done
    
    # Check USB subsystem
    if [[ -d /sys/bus/usb ]]; then
        print_status "$GREEN" "✅ USB subsystem is available"
    else
        print_status "$RED" "❌ USB subsystem not found"
        requirements_met=false
    fi
    
    # Check for development headers
    local kernel_headers="/lib/modules/$(uname -r)/build"
    if [[ -d "$kernel_headers" ]]; then
        print_status "$GREEN" "✅ Kernel headers are available"
    else
        print_status "$YELLOW" "⚠️  Kernel headers not found at $kernel_headers"
        print_status "$YELLOW" "    Driver compilation may fail"
    fi
    
    return $requirements_met
}

# Detect Xiaomi fingerprint devices
detect_xiaomi_devices() {
    print_status "$BLUE" "🔍 Scanning for Xiaomi fingerprint devices..."
    
    local devices_found=()
    local compatible_devices=()
    
    # Scan USB devices
    while IFS= read -r line; do
        if [[ $line =~ ID[[:space:]]+${XIAOMI_VID}:([0-9a-fA-F]{4}) ]]; then
            local pid="${BASH_REMATCH[1]}"
            devices_found+=("$pid")
            log "Found Xiaomi device with PID: $pid"
            
            # Check if PID is in supported list
            for supported_pid in "${SUPPORTED_PIDS[@]}"; do
                if [[ "$pid" == "$supported_pid" ]]; then
                    compatible_devices+=("$pid")
                    break
                fi
            done
        fi
    done < <(lsusb)
    
    if [[ ${#devices_found[@]} -eq 0 ]]; then
        print_status "$RED" "❌ No Xiaomi devices found"
        return 1
    fi
    
    print_status "$GREEN" "✅ Found ${#devices_found[@]} Xiaomi device(s)"
    
    for pid in "${devices_found[@]}"; do
        if [[ " ${compatible_devices[@]} " =~ " ${pid} " ]]; then
            print_status "$GREEN" "  ✅ Device ${XIAOMI_VID}:${pid} is supported"
        else
            print_status "$YELLOW" "  ⚠️  Device ${XIAOMI_VID}:${pid} may not be fully supported"
        fi
    done
    
    # Get detailed device information
    if [[ $VERBOSE == true ]]; then
        print_status "$BLUE" "📝 Detailed device information:"
        lsusb -v -d "${XIAOMI_VID}:" 2>/dev/null | tee -a "$LOG_FILE" || true
    fi
    
    return 0
}

# Check device permissions
check_device_permissions() {
    print_status "$BLUE" "🔐 Checking device permissions..."
    
    local permission_issues=false
    
    # Find Xiaomi devices in /dev
    local device_paths=()
    while IFS= read -r line; do
        if [[ $line =~ /dev/bus/usb/([0-9]+)/([0-9]+) ]]; then
            local bus="${BASH_REMATCH[1]}"
            local device="${BASH_REMATCH[2]}"
            local device_path="/dev/bus/usb/$bus/$device"
            
            # Check if this is a Xiaomi device
            local device_info=$(lsusb -s "$bus:$device" 2>/dev/null || echo "")
            if [[ $device_info =~ $XIAOMI_VID: ]]; then
                device_paths+=("$device_path")
            fi
        fi
    done < <(find /dev/bus/usb -type c 2>/dev/null || true)
    
    for device_path in "${device_paths[@]}"; do
        if [[ -r "$device_path" && -w "$device_path" ]]; then
            print_status "$GREEN" "✅ Device $device_path has proper permissions"
        else
            print_status "$YELLOW" "⚠️  Device $device_path may have permission issues"
            permission_issues=true
            
            if [[ $VERBOSE == true ]]; then
                ls -l "$device_path" | tee -a "$LOG_FILE"
            fi
        fi
    done
    
    if [[ $permission_issues == true ]]; then
        print_status "$YELLOW" "💡 Consider adding udev rules for proper permissions"
    fi
    
    return 0
}

# Check for conflicting drivers
check_conflicting_drivers() {
    print_status "$BLUE" "⚔️  Checking for conflicting drivers..."
    
    local conflicts_found=false
    
    # Check loaded modules
    local conflicting_modules=("libfprint" "fprint" "validity" "synaptics")
    for module in "${conflicting_modules[@]}"; do
        if lsmod | grep -q "^$module"; then
            print_status "$YELLOW" "⚠️  Potentially conflicting module loaded: $module"
            conflicts_found=true
            
            if [[ $VERBOSE == true ]]; then
                lsmod | grep "^$module" | tee -a "$LOG_FILE"
            fi
        fi
    done
    
    # Check for existing fingerprint services
    local services=("fprintd" "fprint" "fingerprint-gui")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            print_status "$YELLOW" "⚠️  Fingerprint service is running: $service"
            conflicts_found=true
        fi
    done
    
    if [[ $conflicts_found == false ]]; then
        print_status "$GREEN" "✅ No conflicting drivers or services detected"
    fi
    
    return 0
}

# Test USB communication
test_usb_communication() {
    print_status "$BLUE" "📡 Testing USB communication..."
    
    # Look for Xiaomi devices and try basic communication
    local test_passed=false
    
    while IFS= read -r line; do
        if [[ $line =~ Bus[[:space:]]+([0-9]+)[[:space:]]+Device[[:space:]]+([0-9]+).*ID[[:space:]]+${XIAOMI_VID}: ]]; then
            local bus="${BASH_REMATCH[1]}"
            local device="${BASH_REMATCH[2]}"
            
            print_status "$BLUE" "  Testing device on bus $bus, device $device"
            
            # Try to get device descriptor
            if lsusb -v -s "$bus:$device" >/dev/null 2>&1; then
                print_status "$GREEN" "  ✅ Device descriptor accessible"
                test_passed=true
            else
                print_status "$RED" "  ❌ Cannot access device descriptor"
            fi
            
            # Check device speed
            local speed_info=$(lsusb -v -s "$bus:$device" 2>/dev/null | grep -i "bcdUSB" || echo "Unknown")
            log "Device USB version: $speed_info"
            
            if [[ $VERBOSE == true ]]; then
                print_status "$BLUE" "  USB Speed: $speed_info"
            fi
        fi
    done < <(lsusb)
    
    if [[ $test_passed == true ]]; then
        print_status "$GREEN" "✅ USB communication test passed"
    else
        print_status "$RED" "❌ USB communication test failed"
    fi
    
    return $test_passed
}

# Check system logs for relevant messages
check_system_logs() {
    print_status "$BLUE" "📋 Checking system logs..."
    
    # Check dmesg for USB and fingerprint related messages
    local recent_messages=$(dmesg | tail -100 | grep -i -E "(usb|fingerprint|${XIAOMI_VID})" || true)
    
    if [[ -n "$recent_messages" ]]; then
        print_status "$BLUE" "📝 Recent relevant system messages:"
        echo "$recent_messages" | while read -r line; do
            if [[ $line =~ (error|fail|warn) ]]; then
                print_status "$YELLOW" "  ⚠️  $line"
            else
                print_status "$GREEN" "  ℹ️  $line"
            fi
        done
        
        if [[ $VERBOSE == true ]]; then
            echo "$recent_messages" >> "$LOG_FILE"
        fi
    else
        print_status "$GREEN" "✅ No concerning messages in recent logs"
    fi
    
    return 0
}

# Generate compatibility report
generate_report() {
    print_status "$BLUE" "📊 Generating compatibility report..."
    
    local report_file="/tmp/xiaomi_fp_compatibility_report.txt"
    
    cat > "$report_file" << EOF
=== Xiaomi Fingerprint Scanner Compatibility Report ===
Generated: $(date)
System: $(uname -a)
Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")

Hardware Detection:
$(lsusb | grep "$XIAOMI_VID" || echo "No Xiaomi devices found")

System Requirements:
- Kernel Version: $(uname -r)
- USB Subsystem: $([ -d /sys/bus/usb ] && echo "Available" || echo "Not found")
- Development Headers: $([ -d "/lib/modules/$(uname -r)/build" ] && echo "Available" || echo "Not found")

Recommendations:
EOF

    # Add specific recommendations based on findings
    if ! lsusb | grep -q "$XIAOMI_VID"; then
        echo "- No Xiaomi fingerprint devices detected" >> "$report_file"
        echo "- Ensure device is connected and powered on" >> "$report_file"
    fi
    
    if [[ ! -d "/lib/modules/$(uname -r)/build" ]]; then
        echo "- Install kernel development headers for driver compilation" >> "$report_file"
    fi
    
    echo "- Check log file: $LOG_FILE for detailed information" >> "$report_file"
    
    print_status "$GREEN" "✅ Compatibility report saved to: $report_file"
    
    return 0
}

# Main execution
main() {
    local overall_status=0
    
    # Run all checks
    check_root || true
    check_system_requirements || overall_status=1
    detect_xiaomi_devices || overall_status=1
    check_device_permissions || true
    check_conflicting_drivers || true
    test_usb_communication || overall_status=1
    check_system_logs || true
    generate_report || true
    
    # Final status
    print_status "$BLUE" "📋 Compatibility Check Summary:"
    
    if [[ $overall_status -eq 0 ]]; then
        print_status "$GREEN" "✅ System appears compatible with Xiaomi fingerprint scanner driver"
        print_status "$GREEN" "✅ You can proceed with driver installation"
    else
        print_status "$YELLOW" "⚠️  Some compatibility issues detected"
        print_status "$YELLOW" "⚠️  Review the log file and address issues before installation"
    fi
    
    print_status "$BLUE" "📄 Full log available at: $LOG_FILE"
    
    return $overall_status
}

# Run main function
main "$@"