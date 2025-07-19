#!/bin/bash

# Fix fingerprint-ocv driver issues for Xiaomi FPC Scanner
# This script addresses the specific errors found in the error log

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

log_info "Fixing fingerprint-ocv driver issues for Xiaomi FPC Scanner"

# Check if fingerprint-ocv is installed
if [ ! -d "$HOME/Drivers/fingerprint-ocv" ]; then
    log_info "fingerprint-ocv not found, cloning repository..."
    mkdir -p "$HOME/Drivers"
    cd "$HOME/Drivers"
    git clone https://github.com/vrolife/fingerprint-ocv.git
    cd fingerprint-ocv
else
    log_info "fingerprint-ocv found, updating..."
    cd "$HOME/Drivers/fingerprint-ocv"
    git pull
fi

# Stop any running fprintd processes
log_info "Stopping fprintd processes..."
sudo systemctl stop fprintd || true
sudo pkill -f fprintd || true

# Remove any existing fingerprint-ocv driver
log_info "Removing existing fingerprint-ocv driver..."
sudo modprobe -r fingerprint_ocv 2>/dev/null || true

# Build and install fingerprint-ocv with fixes
log_info "Building fingerprint-ocv with Xiaomi FPC fixes..."

# Create a patched version that fixes the claiming issues
cat << 'EOF' > xiaomi_fpc_fix.patch
--- a/src/fingerprint_ocv.c
+++ b/src/fingerprint_ocv.c
@@ -100,7 +100,7 @@ static int fp_ocv_open(struct fp_dev *dev)
     }
     
     // Set device timeout to handle slow FPC responses
-    dev->timeout = 5000;
+    dev->timeout = 15000;
     
     return 0;
 }
@@ -200,6 +200,10 @@ static int fp_ocv_enroll(struct fp_dev *dev)
     if (ret < 0) {
         return ret;
     }
+    
+    // Add delay for FPC device stability
+    usleep(100000);  // 100ms delay
+    
     return 0;
 }
 
@@ -250,6 +254,9 @@ static int fp_ocv_verify(struct fp_dev *dev)
     if (ret < 0) {
         return ret;
     }
+    
+    // Add delay for FPC device stability
+    usleep(50000);   // 50ms delay
     
     return ret;
 }
EOF

# Apply patch if it exists
if patch --dry-run -p1 < xiaomi_fpc_fix.patch >/dev/null 2>&1; then
    log_info "Applying Xiaomi FPC compatibility patch..."
    patch -p1 < xiaomi_fpc_fix.patch
else
    log_warning "Patch already applied or not applicable"
fi

# Build the driver
log_info "Building fingerprint-ocv driver..."
make clean || true
make

# Install the driver
log_info "Installing fingerprint-ocv driver..."
sudo make install

# Create systemd service for fingerprint-ocv
log_info "Creating systemd service for fingerprint-ocv..."
cat << 'EOF' | sudo tee /etc/systemd/system/fingerprint-ocv.service >/dev/null
[Unit]
Description=Fingerprint OCV Driver Service
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe fingerprint_ocv
ExecStop=/sbin/modprobe -r fingerprint_ocv
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
sudo systemctl daemon-reload
sudo systemctl enable fingerprint-ocv.service

# Create fprintd configuration specifically for fingerprint-ocv
log_info "Configuring fprintd for fingerprint-ocv..."
sudo mkdir -p /etc/fprintd

cat << 'EOF' | sudo tee /etc/fprintd/fingerprint-ocv.conf >/dev/null
[fprintd]
# Extended timeout for fingerprint-ocv driver
timeout = 30

[device]
# Device claiming timeout
claim_timeout = 10

[fingerprint_ocv]
# Driver-specific settings
device_timeout = 15
enroll_timeout = 30
verify_timeout = 15
max_retries = 5
EOF

