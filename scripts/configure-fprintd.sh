#!/bin/bash

# Configure fprintd for Xiaomi FPC Fingerprint Scanner
# This script fixes the device claiming and timeout issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root"
    exit 1
fi

log_info "Configuring fprintd for Xiaomi FPC Fingerprint Scanner"

# Stop fprintd service
log_info "Stopping fprintd service..."
sudo systemctl stop fprintd || true

# Create fprintd configuration directory
sudo mkdir -p /etc/fprintd

# Create fprintd configuration to fix timeout issues
log_info "Creating fprintd configuration..."
cat << 'EOF' | sudo tee /etc/fprintd/fprintd.conf >/dev/null
[fprintd]
# Increase timeout for FPC devices
timeout = 30

[storage]
# Use system storage for templates
type = file

[xiaomi_fpc]
# Xiaomi FPC specific settings
device_timeout = 15
enroll_timeout = 30
verify_timeout = 10
max_enroll_stages = 5
EOF

# Create systemd service override to fix claiming issues
log_info "Creating systemd service override..."
sudo mkdir -p /etc/systemd/system/fprintd.service.d

cat << 'EOF' | sudo tee /etc/systemd/system/fprintd.service.d/xiaomi-fpc.conf >/dev/null
[Service]
# Restart fprintd if it fails (helps with device claiming issues)
Restart=on-failure
RestartSec=5

# Environment variables for better FPC support
Environment="LIBFPRINT_DEBUG=1"
Environment="FP_XIAOMI_TIMEOUT=15000"

# Ensure proper device permissions
ExecStartPre=/bin/bash -c 'if [ -c /dev/fp_xiaomi0 ]; then chmod 664 /dev/fp_xiaomi0; chgrp plugdev /dev/fp_xiaomi0; fi'
EOF

# Create udev rules for proper device handling
log_info "Creating enhanced udev rules..."
cat << 'EOF' | sudo tee /etc/udev/rules.d/60-xiaomi-fingerprint-fprintd.rules >/dev/null
# Xiaomi FPC Fingerprint Scanner - Enhanced rules for fprintd

# Main device rule
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", MODE="0664", GROUP="plugdev", TAG+="uaccess"

# Character device rule
KERNEL=="fp_xiaomi*", MODE="0664", GROUP="plugdev", TAG+="uaccess"

# Auto-load driver and restart fprintd when device is connected
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", RUN+="/sbin/modprobe fp_xiaomi"
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", RUN+="/bin/systemctl restart fprintd"

# Set device attributes for better power management
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", ATTR{power/autosuspend_delay_ms}="2000"
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", ATTR{power/control}="auto"
EOF

# Create fprintd device configuration
log_info "Creating device-specific configuration..."
sudo mkdir -p /var/lib/fprint

cat << 'EOF' | sudo tee /var/lib/fprint/xiaomi_fpc.conf >/dev/null
# Xiaomi FPC Device Configuration
[device]
name = "Xiaomi FPC Fingerprint Scanner"
driver = "xiaomi_fpc"
vid = 0x10a5
pid = 0x9201

[settings]
# Enrollment settings
enroll_stages = 5
enroll_timeout = 30000
enroll_quality_threshold = 50

# Verification settings
verify_timeout = 10000
verify_quality_threshold = 40

# Device-specific settings
max_retries = 3
power_management = true
debug_level = 1
EOF

# Create wrapper script to handle device claiming
log_info "Creating device claiming wrapper..."
cat << 'EOF' | sudo tee /usr/local/bin/fprintd-xiaomi-wrapper >/dev/null
#!/bin/bash

# Xiaomi FPC fprintd wrapper to handle device claiming issues

# Function to check if device is available
check_device() {
    if [ -c /dev/fp_xiaomi0 ]; then
        return 0
    fi
    return 1
}

