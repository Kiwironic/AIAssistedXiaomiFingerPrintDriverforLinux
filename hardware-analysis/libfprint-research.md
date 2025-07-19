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

*See [docs/development-plan.md](../docs/development-plan.md) for complete development strategy and phases.*

## Next Research Steps (Phase 2)
1. Download and analyze libfprint source code
2. Search for existing FPC 10A5:9201 support
3. Identify similar devices and their implementations
4. Plan reverse engineering approach based on findings

*This research is part of Phase 2 in the development plan.*