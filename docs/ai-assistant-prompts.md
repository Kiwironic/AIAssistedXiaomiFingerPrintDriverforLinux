# AI Assistant Prompts for FPC Fingerprint Driver Installation

This document contains prompts that AI assistants can use to help users install and troubleshoot the FPC Fingerprint Scanner Driver for Linux.

## Installation Guidance Prompt

```
I'll help you install the FPC Fingerprint Scanner Driver for your Xiaomi laptop. This driver enables fingerprint authentication on Linux for laptops with FPC1020/FPC1155 fingerprint scanners.

### Step 1: Check Hardware Compatibility

First, let's verify that your laptop has a compatible fingerprint scanner:

```bash
lsusb | grep -E "(10a5|2717)"
```

If you see output containing one of these device IDs: `10a5:9201`, `2717:0368`, `2717:0369`, `2717:036A`, or `2717:036B`, your laptop is compatible.

### Step 2: Install Dependencies

Depending on your Linux distribution, you'll need to install some dependencies:

**Ubuntu/Debian/Mint:**
```bash
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git cmake
sudo apt install -y libusb-1.0-0-dev libfprint-2-dev fprintd
```

**Fedora/RHEL/CentOS:**
```bash
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y kernel-devel libusb1-devel libfprint-devel fprintd
```

**Arch Linux/Manjaro:**
```bash
sudo pacman -S --needed base-devel linux-headers git cmake
sudo pacman -S libusb libfprint fprintd
```

### Step 3: Clone and Install the Driver

```bash
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh
```

### Step 4: Enroll Your Fingerprint

After installation, you can enroll your fingerprint:

```bash
fprintd-enroll
```

Or use your desktop environment's settings:
- **GNOME**: Settings → Users → Add Fingerprint
- **KDE**: System Settings → Users → Add Fingerprint

### Step 5: Test the Driver

Verify that the fingerprint scanner works:

```bash
fprintd-verify
```

### Troubleshooting

If you encounter issues:

1. Check if the device is detected:
   ```bash
   lsusb | grep -E "(10a5|2717)"
   ```

2. Check if the driver is loaded:
   ```bash
   lsmod | grep fp_xiaomi
   ```

3. Run diagnostics:
   ```bash
   sudo bash scripts/diagnostics.sh
   ```

4. Check logs:
   ```bash
   dmesg | grep -i fingerprint
   ```

Let me know if you encounter any specific errors, and I'll help you troubleshoot them.
```

## Troubleshooting Prompt

