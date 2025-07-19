#!/bin/bash

# Hardware Information Collection Script
# This script gathers information about fingerprint scanners on the system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/hardware-analysis"

echo "=== Fingerprint Scanner Hardware Detection ==="
echo "Date: $(date)"
echo "System: Linux"
echo

# Create output directory for structured output
mkdir -p "$OUTPUT_DIR"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for USB fingerprint devices
echo "=== USB Device Information ==="
if command -v lsusb &> /dev/null; then
    echo "All USB devices:"
    lsusb -v 2>/dev/null | grep -A 20 -B 5 -i "fingerprint\|biometric\|fpc"
    
    echo -e "\nUSB devices by class (looking for biometric devices):"
    lsusb | while read line; do
        bus=$(echo $line | cut -d' ' -f2)
        device=$(echo $line | cut -d' ' -f4 | sed 's/://')
        vendor_product=$(echo $line | cut -d' ' -f6)
        
        # Get device class information
        class_info=$(lsusb -s $bus:$device -v 2>/dev/null | grep -E "bDeviceClass|bInterfaceClass" | head -1)
        if [[ $class_info == *"Vendor Specific"* ]] || [[ $class_info == *"Human Interface Device"* ]]; then
            echo "Potential fingerprint device: $line"
            echo "  Class info: $class_info"
        fi
    done
else
    echo "lsusb not available. Install usbutils package."
fi

echo -e "\n=== PCI Device Information ==="
if command -v lspci &> /dev/null; then
    echo "Checking for PCI fingerprint devices:"
    lspci -v | grep -A 10 -B 2 -i "fingerprint\|biometric"
else
    echo "lspci not available. Install pciutils package."
fi

echo -e "\n=== Kernel Module Information ==="
echo "Currently loaded modules related to fingerprint/biometric:"
lsmod | grep -i "fp\|finger\|bio\|fpc"

echo -e "\n=== Device Files ==="
echo "Checking for existing fingerprint device files:"
ls -la /dev/ | grep -i "fp\|finger\|bio"

echo -e "\n=== System Logs ==="
echo "Recent kernel messages about USB devices:"
dmesg | grep -i "usb\|fingerprint\|biometric" | tail -20

echo -e "\n=== Hardware Detection Summary ==="
echo "Please run this script and save the output to hardware-info.txt"
echo "This information will help identify the specific fingerprint scanner hardware."

# Check for Windows dual-boot
echo -e "\n=== Windows Detection ==="
if [ -d "/mnt/c" ] || [ -d "/media" ]; then
    echo "Possible Windows installation detected."
    echo "If dual-booting, you can access Windows drivers from:"
    echo "  - C:\\Windows\\System32\\drivers\\"
    echo "  - C:\\Windows\\System32\\DriverStore\\"
fi

echo -e "\n=== Saving Results ==="
# Save all output to structured files
{
    echo "# Hardware Information Summary"
    echo "# Generated: $(date)"
    echo "# System: Linux"
    echo ""
    echo "## USB Devices Found"
    if command_exists lsusb; then
        USB_COUNT=$(lsusb | wc -l)
        echo "- Total USB devices: $USB_COUNT"
        POTENTIAL_FP=$(lsusb | grep -i "fingerprint\|biometric\|fpc" | wc -l)
        echo "- Potential fingerprint devices: $POTENTIAL_FP"
    else
        echo "- USB information not available"
    fi
} > "$OUTPUT_DIR/summary.txt"

echo "Results saved to: $OUTPUT_DIR/"
echo "Summary available at: $OUTPUT_DIR/summary.txt"

echo -e "\n=== Next Steps ==="
echo "1. Review the summary in $OUTPUT_DIR/summary.txt"
echo "2. If Windows is available, run: tools/windows-analysis.ps1"
echo "3. Identify the specific VID:PID of your fingerprint scanner"
echo "4. Research existing Linux support for your device"