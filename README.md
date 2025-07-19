# FPC Fingerprint Scanner Driver for Linux

A production-ready Linux kernel driver for FPC Sensor Controller L:0001 (10a5:9201) and compatible fingerprint scanners in modern laptops.

## ✨ Features

- **Hardware Support**: Native support for FPC Sensor Controller L:0001 (10a5:9201) and select Xiaomi implementations
- **Linux Integration**: Seamless integration with libfprint and PAM
- **Error Recovery**: Automatic failure detection and recovery
- **Multi-Distro**: Tested on Fedora, Ubuntu, Arch Linux, and more
- **Power Management**: Optimized for modern laptop power states

## 🚀 Quick Start

### Prerequisites
- Linux kernel 5.15 or newer
- Basic build tools (gcc, make, kernel headers)
- libfprint (v1.90+ recommended)

### Installation
```bash
# Clone the repository
git clone https://github.com/Kiwironic/AIAssistedXiaomiFingerPrintDriverforLinux.git
cd AIAssistedXiaomiFingerPrintDriverforLinux

# Install dependencies and driver (Fedora/RHEL)
sudo dnf install -y kernel-devel gcc make libfprint-devel

# Install driver
sudo ./scripts/install-driver.sh

# Enroll your fingerprint
fprintd-enroll
```

## ✔️ Supported Hardware

### Primary Device
- **Model**: FPC Sensor Controller L:0001
- **USB ID**: 10a5:9201
- **Firmware**: 021.26.2.031
- **Interface**: USB 2.0 High Speed (480Mbps)

### Confirmed Working Laptops
- **Xiaomi**:
  - Mi Notebook Pro 14/15.6" (2021-2022)
  - RedmiBook Pro 14/15 (2022)
  - Xiaomi Book Pro 14/16 (2022)
  - Redmi G Pro (2022)
  - Mi Notebook Air 13.3"
  - Mi Notebook Air 12.5"

- **Other Brands**:
  - ASUS ZenBook 14X OLED (UX5401)
  - Lenovo ThinkBook 13s/14/15 Gen 2
  - HONOR MagicBook 16 (2022)
  - HUAWEI MateBook 16 (2021)
  - DELL XPS 13 Plus (2022) - Partial support

For complete list, see [Hardware Compatibility](docs/hardware-compatibility-database.md)

## 🔍 Verify Your Hardware

```bash
# Check if your device is detected
lsusb | grep -i "10a5:9201"

# Expected output:
# Bus 003 Device 003: ID 10a5:9201 FPC FPC Sensor Controller L:0001 FW:021.26.2.031
```

## 📚 Documentation

- [Installation Guide](docs/installation-guide.md) - Step-by-step installation for all major distributions
- [Quick Start Guide](docs/quick-start-guide.md) - Get up and running quickly
- [Hardware Compatibility](docs/hardware-compatibility-database.md) - Complete list of supported devices and models
- [Troubleshooting](docs/FAQ.md) - Common issues and solutions
- [Development Guide](docs/development-guide.md) - For contributors and advanced users

## 🐛 Reporting Issues

Please include the following information when reporting issues:
1. Laptop model and year
2. Output of `lsusb -d 10a5:9201 -v`
3. Kernel version (`uname -r`)
4. Distribution and version
5. Detailed error logs from `dmesg | grep -i fpc`

## 🤝 Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) before submitting pull requests.

## 📄 License

This project is licensed under the **GNU General Public License v2.0**.

## ⚠️ Disclaimer

This is an unofficial driver created through reverse engineering for interoperability purposes. We are not affiliated with Fingerprint Cards AB, Xiaomi Corporation, or any other hardware manufacturer.