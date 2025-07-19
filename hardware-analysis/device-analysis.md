# Hardware Analysis Report - Xiaomi Laptop Fingerprint Scanner

## Device Information

### Primary Fingerprint Scanner (Xiaomi Laptop)
- **Device Name**: FPC Fingerprint Reader (Disum)
- **Manufacturer**: Fingerprint Cards AB
- **Vendor ID**: 10A5 (Fingerprint Cards AB)
- **Product ID**: 9201
- **Device ID**: USB\VID_10A5&PID_9201
- **Hardware IDs**: 
  - USB\VID_10A5&PID_9201&REV_0231
  - USB\VID_10A5&PID_9201
- **Status**: OK (Working)
- **Interface**: USB
- **Device Class**: Biometric
- **Service**: WUDFRd (Windows User-Mode Driver Framework)



## Driver Information

### FPC Driver Package
- **Driver Package**: fpc_disum_um_usb.inf
- **Location**: Windows DriverStore
- **Size**: 7,791 bytes
- **Date**: March 28, 2022
- **Type**: User-mode USB driver

### Windows Biometric Framework
- **Service**: WbioSrvc (Windows Biometric Service)
- **Provider Type**: Fingerprint
- **Biometric Type**: 8 (Fingerprint)
- **Configuration**: None active (not configured for Windows Hello)

## System Information

### Environment
- **OS**: Microsoft Windows 11 Pro
- **Laptop Model**: Timi Book Pro 14 2022 / Xiaomi Book Pro 14 2022
- **Processor**: Intel i5-1240P
- **System SKU**: TM2117-40430
- **BIOS Version**: TIMI XMAAD4B0P1717
- **Architecture**: x64

### Windows Hello Status
- **Status**: Not configured or unknown
- **Biometric Framework**: Available but not active

## Technical Specifications

### USB Details
- **Connection**: USB interface
- **Revision**: 0231

- **Driver Framework**: WUDF (Windows User-Mode Driver Framework)

### Device Capabilities
- **Type**: Capacitive fingerprint sensor (typical for FPC devices)
- **Vendor**: Fingerprint Cards AB (Swedish company, major fingerprint sensor manufacturer)
- **Model**: Disum series (FPC's touch sensor line)

## Linux Driver Development Implications

### Known Information
1. **Vendor**: Fingerprint Cards AB is a well-known manufacturer
2. **USB Interface**: Standard USB communication
3. **Device Class**: Biometric device class
4. **Driver Type**: Uses Windows user-mode framework (not kernel driver)

### Research Needed
1. **Protocol Analysis**: Need to reverse engineer USB communication
2. **Existing Linux Support**: Check if libfprint already supports this device
3. **Similar Devices**: Look for other FPC devices with Linux support
4. **Communication Protocol**: Analyze USB packets during operation

### Development Strategy
*See [docs/development-plan.md](../docs/development-plan.md) for complete development roadmap and strategy.*

## Files for Analysis

### Windows Driver Files
- `fpc_disum_um_usb.inf` - Driver installation information
- Windows registry entries for biometric service configuration
- USB device descriptors and endpoints

### Required Tools
- Wireshark with USBPcap for protocol analysis
- libfprint source code for reference
- Linux kernel USB driver examples
- FPC technical documentation (if available)

## Hardware Compatibility

### Confirmed Working
- ✅ **Xiaomi Laptop (SKU: TM2117-40430)**
  - BIOS: TIMI XMAAD4B0P1717
  - Windows 11 Pro with native driver
  - USB interface functional
  - Device enumeration successful
  - Biometric service recognition

### Linux Status
- ❓ Unknown - requires development
- 🎯 Target for this project

### Compatibility Notes
- This specific Xiaomi laptop model (TM2117-40430) confirmed working with Windows
- BIOS version TIMI XMAAD4B0P1717 supports fingerprint scanner functionality
- Other Xiaomi laptops with same FPC VID:PID may also be compatible

## Risk Assessment

### Low Risk
- Standard USB interface
- Well-known manufacturer
- Working Windows reference

### Medium Risk
- Proprietary communication protocol
- No existing Linux driver confirmed
- User-mode vs kernel-mode driver differences

### Mitigation
- Comprehensive protocol analysis
- Reference existing FPC drivers in libfprint
- Incremental development approach