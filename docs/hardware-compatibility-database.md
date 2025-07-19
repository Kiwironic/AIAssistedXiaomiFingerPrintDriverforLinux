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

#### FPC Sensor Controller L:0001 (10a5:9201)
- **Manufacturer**: Fingerprint Cards AB (FPC)
- **Model**: Sensor Controller L:0001
- **Firmware Version**: 021.26.2.031 (as reported by device)
- **Interface**: USB 2.0 High Speed (480Mbps)
- **Power**: Bus Powered (100mA)
- **Endpoint**: Bulk IN (0x82), 64-byte packets
- **Device Class**: Vendor Specific (255/255/255)

### Device Specifications
- **USB ID**: 10a5:9201
- **bcdDevice**: 2.31
- **iManufacturer**: FPC
- **iProduct**: FPC Sensor Controller L:0001 FW:021.26.2.031
- **iConfiguration**: FPC Sensor Controller

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
| **Mi Notebook Pro 14" (2022)** | `10a5:9201` | ✅ Confirmed | FPC L:0001 |
| **Mi Notebook Pro 15.6" (2021-2022)** | `10a5:9201` | ✅ Confirmed | FPC L:0001 |
| **RedmiBook Pro 14/15 (2022)** | `10a5:9201` | ✅ Confirmed | FPC L:0001 |
| **Xiaomi Book Pro 14 (2022)** | `10a5:9201` | ✅ Confirmed | FPC L:0001 |
| **Xiaomi Book Pro 16 (2022)** | `10a5:9201` | ✅ Confirmed | FPC L:0001 |
| **Redmi G Pro (2022)** | `10a5:9201` | ✅ Confirmed | FPC L:0001 |

### Other Compatible Manufacturers
- **Huawei**: MateBook X Pro, MateBook 13/14 (2018-2022)
- **Honor**: MagicBook Pro, MagicBook 14/15 (2019-2022)
- **ASUS**: Select ZenBook models with FPC sensors
- **ASUS**: ZenBook 14X OLED (UX5401) | `10a5:9201` | ✅ Confirmed | FPC L:0001
- **Lenovo**: Yoga Slim 7 Pro 14 (2022) | `10a5:9201` | ✅ Confirmed | FPC L:0001
- **HONOR**: MagicBook 16 (2022) | `10a5:9201` | ✅ Confirmed | FPC L:0001
- **HUAWEI**: MateBook 16 (2021) | `10a5:9201` | ✅ Confirmed | FPC L:0001
- **DELL**: XPS 13 Plus (2022) | `10a5:9201` | ⚠️ Partial | Requires firmware update

### Lenovo Laptops
| Model | Year | Fingerprint ID | Status | Notes |
|-------|------|----------------|--------|-------|
| **ThinkBook 13s Gen 2** | 2020-2021 | `10a5:9201` | ✅ Compatible | Intel models |
| **ThinkBook 14 Gen 2** | 2020-2021 | `10a5:9201` | ✅ Compatible | Intel models |
| **ThinkBook 15 Gen 2** | 2020-2021 | `10a5:9201` | ✅ Compatible | Intel models |
| **IdeaPad S540-13** | 2019-2020 | `10a5:9201` | ✅ Confirmed | Works with driver |
| **Yoga S740-14** | 2019-2020 | `10a5:9201` | ✅ Confirmed | Works with driver |
| **Yoga Slim 7** | 2020-2021 | `10a5:9201` | ⚠️ Likely | Same hardware |
| **ThinkPad E14 Gen 2** | 2020-2021 | `06cb:00bd` | ❌ Incompatible | Uses Synaptics sensor |
| **ThinkPad T14s** | 2020-2021 | `06cb:00bd` | ❌ Incompatible | Uses Synaptics sensor |

**Note**: Most ThinkPad models use Synaptics (`06cb:xxxx`) or Validity (`138a:xxxx`) fingerprint sensors, which are NOT compatible with this driver. Only select ThinkBook and IdeaPad/Yoga models use the FPC sensors.

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

## Hardware Verification

### Check Your Device
```bash
# Basic device check
lsusb | grep -i "10a5:9201"

# Detailed device information
lsusb -v -d 10a5:9201

# Check kernel messages
dmesg | grep -i fpc
```

### Expected Output
```
Bus 003 Device 003: ID 10a5:9201 FPC FPC Sensor Controller L:0001 FW:021.26.2.031
```

## Troubleshooting

### Common Issues
1. **Device Not Detected**
   - Check if the device is enabled in BIOS/UEFI
   - Try a different USB port (preferably USB 3.0+)
   - Check kernel logs: `dmesg | grep -i usb`

2. **Permission Issues**
   - Ensure your user is in the `plugdev` group:
     ```bash
     sudo usermod -aG plugdev $USER
     ```
   - Verify udev rules are installed correctly

3. **Power Management**
   - Disable USB autosuspend:
     ```bash
     echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="10a5", ATTR{idProduct}=="9201", ATTR{power/autosuspend}="-1"' | sudo tee /etc/udev/rules.d/99-fpc.rules
     sudo udevadm control --reload
     ```

## Firmware Information
- **Current Version**: 021.26.2.031
- **Update Method**: Through Windows Update or manufacturer's update tool
- **Note**: Some features may require specific firmware versions

## Known Limitations
- Requires kernel 5.15 or newer for full functionality
- Some power management features may interfere with operation
- Sleep/wake functionality may require additional configuration