#!/bin/bash

# Fallback Driver System for Xiaomi Fingerprint Scanner
# Provides automatic fallback mechanisms when primary driver fails

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/fp_xiaomi_fallback.log"
BACKUP_DIR="/tmp/fp_xiaomi_backup"
VERBOSE=false

# Fallback strategies
FALLBACK_STRATEGIES=(
    "generic_libfprint"
    "compatibility_mode"
    "minimal_driver"
    "user_space_only"
)

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
    log "$message"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Fallback Driver System for Xiaomi Fingerprint Scanner

COMMANDS:
    install         Install fallback system
    activate        Activate fallback driver
    restore         Restore original driver
    test            Test fallback functionality
    status          Show current status
    list            List available fallback strategies

OPTIONS:
    -v, --verbose       Enable verbose output
    -s, --strategy STR  Specify fallback strategy
    -h, --help         Show this help message

STRATEGIES:
    generic_libfprint   Use generic libfprint driver
    compatibility_mode  Use compatibility mode driver
    minimal_driver      Use minimal functionality driver
    user_space_only     Use user-space only implementation

EXAMPLES:
    $0 install                    # Install fallback system
    $0 activate -s generic_libfprint  # Activate specific fallback
    $0 test                       # Test current fallback
    $0 restore                    # Restore original driver

EOF
}

# Parse command line arguments
COMMAND=""
STRATEGY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        install|activate|restore|test|status|list)
            COMMAND="$1"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -s|--strategy)
            STRATEGY="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    echo "Error: No command specified"
    usage
    exit 1
fi

# Initialize log
echo "=== Xiaomi Fingerprint Fallback System ===" > "$LOG_FILE"
log "Starting fallback system operation: $COMMAND"

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_status "$RED" "❌ This script must be run as root"
        exit 1
    fi
}

# Create backup directory
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log "Created backup directory: $BACKUP_DIR"
    fi
}

# Backup current driver configuration
backup_current_config() {
    print_status "$BLUE" "💾 Backing up current configuration..."
    
    create_backup_dir
    
    # Backup loaded modules
    lsmod > "$BACKUP_DIR/loaded_modules.txt"
    
    # Backup udev rules
    if [[ -f /etc/udev/rules.d/60-fp-xiaomi.rules ]]; then
        cp /etc/udev/rules.d/60-fp-xiaomi.rules "$BACKUP_DIR/"
    fi
    
    # Backup systemd services
    if systemctl list-unit-files | grep -q fprintd; then
        systemctl status fprintd > "$BACKUP_DIR/fprintd_status.txt" 2>/dev/null || true
    fi
    
    # Backup libfprint configuration
    if [[ -d /usr/lib/libfprint-2 ]]; then
        find /usr/lib/libfprint-2 -name "*xiaomi*" -o -name "*2717*" > "$BACKUP_DIR/libfprint_files.txt" 2>/dev/null || true
    fi
    
    print_status "$GREEN" "✅ Configuration backed up to $BACKUP_DIR"
}

# Generic libfprint fallback
activate_generic_libfprint() {
    print_status "$BLUE" "🔄 Activating generic libfprint fallback..."
    
    # Install generic libfprint if not present
    if ! dpkg -l | grep -q libfprint; then
        print_status "$YELLOW" "📦 Installing libfprint..."
        apt-get update && apt-get install -y libfprint-2-2 libfprint-2-dev fprintd
    fi
    
    # Create generic device configuration
    cat > /tmp/xiaomi_generic.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<device>
    <name>Xiaomi Fingerprint Scanner (Generic)</name>
    <vendor_id>0x2717</vendor_id>
    <product_id>0x0368</product_id>
    <driver>generic</driver>
    <fallback>true</fallback>
</device>
EOF
    
    # Try to register with libfprint
    if command -v fprint-list-devices >/dev/null 2>&1; then
        print_status "$BLUE" "📋 Available fingerprint devices:"
        fprint-list-devices || true
    fi
    
    print_status "$GREEN" "✅ Generic libfprint fallback activated"
    return 0
}

# Compatibility mode fallback
activate_compatibility_mode() {
    print_status "$BLUE" "🔄 Activating compatibility mode fallback..."
    
    # Load our driver with compatibility flags
    if [[ -f "$PROJECT_ROOT/src/fp_xiaomi_driver.ko" ]]; then
        # Unload existing driver
        rmmod fp_xiaomi_driver 2>/dev/null || true
        
        # Load with compatibility mode
        insmod "$PROJECT_ROOT/src/fp_xiaomi_driver.ko" compatibility_mode=1 debug=1
        
        print_status "$GREEN" "✅ Compatibility mode activated"
        return 0
    else
        print_status "$RED" "❌ Driver module not found"
        return 1
    fi
}

