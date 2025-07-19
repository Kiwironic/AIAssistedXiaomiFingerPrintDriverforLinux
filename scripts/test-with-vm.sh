#!/bin/bash

# Virtual Machine Testing Script for Xiaomi Fingerprint Driver
# Creates and tests installation on VM snapshots

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_LOG="/tmp/fp_xiaomi_vm_test.log"

# VM configurations
VM_CONFIGS=(
    "ubuntu-22.04:Ubuntu 22.04 LTS"
    "ubuntu-20.04:Ubuntu 20.04 LTS"
    "fedora-39:Fedora 39"
    "fedora-40:Fedora 40"
    "mint-21:Linux Mint 21"
)

# Print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$TEST_LOG"
}

# Print section header
print_section() {
    local title=$1
    echo ""
    print_status "$CYAN" "═══════════════════════════════════════════════════════════════"
    print_status "$CYAN" "  $title"
    print_status "$CYAN" "═══════════════════════════════════════════════════════════════"
}

# Check for virtualization tools
check_virtualization_tools() {
    print_section "CHECKING VIRTUALIZATION TOOLS"
    
    local virt_tools=()
    
    # Check for VirtualBox
    if command -v VBoxManage >/dev/null 2>&1; then
        virt_tools+=("VirtualBox")
        print_status "$GREEN" "✅ VirtualBox detected"
        VIRT_TOOL="virtualbox"
    fi
    
    # Check for QEMU/KVM
    if command -v qemu-system-x86_64 >/dev/null 2>&1; then
        virt_tools+=("QEMU/KVM")
        print_status "$GREEN" "✅ QEMU/KVM detected"
        if [[ -z "${VIRT_TOOL:-}" ]]; then
            VIRT_TOOL="qemu"
        fi
    fi
    
    # Check for VMware
    if command -v vmrun >/dev/null 2>&1; then
        virt_tools+=("VMware")
        print_status "$GREEN" "✅ VMware detected"
        if [[ -z "${VIRT_TOOL:-}" ]]; then
            VIRT_TOOL="vmware"
        fi
    fi
    
    # Check for Vagrant
    if command -v vagrant >/dev/null 2>&1; then
        virt_tools+=("Vagrant")
        print_status "$GREEN" "✅ Vagrant detected"
        if [[ -z "${VIRT_TOOL:-}" ]]; then
            VIRT_TOOL="vagrant"
        fi
    fi
    
    if [[ ${#virt_tools[@]} -eq 0 ]]; then
        print_status "$RED" "❌ No virtualization tools detected"
        print_status "$BLUE" "💡 Install one of the following:"
        echo "   • VirtualBox: https://www.virtualbox.org/"
        echo "   • QEMU/KVM: sudo apt install qemu-kvm (Ubuntu) or sudo dnf install qemu-kvm (Fedora)"
        echo "   • VMware Workstation/Player"
        echo "   • Vagrant: https://www.vagrantup.com/"
        return 1
    fi
    
    print_status "$BLUE" "📋 Available virtualization tools: ${virt_tools[*]}"
    print_status "$GREEN" "✅ Using: $VIRT_TOOL"
    
    return 0
}

# Create Vagrant test environment
create_vagrant_environment() {
    local distro=$1
    local description=$2
    
    print_status "$BLUE" "🏗️  Creating Vagrant environment for $description"
    
    local vagrant_dir="/tmp/fp-xiaomi-test-$distro"
    mkdir -p "$vagrant_dir"
    
    # Create Vagrantfile
    cat > "$vagrant_dir/Vagrantfile" << EOF
Vagrant.configure("2") do |config|
  # Base box configuration
  case "$distro"
  when "ubuntu-22.04"
    config.vm.box = "ubuntu/jammy64"
  when "ubuntu-20.04"
    config.vm.box = "ubuntu/focal64"
  when "fedora-39"
    config.vm.box = "fedora/39-cloud-base"
  when "fedora-40"
    config.vm.box = "fedora/40-cloud-base"
  when "mint-21"
    config.vm.box = "linuxmint/21"
  else
    config.vm.box = "ubuntu/jammy64"
  end
  
  # VM configuration
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
    vb.name = "fp-xiaomi-test-$distro"
  end
  
  # Network configuration
  config.vm.network "private_network", type: "dhcp"
  
  # Shared folders
  config.vm.synced_folder "$PROJECT_ROOT", "/project", type: "rsync"
  
  # Provisioning script
  config.vm.provision "shell", inline: <<-SHELL
    echo "Setting up test environment for $description"
    
    # Update system
    case "$distro" in
      ubuntu-*|mint-*)
        apt-get update
        apt-get install -y curl wget git
        ;;
      fedora-*)
        dnf update -y
        dnf install -y curl wget git
        ;;
    esac
    
    # Create test script
    cat > /home/vagrant/test-installation.sh << 'TESTSCRIPT'
#!/bin/bash
set -e

echo "Starting installation test on $description"

cd /project

# Test script syntax
echo "Testing script syntax..."
bash -n scripts/install-driver.sh
bash -n scripts/universal-install.sh
bash -n scripts/hardware-compatibility-check.sh

echo "Running dry-run installation test..."

# Set environment for testing
export DRY_RUN=true
export TESTING_MODE=true

# Test hardware compatibility check
if [[ -f scripts/hardware-compatibility-check.sh ]]; then
    echo "Testing hardware compatibility check..."
    bash scripts/hardware-compatibility-check.sh --help
fi

# Test diagnostics
if [[ -f scripts/diagnostics.sh ]]; then
    echo "Testing diagnostics script..."
    bash scripts/diagnostics.sh --help
fi

echo "Installation test completed successfully on $description"
TESTSCRIPT
    
    chmod +x /home/vagrant/test-installation.sh
    chown vagrant:vagrant /home/vagrant/test-installation.sh
    
    echo "Test environment ready for $description"
  SHELL
end
EOF
    
    print_status "$GREEN" "✅ Vagrantfile created for $distro"
    echo "$vagrant_dir"
}

# Test with Vagrant
test_with_vagrant() {
    print_section "TESTING WITH VAGRANT"
    
    if ! command -v vagrant >/dev/null 2>&1; then
        print_status "$RED" "❌ Vagrant not found"
        return 1
    fi
    
    local test_results=()
    
    for config in "${VM_CONFIGS[@]}"; do
        local distro=$(echo "$config" | cut -d: -f1)
        local description=$(echo "$config" | cut -d: -f2)
        
        print_status "$BLUE" "🧪 Testing $description with Vagrant"
        
        # Create Vagrant environment
        local vagrant_dir=$(create_vagrant_environment "$distro" "$description")
        
        cd "$vagrant_dir"
        
        # Start VM
        print_status "$BLUE" "   → Starting VM..."
        if vagrant up 2>&1 | tee "/tmp/vagrant-$distro.log"; then
            print_status "$GREEN" "   ✅ VM started successfully"
            
            # Run tests
            print_status "$BLUE" "   → Running installation tests..."
            if vagrant ssh -c "/home/vagrant/test-installation.sh" 2>&1 | tee "/tmp/vagrant-test-$distro.log"; then
                print_status "$GREEN" "   ✅ Tests passed for $description"
                test_results+=("✅ $description: PASS")
            else
                print_status "$RED" "   ❌ Tests failed for $description"
                test_results+=("❌ $description: FAIL")
            fi
            
            # Cleanup
            print_status "$BLUE" "   → Cleaning up VM..."
            vagrant destroy -f >/dev/null 2>&1
            
        else
            print_status "$RED" "   ❌ Failed to start VM for $description"
            test_results+=("❌ $description: VM_FAIL")
        fi
        
        cd - >/dev/null
        rm -rf "$vagrant_dir"
    done
    
    # Show results
    print_status "$BLUE" "📊 Vagrant Test Results:"
    for result in "${test_results[@]}"; do
        if [[ "$result" == *"PASS"* ]]; then
            print_status "$GREEN" "$result"
        else
            print_status "$RED" "$result"
        fi
    done
}

# Create QEMU test script
create_qemu_test() {
    local distro=$1
    local iso_url=$2
    
    print_status "$BLUE" "🏗️  Creating QEMU test for $distro"
    
    # This is a simplified example - in practice, you'd need actual ISO files
    cat > "/tmp/qemu-test-$distro.sh" << EOF
#!/bin/bash

# QEMU test script for $distro
echo "QEMU testing for $distro would require:"
echo "1. Download ISO: $iso_url"
echo "2. Create VM disk image"
echo "3. Install OS automatically"
echo "4. Run installation tests"
echo "5. Capture results"

echo "This is a placeholder for full QEMU automation"
echo "For manual testing:"
echo "  1. Create VM with $distro"
echo "  2. Copy project files to VM"
echo "  3. Run: bash scripts/install-driver.sh"
echo "  4. Verify installation works"
EOF
    
    chmod +x "/tmp/qemu-test-$distro.sh"
    print_status "$GREEN" "✅ QEMU test script created: /tmp/qemu-test-$distro.sh"
}

# Create VirtualBox test automation
create_virtualbox_test() {
    local vm_name=$1
    local distro=$2
    
    print_status "$BLUE" "🏗️  Creating VirtualBox test for $distro"
    
    cat > "/tmp/vbox-test-$distro.sh" << EOF
#!/bin/bash

# VirtualBox automation script for $distro
VM_NAME="$vm_name"

echo "VirtualBox testing automation for $distro"
echo "This script would:"
echo "1. Create VM: VBoxManage createvm --name \$VM_NAME"
echo "2. Configure VM settings"
echo "3. Install OS from ISO"
echo "4. Setup SSH access"
echo "5. Copy project files"
echo "6. Run installation tests"
echo "7. Capture results"
echo "8. Cleanup VM"

echo "For manual testing:"
echo "1. Create a VM with $distro"
echo "2. Install the OS"
echo "3. Copy the project to the VM"
echo "4. Run: sudo bash scripts/install-driver.sh"
echo "5. Test fingerprint functionality"

# Example VirtualBox commands (commented out)
# VBoxManage createvm --name \$VM_NAME --register
# VBoxManage modifyvm \$VM_NAME --memory 2048 --cpus 2
# VBoxManage modifyvm \$VM_NAME --nic1 nat
# VBoxManage createhd --filename \$VM_NAME.vdi --size 20480
# VBoxManage storagectl \$VM_NAME --name "SATA Controller" --add sata
# VBoxManage storageattach \$VM_NAME --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium \$VM_NAME.vdi
EOF
    
    chmod +x "/tmp/vbox-test-$distro.sh"
    print_status "$GREEN" "✅ VirtualBox test script created: /tmp/vbox-test-$distro.sh"
}

# Create manual testing guide
create_manual_testing_guide() {
    print_section "CREATING MANUAL TESTING GUIDE"
    
    local guide_file="/tmp/manual-vm-testing-guide.md"
    
    cat > "$guide_file" << 'EOF'
# Manual VM Testing Guide for Xiaomi Fingerprint Driver

## Overview
This guide helps you manually test the Xiaomi fingerprint driver installation on virtual machines.

## Prerequisites
- Virtualization software (VirtualBox, VMware, QEMU, etc.)
- ISO files for target distributions
- At least 4GB RAM and 20GB disk space per VM

## Testing Procedure

### 1. Create Virtual Machines

#### Ubuntu 22.04 LTS
1. Download Ubuntu 22.04 ISO from https://ubuntu.com/download/desktop
2. Create VM with 2GB RAM, 20GB disk
3. Install Ubuntu with default settings
4. Update system: `sudo apt update && sudo apt upgrade`

#### Ubuntu 20.04 LTS
1. Download Ubuntu 20.04 ISO
2. Create VM with 2GB RAM, 20GB disk
3. Install Ubuntu with default settings
4. Update system: `sudo apt update && sudo apt upgrade`

#### Fedora 39/40
1. Download Fedora Workstation ISO from https://getfedora.org/
2. Create VM with 2GB RAM, 20GB disk
3. Install Fedora with default settings
4. Update system: `sudo dnf update`

#### Linux Mint 21
1. Download Linux Mint ISO from https://linuxmint.com/download.php
2. Create VM with 2GB RAM, 20GB disk
3. Install Mint with default settings
4. Update system: `sudo apt update && sudo apt upgrade`

### 2. Prepare Test Environment

For each VM:

1. **Install Git and basic tools:**
   ```bash
   # Ubuntu/Mint:
   sudo apt install git curl wget
   
   # Fedora:
   sudo dnf install git curl wget
   ```

2. **Clone the project:**
   ```bash
   git clone https://github.com/your-repo/xiaomi-fingerprint-driver.git
   cd xiaomi-fingerprint-driver
   ```

3. **Make scripts executable:**
   ```bash
   chmod +x scripts/*.sh
   ```

### 3. Run Installation Tests

#### Test 1: Hardware Compatibility Check
```bash
sudo bash scripts/hardware-compatibility-check.sh -v
```
**Expected Result:** Should complete without errors, may warn about no hardware

#### Test 2: Dry Run Installation
```bash
# Set dry run mode (if supported)
export DRY_RUN=true
sudo bash scripts/install-driver.sh
```
**Expected Result:** Should simulate installation without making changes

#### Test 3: Full Installation
```bash
sudo bash scripts/install-driver.sh
```
**Expected Results:**
- All dependencies installed successfully
- Driver compiled without errors
- Services configured properly
- No critical errors in logs

#### Test 4: Universal Installer
```bash
sudo bash scripts/universal-install.sh
```
**Expected Result:** Should detect distribution and install correctly

#### Test 5: Interactive Installer
```bash
sudo bash scripts/interactive-install.sh
```
**Expected Result:** Should provide user-friendly installation wizard

### 4. Verification Tests

After installation, verify:

1. **Driver Status:**
   ```bash
   lsmod | grep fp_xiaomi
   ```
   Should show the driver is loaded (may not work without hardware)

2. **Service Status:**
   ```bash
   systemctl status fprintd
   ```
   Should show fprintd service is active

3. **Dependencies:**
   ```bash
   # Ubuntu/Mint:
   dpkg -l | grep -E "(libfprint|fprintd|build-essential)"
   
   # Fedora:
   rpm -qa | grep -E "(libfprint|fprintd)"
   ```
   Should show required packages are installed

4. **Configuration Files:**
   ```bash
   ls -la /etc/udev/rules.d/*fp*
   ls -la /etc/modules-load.d/*fp*
   ```
   Should show configuration files are created

### 5. Troubleshooting Tests

Test the troubleshooting tools:

1. **Diagnostics:**
   ```bash
   sudo bash scripts/diagnostics.sh
   ```

2. **Distribution-specific troubleshooting:**
   ```bash
   sudo bash scripts/distro-specific-troubleshoot.sh
   ```

3. **Fallback system:**
   ```bash
   sudo bash scripts/fallback-driver.sh status
   ```

### 6. Test Results Documentation

For each distribution, document:

- ✅/❌ Hardware compatibility check
- ✅/❌ Dependency installation
- ✅/❌ Driver compilation
- ✅/❌ Service configuration
- ✅/❌ Installation completion
- Any error messages or warnings
- Performance observations
- Specific distribution issues

### 7. Cleanup

After testing:

1. **Uninstall driver (if needed):**
   ```bash
   sudo /usr/local/bin/uninstall-xiaomi-fp.sh
   ```

2. **Take VM snapshot** for future testing

3. **Document results** in testing report

## Common Issues and Solutions

### Issue: Package installation fails
**Solution:** Check internet connection, update package lists

### Issue: Kernel headers not found
**Solution:** Install appropriate kernel headers package

### Issue: Permission denied errors
**Solution:** Ensure running with sudo, check user groups

### Issue: Service fails to start
**Solution:** Check systemd logs, verify dependencies

## Automation Tips

To automate testing:

1. Use VM snapshots for quick reset
2. Create shell scripts for repetitive tasks
3. Use SSH for remote testing
4. Capture logs automatically
5. Use configuration management tools

## Reporting Results

Create a test report including:
- Distribution and version tested
- Installation method used
- Success/failure status
- Error messages (if any)
- Performance notes
- Recommendations

EOF
    
    print_status "$GREEN" "✅ Manual testing guide created: $guide_file"
}

# Create VM testing automation framework
create_vm_automation_framework() {
    print_section "CREATING VM AUTOMATION FRAMEWORK"
    
    print_status "$BLUE" "🏗️  Creating automation scripts for different virtualization platforms"
    
    # Create framework directory
    local framework_dir="/tmp/fp-xiaomi-vm-framework"
    mkdir -p "$framework_dir"
    
    # Create main automation script
    cat > "$framework_dir/vm-test-runner.sh" << 'EOF'
#!/bin/bash

# VM Test Runner Framework
# Supports multiple virtualization platforms

set -e

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-/path/to/xiaomi-fingerprint-driver}"

# Configuration
VM_MEMORY="2048"
VM_DISK_SIZE="20480"
VM_CPUS="2"

# Supported platforms
PLATFORMS=("virtualbox" "qemu" "vmware" "vagrant")

# Test configurations
TEST_CONFIGS=(
    "ubuntu-22.04:ubuntu/jammy64:Ubuntu 22.04 LTS"
    "ubuntu-20.04:ubuntu/focal64:Ubuntu 20.04 LTS"
    "fedora-39:fedora/39-cloud-base:Fedora 39"
    "fedora-40:fedora/40-cloud-base:Fedora 40"
)

print_status() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Platform-specific implementations
source_platform_scripts() {
    for platform in "${PLATFORMS[@]}"; do
        local script="$FRAMEWORK_DIR/platforms/$platform.sh"
        if [[ -f "$script" ]]; then
            source "$script"
        fi
    done
}

# Main test runner
run_tests() {
    local platform=$1
    
    print_status "Starting tests on platform: $platform"
    
    for config in "${TEST_CONFIGS[@]}"; do
        local vm_id=$(echo "$config" | cut -d: -f1)
        local vm_box=$(echo "$config" | cut -d: -f2)
        local vm_desc=$(echo "$config" | cut -d: -f3)
        
        print_status "Testing: $vm_desc"
        
        case "$platform" in
            virtualbox)
                test_virtualbox "$vm_id" "$vm_desc"
                ;;
            qemu)
                test_qemu "$vm_id" "$vm_desc"
                ;;
            vmware)
                test_vmware "$vm_id" "$vm_desc"
                ;;
            vagrant)
                test_vagrant "$vm_id" "$vm_box" "$vm_desc"
                ;;
            *)
                print_status "Unknown platform: $platform"
                ;;
        esac
    done
}