```
I'll help you troubleshoot issues with your FPC Fingerprint Scanner Driver. Let's go through some common problems and solutions:

### Issue 1: Device Not Detected

**Symptoms:** The `lsusb` command doesn't show your fingerprint device.

**Solutions:**
1. Check if fingerprint scanner is enabled in BIOS
2. Try running: `sudo bash scripts/hardware-compatibility-check.sh -v`
3. Verify your laptop model is compatible (check docs/hardware-compatibility-database.md)

### Issue 2: Driver Not Loading

**Symptoms:** The `lsmod | grep fp_xiaomi` command shows no output.

**Solutions:**
1. Try manually loading the driver: `sudo modprobe fp_xiaomi`
2. Check for errors: `dmesg | grep -i fp_xiaomi`
3. Reinstall the driver: `sudo bash scripts/install-driver.sh`
4. Check kernel version compatibility: `uname -r` (should be 4.19 or newer)

### Issue 3: Permission Denied

**Symptoms:** You get "Permission denied" errors when using the fingerprint scanner.

**Solutions:**
1. Add your user to required groups: `sudo usermod -a -G plugdev,input $USER`
2. Log out and log back in for group changes to take effect
3. Check device permissions: `ls -l /dev/fp_xiaomi*`
4. Reload udev rules: `sudo udevadm control --reload-rules && sudo udevadm trigger`

### Issue 4: Enrollment Fails

**Symptoms:** The `fprintd-enroll` command fails or times out.

**Solutions:**
1. Check fprintd service: `systemctl status fprintd`
2. Restart fprintd: `sudo systemctl restart fprintd`
3. Try the fallback driver: `sudo bash scripts/fallback-driver.sh activate -s generic_libfprint`
4. Run diagnostics: `sudo bash scripts/diagnostics.sh`

### Issue 5: Authentication Not Working

**Symptoms:** Fingerprint is enrolled but doesn't work for login or sudo.

**Solutions:**
1. Check PAM configuration:
   - Ubuntu/Debian: `sudo pam-auth-update`
   - Fedora: `sudo authselect select sssd with-fingerprint`
2. Verify fprintd integration: `sudo bash scripts/configure-fprintd.sh`
3. Test verification: `fprintd-verify`
4. Check logs: `journalctl -u fprintd`

### Issue 6: Kernel Updates Break Driver

**Symptoms:** Driver stops working after kernel update.

**Solutions:**
1. Reinstall the driver: `sudo bash scripts/install-driver.sh`
2. Check kernel headers: `sudo apt install linux-headers-$(uname -r)` (or equivalent for your distro)
3. Reload the driver: `sudo modprobe -r fp_xiaomi && sudo modprobe fp_xiaomi`

### Issue 7: Desktop Environment Integration Issues

**Symptoms:** Fingerprint options don't appear in system settings.

**Solutions:**
1. Verify fprintd is installed: `which fprintd-enroll`
2. Check desktop integration: `sudo bash scripts/configure-fprintd.sh`
3. Install desktop-specific packages:
   - GNOME: `sudo apt install gnome-control-center-data`
   - KDE: `sudo apt install plasma-desktop`

### Issue 8: Lenovo-Specific Issues

**Symptoms:** Driver doesn't work on Lenovo ThinkPad models.

**Solutions:**
1. Check if your model is compatible:
   - Compatible: ThinkBook 13s/14/15 Gen 2, IdeaPad S540, Yoga S740, Yoga Slim 7
   - Incompatible: Most ThinkPad models (T/X/P series) use Synaptics or Validity sensors
2. Verify your device ID: `lsusb | grep -E "(10a5|2717|06cb|138a)"`
   - `10a5:9201` or `2717:xxxx`: Compatible FPC sensor
   - `06cb:xxxx`: Synaptics sensor (not compatible)
   - `138a:xxxx`: Validity sensor (not compatible)
3. For ThinkPad models, try the libfprint-2-tod1-goodix package instead

Please provide specific error messages or symptoms you're experiencing, and I'll help you troubleshoot further.
```

## Hardware Verification Prompt

```
I'll help you verify if your laptop's fingerprint scanner is compatible with the FPC Fingerprint Scanner Driver. Let's check your hardware:

### Step 1: Check USB Devices

Run this command to list USB devices:
```bash
lsusb
```

Look for entries with IDs like:
- `10a5:9201` (FPC Sensor Controller)
- `2717:0368`, `2717:0369`, `2717:036A`, or `2717:036B` (Xiaomi implementations)

### Step 2: Get Detailed Device Information

If you found a matching device, get more details:
```bash
lsusb -v -d VENDOR:PRODUCT
```
(Replace VENDOR:PRODUCT with your device ID, e.g., `10a5:9201`)

### Step 3: Check Laptop Model Compatibility

The following laptop models are known to be compatible:

**Xiaomi Laptops:**
- Mi Notebook Pro 15.6" (2017-2019)
- Mi Notebook Pro 14" (2020-2022)
- Mi Notebook Air 13.3"/12.5" (2018-2020)
- RedmiBook 13"/14"/16" (2019-2022)
- Timi Book Pro 14" (2022)

**Other Compatible Brands:**
- Huawei MateBook series
- Honor MagicBook series
- Select ASUS ZenBook models
- Lenovo models:
  - ThinkBook 13s/14/15 Gen 2 (Intel models)
  - IdeaPad S540-13
  - Yoga S740-14
  - Yoga Slim 7

**Important Note for Lenovo Users:** Most ThinkPad models use Synaptics (`06cb:xxxx`) or Validity (`138a:xxxx`) fingerprint sensors, which are NOT compatible with this driver. Only select ThinkBook and IdeaPad/Yoga models use the compatible FPC sensors.

### Step 4: Run Hardware Compatibility Check

If you've already cloned the repository, run:
```bash
sudo bash scripts/hardware-compatibility-check.sh -v
```

### Step 5: Check BIOS Settings

Ensure the fingerprint scanner is enabled in your BIOS settings. This is often found under:
- Security settings
- Biometric devices
- Fingerprint settings

Based on your hardware information, I can tell you if your laptop is compatible with the driver and guide you through the installation process.
```

