# Linux Fingerprint Scanner Driver

A reverse-engineered Linux driver for fingerprint scanners, ported from Windows drivers.

## Project Overview

This project aims to create a comprehensive Linux driver for fingerprint scanners by reverse engineering existing Windows drivers. The driver is designed to work across multiple Linux distributions and kernel versions.

## Hardware Support

- **Target Hardware**: FPC Fingerprint Reader (Disum)
- **Vendor**: Fingerprint Cards AB
- **Device ID**: VID:PID 10A5:9201
- **Interface**: USB

## Project Status

🔄 **In Development** - Hardware analysis complete, moving to libfprint research

### Current Phase: Research and Analysis ✅
- [x] Hardware identification - **FPC Fingerprint Reader (Disum) VID:PID 10A5:9201**
- [x] Windows driver analysis - **Complete**
- [ ] Protocol reverse engineering - **Next Phase**
- [ ] Linux kernel module development - **Planned**
- [ ] Testing and validation - **Planned**

### Next Phase: libfprint Integration Research
- [ ] Check existing libfprint support for this device
- [ ] Analyze similar FPC implementations
- [ ] Plan development approach

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

- [Development Plan](docs/development-plan.md) - **Current project roadmap**
- [Hardware Analysis](hardware-analysis/device-analysis.md) - **Complete device specifications**
- [Reverse Engineering Process](docs/reverse-engineering.md)
- [Driver Architecture](docs/architecture.md)
- [Information Needed](docs/information-needed.md)

## Contributing

This project follows standard Linux kernel development practices. Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the GPL v2 License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This driver is developed through reverse engineering for interoperability purposes. All work complies with applicable laws and regulations.