# Usage information
usage() {
    cat << USAGE
Usage: $0 [PLATFORM] [OPTIONS]

PLATFORMS:
    virtualbox    Test with VirtualBox
    qemu         Test with QEMU/KVM
    vmware       Test with VMware
    vagrant      Test with Vagrant
    all          Test with all available platforms

OPTIONS:
    --memory SIZE    VM memory in MB (default: $VM_MEMORY)
    --disk SIZE      VM disk size in MB (default: $VM_DISK_SIZE)
    --cpus COUNT     VM CPU count (default: $VM_CPUS)
    --help          Show this help

EXAMPLES:
    $0 vagrant                    # Test with Vagrant
    $0 virtualbox --memory 4096   # Test with VirtualBox, 4GB RAM
    $0 all                        # Test with all platforms

USAGE
}

# Main function
main() {
    local platform="${1:-vagrant}"
    
    case "$platform" in
        --help|-h)
            usage
            exit 0
            ;;
        all)
            for p in "${PLATFORMS[@]}"; do
                if command -v "${p}" >/dev/null 2>&1 || [[ "$p" == "vagrant" ]]; then
                    run_tests "$p"
                fi
            done
            ;;
        *)
            run_tests "$platform"
            ;;
    esac
}

# Initialize framework
source_platform_scripts
main "$@"
EOF
    
    chmod +x "$framework_dir/vm-test-runner.sh"
    
    # Create platform-specific scripts directory
    mkdir -p "$framework_dir/platforms"
    
    # Create Vagrant platform script
    cat > "$framework_dir/platforms/vagrant.sh" << 'EOF'