## Advanced Configuration Prompt

```
I'll help you with advanced configuration of the FPC Fingerprint Scanner Driver. Here are some customizations you can make:

### Custom Installation Options

You can use these flags with the installation script:
```bash
# Force installation (skip compatibility checks)
sudo bash scripts/universal-install.sh --force

# Debug mode installation
sudo bash scripts/universal-install.sh --debug

# Minimal installation (driver only)
sudo bash scripts/universal-install.sh --no-fallback --no-configure

# Skip hardware tests
sudo bash scripts/universal-install.sh --skip-tests
```

### PAM Configuration

To configure PAM authentication for different services:

**Login Authentication:**
```bash
sudo bash scripts/configure-fprintd.sh --service login
```

**Sudo Authentication:**
```bash
sudo bash scripts/configure-fprintd.sh --service sudo
```

**Custom PAM Service:**
```bash
sudo bash scripts/configure-fprintd.sh --service custom --pam-file /etc/pam.d/your-service
```

### Fallback Systems

If the primary driver doesn't work, try these fallback options:

```bash
# Generic libfprint fallback
sudo bash scripts/fallback-driver.sh activate -s generic_libfprint

# Compatibility mode
sudo bash scripts/fallback-driver.sh activate -s compatibility_mode

# User-space only mode
sudo bash scripts/fallback-driver.sh activate -s user_space_only

# Restore original configuration
sudo bash scripts/fallback-driver.sh restore
```

### Performance Tuning

To optimize driver performance:

1. **Adjust USB parameters:**
   ```bash
   echo 'options fp_xiaomi usb_timeout=5000 buffer_size=128' | sudo tee /etc/modprobe.d/fp_xiaomi.conf
   ```

2. **Disable USB autosuspend for the device:**
   ```bash
   echo 'ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", ATTR{power/autosuspend}="-1"' | sudo tee /etc/udev/rules.d/70-fp-xiaomi-power.rules
   ```

3. **Optimize fprintd settings:**
   ```bash
   mkdir -p ~/.config/fprintd
   echo '[fprintd]' > ~/.config/fprintd/fprintd.conf
   echo 'timeout=10' >> ~/.config/fprintd/fprintd.conf
   ```

### Security Hardening

For enhanced security:

1. **Restrict device access:**
   ```bash
   echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="10a5", ATTRS{idProduct}=="9201", MODE="0660", GROUP="plugdev"' | sudo tee /etc/udev/rules.d/65-fp-xiaomi-secure.rules
   ```

2. **Enable template encryption:**
   ```bash
   fprintd-enroll --encrypt
   ```

3. **Set up automatic driver unloading when not in use:**
   ```bash
   echo 'options fp_xiaomi auto_unload=1 unload_timeout=300' | sudo tee -a /etc/modprobe.d/fp_xiaomi.conf
   ```

Let me know which advanced configurations you'd like to implement, and I'll provide more specific guidance.
```

## Distribution-Specific Prompt

```
I'll help you install the FPC Fingerprint Scanner Driver on your specific Linux distribution. Let's go through the installation process customized for your system.

### Ubuntu/Debian/Mint Installation

```bash
# Install dependencies
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) git cmake
sudo apt install -y libusb-1.0-0-dev libfprint-2-dev fprintd libpam-fprintd

# Clone repository
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver

# Install driver
sudo bash scripts/install-driver.sh --distro ubuntu

# Configure PAM
sudo pam-auth-update --enable fprintd
```

### Fedora/RHEL/CentOS Installation

```bash
# Install dependencies
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y kernel-devel libusb1-devel libfprint-devel fprintd fprintd-pam

