# libfprint Research for FPC Device

## Device Details
- **Vendor ID**: 10A5 (Fingerprint Cards AB)
- **Product ID**: 9201
- **Device**: FPC Fingerprint Reader (Disum)

## Research Status

### libfprint Database Check
Need to verify if VID:PID 10A5:9201 is supported in:
- Current libfprint releases
- Development branches
- Community contributions

### Known FPC Support in libfprint
Fingerprint Cards AB devices that are known to be supported:
- Various FPC sensors under different VID:PID combinations
- FPC sensors integrated by laptop manufacturers

### Research Actions Required
1. **Check libfprint source**: Look for 10A5:9201 in device tables
2. **Community forums**: Search for this specific device
3. **Similar devices**: Find related FPC sensors with Linux support
4. **Protocol documentation**: Look for FPC technical specifications

### Expected Findings
- **If supported**: Use existing driver as reference
- **If partially supported**: Extend existing FPC driver
- **If not supported**: Develop new driver based on FPC patterns

## Development Approach

### If Device is Supported
1. Test current libfprint version
2. Identify any issues or limitations
3. Contribute improvements if needed

### If Device is Not Supported
1. Analyze similar FPC devices in libfprint
2. Reverse engineer communication protocol
3. Implement new driver following libfprint patterns
4. Submit contribution to libfprint project

### Protocol Analysis Strategy
1. **USB packet capture** during Windows operation
2. **Compare with existing FPC drivers** in libfprint
3. **Identify command/response patterns**
4. **Document protocol specifications**

## Next Research Steps
1. Download and analyze libfprint source code
2. Search for existing FPC 10A5:9201 support
3. Identify similar devices and their implementations
4. Plan reverse engineering approach based on findings