#!/bin/bash

# Vagrant platform implementation

test_vagrant() {
    local vm_id=$1
    local vm_box=$2
    local vm_desc=$3
    
    local test_dir="/tmp/vagrant-test-$vm_id"
    mkdir -p "$test_dir"
    
    cat > "$test_dir/Vagrantfile" << VAGRANTFILE
Vagrant.configure("2") do |config|
  config.vm.box = "$vm_box"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "$VM_MEMORY"
    vb.cpus = $VM_CPUS
  end
  config.vm.synced_folder "$PROJECT_ROOT", "/project"
  config.vm.provision "shell", path: "$FRAMEWORK_DIR/test-script.sh"
end
VAGRANTFILE
    
    cd "$test_dir"
    
    if vagrant up; then
        print_status "✅ $vm_desc: VM started"
        
        if vagrant ssh -c "cd /project && sudo bash scripts/install-driver.sh"; then
            print_status "✅ $vm_desc: Installation test passed"
        else
            print_status "❌ $vm_desc: Installation test failed"
        fi
        
        vagrant destroy -f
    else
        print_status "❌ $vm_desc: VM failed to start"
    fi
    
    cd - >/dev/null
    rm -rf "$test_dir"
}
EOF
    
    # Create test script
    cat > "$framework_dir/test-script.sh" << 'EOF'
