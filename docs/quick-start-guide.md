# Quick Start Guide - Ubuntu, Mint & Fedora

This guide provides step-by-step instructions specifically optimized for Ubuntu, Linux Mint, and Fedora users.

## 🚀 One-Command Installation

### For Ubuntu 20.04/22.04/24.04
```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/xiaomi-fingerprint-driver/main/scripts/universal-install.sh | sudo bash
```

### For Linux Mint 20.x/21.x
```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/xiaomi-fingerprint-driver/main/scripts/universal-install.sh | sudo bash
```

### For Fedora 38/39/40
```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/xiaomi-fingerprint-driver/main/scripts/universal-install.sh | sudo bash
```

## 📋 Step-by-Step Installation

### Hardware Compatibility Check First!
Before installation, verify your laptop is supported:

```bash
# Check your fingerprint scanner
lsusb | grep -E "(2717|10a5)"

# Supported outputs:
# ID 2717:0368 - Mi Notebook Pro/Air, RedmiBook (Gen 1)
# ID 2717:0369 - Newer Mi Notebook, RedmiBook Pro (Gen 2)  
# ID 2717:036A - Latest Mi Notebook, Timi Book (Gen 3)
# ID 2717:036B - Newest models with enhanced security (Gen 4)
# ID 10a5:9201 - Timi Book Pro, some Huawei/Honor models
```

**✅ Confirmed Compatible Models:**
- Mi Notebook Pro 15.6"/14" (2021-2024)
- Mi Notebook Air 13.3"/12.5" (2019-2023)
- RedmiBook Pro 15"/14"/13" (2020-2024)
- Timi Book Pro 14"/15" (2021-2024) ⭐ **Primary Development Model**
- Mi Gaming Laptop 15.6" (2019-2021)
- Mi Notebook Ultra 3.5K (2022-2024)

### Ubuntu/Linux Mint Users

#### Step 1: Update Your System
```bash
# Update package repositories
sudo apt update && sudo apt upgrade -y

# Reboot if kernel was updated
sudo reboot  # Only if kernel was updated
```

#### Step 2: Install Prerequisites
```bash
# Install essential build tools
sudo apt install -y curl git wget build-essential

# Verify installation
git --version
curl --version
gcc --version
```

#### Step 3: Download and Install Driver
```bash
# Clone the repository
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver

# Make scripts executable
chmod +x scripts/*.sh

# Run the installer
sudo ./scripts/install-driver.sh
```

#### Step 4: Verify Installation
```bash
# Check if driver is loaded
lsmod | grep fp_xiaomi

# Check if device is detected
lsusb | grep -E "(2717|10a5)"

# Test fingerprint service
systemctl status fprintd
```

#### Step 5: Enroll Your Fingerprint
```bash
# Enroll fingerprint for current user
fprintd-enroll

# Or use GUI: Settings → Users → Add Fingerprint
```

### Fedora Users

#### Step 1: Update Your System
```bash
# Update all packages
sudo dnf update -y

# Reboot if kernel was updated
sudo reboot  # Only if kernel was updated
```

#### Step 2: Install Prerequisites
```bash
# Install essential tools
sudo dnf install -y curl git wget

# Verify installation
git --version
curl --version
```

#### Step 3: Download and Install Driver
```bash
# Clone the repository
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver

# Make scripts executable
chmod +x scripts/*.sh

# Run the installer
sudo ./scripts/install-driver.sh
```

#### Step 4: Configure SELinux (if enabled)
```bash
# Check if SELinux is enforcing
getenforce

# If enforcing, configure for fingerprint access
sudo setsebool -P authlogin_yubikey on
```

#### Step 5: Verify Installation
```bash
# Check if driver is loaded
lsmod | grep fp_xiaomi

# Check if device is detected
lsusb | grep -E "(2717|10a5)"

# Test fingerprint service
systemctl status fprintd
```

#### Step 6: Enroll Your Fingerprint
```bash
# Enroll fingerprint for current user
fprintd-enroll

# Or use GUI: Settings → Users → Add Fingerprint
```

## 🔧 Distribution-Specific Troubleshooting

### Ubuntu/Mint Common Issues

#### Issue: "Package not found" errors
```bash
# Enable universe repository (Ubuntu)
sudo add-apt-repository universe
sudo apt update

# For Mint, ensure all repositories are enabled
sudo apt install software-properties-common
```

#### Issue: Secure Boot blocking driver
```bash
# Check if Secure Boot is enabled
mokutil --sb-state

# If enabled, either:
# 1. Disable Secure Boot in BIOS, or
# 2. Sign the module (advanced)
```

#### Issue: Permission denied for device access
```bash
# Add user to required groups
sudo usermod -a -G plugdev,input $USER

# Log out and back in
# Or run: newgrp plugdev
```

### Fedora Common Issues

#### Issue: SELinux blocking access
```bash
# Check SELinux status
getenforce
sestatus

# Allow fingerprint access
sudo setsebool -P authlogin_yubikey on

# Check for denials
sudo ausearch -m avc -ts recent | grep fprintd
```

#### Issue: Firewall blocking services
```bash
# Check firewall status
sudo firewall-cmd --state

# Fingerprint services are local, no firewall changes needed
# But if issues persist, check:
sudo firewall-cmd --list-all
```

