# Installation Guide

This guide provides installation instructions for the FPC Fingerprint Scanner Driver on various Linux distributions.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Installation](#quick-installation)
3. [Distribution-Specific Instructions](#distribution-specific-instructions)
4. [Manual Installation](#manual-installation)
5. [Troubleshooting](#troubleshooting)
6. [Uninstallation](#uninstallation)

## Prerequisites

### Hardware Requirements
- A laptop with a supported fingerprint scanner (see [Hardware Compatibility](hardware-compatibility-database.md))
- **Supported Device IDs**: `10a5:9201` (FPC L:0001), `2717:0368`, `2717:0369`, `2717:036A`, `2717:036B`
- **Minimum**: 2GB RAM, 10GB free disk space
- **Recommended**: 4GB+ RAM, 20GB free disk space

### Software Requirements
- **Linux kernel**: 5.4 or newer (5.15+ recommended)
- **GCC**: 9.0 or newer
- **Make**: 4.0 or newer
- **Git**: For source installation
- **libfprint**: 1.90 or newer
- **Root/sudo access**

### Verified Distributions
- **Ubuntu**: 22.04 LTS, 24.04 LTS
- **Fedora**: 38, 39, 40
- **Debian**: 12 (Bookworm)
- **Arch Linux**: Rolling release
- **Linux Mint**: 21.x (based on Ubuntu 22.04)
- **RHEL/CentOS/Rocky/AlmaLinux**: 9.x

### Hardware Verification
Before installation, verify your fingerprint scanner:
```bash
# Check your fingerprint scanner device ID
lsusb | grep -E "(10a5:9201|2717:036[89AB])"

# For detailed information (requires root):
sudo lsusb -v -d 10a5:9201 2>/dev/null || sudo lsusb -v -d 2717:0368 2>/dev/null

# Check kernel messages
dmesg | grep -i -E "(fpc|fingerprint)" | tail -20
```

## Quick Installation

For most users, the automated installation script is recommended:

```bash
# Clone the repository
git clone https://github.com/Kiwironic/AIAssistedXiaomiFingerPrintDriverforLinux.git
cd AIAssistedXiaomiFingerPrintDriverforLinux

# Run the installation script
sudo ./scripts/install-driver.sh

# Enroll your fingerprint
fprintd-enroll
```

## Distribution-Specific Instructions

### Ubuntu / Debian / Linux Mint

#### Ubuntu 22.04 LTS / 24.04 LTS, Linux Mint 21.x
```bash
# Install dependencies
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git
sudo apt install -y libfprint-2-dev fprintd libfprint-2-2

# Proceed with the quick installation above
```

#### Debian 12 (Bookworm)
```bash
# Install dependencies
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git
sudo apt install -y libfprint-2-dev fprintd libfprint-2-2
```

### Fedora / RHEL / CentOS

#### Fedora 38/39/40
```bash
# Install dependencies
sudo dnf install -y gcc make kernel-devel kernel-headers
sudo dnf install -y libfprint-devel fprintd-pam fprintd
```

#### RHEL 9 / Rocky Linux 9 / AlmaLinux 9
```bash
# Enable EPEL and CodeReady Builder
sudo dnf install -y epel-release
sudo dnf config-manager --set-enabled crb

# Install dependencies
sudo dnf install -y gcc make kernel-devel kernel-headers
sudo dnf install -y libfprint-devel fprintd-pam fprintd
```

### Arch Linux / Manjaro

```bash
# Install dependencies
sudo pacman -S --needed base-devel linux-headers git
sudo pacman -S --needed libfprint fprintd
```

### openSUSE

#### openSUSE Tumbleweed / Leap 15.5+
```bash
# Install dependencies
sudo zypper install -y -t pattern devel_basis
sudo zypper install -y kernel-devel libfprint-devel fprintd
```

## Manual Installation

If the automated script doesn't work, you can install manually:

```bash
# Clone the repository
git clone https://github.com/Kiwironic/AIAssistedXiaomiFingerPrintDriverforLinux.git
cd AIAssistedXiaomiFingerPrintDriverforLinux

# Build and install
make
sudo make install

# Load the kernel module
sudo modprobe fpc1020

# Set up udev rules
sudo cp udev/60-fingerprint-sensor.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger

# Restart fprintd
sudo systemctl restart fprintd
```

## Troubleshooting

### Common Issues

#### Driver Not Loading
```bash
# Check if the module is loaded
lsmod | grep fpc

# Check kernel messages
dmesg | grep -i fpc

# Try manually loading the module
sudo modprobe fpc1020
```

#### Fingerprint Not Detected
```bash
# Check USB devices
lsusb | grep -E "(10a5:9201|2717:036[89AB])"

# Check udev rules
ls -l /etc/udev/rules.d/*fingerprint*.rules

# Check fprintd status
systemctl status fprintd
```

#### Permission Issues
```bash
# Add your user to the plugdev group
sudo usermod -aG plugdev $USER

# Reload udev rules
sudo udevadm control --reload
sudo udevadm trigger
```

### Debugging

Enable debug logging:
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