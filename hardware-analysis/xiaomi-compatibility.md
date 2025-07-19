# Xiaomi Laptop Compatibility Matrix

## Confirmed Compatible Models

### TM2117-40430 ✅
- **System SKU**: TM2117-40430
- **BIOS Version**: TIMI XMAAD4B0P1717
- **Fingerprint Scanner**: FPC Fingerprint Reader (Disum)
- **VID:PID**: 10A5:9201
- **Windows Status**: ✅ Working (Windows 11 Pro)
- **Linux Status**: 🔄 In Development
- **Tested By**: Project maintainer
- **Date Confirmed**: July 19, 2025

## Potentially Compatible Models

### Models with Same Fingerprint Scanner
Any Xiaomi laptop with:
- **Fingerprint Scanner**: FPC Fingerprint Reader (Disum)
- **VID:PID**: 10A5:9201
- **Manufacturer**: Fingerprint Cards AB

### How to Check Your Device
1. **Windows Device Manager**:
   - Open Device Manager
   - Look for "Biometric devices" or "FPC Fingerprint Reader"
   - Check Properties → Details → Hardware IDs
   - Look for `USB\VID_10A5&PID_9201`

2. **System Information**:
   - Run `msinfo32` in Windows
   - Check System SKU and BIOS Version
   - Compare with confirmed compatible models

3. **Linux Detection**:
   ```bash
   # Run the hardware detection script
   ./tools/hardware-info.sh
   # Look for VID:PID 10A5:9201 in the output
   ```

## Compatibility Reporting

### If Your Xiaomi Laptop Works
Please report compatibility by creating a GitHub issue with:
- **System SKU**: (from msinfo32)
- **BIOS Version**: (from msinfo32)
- **Fingerprint Scanner Model**: (from Device Manager)
- **VID:PID**: (from Device Manager Hardware IDs)
- **Windows Version**: (e.g., Windows 11 Pro)
- **Working Status**: (enrollment/verification working?)

### If Your Xiaomi Laptop Doesn't Work
Please report issues with:
- Same system information as above
- **Error Description**: What doesn't work?
- **Driver Status**: Is the Windows driver installed?
- **Device Manager Status**: Any error codes?

## Model Variations

### Expected Compatible Series
Based on the confirmed model, these Xiaomi laptop series may be compatible:
- **TM2117-xxxxx** series (same base model)
- **RedmiBook Pro** series with FPC scanners
- **Mi Notebook** series with FPC scanners

### BIOS Considerations
- **TIMI BIOS**: Xiaomi uses TIMI BIOS versions
- **Fingerprint Support**: Must be enabled in BIOS
- **Secure Boot**: May affect Linux driver loading

## Development Priority

### Primary Target
- **TM2117-40430** with BIOS TIMI XMAAD4B0P1717
- This is the confirmed working model for development

### Secondary Targets
- Other TM2117-xxxxx variants
- Models with same VID:PID but different SKUs
- Community-reported compatible models

## Testing Requirements

### For New Model Confirmation
1. **Windows Testing**:
   - Confirm fingerprint enrollment works
   - Confirm fingerprint verification works
   - Check Windows Hello compatibility

2. **Hardware Analysis**:
   - Run Windows analysis script
   - Confirm VID:PID matches 10A5:9201
   - Document any driver differences

3. **Linux Testing** (when driver available):
   - Test device recognition
   - Test basic functionality
   - Report any model-specific issues

## Community Contributions

### How to Contribute
1. **Test on your Xiaomi laptop**
2. **Report compatibility results**
3. **Submit hardware information**
4. **Help with testing when Linux driver is ready**

### Recognition
Contributors will be acknowledged in:
- This compatibility matrix
- Project documentation
- Release notes
- GitHub contributors list

## Future Expansion

### Other Fingerprint Scanners
If your Xiaomi laptop has a different fingerprint scanner:
- **Synaptics**: Different VID:PID, may need separate driver
- **Goodix**: Different VID:PID, may need separate driver
- **Validity**: Different VID:PID, may need separate driver

### Multiple Scanner Support
Future versions may support multiple fingerprint scanner types found in Xiaomi laptops.

## Contact

For compatibility questions or to report new compatible models:
- **GitHub Issues**: Create a new issue with "Compatibility" label
- **Discussions**: Use GitHub Discussions for questions
- **Pull Requests**: Submit compatibility updates via PR