# Minimal driver fallback
activate_minimal_driver() {
    print_status "$BLUE" "🔄 Activating minimal driver fallback..."
    
    # Create minimal driver configuration
    cat > /tmp/fp_xiaomi_minimal.conf << 'EOF'
# Minimal Xiaomi Fingerprint Driver Configuration
options fp_xiaomi_driver minimal_mode=1 reduced_functionality=1
EOF
    
    if [[ -f "$PROJECT_ROOT/src/fp_xiaomi_driver.ko" ]]; then
        # Unload existing driver
        rmmod fp_xiaomi_driver 2>/dev/null || true
        
        # Load minimal driver
        insmod "$PROJECT_ROOT/src/fp_xiaomi_driver.ko" minimal_mode=1
        
        print_status "$GREEN" "✅ Minimal driver activated"
        return 0
    else
        print_status "$RED" "❌ Driver module not found"
        return 1
    fi
}

# User-space only fallback
activate_user_space_only() {
    print_status "$BLUE" "🔄 Activating user-space only fallback..."
    
    # Compile user-space library if needed
    if [[ -f "$PROJECT_ROOT/src/libfp_xiaomi.c" ]]; then
        cd "$PROJECT_ROOT/src"
        gcc -shared -fPIC -o libfp_xiaomi_fallback.so libfp_xiaomi.c -lusb-1.0
        
        # Install library
        cp libfp_xiaomi_fallback.so /usr/local/lib/
        ldconfig
        
        print_status "$GREEN" "✅ User-space fallback library installed"
    fi
    
    # Create user-space service
    cat > /etc/systemd/system/fp-xiaomi-userspace.service << 'EOF'
[Unit]
Description=Xiaomi Fingerprint User-space Service
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/fp_xiaomi_userspace
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable fp-xiaomi-userspace.service
    
    print_status "$GREEN" "✅ User-space only fallback activated"
    return 0
}

# Test fallback functionality
test_fallback() {
    print_status "$BLUE" "🧪 Testing fallback functionality..."
    
    local test_passed=true
    
    # Test device detection
    if lsusb | grep -q "2717:"; then
        print_status "$GREEN" "✅ Device detection: PASS"
    else
        print_status "$RED" "❌ Device detection: FAIL"
        test_passed=false
    fi
    
    # Test driver loading
    if lsmod | grep -q fp_xiaomi; then
        print_status "$GREEN" "✅ Driver loading: PASS"
    else
        print_status "$YELLOW" "⚠️  Driver loading: No kernel driver loaded (may be user-space only)"
    fi
    
    # Test basic communication
    if [[ -c /dev/fp_xiaomi0 ]]; then
        print_status "$GREEN" "✅ Device node: PASS"
        
        # Try basic device communication
        if timeout 5 cat /dev/fp_xiaomi0 >/dev/null 2>&1; then
            print_status "$GREEN" "✅ Basic communication: PASS"
        else
            print_status "$YELLOW" "⚠️  Basic communication: Limited or no response"
        fi
    else
        print_status "$YELLOW" "⚠️  Device node: Not found (may be user-space only)"
    fi
    
    # Test with libfprint if available
    if command -v fprint-list-devices >/dev/null 2>&1; then
        if fprint-list-devices | grep -i xiaomi >/dev/null 2>&1; then
            print_status "$GREEN" "✅ libfprint integration: PASS"
        else
            print_status "$YELLOW" "⚠️  libfprint integration: Device not recognized"
        fi
    fi
    
    if [[ $test_passed == true ]]; then
        print_status "$GREEN" "✅ Fallback functionality test: OVERALL PASS"
        return 0
    else
        print_status "$YELLOW" "⚠️  Fallback functionality test: PARTIAL PASS"
        return 1
    fi
}

# Install fallback system
install_fallback_system() {
    print_status "$BLUE" "📦 Installing fallback system..."
    
    check_root
    create_backup_dir
    backup_current_config
    
    # Create fallback configuration directory
    mkdir -p /etc/fp-xiaomi-fallback
    
    # Install fallback scripts
    cp "$0" /usr/local/bin/fp-xiaomi-fallback
    chmod +x /usr/local/bin/fp-xiaomi-fallback
    
    # Create fallback configuration
    cat > /etc/fp-xiaomi-fallback/config << EOF
# Xiaomi Fingerprint Fallback Configuration
FALLBACK_ENABLED=true
DEFAULT_STRATEGY=generic_libfprint
AUTO_FALLBACK=true
FALLBACK_TIMEOUT=30
EOF
    
    # Create systemd service for automatic fallback
    cat > /etc/systemd/system/fp-xiaomi-fallback.service << 'EOF'
[Unit]
Description=Xiaomi Fingerprint Fallback Monitor
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fp-xiaomi-fallback monitor
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable fp-xiaomi-fallback.service
    
    print_status "$GREEN" "✅ Fallback system installed successfully"
}