# Clone repository
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver

# Install driver
sudo bash scripts/install-driver.sh --distro fedora

# Configure PAM
sudo authselect select sssd with-fingerprint
```

### Arch Linux/Manjaro Installation

```bash
# Install dependencies
sudo pacman -S --needed base-devel linux-headers git cmake
sudo pacman -S libusb libfprint fprintd

# Clone repository
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver

# Install driver
sudo bash scripts/install-driver.sh --distro arch

# Configure PAM
sudo bash scripts/configure-fprintd.sh
```

### openSUSE Installation

```bash
# Install dependencies
sudo zypper install -y -t pattern devel_basis
sudo zypper install -y kernel-default-devel libusb-1_0-devel libfprint-devel fprintd

# Clone repository
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver

# Install driver
sudo bash scripts/install-driver.sh --distro opensuse

# Configure PAM
sudo bash scripts/configure-fprintd.sh
```

### Gentoo Installation

```bash
# Install dependencies
sudo emerge --ask sys-kernel/linux-headers dev-libs/libusb sys-auth/libfprint sys-auth/fprintd

# Clone repository
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver

# Install driver
sudo bash scripts/install-driver.sh --distro gentoo

# Configure PAM
sudo bash scripts/configure-fprintd.sh
```

### Alpine Linux Installation

```bash
# Install dependencies
sudo apk add build-base linux-headers git cmake
sudo apk add libusb-dev libfprint-dev fprintd

# Clone repository
git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
cd xiaomi-fingerprint-driver

# Install driver
sudo bash scripts/install-driver.sh --distro alpine

# Configure PAM
sudo bash scripts/configure-fprintd.sh
```

Let me know which distribution you're using, and I'll provide more specific guidance if needed.
```

## Uninstallation Prompt

```
I'll help you uninstall the FPC Fingerprint Scanner Driver from your system. Follow these steps:

### Method 1: Using the Uninstall Script

If you still have the driver repository:

```bash
cd xiaomi-fingerprint-driver
sudo bash scripts/install-driver.sh --uninstall
```

### Method 2: Manual Uninstallation

If you don't have the repository anymore:

1. **Unload the kernel module:**
   ```bash
   sudo modprobe -r fp_xiaomi
   ```

2. **Remove the kernel module:**
   ```bash
   sudo rm -f /lib/modules/$(uname -r)/kernel/drivers/input/misc/fp_xiaomi.ko
   sudo depmod -a
   ```

3. **Remove the user-space library:**
   ```bash
   sudo rm -f /usr/local/lib/libfp_xiaomi*
   sudo rm -f /usr/local/include/libfp_xiaomi.h
   sudo ldconfig
   ```

4. **Remove udev rules:**
   ```bash
   sudo rm -f /etc/udev/rules.d/60-fp-xiaomi.rules
   sudo udevadm control --reload-rules
   ```

5. **Remove PAM configuration:**
   ```bash
   # For Ubuntu/Debian
   sudo pam-auth-update --disable fprintd
   
   # For Fedora/RHEL
   sudo authselect select sssd without-fingerprint
   ```

6. **Clean up fprintd data (optional - removes enrolled fingerprints):**
   ```bash
   fprintd-delete $USER
   ```

### Method 3: Using Package Manager (if installed as a package)

If you installed the driver through a package manager:

```bash
# For Ubuntu/Debian
sudo apt remove --purge fp-xiaomi-driver

# For Fedora/RHEL
sudo dnf remove fp-xiaomi-driver

# For Arch Linux
sudo pacman -Rs fp-xiaomi-driver
```

### Verification

To verify the driver is completely removed:

```bash
# Check if module is loaded
lsmod | grep fp_xiaomi

# Check for device nodes
ls -la /dev/fp_xiaomi* 2>/dev/null

# Check for library files
ls -la /usr/local/lib/libfp_xiaomi* 2>/dev/null
```

If you encounter any issues during uninstallation, please let me know, and I'll help you resolve them.
```    I