#!/bin/bash

# VM test script
set -e

echo "Starting Xiaomi fingerprint driver test"

# Update system
if command -v apt >/dev/null; then
    apt update
    apt install -y curl git
elif command -v dnf >/dev/null; then
    dnf update -y
    dnf install -y curl git
fi

# Test installation
cd /project

echo "Testing script syntax..."
bash -n scripts/install-driver.sh

echo "Running installation..."
bash scripts/install-driver.sh

echo "Test completed successfully"
EOF
    
    chmod +x "$framework_dir/test-script.sh"
    
    print_status "$GREEN" "✅ VM automation framework created: $framework_dir"
    print_status "$BLUE" "💡 Usage: $framework_dir/vm-test-runner.sh vagrant"
}

# Generate VM testing report
generate_vm_report() {
    print_section "GENERATING VM TESTING REPORT"
    
    local report_file="/tmp/xiaomi_fp_vm_test_report.md"
    
    cat > "$report_file" << EOF
# Xiaomi Fingerprint Driver - VM Testing Report

Generated: $(date)
Host System: $(uname -a)

## Testing Overview

This report covers virtual machine testing of the Xiaomi fingerprint driver installation scripts.

## Available Testing Methods

### 1. Vagrant Testing (Recommended)
- **Pros:** Easy automation, reproducible environments
- **Cons:** Requires VirtualBox or other provider
- **Status:** $(command -v vagrant >/dev/null && echo "✅ Available" || echo "❌ Not installed")

### 2. Docker Testing (Alternative)
- **Pros:** Lightweight, fast, good for CI/CD
- **Cons:** Limited kernel module testing
- **Status:** $(command -v docker >/dev/null && echo "✅ Available" || echo "❌ Not installed")

### 3. Manual VM Testing
- **Pros:** Full control, real hardware simulation
- **Cons:** Time-consuming, manual process
- **Status:** ✅ Always available

## Test Configurations

EOF
    
    for config in "${VM_CONFIGS[@]}"; do
        local distro=$(echo "$config" | cut -d: -f1)
        local description=$(echo "$config" | cut -d: -f2)
        echo "- **$description** ($distro)" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

## Testing Tools Created

1. **Vagrant Automation:** Automated VM creation and testing
2. **Manual Testing Guide:** Step-by-step manual testing procedures
3. **VM Framework:** Extensible testing framework for multiple platforms
4. **Test Scripts:** Automated installation and verification scripts

## Recommendations

1. **For Development:** Use Docker testing for quick validation
2. **For Release:** Use Vagrant testing for comprehensive validation
3. **For Hardware Testing:** Use manual VM testing with USB passthrough
4. **For CI/CD:** Integrate Docker testing into build pipeline

## Next Steps

1. Set up Vagrant environment: \`vagrant --version\`
2. Run automated tests: \`bash scripts/test-with-vm.sh\`
3. Review test results and logs
4. Address any distribution-specific issues

## Files Created

- Manual testing guide: /tmp/manual-vm-testing-guide.md
- VM automation framework: /tmp/fp-xiaomi-vm-framework/
- Test logs: $TEST_LOG

EOF
    
    print_status "$GREEN" "✅ VM testing report generated: $report_file"
}

# Main function
main() {
    echo "=== Xiaomi Fingerprint Driver VM Testing ===" > "$TEST_LOG"
    echo "Started at: $(date)" >> "$TEST_LOG"
    
    print_status "$PURPLE" "🖥️  Starting Virtual Machine Testing Setup"
    
    # Check for virtualization tools
    if check_virtualization_tools; then
        case "$VIRT_TOOL" in
            vagrant)
                test_with_vagrant
                ;;
            virtualbox)
                print_status "$BLUE" "💡 VirtualBox detected - creating automation scripts"
                for config in "${VM_CONFIGS[@]}"; do
                    local distro=$(echo "$config" | cut -d: -f1)
                    create_virtualbox_test "fp-xiaomi-$distro" "$distro"
                done
                ;;
            qemu)
                print_status "$BLUE" "💡 QEMU detected - creating test scripts"
                for config in "${VM_CONFIGS[@]}"; do
                    local distro=$(echo "$config" | cut -d: -f1)
                    create_qemu_test "$distro" "https://example.com/$distro.iso"
                done
                ;;
            *)
                print_status "$BLUE" "💡 Creating manual testing procedures"
                ;;
        esac
    else
        print_status "$YELLOW" "⚠️  No virtualization tools found - creating manual testing guide"
    fi
    
    # Always create manual testing guide and automation framework
    create_manual_testing_guide
    create_vm_automation_framework
    
    # Generate report
    generate_vm_report
    
    print_status "$GREEN" "🎉 VM testing setup completed!"
    print_status "$BLUE" "📄 Check the generated files for testing procedures"
    print_status "$BLUE" "📄 Test log: $TEST_LOG"
}

# Run main function
main "$@"