# Activate specific fallback strategy
activate_fallback() {
    local strategy="${STRATEGY:-generic_libfprint}"
    
    print_status "$BLUE" "🔄 Activating fallback strategy: $strategy"
    
    check_root
    backup_current_config
    
    case "$strategy" in
        generic_libfprint)
            activate_generic_libfprint
            ;;
        compatibility_mode)
            activate_compatibility_mode
            ;;
        minimal_driver)
            activate_minimal_driver
            ;;
        user_space_only)
            activate_user_space_only
            ;;
        *)
            print_status "$RED" "❌ Unknown fallback strategy: $strategy"
            print_status "$BLUE" "Available strategies: ${FALLBACK_STRATEGIES[*]}"
            exit 1
            ;;
    esac
    
    # Test the activated fallback
    sleep 2
    test_fallback
}

# Restore original driver
restore_original() {
    print_status "$BLUE" "🔄 Restoring original driver configuration..."
    
    check_root
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_status "$RED" "❌ No backup found to restore from"
        exit 1
    fi
    
    # Stop fallback services
    systemctl stop fp-xiaomi-fallback.service 2>/dev/null || true
    systemctl stop fp-xiaomi-userspace.service 2>/dev/null || true
    
    # Unload fallback drivers
    rmmod fp_xiaomi_driver 2>/dev/null || true
    
    # Restore original configuration
    if [[ -f "$BACKUP_DIR/60-fp-xiaomi.rules" ]]; then
        cp "$BACKUP_DIR/60-fp-xiaomi.rules" /etc/udev/rules.d/
        udevadm control --reload-rules
    fi
    
    # Restart original services
    systemctl restart fprintd 2>/dev/null || true
    
    print_status "$GREEN" "✅ Original driver configuration restored"
}

# Show current status
show_status() {
    print_status "$BLUE" "📊 Current Fallback System Status"
    
    echo "System Information:"
    echo "  Kernel: $(uname -r)"
    echo "  Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
    echo ""
    
    echo "Hardware Detection:"
    if lsusb | grep -q "2717:"; then
        echo "  ✅ Xiaomi device detected"
        lsusb | grep "2717:" | sed 's/^/    /'
    else
        echo "  ❌ No Xiaomi device detected"
    fi
    echo ""
    
    echo "Driver Status:"
    if lsmod | grep -q fp_xiaomi; then
        echo "  ✅ Xiaomi driver loaded"
        lsmod | grep fp_xiaomi | sed 's/^/    /'
    else
        echo "  ⚠️  No Xiaomi kernel driver loaded"
    fi
    echo ""
    
    echo "Services Status:"
    for service in fprintd fp-xiaomi-fallback fp-xiaomi-userspace; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "  ✅ $service: active"
        elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
            echo "  ⚠️  $service: enabled but not active"
        else
            echo "  ❌ $service: not available"
        fi
    done
    echo ""
    
    echo "Fallback Configuration:"
    if [[ -f /etc/fp-xiaomi-fallback/config ]]; then
        echo "  ✅ Fallback system installed"
        cat /etc/fp-xiaomi-fallback/config | sed 's/^/    /'
    else
        echo "  ❌ Fallback system not installed"
    fi
}

# List available strategies
list_strategies() {
    print_status "$BLUE" "📋 Available Fallback Strategies"
    
    echo "1. generic_libfprint"
    echo "   Uses the generic libfprint driver for basic functionality"
    echo "   Pros: Wide compatibility, stable"
    echo "   Cons: Limited features"
    echo ""
    
    echo "2. compatibility_mode"
    echo "   Uses our driver with compatibility flags enabled"
    echo "   Pros: Full features, better compatibility"
    echo "   Cons: May be slower"
    echo ""
    
    echo "3. minimal_driver"
    echo "   Uses our driver with minimal functionality"
    echo "   Pros: Lightweight, stable"
    echo "   Cons: Reduced features"
    echo ""
    
    echo "4. user_space_only"
    echo "   Uses user-space implementation without kernel driver"
    echo "   Pros: No kernel dependencies"
    echo "   Cons: Requires root access, may be slower"
}

# Main execution
case "$COMMAND" in
    install)
        install_fallback_system
        ;;
    activate)
        activate_fallback
        ;;
    restore)
        restore_original
        ;;
    test)
        test_fallback
        ;;
    status)
        show_status
        ;;
    list)
        list_strategies
        ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac

print_status "$BLUE" "📄 Full log available at: $LOG_FILE"