# FPC Fingerprint Scanner Driver for Linux

A Linux kernel driver for FPC1020/FPC1155 fingerprint scanners found in Xiaomi laptops and other compatible brands.

## Features

- **Hardware Support**: Compatible with Xiaomi laptop fingerprint scanners
- **Error Recovery**: Automatic hardware failure detection and recovery
- **Multi-Distribution Support**: Works on major Linux distributions
- **libfprint Integration**: Desktop environment support
- **PAM Authentication**: Login and sudo authentication

## Supported Hardware

### Device IDs
- `10a5:9201` - FPC Sensor Controller (Standard)
- `2717:0368` - Xiaomi FPC Implementation Gen 1
- `2717:0369` - Xiaomi FPC Implementation Gen 2
- `2717:036A` - Xiaomi FPC Implementation Gen 3
- `2717:036B` - Xiaomi FPC Implementation Gen 4

### Compatible Laptops

#### Primary Target: Xiaomi Laptops
- Mi Notebook Pro 15.6" (2017-2019)
- Mi Notebook Pro 14" (2020-2022)
- Mi Notebook Air 13.3"/12.5" (2018-2020)
- RedmiBook 13"/14"/16" (2019-2022)
- Timi Book Pro 14" (2022)

#### Other Compatible Brands
- Huawei MateBook series
- Honor MagicBook series
- Select ASUS ZenBook models
- Select Lenovo IdeaPad/Yoga models

### Hardware Verification
Check if your laptop is compatible:
```bash
# Check for supported fingerprint scanner
lsusb | grep -E "(10a5|2717)"
```

## Installation

### Quick Installation
```bash
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh
```

## Usage

### Fingerprint Enrollment
```bash
# Enroll your fingerprint
fprintd-enroll
```

### Verification
```bash
# Test fingerprint verification
fprintd-verify
```

### Desktop Integration
- **GNOME**: Settings → Users → Add Fingerprint
- **KDE**: System Settings → Users → Add Fingerprint

## Troubleshooting

```bash
# Check if device is detected
lsusb | grep -E "(10a5|2717)"

# Check driver status
lsmod | grep fp_xiaomi

# Run diagnostics
sudo bash scripts/diagnostics.sh
```

## Project Structure

```
xiaomi-fingerprint-driver/
├── src/                    # Driver source code
├── scripts/                # Installation scripts
└── docs/                   # Documentation
```

## Documentation

- [Installation Guide](docs/installation-guide.md)
- [Architecture](docs/architecture.md)
- [FAQ](docs/FAQ.md)

## License

This project is licensed under the GNU General Public License v2.0.

## Disclaimer

This is an unofficial driver created through reverse engineering for interoperability purposes. We are not affiliated with Xiaomi Corporation.