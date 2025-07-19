#!/bin/bash

# Hardware Information Collection Script
# This script gathers information about fingerprint scanners on the system

echo "=== Fingerprint Scanner Hardware Detection ==="
echo "Date: $(date)"
echo "System: $(uname -a)"
echo

# Check for USB fingerprint devices
echo "=== USB Device Information ==="
if command -v lsusb &> /dev/null; then
    echo "All USB devices:"
    lsusb -v 2>/dev/null | grep -A 20 -B 5 -i "fingerprint\|biometric\|validity\|synaptics\|elan\|goodix"
    
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
lsmod | grep -i "fp\|finger\|bio\|validity\|synaptics\|elan"

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

echo -e "\n=== Next Steps ==="
echo "1. Save this output to hardware-info.txt"
echo "2. If Windows is available, run the Windows analysis script"
echo "3. Identify the specific VID:PID of your fingerprint scanner"
echo "4. Research existing Linux support for your device"