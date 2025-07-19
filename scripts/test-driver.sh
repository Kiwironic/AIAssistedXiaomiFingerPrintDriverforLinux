#!/bin/bash

# Xiaomi FPC Fingerprint Driver Test Script
# Copyright (C) 2025 AI-Assisted Development
# Licensed under GPL v2

set -e

# Script configuration
SCRIPT_NAME="Xiaomi FPC Fingerprint Driver Tester"
SCRIPT_VERSION="1.0.0"
DRIVER_NAME="fp_xiaomi"
DEVICE_NODE="/dev/fp_xiaomi0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test function wrapper
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TESTS_TOTAL++))
    echo
    log_info "Running test: $test_name"
    
    if $test_function; then
        log_success "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# Test 1: Check if driver module is loaded
test_module_loaded() {
    if lsmod | grep -q "$DRIVER_NAME"; then
        return 0
    else
        log_error "Driver module not loaded"
        return 1
    fi
}

# Test 2: Check USB device detection
test_usb_device() {
    if lsusb | grep -q "10a5:9201"; then
        local device_info=$(lsusb | grep "10a5:9201")
        log_info "USB device: $device_info"
        return 0
    else
        log_error "USB device 10a5:9201 not found"
        return 1
    fi
}

# Test 3: Check device node creation
test_device_node() {
    if [ -c "$DEVICE_NODE" ]; then
        local permissions=$(ls -la "$DEVICE_NODE")
        log_info "Device node: $permissions"
        return 0
    else
        log_error "Device node $DEVICE_NODE not found"
        return 1
    fi
}

# Test 4: Check device permissions
test_device_permissions() {
    if [ -c "$DEVICE_NODE" ]; then
        if [ -r "$DEVICE_NODE" ] && [ -w "$DEVICE_NODE" ]; then
            return 0
        else
            log_error "Device node not accessible (check permissions)"
            return 1
        fi
    else
        log_error "Device node not found"
        return 1
    fi
}

# Test 5: Check kernel messages
test_kernel_messages() {
    local messages=$(dmesg | grep -i "fp_xiaomi" | tail -5)
    if [ -n "$messages" ]; then
        log_info "Recent kernel messages:"
        echo "$messages" | while read line; do
            echo "  $line"
        done
        
        # Check for error messages
        if echo "$messages" | grep -qi "error\|fail"; then
            log_warning "Error messages found in kernel log"
            return 1
        else
            return 0
        fi
    else
        log_error "No kernel messages found for driver"
        return 1
    fi
}

# Test 6: Test basic device communication
test_device_communication() {
    if [ ! -c "$DEVICE_NODE" ]; then
        log_error "Device node not available"
        return 1
    fi
    
    # Try to open device (this tests basic driver functionality)
    if timeout 5 cat "$DEVICE_NODE" >/dev/null 2>&1 &
    then
        local cat_pid=$!
        sleep 1
        kill $cat_pid 2>/dev/null || true
        wait $cat_pid 2>/dev/null || true
        return 0
    else
        log_error "Failed to communicate with device"
        return 1
    fi
}

# Test 7: Check driver version and info
test_driver_info() {
    if modinfo "$DRIVER_NAME" >/dev/null 2>&1; then
        local version=$(modinfo "$DRIVER_NAME" | grep "^version:" | cut -d: -f2 | xargs)
        local description=$(modinfo "$DRIVER_NAME" | grep "^description:" | cut -d: -f2 | xargs)
        log_info "Driver version: $version"
        log_info "Description: $description"
        return 0
    else
        log_error "Cannot get driver information"
        return 1
    fi
}

# Test 8: Check system integration
test_system_integration() {
    local integration_ok=true
    
    # Check udev rules
    if [ -f /etc/udev/rules.d/99-xiaomi-fingerprint.rules ]; then
        log_info "Udev rules installed"
    else
        log_warning "Udev rules not found"
        integration_ok=false
    fi
    
    # Check module loading configuration
    if [ -f /etc/modules-load.d/fp_xiaomi.conf ]; then
        log_info "Module loading configured"
    else
        log_warning "Module loading not configured"
        integration_ok=false
    fi
    
    # Check user groups
    if groups | grep -q plugdev; then
        log_info "User in plugdev group"
    else
        log_warning "User not in plugdev group"
        integration_ok=false
    fi
    
    return $($integration_ok && echo 0 || echo 1)
}

# Test 9: Check libfprint integration
test_libfprint_integration() {
    if command -v fprintd-list >/dev/null 2>&1; then
        log_info "fprintd available"
        
        # Try to list devices
        if fprintd-list 2>/dev/null | grep -q "fp_xiaomi\|FPC"; then
            log_info "Device recognized by fprintd"
            return 0
        else
            log_warning "Device not recognized by fprintd"
            return 1
        fi
    else
        log_info "fprintd not installed (optional)"
        return 0
    fi
}

