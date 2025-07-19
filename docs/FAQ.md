# Frequently Asked Questions (FAQ)

## General Questions

### Q: What is this driver for?
**A:** This driver enables fingerprint authentication on Linux for laptops with FPC1020/FPC1155 fingerprint scanners, primarily targeting Xiaomi laptops.

### Q: Which laptops are supported?
**A:** The driver supports Xiaomi laptops with FPC fingerprint scanners. Check the [Hardware Compatibility Database](hardware-compatibility-database.md) for details.

### Q: How do I know if my laptop is compatible?
**A:** Run this command to check:
```bash
lsusb | grep -E "(10a5|2717)"
```
If you see output with device IDs `10a5:9201`, `2717:0368`, `2717:0369`, `2717:036A`, or `2717:036B`, your laptop is compatible.

## Installation Questions

### Q: What's the easiest way to install?
**A:** Use the one-line installer:
```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/xiaomi-fingerprint-driver/main/scripts/universal-install.sh | sudo bash
```

### Q: What if the installation fails?
**A:** Run the diagnostic tool:
```bash
sudo bash scripts/diagnostics.sh
```

## Usage Questions

### Q: How do I enroll my fingerprint?
**A:** After installation:
```bash
# Command line
fprintd-enroll

# Or use your desktop environment:
# GNOME: Settings → Users → Add Fingerprint
# KDE: System Settings → Users → Add Fingerprint
```

### Q: How do I test if the fingerprint works?
**A:**
```bash
# Test verification
fprintd-verify

# Check driver status
lsmod | grep fp_xiaomi
```

## Troubleshooting Questions

### Q: The driver loads but fingerprint doesn't work. What should I do?
**A:**
1. **Check hardware**: `lsusb | grep -E "(10a5|2717)"`
2. **Check driver**: `lsmod | grep fp_xiaomi`
3. **Check service**: `systemctl status fprintd`
4. **Run diagnostics**: `sudo bash scripts/diagnostics.sh`

### Q: I get "Permission denied" errors. How do I fix this?
**A:**
```bash
# Add user to required groups
sudo usermod -a -G plugdev,input $USER

# Log out and back in
```

### Q: Can I uninstall the driver?
**A:** Yes, run:
```bash
sudo bash scripts/uninstall-driver.sh
```

## Technical Questions

### Q: Does the driver store fingerprint data?
**A:** The driver uses the standard Linux fingerprint framework (libfprint/fprintd), which stores encrypted templates locally. No data is transmitted over the network.

### Q: Can I contribute to the project?
**A:** Yes! See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.