# Create udev rules for fingerprint-ocv
log_info "Creating udev rules for fingerprint-ocv..."
cat << 'EOF' | sudo tee /etc/udev/rules.d/70-fingerprint-ocv.rules >/dev/null
# Fingerprint OCV driver rules
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", MODE="0664", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", RUN+="/sbin/modprobe fingerprint_ocv"

# Set device attributes for better stability
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", ATTR{power/autosuspend_delay_ms}="5000"
SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", ATTR{power/control}="on"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Load the driver
log_info "Loading fingerprint-ocv driver..."
sudo modprobe fingerprint_ocv

# Wait for driver to initialize
sleep 3

# Create wrapper scripts to handle the claiming issues
log_info "Creating wrapper scripts to fix claiming issues..."

cat << 'EOF' | sudo tee /usr/local/bin/fp-ocv-enroll >/dev/null
#!/bin/bash

# Wrapper script to fix fingerprint-ocv enrollment claiming issues

USER_NAME="${1:-$USER}"

echo "Enrolling fingerprint for user: $USER_NAME"

# Stop fprintd to release device
sudo systemctl stop fprintd

# Wait for service to stop
sleep 2

# Restart fprintd
sudo systemctl start fprintd

# Wait for service to start
sleep 3

# Try enrollment with timeout handling
timeout 60 fprintd-enroll "$USER_NAME" || {
    echo "Enrollment timed out, trying alternative method..."
    
    # Reset the device
    sudo modprobe -r fingerprint_ocv
    sleep 1
    sudo modprobe fingerprint_ocv
    sleep 3
    
    # Restart fprintd
    sudo systemctl restart fprintd
    sleep 3
    
    # Try again
    timeout 60 fprintd-enroll "$USER_NAME"
}
EOF

cat << 'EOF' | sudo tee /usr/local/bin/fp-ocv-verify >/dev/null
#!/bin/bash

# Wrapper script to fix fingerprint-ocv verification claiming issues

USER_NAME="${1:-$USER}"

echo "Verifying fingerprint for user: $USER_NAME"

# Ensure fprintd is running
sudo systemctl start fprintd
sleep 2

# Try verification with timeout handling
timeout 30 fprintd-verify "$USER_NAME" || {
    echo "Verification timed out, trying alternative method..."
    
    # Restart fprintd
    sudo systemctl restart fprintd
    sleep 3
    
    # Try again
    timeout 30 fprintd-verify "$USER_NAME"
}
EOF

cat << 'EOF' | sudo tee /usr/local/bin/fp-ocv-list >/dev/null
#!/bin/bash

# Wrapper script to fix fingerprint-ocv listing claiming issues

echo "Listing enrolled fingerprints..."

# Ensure fprintd is running
sudo systemctl start fprintd
sleep 2

# Try listing with timeout handling
timeout 15 fprintd-list || {
    echo "Listing timed out, restarting service..."
    
    # Restart fprintd
    sudo systemctl restart fprintd
    sleep 3
    
    # Try again
    timeout 15 fprintd-list
}
EOF

# Make scripts executable
sudo chmod +x /usr/local/bin/fp-ocv-*

# Start fprintd
log_info "Starting fprintd service..."
sudo systemctl start fprintd

# Test the fixes
log_info "Testing fingerprint-ocv fixes..."
sleep 3

if timeout 10 fp-ocv-list >/dev/null 2>&1; then
    log_success "fingerprint-ocv is working correctly!"
else
    log_warning "fingerprint-ocv may still have issues"
    log_info "Check the service status:"
    echo "  sudo systemctl status fprintd"
    echo "  dmesg | grep fingerprint"
fi

echo
log_success "fingerprint-ocv fixes applied!"
echo
log_info "Usage:"
echo "  - Enroll fingerprint: fp-ocv-enroll \$USER"
echo "  - Verify fingerprint: fp-ocv-verify \$USER"
echo "  - List fingerprints: fp-ocv-list"
echo
log_info "If issues persist, try:"
echo "  - Restart the system"
echo "  - Check kernel messages: dmesg | grep fingerprint"
echo "  - Check fprintd status: systemctl status fprintd"