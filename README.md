# AI-Assisted Xiaomi Fingerprint Driver for Linux

A reverse-engineered Linux driver for Xiaomi laptop fingerprint scanners, ported from Windows drivers using AI assistance.

## Project Overview

This project aims to create a comprehensive Linux driver for Xiaomi laptop fingerprint scanners by reverse engineering existing Windows drivers. The driver is designed to work across multiple Linux distributions and kernel versions, developed with AI assistance for efficient reverse engineering and implementation.

## Hardware Support

- **Target Device**: Timi/Xiaomi Book Pro 14 2022 with FPC Fingerprint Reader (Disum)
- **Laptop Model**: Timi Book Pro 14 2022 / Xiaomi Book Pro 14 2022
- **Processor**: Intel i5-1240P
- **System SKU**: TM2117-40430
- **BIOS Version**: TIMI XMAAD4B0P1717
- **Scanner Manufacturer**: Fingerprint Cards AB
- **Device ID**: VID:PID 10A5:9201
- **Interface**: USB

## 🚀 Major Discovery: Existing Linux Support!

**BREAKTHROUGH**: The [fingerprint-ocv](https://github.com/vrolife/fingerprint-ocv) project targets the **exact same device**:
- **VID:PID**: 10A5:9201 ✅ **PERFECT MATCH**
- **Device**: FPC Sensor Controller L:0001 FW:021.26.2.x
- **Status**: Active Linux driver development

This significantly accelerates our development timeline and provides a proven codebase foundation!

## Project Status

🔄 **In Development** - Hardware analysis complete, existing Linux driver discovered!

### Current Phase: Research and Analysis ✅
- [x] Hardware identification - **FPC Fingerprint Reader (Disum) VID:PID 10A5:9201**
- [x] Windows driver analysis - **Complete**
- [ ] Protocol reverse engineering - **Next Phase**
- [ ] Linux kernel module development - **Planned**
- [ ] Testing and validation - **Planned**

### Next Phase: Existing Linux Driver Analysis ⚡
- [ ] **MAJOR DISCOVERY**: fingerprint-ocv project targets same VID:PID 10A5:9201
- [ ] Test fingerprint-ocv compatibility with Xiaomi Book Pro 14 2022
- [ ] Analyze existing implementation and contribute improvements

## Tested Hardware

### ✅ Confirmed Compatible
- **Laptop Model**: Timi/Xiaomi Book Pro 14 2022 (Intel i5-1240P)
- **System SKU**: TM2117-40430
- **BIOS Version**: TIMI XMAAD4B0P1717
- **Fingerprint Scanner**: FPC Fingerprint Reader (Disum) VID:PID 10A5:9201
- **Status**: Working on Windows 11 Pro, Linux driver in development

### 🔍 Potentially Compatible
Other Xiaomi laptops with the same FPC fingerprint scanner (VID:PID 10A5:9201) may also be compatible. Please check your device ID and contribute compatibility information.

## Requirements

### System Requirements
- Linux kernel 4.19+ (for maximum compatibility)
- Development tools: gcc, make, kernel headers
- USB development libraries (if USB device)

### Supported Distributions
- Fedora 42+
- Ubuntu 20.04+
- Debian 11+
- CentOS/RHEL 8+
- Arch Linux
- openSUSE

## Getting Started

### Prerequisites
```bash
# Fedora/RHEL
sudo dnf install kernel-devel gcc make

# Ubuntu/Debian
sudo apt install linux-headers-$(uname -r) build-essential

# Arch Linux
sudo pacman -S linux-headers base-devel
```

## Documentation

- [Development Plan](docs/development-plan.md) - **Updated project roadmap**
- [Existing Linux Support](hardware-analysis/existing-linux-support.md) - **🚀 fingerprint-ocv analysis**
- [Hardware Analysis](hardware-analysis/device-analysis.md) - **Complete device specifications**
- [Xiaomi Compatibility](hardware-analysis/xiaomi-compatibility.md) - **Supported Xiaomi laptop models**
- [libfprint Research](hardware-analysis/libfprint-research.md) - **Linux integration research**
- [Reverse Engineering Process](docs/reverse-engineering.md)
- [Driver Architecture](docs/architecture.md)

## Contributing

This project follows standard Linux kernel development practices. Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the GPL v2 License - see the [LICENSE](LICENSE) file for details.

## AI Development Approach

This project leverages AI assistance for:
- Automated hardware analysis and documentation
- Code generation following Linux kernel best practices
- Systematic reverse engineering methodology
- Quality assurance and testing strategies

## Disclaimer

This driver is developed through reverse engineering for interoperability purposes. All work complies with applicable laws and regulations. The AI assistance ensures systematic development while maintaining code quality and documentation standards.