# Test 10: Performance test
test_performance() {
    if [ ! -c "$DEVICE_NODE" ]; then
        log_error "Device node not available"
        return 1
    fi
    
    log_info "Running performance test..."
    
    # Test multiple rapid opens/closes
    local start_time=$(date +%s%N)
    for i in {1..10}; do
        if ! timeout 1 bash -c "exec 3<$DEVICE_NODE; exec 3<&-" 2>/dev/null; then
            log_error "Performance test failed at iteration $i"
            return 1
        fi
    done
    local end_time=$(date +%s%N)
    
    local duration=$(( (end_time - start_time) / 1000000 ))
    log_info "10 device operations completed in ${duration}ms"
    
    if [ $duration -lt 5000 ]; then  # Less than 5 seconds
        return 0
    else
        log_warning "Performance test slow (${duration}ms)"
        return 1
    fi
}

# Diagnostic information collection
collect_diagnostics() {
    echo
    log_info "Collecting diagnostic information..."
    
    echo "=== System Information ==="
    uname -a
    echo
    
    echo "=== Kernel Version ==="
    uname -r
    echo
    
    echo "=== Distribution ==="
    if [ -f /etc/os-release ]; then
        grep PRETTY_NAME /etc/os-release
    fi
    echo
    
    echo "=== USB Devices ==="
    lsusb | grep -E "(10a5:9201|Fingerprint|FPC)" || echo "No fingerprint devices found"
    echo
    
    echo "=== Loaded Modules ==="
    lsmod | grep -E "(fp_|fingerprint|fpc)" || echo "No fingerprint modules loaded"
    echo
    
    echo "=== Device Nodes ==="
    ls -la /dev/fp_* 2>/dev/null || echo "No fingerprint device nodes found"
    echo
    
    echo "=== Kernel Messages (last 20) ==="
    dmesg | grep -i "fp_xiaomi\|fingerprint\|fpc" | tail -20 || echo "No relevant kernel messages"
    echo
    
    echo "=== Driver Information ==="
    if modinfo "$DRIVER_NAME" >/dev/null 2>&1; then
        modinfo "$DRIVER_NAME"
    else
        echo "Driver not found"
    fi
    echo
    
    echo "=== Process Information ==="
    ps aux | grep -E "(fprintd|fp_)" | grep -v grep || echo "No fingerprint processes running"
    echo
}

# Main test function
main() {
    echo "========================================"
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
    echo "========================================"
    echo
    
    # Run all tests
    run_test "Module Loading" test_module_loaded
    run_test "USB Device Detection" test_usb_device
    run_test "Device Node Creation" test_device_node
    run_test "Device Permissions" test_device_permissions
    run_test "Kernel Messages" test_kernel_messages
    run_test "Device Communication" test_device_communication
    run_test "Driver Information" test_driver_info
    run_test "System Integration" test_system_integration
    run_test "libfprint Integration" test_libfprint_integration
    run_test "Performance Test" test_performance
    
    # Test summary
    echo
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo "Total tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed! Driver is working correctly."
        echo
        log_info "Your Xiaomi fingerprint scanner should now work with:"
        echo "- Desktop environment fingerprint settings"
        echo "- fprintd command-line tools"
        echo "- PAM authentication (if configured)"
    else
        log_error "$TESTS_FAILED test(s) failed. Driver may not work correctly."
        echo
        log_info "Troubleshooting steps:"
        echo "1. Check if your hardware is supported"
        echo "2. Verify BIOS settings enable fingerprint scanner"
        echo "3. Check for conflicting drivers"
        echo "4. Review kernel messages for errors"
        echo "5. Try reinstalling the driver"
    fi
    
    # Offer to collect diagnostics
    echo
    read -p "Collect diagnostic information? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        collect_diagnostics
        echo
        log_info "Diagnostic information collected above"
        log_info "You can copy this information when reporting issues"
    fi
    
    # Exit with appropriate code
    if [ $TESTS_FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "$SCRIPT_NAME v$SCRIPT_VERSION"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --diag, -d     Collect diagnostic information only"
        echo "  --quick, -q    Run quick tests only"
        echo
        exit 0
        ;;
    --diag|-d)
        collect_diagnostics
        exit 0
        ;;
    --quick|-q)
        echo "Running quick tests..."
        run_test "Module Loading" test_module_loaded
        run_test "USB Device Detection" test_usb_device
        run_test "Device Node Creation" test_device_node
        echo "Quick test completed: $TESTS_PASSED/$TESTS_TOTAL passed"
        exit $([[ $TESTS_FAILED -eq 0 ]] && echo 0 || echo 1)
        ;;
    "")
        # No arguments, run main function
        main "$@"
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac