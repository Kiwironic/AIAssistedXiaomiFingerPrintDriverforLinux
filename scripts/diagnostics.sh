#!/bin/bash

# Comprehensive Diagnostics Script for Xiaomi Fingerprint Scanner
# Provides detailed system analysis and troubleshooting information

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/tmp/fp_xiaomi_diagnostics.log"
REPORT_FILE="/tmp/fp_xiaomi_diagnostic_report.html"
VERBOSE=false
COLLECT_LOGS=false
EXPORT_FORMAT="text"

# Device information
XIAOMI_VID="2717"
SUPPORTED_PIDS=("0368" "0369" "036A" "036B")

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

# Print section header
print_section() {
    local title=$1
    echo ""
    print_status "$CYAN" "═══════════════════════════════════════════════════════════════"
    print_status "$CYAN" "  $title"
    print_status "$CYAN" "═══════════════════════════════════════════════════════════════"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Comprehensive Diagnostics for Xiaomi Fingerprint Scanner

COMMANDS:
    full            Run complete diagnostic suite (default)
    hardware        Hardware-specific diagnostics
    driver          Driver and kernel diagnostics
    system          System configuration diagnostics
    performance     Performance analysis
    logs            Collect and analyze system logs
    network         Network and connectivity diagnostics
    export          Export diagnostic report

OPTIONS:
    -v, --verbose       Enable verbose output
    -l, --collect-logs  Collect system logs
    -f, --format FORMAT Export format (text|html|json)
    -o, --output FILE   Output file for report
    -h, --help         Show this help message

EXAMPLES:
    $0                          # Run full diagnostics
    $0 hardware -v              # Verbose hardware diagnostics
    $0 logs -l                  # Collect system logs
    $0 export -f html -o report.html  # Export HTML report

EOF
}

# Parse command line arguments
COMMAND="full"
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        full|hardware|driver|system|performance|logs|network|export)
            COMMAND="$1"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -l|--collect-logs)
            COLLECT_LOGS=true
            shift
            ;;
        -f|--format)
            EXPORT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
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

# Initialize log
echo "=== Xiaomi Fingerprint Scanner Diagnostics ===" > "$LOG_FILE"
log "Starting diagnostics at $(date)"
log "Command: $COMMAND, Verbose: $VERBOSE, Collect Logs: $COLLECT_LOGS"

# System information collection
collect_system_info() {
    print_section "SYSTEM INFORMATION"
    
    # Basic system info
    print_status "$BLUE" "🖥️  System Details:"
    echo "  Hostname: $(hostname)"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Unknown')"
    echo "  Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "  Load Average: $(cat /proc/loadavg)"
    echo "  Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    echo "  Disk Usage: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
    
    if [[ $VERBOSE == true ]]; then
        echo ""
        print_status "$BLUE" "📋 Detailed System Information:"
        echo "  CPU: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d: -f2 | xargs)"
        echo "  CPU Cores: $(nproc)"
        echo "  Total Memory: $(cat /proc/meminfo | grep MemTotal | awk '{print $2 $3}')"
        echo "  Swap: $(cat /proc/meminfo | grep SwapTotal | awk '{print $2 $3}')"
        echo "  Boot Time: $(who -b 2>/dev/null | awk '{print $3, $4}' || echo 'Unknown')"
    fi
}

