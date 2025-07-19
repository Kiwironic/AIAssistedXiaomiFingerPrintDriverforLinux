# Xiaomi Fingerprint Scanner Driver - Installation Guide

This comprehensive guide covers installation procedures for all major Linux distributions, including troubleshooting and fallback options.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Distribution-Specific Instructions](#distribution-specific-instructions)
3. [Automated Installation](#automated-installation)
4. [Manual Installation](#manual-installation)
5. [Post-Installation Configuration](#post-installation-configuration)
6. [Troubleshooting](#troubleshooting)
7. [Fallback Options](#fallback-options)

## Prerequisites

### Hardware Requirements
- **Xiaomi laptop** with supported fingerprint scanner (see [Hardware Compatibility Database](hardware-compatibility-database.md))
- **Supported Device IDs**: `2717:0368`, `2717:0369`, `2717:036A`, `2717:036B`, `10a5:9201`
- **USB 2.0 or higher** port (built-in scanners use internal USB)
- **Minimum 4GB RAM** (8GB recommended for compilation)
- **20GB free disk space** (for development headers and build tools)

### Software Requirements
- **Linux kernel 4.15 or higher** (5.4+ recommended)
- **GCC compiler** (version 7.0+)
- **Make build system** (GNU Make 4.0+)
- **Kernel headers** for your distribution
- **Git** (for source installation)
- **Root/sudo access** for installation
- **Internet connection** for package downloads

### Verified Compatible Systems
- **Ubuntu**: 20.04 LTS, 22.04 LTS, 24.04 LTS
- **Linux Mint**: 20.x, 21.x (all editions)
- **Fedora**: 38, 39, 40 (Workstation/Server)
- **Debian**: 11 (Bullseye), 12 (Bookworm)
- **Arch Linux**: Rolling release (current)
- **openSUSE**: Leap 15.4/15.5, Tumbleweed
- **RHEL/CentOS**: 8, 9 (and derivatives)

### Hardware Verification
Before installation, verify your hardware compatibility:
```bash
# Check your fingerprint scanner device ID
lsusb | grep -E "(2717|10a5)"

# Expected output examples:
# Bus 001 Device 003: ID 2717:0368 Xiaomi Inc. Fingerprint Reader
# Bus 001 Device 003: ID 10a5:9201 FPC Fingerprint Reader
```

## Distribution-Specific Instructions

### Ubuntu / Debian / Linux Mint

#### Ubuntu 20.04 LTS / 22.04 LTS / 24.04 LTS
```bash
# Update package list
sudo apt update

# Install build dependencies
sudo apt install -y build-essential linux-headers-$(uname -r) git cmake
sudo apt install -y libusb-1.0-0-dev libfprint-2-dev fprintd
sudo apt install -y dkms udev

# Clone repository
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver

# Run compatibility check
sudo bash scripts/hardware-compatibility-check.sh -v

# Install driver
sudo bash scripts/install-driver.sh --distro ubuntu

# Configure system
sudo bash scripts/configure-fprintd.sh
```

#### Debian 11 (Bullseye) / 12 (Bookworm)
```bash
# Enable non-free repositories (if needed)
sudo sed -i 's/main$/main contrib non-free/' /etc/apt/sources.list
sudo apt update

# Install dependencies
sudo apt install -y build-essential linux-headers-$(uname -r) git
sudo apt install -y libusb-1.0-0-dev libfprint-2-dev fprintd-dev
sudo apt install -y dkms module-assistant

# Prepare kernel module environment
sudo m-a prepare

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro debian
```

#### Linux Mint 20.x / 21.x
```bash
# Same as Ubuntu, but with Mint-specific adjustments
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git
sudo apt install -y libusb-1.0-0-dev libfprint-2-dev fprintd

git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro mint
```

### Red Hat / CentOS / Rocky Linux / AlmaLinux

#### RHEL 8 / CentOS 8 / Rocky Linux 8 / AlmaLinux 8
```bash
# Enable EPEL repository
sudo dnf install -y epel-release

# Install development tools
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y kernel-devel kernel-headers git cmake
sudo dnf install -y libusb1-devel libfprint-devel fprintd

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro rhel8
```

#### RHEL 9 / Rocky Linux 9 / AlmaLinux 9
```bash
# Enable CodeReady Builder (CRB) repository
sudo dnf config-manager --set-enabled crb
sudo dnf install -y epel-release

# Install dependencies
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y kernel-devel-$(uname -r) git cmake
sudo dnf install -y libusb1-devel libfprint-devel fprintd

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro rhel9
```

#### CentOS 7 (Legacy Support)
```bash
# Install development tools
sudo yum groupinstall -y "Development Tools"
sudo yum install -y kernel-devel-$(uname -r) git cmake3
sudo yum install -y libusb1-devel epel-release

# Install libfprint from EPEL
sudo yum install -y libfprint-devel fprintd

# Install driver with legacy support
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro centos7 --legacy
```

### Fedora

#### Fedora 38 / 39 / 40
```bash
# Install development packages
sudo dnf groupinstall -y "Development Tools" "C Development Tools and Libraries"
sudo dnf install -y kernel-devel kernel-headers git cmake
sudo dnf install -y libusb1-devel libfprint-devel fprintd

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro fedora
```

### openSUSE

#### openSUSE Leap 15.4 / 15.5
```bash
# Install development pattern
sudo zypper install -y -t pattern devel_basis
sudo zypper install -y kernel-default-devel git cmake
sudo zypper install -y libusb-1_0-devel libfprint-devel fprintd

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro opensuse-leap
```

#### openSUSE Tumbleweed
```bash
# Install development tools
sudo zypper install -y -t pattern devel_basis
sudo zypper install -y kernel-default-devel git cmake
sudo zypper install -y libusb-1_0-devel libfprint-devel fprintd

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro opensuse-tumbleweed
```

### Arch Linux / Manjaro

#### Arch Linux
```bash
# Update system
sudo pacman -Syu

# Install base development packages
sudo pacman -S --needed base-devel linux-headers git cmake
sudo pacman -S libusb libfprint fprintd

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro arch
```

#### Manjaro
```bash
# Update system
sudo pacman -Syu

# Install development tools
sudo pacman -S --needed base-devel $(pacman -Qs linux | grep headers | awk '{print $1}' | head -1)
sudo pacman -S git cmake libusb libfprint fprintd

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro manjaro
```

### Gentoo

#### Gentoo Linux
```bash
# Ensure kernel sources are available
emerge --ask sys-kernel/gentoo-sources

# Install dependencies
emerge --ask dev-vcs/git dev-util/cmake
emerge --ask dev-libs/libusb sys-auth/libfprint sys-auth/fprintd

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro gentoo
```

### Alpine Linux

#### Alpine Linux 3.17 / 3.18
```bash
# Install development packages
sudo apk add build-base linux-headers git cmake
sudo apk add libusb-dev libfprint-dev fprintd

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro alpine
```

### Void Linux

#### Void Linux
```bash
# Install development packages
sudo xbps-install -S base-devel linux-headers git cmake
sudo xbps-install -S libusb-devel libfprint-devel fprintd

# Install driver
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --distro void
```

## Automated Installation

### Universal Installation Script

For most distributions, you can use our universal installation script:

```bash
# Download and run the universal installer
curl -fsSL https://raw.githubusercontent.com/your-repo/xiaomi-fingerprint-driver/main/scripts/universal-install.sh | sudo bash

# Or with wget
wget -qO- https://raw.githubusercontent.com/your-repo/xiaomi-fingerprint-driver/main/scripts/universal-install.sh | sudo bash
```

### Interactive Installation

For a guided installation experience:

```bash
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/interactive-install.sh
```

## Manual Installation

### Step-by-Step Manual Installation

1. **Download Source Code**
   ```bash
   git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
   cd xiaomi-fingerprint-driver
   ```

2. **Check Hardware Compatibility**
   ```bash
   sudo bash scripts/hardware-compatibility-check.sh -v
   ```

3. **Install Dependencies** (distribution-specific, see above)

4. **Compile Driver**
   ```bash
   cd src
   make clean
   make
   ```

5. **Install Driver Module**
   ```bash
   sudo make install
   sudo depmod -a
   ```

6. **Install udev Rules**
   ```bash
   sudo cp ../udev/60-fp-xiaomi.rules /etc/udev/rules.d/
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

7. **Load Driver**
   ```bash
   sudo modprobe fp_xiaomi_driver
   ```

8. **Configure libfprint**
   ```bash
   sudo bash ../scripts/configure-fprintd.sh
   ```

## Post-Installation Configuration

### Enable Services
```bash
# Enable and start fprintd service
sudo systemctl enable fprintd.service
sudo systemctl start fprintd.service

# Check service status
sudo systemctl status fprintd.service
```

### Configure PAM (for login authentication)
```bash
# Ubuntu/Debian
sudo pam-auth-update

# RHEL/CentOS/Fedora
sudo authselect select sssd with-fingerprint

# Manual PAM configuration
echo "auth sufficient pam_fprintd.so" | sudo tee -a /etc/pam.d/common-auth
```

### Test Installation
```bash
# Test driver functionality
sudo bash scripts/test-driver.sh

# Test fingerprint enrollment
fprintd-enroll

# Test fingerprint verification
fprintd-verify
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: Device Not Detected
```bash
# Check USB connection
lsusb | grep 2717

# Check permissions
ls -l /dev/bus/usb/*/

# Run diagnostics
sudo bash scripts/diagnostics.sh hardware
```

#### Issue: Driver Compilation Fails
```bash
# Check kernel headers
ls /lib/modules/$(uname -r)/build

# Install missing headers (Ubuntu/Debian)
sudo apt install linux-headers-$(uname -r)

# Install missing headers (RHEL/CentOS)
sudo dnf install kernel-devel-$(uname -r)
```

#### Issue: Permission Denied
```bash
# Add user to required groups
sudo usermod -a -G plugdev,input $USER

# Logout and login again
# Or run: newgrp plugdev
```

#### Issue: Conflicting Drivers
```bash
# Check for conflicts
lsmod | grep -E "(libfprint|validity|synaptics)"

# Remove conflicting drivers
sudo rmmod conflicting_driver_name

# Blacklist conflicting drivers
echo "blacklist conflicting_driver" | sudo tee -a /etc/modprobe.d/blacklist.conf
```

### Advanced Troubleshooting

#### Enable Debug Mode
```bash
# Load driver with debug enabled
sudo rmmod fp_xiaomi_driver
sudo modprobe fp_xiaomi_driver debug=1

# Check debug messages
sudo dmesg | tail -50
```

#### Collect Diagnostic Information
```bash
# Run comprehensive diagnostics
sudo bash scripts/diagnostics.sh full -v -l

# Generate diagnostic report
sudo bash scripts/diagnostics.sh export -f html -o diagnostic_report.html
```

## Fallback Options

### If Primary Driver Fails

#### Option 1: Generic libfprint Driver
```bash
sudo bash scripts/fallback-driver.sh activate -s generic_libfprint
```

#### Option 2: Compatibility Mode
```bash
sudo bash scripts/fallback-driver.sh activate -s compatibility_mode
```

#### Option 3: User-Space Only
```bash
sudo bash scripts/fallback-driver.sh activate -s user_space_only
```

### Restore Original Configuration
```bash
sudo bash scripts/fallback-driver.sh restore
```

## Distribution-Specific Notes

### Ubuntu/Debian Notes
- Secure Boot may require driver signing
- Use `mokutil` to manage Secure Boot keys if needed
- Consider using DKMS for automatic kernel updates

### RHEL/CentOS Notes
- SELinux may block driver access
- Use `setsebool -P authlogin_yubikey on` if needed
- Consider creating custom SELinux policy

### Fedora Notes
- Automatic updates may require DKMS
- Wayland may have different behavior than X11
- Check firewall settings if using network features

### Arch Linux Notes
- AUR packages may be available
- Use `dkms` for kernel update compatibility
- Check `/etc/mkinitcpio.conf` for module loading

### openSUSE Notes
- YaST can be used for some configuration
- Check AppArmor profiles if access is denied
- Use `zypper` for dependency management

## Support and Community

### Getting Help
- Check our [FAQ](FAQ.md)
- Search existing [GitHub Issues](https://github.com/your-repo/xiaomi-fingerprint-driver/issues)
- Join our [Discord Community](https://discord.gg/your-invite)
- Read the [Troubleshooting Guide](troubleshooting.md)

### Reporting Issues
When reporting issues, please include:
- Distribution and version
- Kernel version (`uname -r`)
- Hardware model and device ID
- Output from diagnostic script
- Relevant log files

### Contributing
- See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines
- Test on your distribution and report results
- Submit patches for distribution-specific fixes
- Help improve documentation

## Security Considerations

### Secure Boot
If Secure Boot is enabled:
1. Sign the driver module with your own key
2. Or disable Secure Boot temporarily
3. Or use the fallback user-space driver

### Permissions
The driver requires appropriate permissions:
- Device access permissions via udev rules
- User group membership (plugdev, input)
- SELinux/AppArmor policy adjustments if needed

### Data Security
- Fingerprint templates are stored locally
- No data is transmitted over network
- Templates are encrypted using system keys
- Consider full disk encryption for additional security

---

**Note**: This installation guide is regularly updated. For the latest version and distribution-specific updates, check our [GitHub repository](https://github.com/your-repo/xiaomi-fingerprint-driver).