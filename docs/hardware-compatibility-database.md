# Hardware Compatibility Database

## Supported Fingerprint Scanner Hardware

### FPC (Fingerprint Cards) Sensors

#### FPC1020 Series
- **Interface**: USB
- **Resolution**: 160x160 pixels
- **Technology**: Capacitive touch

**Device IDs:**
- `10a5:9201` - FPC Sensor Controller
- `2717:0368` - Xiaomi implementation
- `2717:0369` - Xiaomi implementation (variant)

#### FPC1155 Series  
- **Interface**: USB
- **Resolution**: 192x192 pixels
- **Technology**: Capacitive touch

**Device IDs:**
- `2717:036A` - Xiaomi implementation
- `2717:036B` - Xiaomi implementation (variant)

## Compatible Laptop Models

### Xiaomi Laptops (Primary Target)
| Model | Fingerprint ID | Status |
|-------|----------------|--------|
| **Mi Notebook Pro 15.6"** | `10a5:9201` | ✅ Confirmed |
| **Mi Notebook Pro 14"** | `2717:0368` | ✅ Confirmed |
| **Mi Notebook Air 13.3"** | `10a5:9201` | ✅ Compatible |
| **Mi Notebook Air 12.5"** | `10a5:9201` | ✅ Compatible |
| **RedmiBook 13/14/16"** | `2717:0368`, `2717:036A` | ✅ Compatible |
| **Timi Book Pro 14"** | `10a5:9201` | ✅ Confirmed |

### Other Compatible Manufacturers
- **Huawei**: MateBook X Pro, MateBook 13/14 (2018-2022)
- **Honor**: MagicBook Pro, MagicBook 14/15 (2019-2022)
- **ASUS**: Select ZenBook models with FPC sensors
- **Lenovo**: Select IdeaPad/Yoga models with FPC sensors

## Hardware Identification

### How to Check Your Device
```bash
# Check for supported fingerprint scanner
lsusb | grep -E "(10a5|2717)"

# Get detailed device information
lsusb -v -d 10a5:9201  # or your specific device ID
```

## Compatibility Status Legend
- ✅ **Confirmed**: Tested and working
- ✅ **Compatible**: Same hardware, expected to work
- ⚠️ **Likely**: Similar hardware, probably compatible

## Troubleshooting Tips

- **BIOS Settings**: Ensure fingerprint scanner is enabled in BIOS
- **Power Management**: Some devices may require USB autosuspend to be disabled
- **Firmware**: Different regions may have different firmware versions