# Hardware diagnostics
diagnose_hardware() {
    print_section "HARDWARE DIAGNOSTICS"
    
    # USB subsystem check
    print_status "$BLUE" "🔌 USB Subsystem Analysis:"
    
    if [[ -d /sys/bus/usb ]]; then
        print_status "$GREEN" "  ✅ USB subsystem available"
        
        # USB controller information
        echo "  USB Controllers:"
        lspci | grep -i usb | sed 's/^/    /'
        
        # USB version support
        if [[ $VERBOSE == true ]]; then
            echo "  USB Hubs and Ports:"
            lsusb -t | sed 's/^/    /'
        fi
    else
        print_status "$RED" "  ❌ USB subsystem not available"
    fi
    
    # Device detection
    print_status "$BLUE" "🔍 Xiaomi Device Detection:"
    
    local devices_found=()
    local device_details=()
    
    while IFS= read -r line; do
        if [[ $line =~ Bus[[:space:]]+([0-9]+)[[:space:]]+Device[[:space:]]+([0-9]+).*ID[[:space:]]+${XIAOMI_VID}:([0-9a-fA-F]{4}) ]]; then
            local bus="${BASH_REMATCH[1]}"
            local device="${BASH_REMATCH[2]}"
            local pid="${BASH_REMATCH[3]}"
            
            devices_found+=("$bus:$device:$pid")
            
            # Get detailed device information
            local device_info=$(lsusb -v -s "$bus:$device" 2>/dev/null || echo "Unable to get detailed info")
            device_details+=("$device_info")
            
            print_status "$GREEN" "  ✅ Found device: Bus $bus, Device $device, PID $pid"
            
            # Check if supported
            local supported=false
            for supported_pid in "${SUPPORTED_PIDS[@]}"; do
                if [[ "$pid" == "$supported_pid" ]]; then
                    supported=true
                    break
                fi
            done
            
            if [[ $supported == true ]]; then
                print_status "$GREEN" "    ✅ Device is officially supported"
            else
                print_status "$YELLOW" "    ⚠️  Device may have limited support"
            fi
            
            # Device capabilities
            if [[ $VERBOSE == true ]]; then
                echo "    Device Details:"
                echo "$device_info" | grep -E "(bcdUSB|bMaxPacketSize|bNumInterfaces|bInterfaceClass)" | sed 's/^/      /'
            fi
        fi
    done < <(lsusb)
    
    if [[ ${#devices_found[@]} -eq 0 ]]; then
        print_status "$RED" "  ❌ No Xiaomi fingerprint devices found"
        
        # Suggest troubleshooting steps
        print_status "$YELLOW" "  💡 Troubleshooting suggestions:"
        echo "    - Ensure device is properly connected"
        echo "    - Try different USB ports"
        echo "    - Check if device is powered on"
        echo "    - Verify cable integrity"
    fi
    
    # Power management analysis
    print_status "$BLUE" "⚡ Power Management Analysis:"
    
    for device_info in "${devices_found[@]}"; do
        IFS=':' read -r bus device pid <<< "$device_info"
        local device_path="/sys/bus/usb/devices/$bus-$device"
        
        if [[ -d "$device_path" ]]; then
            echo "  Device $bus:$device power state:"
            
            if [[ -f "$device_path/power/control" ]]; then
                local power_control=$(cat "$device_path/power/control")
                echo "    Power Control: $power_control"
                
                if [[ "$power_control" == "auto" ]]; then
                    print_status "$YELLOW" "    ⚠️  Auto power management enabled (may cause issues)"
                fi
            fi
            
            if [[ -f "$device_path/power/autosuspend_delay_ms" ]]; then
                local autosuspend=$(cat "$device_path/power/autosuspend_delay_ms")
                echo "    Autosuspend Delay: ${autosuspend}ms"
            fi
        fi
    done
}

# Driver diagnostics
diagnose_driver() {
    print_section "DRIVER DIAGNOSTICS"
    
    # Kernel module analysis
    print_status "$BLUE" "🔧 Kernel Module Analysis:"
    
    if lsmod | grep -q fp_xiaomi; then
        print_status "$GREEN" "  ✅ Xiaomi fingerprint driver loaded"
        
        # Module details
        local module_info=$(lsmod | grep fp_xiaomi)
        echo "  Module Info: $module_info"
        
        # Module parameters
        if [[ -d /sys/module/fp_xiaomi_driver ]]; then
            echo "  Module Parameters:"
            find /sys/module/fp_xiaomi_driver/parameters -type f 2>/dev/null | while read -r param_file; do
                local param_name=$(basename "$param_file")
                local param_value=$(cat "$param_file" 2>/dev/null || echo "N/A")
                echo "    $param_name: $param_value"
            done
        fi
        
        # Module dependencies
        if [[ $VERBOSE == true ]]; then
            echo "  Module Dependencies:"
            lsmod | grep fp_xiaomi | awk '{print $4}' | tr ',' '\n' | sed 's/^/    /'
        fi
    else
        print_status "$YELLOW" "  ⚠️  Xiaomi fingerprint driver not loaded"
        
        # Check if module exists
        if [[ -f "$PROJECT_ROOT/src/fp_xiaomi_driver.ko" ]]; then
            print_status "$BLUE" "  ✅ Driver module found at: $PROJECT_ROOT/src/fp_xiaomi_driver.ko"
            
            # Module information
            if command -v modinfo >/dev/null 2>&1; then
                echo "  Module Information:"
                modinfo "$PROJECT_ROOT/src/fp_xiaomi_driver.ko" | sed 's/^/    /'
            fi
        else
            print_status "$RED" "  ❌ Driver module not found - needs compilation"
        fi
    fi
    
    # Device nodes
    print_status "$BLUE" "📁 Device Node Analysis:"
    
    local device_nodes=()
    for node in /dev/fp_xiaomi* /dev/fingerprint* /dev/hidraw*; do
        if [[ -e "$node" ]]; then
            device_nodes+=("$node")
        fi
    done
    
    if [[ ${#device_nodes[@]} -gt 0 ]]; then
        print_status "$GREEN" "  ✅ Found device nodes:"
        for node in "${device_nodes[@]}"; do
            local permissions=$(ls -l "$node" | awk '{print $1, $3, $4}')
            echo "    $node ($permissions)"
            
            # Test basic access
            if [[ -r "$node" ]]; then
                print_status "$GREEN" "      ✅ Readable"
            else
                print_status "$RED" "      ❌ Not readable"
            fi
            
            if [[ -w "$node" ]]; then
                print_status "$GREEN" "      ✅ Writable"
            else
                print_status "$RED" "      ❌ Not writable"
            fi
        done
    else
        print_status "$YELLOW" "  ⚠️  No device nodes found"
    fi
    
    # Conflicting drivers
    print_status "$BLUE" "⚔️  Conflicting Driver Analysis:"
    
    local conflicts=()
    local conflicting_modules=("libfprint" "fprint" "validity" "synaptics" "goodix")
    
    for module in "${conflicting_modules[@]}"; do
        if lsmod | grep -q "^$module"; then
            conflicts+=("$module")
        fi
    done
    
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        print_status "$YELLOW" "  ⚠️  Potentially conflicting modules loaded:"
        for conflict in "${conflicts[@]}"; do
            echo "    - $conflict"
            
            if [[ $VERBOSE == true ]]; then
                lsmod | grep "^$conflict" | sed 's/^/      /'
            fi
        done
    else
        print_status "$GREEN" "  ✅ No conflicting drivers detected"
    fi
}

# System configuration diagnostics
diagnose_system() {
    print_section "SYSTEM CONFIGURATION"
    
    # Udev rules analysis
    print_status "$BLUE" "📋 Udev Rules Analysis:"
    
    local udev_rules=()
    for rule_file in /etc/udev/rules.d/*fp* /etc/udev/rules.d/*xiaomi* /etc/udev/rules.d/*2717*; do
        if [[ -f "$rule_file" ]]; then
            udev_rules+=("$rule_file")
        fi
    done
    
    if [[ ${#udev_rules[@]} -gt 0 ]]; then
        print_status "$GREEN" "  ✅ Found udev rules:"
        for rule in "${udev_rules[@]}"; do
            echo "    $(basename "$rule")"
            
            if [[ $VERBOSE == true ]]; then
                echo "      Content:"
                cat "$rule" | sed 's/^/        /'
            fi
        done
    else
        print_status "$YELLOW" "  ⚠️  No specific udev rules found"
    fi
    
    # Service analysis
    print_status "$BLUE" "🔧 Service Analysis:"
    
    local services=("fprintd" "systemd-logind" "gdm" "lightdm" "sddm")
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^$service"; then
            local status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
            local enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
            
            echo "  $service: $status ($enabled)"
            
            if [[ $VERBOSE == true && "$status" == "active" ]]; then
                echo "    Process Info:"
                systemctl status "$service" --no-pager -l | head -10 | sed 's/^/      /'
            fi
        fi
    done
    
    # Permission analysis
    print_status "$BLUE" "🔐 Permission Analysis:"
    
    # Check user groups
    local current_user=$(whoami)
    local user_groups=$(groups "$current_user" 2>/dev/null || echo "")
    echo "  Current user: $current_user"
    echo "  User groups: $user_groups"
    
    # Check important groups
    local important_groups=("plugdev" "input" "dialout")
    for group in "${important_groups[@]}"; do
        if echo "$user_groups" | grep -q "$group"; then
            print_status "$GREEN" "    ✅ User is in $group group"
        else
            print_status "$YELLOW" "    ⚠️  User is not in $group group"
        fi
    done
    
    # SELinux/AppArmor analysis
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status=$(getenforce 2>/dev/null || echo "Not available")
        echo "  SELinux: $selinux_status"
        
        if [[ "$selinux_status" == "Enforcing" ]]; then
            print_status "$YELLOW" "    ⚠️  SELinux is enforcing - may block driver access"
        fi
    fi
    
    if command -v aa-status >/dev/null 2>&1; then
        local apparmor_status=$(aa-status --enabled 2>/dev/null && echo "Enabled" || echo "Disabled")
        echo "  AppArmor: $apparmor_status"
    fi
}

# Performance diagnostics
diagnose_performance() {
    print_section "PERFORMANCE ANALYSIS"
    
    # System load analysis
    print_status "$BLUE" "📊 System Load Analysis:"
    
    local load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    local cpu_count=$(nproc)
    echo "  Load Average: $load_avg (CPUs: $cpu_count)"
    
    # Memory analysis
    print_status "$BLUE" "💾 Memory Analysis:"
    
    echo "  Memory Usage:"
    free -h | sed 's/^/    /'
    
    # Check for memory pressure
    local mem_available=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
    local mem_total=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
    local mem_usage_percent=$((100 - (mem_available * 100 / mem_total)))
    
    echo "  Memory Usage: ${mem_usage_percent}%"
    
    if [[ $mem_usage_percent -gt 90 ]]; then
        print_status "$RED" "    ❌ High memory usage detected"
    elif [[ $mem_usage_percent -gt 75 ]]; then
        print_status "$YELLOW" "    ⚠️  Moderate memory usage"
    else
        print_status "$GREEN" "    ✅ Memory usage is normal"
    fi
    
    # I/O analysis
    print_status "$BLUE" "💿 I/O Analysis:"
    
    if [[ -f /proc/diskstats ]]; then
        echo "  Disk I/O (recent activity):"
        cat /proc/diskstats | grep -E "(sd[a-z]|nvme)" | tail -5 | sed 's/^/    /'
    fi
    
    # USB performance
    print_status "$BLUE" "🔌 USB Performance Analysis:"
    
    # Check USB speed for Xiaomi devices
    while IFS= read -r line; do
        if [[ $line =~ Bus[[:space:]]+([0-9]+)[[:space:]]+Device[[:space:]]+([0-9]+).*ID[[:space:]]+${XIAOMI_VID}: ]]; then
            local bus="${BASH_REMATCH[1]}"
            local device="${BASH_REMATCH[2]}"
            
            local speed_info=$(lsusb -v -s "$bus:$device" 2>/dev/null | grep -E "(bcdUSB|MaxPower)" || echo "Speed info not available")
            echo "  Device $bus:$device USB info:"
            echo "$speed_info" | sed 's/^/    /'
        fi
    done < <(lsusb)
}

# Log collection and analysis
collect_and_analyze_logs() {
    print_section "LOG COLLECTION AND ANALYSIS"
    
    print_status "$BLUE" "📋 Collecting System Logs..."
    
    local log_dir="/tmp/fp_xiaomi_logs_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$log_dir"
    
    # Kernel logs
    print_status "$BLUE" "  Collecting kernel logs..."
    dmesg > "$log_dir/dmesg.log"
    dmesg | grep -i -E "(usb|fingerprint|fp_xiaomi|2717)" > "$log_dir/dmesg_filtered.log" 2>/dev/null || touch "$log_dir/dmesg_filtered.log"
    
    # System logs
    if command -v journalctl >/dev/null 2>&1; then
        print_status "$BLUE" "  Collecting systemd logs..."
        journalctl --no-pager -n 1000 > "$log_dir/journal.log" 2>/dev/null || true
        journalctl --no-pager -u fprintd > "$log_dir/fprintd.log" 2>/dev/null || true
    fi
    
    # Syslog
    if [[ -f /var/log/syslog ]]; then
        print_status "$BLUE" "  Collecting syslog..."
        tail -1000 /var/log/syslog > "$log_dir/syslog.log" 2>/dev/null || true
    fi
    
    # USB logs
    if [[ -f /var/log/kern.log ]]; then
        print_status "$BLUE" "  Collecting kernel logs..."
        grep -i usb /var/log/kern.log | tail -500 > "$log_dir/usb_kern.log" 2>/dev/null || true
    fi
    
    # Analyze collected logs
    print_status "$BLUE" "🔍 Analyzing Collected Logs..."
    
    # Look for errors
    local error_patterns=("error" "fail" "timeout" "disconnect" "unable" "cannot")
    local errors_found=false
    
    for pattern in "${error_patterns[@]}"; do
        local matches=$(grep -i "$pattern" "$log_dir"/*.log 2>/dev/null | wc -l)
        if [[ $matches -gt 0 ]]; then
            echo "  Found $matches instances of '$pattern'"
            errors_found=true
            
            if [[ $VERBOSE == true ]]; then
                echo "    Recent examples:"
                grep -i "$pattern" "$log_dir"/*.log 2>/dev/null | tail -3 | sed 's/^/      /'
            fi
        fi
    done
    
    if [[ $errors_found == false ]]; then
        print_status "$GREEN" "  ✅ No obvious errors found in logs"
    else
        print_status "$YELLOW" "  ⚠️  Some errors found - check detailed logs"
    fi
    
    print_status "$GREEN" "  📁 Logs collected in: $log_dir"
}

# Export diagnostic report
export_report() {
    print_section "EXPORTING DIAGNOSTIC REPORT"
    
    local output_file="${OUTPUT_FILE:-$REPORT_FILE}"
    
    case "$EXPORT_FORMAT" in
        html)
            export_html_report "$output_file"
            ;;
        json)
            export_json_report "$output_file"
            ;;
        text|*)
            export_text_report "$output_file"
            ;;
    esac
}

# Export HTML report
export_html_report() {
    local output_file="$1"
    
    print_status "$BLUE" "📄 Generating HTML report..."
    
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Xiaomi Fingerprint Scanner Diagnostic Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007acc; }
        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .error { color: #dc3545; }
        .info { color: #17a2b8; }
        pre { background: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Xiaomi Fingerprint Scanner Diagnostic Report</h1>
        <p>Generated: $(date)</p>
        <p>System: $(uname -a)</p>
    </div>
EOF
    
    # Add diagnostic sections to HTML
    echo "    <div class='section'>" >> "$output_file"
    echo "        <h2>Hardware Status</h2>" >> "$output_file"
    
    if lsusb | grep -q "$XIAOMI_VID"; then
        echo "        <p class='success'>✅ Xiaomi device detected</p>" >> "$output_file"
        echo "        <pre>$(lsusb | grep "$XIAOMI_VID")</pre>" >> "$output_file"
    else
        echo "        <p class='error'>❌ No Xiaomi device detected</p>" >> "$output_file"
    fi
    
    echo "    </div>" >> "$output_file"
    
    # Add more sections...
    echo "</body></html>" >> "$output_file"
    
    print_status "$GREEN" "✅ HTML report generated: $output_file"
}

# Export text report
export_text_report() {
    local output_file="$1"
    
    print_status "$BLUE" "📄 Generating text report..."
    
    # Copy current log to report file
    cp "$LOG_FILE" "$output_file"
    
    print_status "$GREEN" "✅ Text report generated: $output_file"
}

# Export JSON report
export_json_report() {
    local output_file="$1"
    
    print_status "$BLUE" "📄 Generating JSON report..."
    
    cat > "$output_file" << EOF
{
    "diagnostic_report": {
        "timestamp": "$(date -Iseconds)",
        "system": {
            "hostname": "$(hostname)",
            "kernel": "$(uname -r)",
            "distribution": "$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
        },
        "hardware": {
            "xiaomi_devices": [
EOF
    
    # Add device information
    local first_device=true
    while IFS= read -r line; do
        if [[ $line =~ Bus[[:space:]]+([0-9]+)[[:space:]]+Device[[:space:]]+([0-9]+).*ID[[:space:]]+${XIAOMI_VID}:([0-9a-fA-F]{4}) ]]; then
            if [[ $first_device == false ]]; then
                echo "," >> "$output_file"
            fi
            echo "                {" >> "$output_file"
            echo "                    \"bus\": \"${BASH_REMATCH[1]}\"," >> "$output_file"
            echo "                    \"device\": \"${BASH_REMATCH[2]}\"," >> "$output_file"
            echo "                    \"pid\": \"${BASH_REMATCH[3]}\"" >> "$output_file"
            echo "                }" >> "$output_file"
            first_device=false
        fi
    done < <(lsusb)
    
    cat >> "$output_file" << EOF
            ]
        },
        "driver": {
            "loaded": $(lsmod | grep -q fp_xiaomi && echo "true" || echo "false")
        }
    }
}
EOF
    
    print_status "$GREEN" "✅ JSON report generated: $output_file"
}

# Main execution
main() {
    print_status "$PURPLE" "🚀 Starting Xiaomi Fingerprint Scanner Diagnostics"
    
    case "$COMMAND" in
        full)
            collect_system_info
            diagnose_hardware
            diagnose_driver
            diagnose_system
            diagnose_performance
            if [[ $COLLECT_LOGS == true ]]; then
                collect_and_analyze_logs
            fi
            ;;
        hardware)
            collect_system_info
            diagnose_hardware
            ;;
        driver)
            diagnose_driver
            ;;
        system)
            diagnose_system
            ;;
        performance)
            diagnose_performance
            ;;
        logs)
            collect_and_analyze_logs
            ;;
        export)
            export_report
            ;;
        *)
            echo "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
    
    print_status "$GREEN" "✅ Diagnostics completed successfully"
    print_status "$BLUE" "📄 Full log available at: $LOG_FILE"
    
    if [[ "$COMMAND" != "export" ]]; then
        print_status "$BLUE" "💡 To export a report, run: $0 export -f html -o report.html"
    fi
}

# Run main function
main "$@"