# Function to reset device if needed
reset_device() {
    echo "Resetting Xiaomi FPC device..."
    
    # Unload and reload driver
    sudo modprobe -r fp_xiaomi 2>/dev/null || true
    sleep 1
    sudo modprobe fp_xiaomi
    sleep 2
    
    # Check if device is available
    if check_device; then
        echo "Device reset successful"
        return 0
    else
        echo "Device reset failed"
        return 1
    fi
}

# Main wrapper logic
case "$1" in
    "enroll")
        echo "Starting enrollment with device reset..."
        reset_device
        fprintd-enroll "$2"
        ;;
    "verify")
        echo "Starting verification..."
        if ! check_device; then
            reset_device
        fi
        fprintd-verify "$2"
        ;;
    "list")
        fprintd-list
        ;;
    "delete")
        fprintd-delete "$2"
        ;;
    *)
        echo "Usage: $0 {enroll|verify|list|delete} [username]"
        echo "  enroll <user>  - Enroll fingerprint for user"
        echo "  verify <user>  - Verify fingerprint for user"
        echo "  list           - List enrolled fingerprints"
        echo "  delete <user>  - Delete fingerprints for user"
        exit 1
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/fprintd-xiaomi-wrapper

# Reload systemd and udev
log_info "Reloading system configuration..."
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo udevadm trigger

# Add user to plugdev group if not already
if ! groups $USER | grep -q plugdev; then
    log_info "Adding user to plugdev group..."
    sudo usermod -a -G plugdev $USER
    log_warning "You need to log out and back in for group changes to take effect"
fi

# Start fprintd service
log_info "Starting fprintd service..."
sudo systemctl enable fprintd
sudo systemctl start fprintd

# Wait for service to start
sleep 3

# Test fprintd functionality
log_info "Testing fprintd functionality..."
if timeout 10 fprintd-list >/dev/null 2>&1; then
    log_success "fprintd is responding correctly"
else
    log_warning "fprintd may have issues, checking status..."
    sudo systemctl status fprintd --no-pager -l
fi

# Create desktop integration files
log_info "Creating desktop integration..."
mkdir -p ~/.local/share/applications

cat << 'EOF' > ~/.local/share/applications/xiaomi-fingerprint-enroll.desktop
[Desktop Entry]
Name=Xiaomi Fingerprint Enrollment
Comment=Enroll fingerprints for Xiaomi FPC scanner
Exec=/usr/local/bin/fprintd-xiaomi-wrapper enroll %u
Icon=fingerprint-gui
Terminal=true
Type=Application
Categories=System;Security;
EOF

cat << 'EOF' > ~/.local/share/applications/xiaomi-fingerprint-manager.desktop
[Desktop Entry]
Name=Xiaomi Fingerprint Manager
Comment=Manage fingerprints for Xiaomi FPC scanner
Exec=gnome-terminal -- /usr/local/bin/fprintd-xiaomi-wrapper list
Icon=fingerprint-gui
Terminal=false
Type=Application
Categories=System;Security;
EOF

# Final status check
echo
log_success "fprintd configuration completed!"
echo
log_info "Configuration summary:"
echo "  - fprintd timeout increased to handle FPC device"
echo "  - Systemd service configured with restart on failure"
echo "  - Enhanced udev rules for proper device handling"
echo "  - Device-specific configuration created"
echo "  - Wrapper script for device claiming issues"
echo "  - Desktop integration files created"
echo
log_info "Usage:"
echo "  - Enroll fingerprint: fprintd-xiaomi-wrapper enroll \$USER"
echo "  - Verify fingerprint: fprintd-xiaomi-wrapper verify \$USER"
echo "  - List fingerprints: fprintd-xiaomi-wrapper list"
echo "  - Delete fingerprints: fprintd-xiaomi-wrapper delete \$USER"
echo
log_info "GUI Integration:"
echo "  - GNOME: Settings > Users > Add Fingerprint"
echo "  - KDE: System Settings > Users > Add Fingerprint"
echo "  - Or use the desktop applications created in Applications menu"
echo

if groups $USER | grep -q plugdev; then
    log_success "Ready to use! Try enrolling a fingerprint."
else
    log_warning "Please log out and back in, then try enrolling a fingerprint."
fi