#### Issue: Missing development packages
```bash
# Install complete development environment
sudo dnf groupinstall "Development Tools"
sudo dnf install kernel-devel kernel-headers

# Verify kernel headers
ls /lib/modules/$(uname -r)/build
```

## 🧪 Testing Your Installation

### Quick Test Commands

#### Check Hardware Detection
```bash
# List USB devices (should show Xiaomi device)
lsusb | grep -E "(2717|10a5)"

# Check if driver is loaded
lsmod | grep fp_xiaomi

# Check device nodes
ls -la /dev/fp_xiaomi* 2>/dev/null || echo "No device nodes found"
```

#### Test Fingerprint Service
```bash
# Check fprintd status
systemctl status fprintd

# List available devices
fprintd-list

# Test enrollment (will prompt for finger)
fprintd-enroll --finger right-index-finger

# Test verification
fprintd-verify
```

#### Run Comprehensive Diagnostics
```bash
# Run our diagnostic script
sudo ./scripts/diagnostics.sh

# Generate HTML report
sudo ./scripts/diagnostics.sh export -f html -o ~/fingerprint-report.html
```

## 🎯 Desktop Environment Integration

### GNOME (Ubuntu/Fedora default)
1. Open **Settings**
2. Go to **Users** or **Privacy & Security**
3. Click **Add Fingerprint**
4. Follow the enrollment wizard

### KDE Plasma
1. Open **System Settings**
2. Go to **Users**
3. Click **Add Fingerprint**
4. Follow the enrollment process

### Cinnamon (Linux Mint default)
1. Open **System Settings**
2. Go to **Users and Groups**
3. Select your user and click **Add Fingerprint**
4. Complete the enrollment

### XFCE
1. Install fingerprint GUI: `sudo apt install fingerprint-gui` (Ubuntu/Mint)
2. Run `fingerprint-gui` from applications menu
3. Follow the setup wizard

## 🔐 Login Authentication Setup

### Ubuntu/Mint - Enable Fingerprint Login
```bash
# Configure PAM for fingerprint authentication
sudo pam-auth-update

# Select "Fingerprint authentication" and press OK
# This enables fingerprint for login, sudo, and screen unlock
```

### Fedora - Enable Fingerprint Login
```bash
# Configure authentication with authselect
sudo authselect select sssd with-fingerprint

# Or for systems without SSSD:
sudo authselect select minimal with-fingerprint
```

### Manual PAM Configuration (if needed)
```bash
# Edit PAM configuration for login
sudo nano /etc/pam.d/common-auth  # Ubuntu/Mint
sudo nano /etc/pam.d/system-auth  # Fedora

# Add this line at the top:
# auth sufficient pam_fprintd.so

# For sudo access, edit:
sudo nano /etc/pam.d/sudo

# Add the same line at the top
```

## 📱 Application Integration

### Supported Applications
- **System Login**: Username/password or fingerprint
- **Screen Unlock**: Automatic integration
- **Sudo Commands**: Use fingerprint instead of password
- **Firefox**: With proper PAM configuration
- **Chrome/Chromium**: Limited support
- **LibreOffice**: Document protection
- **GNOME Keyring**: Unlock with fingerprint

### Testing Application Integration
```bash
# Test sudo with fingerprint
sudo whoami

# Test screen lock (lock screen and try to unlock)
# Ubuntu/GNOME: Super+L
# Fedora/GNOME: Super+L
# Mint/Cinnamon: Ctrl+Alt+L
```

## 🆘 Getting Help

### Quick Diagnostics
```bash
# Run hardware compatibility check
sudo ./scripts/hardware-compatibility-check.sh -v

# Run full diagnostics
sudo ./scripts/diagnostics.sh full -v

# Check system logs
journalctl -u fprintd -f
```

### Common Log Locations
- **Ubuntu/Mint**: `/var/log/syslog`, `journalctl`
- **Fedora**: `journalctl`, `/var/log/messages`
- **Driver logs**: `dmesg | grep fp_xiaomi`

### Support Resources
- **GitHub Issues**: Report bugs and get help
- **Documentation**: Check `docs/` folder
- **Community**: Join our Discord server
- **Email**: support@your-domain.com

## 🎉 Success Indicators

Your installation is successful when:

✅ **Hardware Detection**: `lsusb` shows your Xiaomi device  
✅ **Driver Loading**: `lsmod | grep fp_xiaomi` shows the driver  
✅ **Service Running**: `systemctl status fprintd` shows active  
✅ **Device Nodes**: `/dev/fp_xiaomi*` files exist  
✅ **Enrollment Works**: `fprintd-enroll` completes successfully  
✅ **Verification Works**: `fprintd-verify` recognizes your finger  
✅ **Login Integration**: You can unlock screen with fingerprint  

## 🔄 Updating the Driver

### When to Update
- New kernel installed
- Driver updates available
- Hardware not working after system update

### Update Process
```bash
# Navigate to driver directory
cd xiaomi-fingerprint-driver

# Pull latest changes
git pull origin main

# Reinstall driver
sudo ./scripts/install-driver.sh

# Or use DKMS for automatic updates
sudo dkms install .
```

---

**Need more help?** Check our [complete installation guide](installation-guide.md) or [troubleshooting guide](troubleshooting.md).