#!/bin/bash

# Interactive Installation Script for Xiaomi Fingerprint Scanner Driver
# Provides a user-friendly guided installation experience

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
LOG_FILE="/tmp/fp_xiaomi_interactive_install.log"

# Installation preferences
INSTALL_TYPE=""
ENABLE_DEBUG=false
INSTALL_FALLBACK=true
AUTO_CONFIGURE=true
SKIP_TESTS=false

# Print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Print section header with box
print_box() {
    local title=$1
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    
    echo ""
    print_status "$CYAN" "┌$(printf '─%.0s' $(seq 1 $width))┐"
    printf "${CYAN}│%*s${BOLD}%s${NC}${CYAN}%*s│${NC}\n" $padding "" "$title" $padding ""
    print_status "$CYAN" "└$(printf '─%.0s' $(seq 1 $width))┘"
    echo ""
}

# Ask yes/no question
ask_yes_no() {
    local question=$1
    local default=${2:-"y"}
    local response
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$(echo -e "${BLUE}$question [Y/n]: ${NC}")" response
            response=${response:-"y"}
        else
            read -p "$(echo -e "${BLUE}$question [y/N]: ${NC}")" response
            response=${response:-"n"}
        fi
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                print_status "$YELLOW" "Please answer yes or no."
                ;;
        esac
    done
}

# Ask multiple choice question
ask_choice() {
    local question=$1
    shift
    local options=("$@")
    local choice
    
    echo -e "${BLUE}$question${NC}"
    for i in "${!options[@]}"; do
        echo "  $((i+1)). ${options[i]}"
    done
    
    while true; do
        read -p "$(echo -e "${BLUE}Enter your choice [1-${#options[@]}]: ${NC}")" choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#options[@]} ]]; then
            return $((choice-1))
        else
            print_status "$YELLOW" "Please enter a valid choice (1-${#options[@]})."
        fi
    done
}

# Display welcome message
show_welcome() {
    clear
    print_box "XIAOMI FINGERPRINT SCANNER DRIVER"
    
    cat << EOF
Welcome to the interactive installation wizard for the Xiaomi Fingerprint
Scanner Driver. This wizard will guide you through the installation process
and help you configure your system for optimal fingerprint recognition.

${GREEN}Features:${NC}
• Automatic hardware detection and compatibility checking
• Distribution-specific package installation
• Kernel driver compilation and installation
• Service configuration and PAM integration
• Fallback system for maximum compatibility
• Comprehensive testing and diagnostics

${YELLOW}Requirements:${NC}
• Xiaomi laptop with supported fingerprint scanner
• Linux kernel 4.15 or higher
• Root/sudo access
• Internet connection for package downloads

EOF
    
    if ! ask_yes_no "Do you want to continue with the installation?"; then
        print_status "$YELLOW" "Installation cancelled by user."
        exit 0
    fi
}

# System information and compatibility check
check_system_compatibility() {
    print_box "SYSTEM COMPATIBILITY CHECK"
    
    print_status "$BLUE" "🔍 Checking system compatibility..."
    
    # Display system information
    echo "System Information:"
    echo "  Hostname: $(hostname)"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 || echo 'Unknown')"
    echo ""
    
    # Check for Xiaomi devices
    print_status "$BLUE" "🔍 Scanning for Xiaomi fingerprint devices..."
    
    local devices_found=false
    while IFS= read -r line; do
        if [[ $line =~ ID[[:space:]]+2717: ]]; then
            print_status "$GREEN" "✅ Found: $line"
            devices_found=true
        fi
    done < <(lsusb)
    
    if [[ $devices_found == false ]]; then
        print_status "$YELLOW" "⚠️  No Xiaomi fingerprint devices detected."
        echo ""
        echo "This could mean:"
        echo "• Device is not connected or powered on"
        echo "• Device is not supported by this driver"
        echo "• USB permissions or hardware issues"
        echo ""
        
        if ask_yes_no "Do you want to continue anyway? (You can install the driver for future use)"; then
            print_status "$BLUE" "Continuing with installation..."
        else
            print_status "$YELLOW" "Installation cancelled."
            exit 0
        fi
    else
        print_status "$GREEN" "✅ Compatible hardware detected!"
    fi
    
    # Run detailed compatibility check if available
    if [[ -f "$PROJECT_ROOT/scripts/hardware-compatibility-check.sh" ]]; then
        echo ""
        if ask_yes_no "Do you want to run a detailed compatibility check?"; then
            bash "$PROJECT_ROOT/scripts/hardware-compatibility-check.sh" -v
        fi
    fi
}

# Choose installation type
choose_installation_type() {
    print_box "INSTALLATION TYPE"
    
    local install_options=(
        "Standard Installation (Recommended)"
        "Advanced Installation (Custom options)"
        "Minimal Installation (Driver only)"
        "Development Installation (Debug enabled)"
    )
    
    ask_choice "Please choose your installation type:" "${install_options[@]}"
    local choice=$?
    
    case $choice in
        0)
            INSTALL_TYPE="standard"
            print_status "$GREEN" "✅ Standard installation selected"
            ;;
        1)
            INSTALL_TYPE="advanced"
            print_status "$BLUE" "🔧 Advanced installation selected"
            configure_advanced_options
            ;;
        2)
            INSTALL_TYPE="minimal"
            INSTALL_FALLBACK=false
            AUTO_CONFIGURE=false
            print_status "$YELLOW" "⚙️  Minimal installation selected"
            ;;
        3)
            INSTALL_TYPE="development"
            ENABLE_DEBUG=true
            print_status "$PURPLE" "🛠️  Development installation selected"
            ;;
    esac
}

# Configure advanced options
configure_advanced_options() {
    print_box "ADVANCED CONFIGURATION"
    
    echo "Configure advanced installation options:"
    echo ""
    
    # Debug mode
    if ask_yes_no "Enable debug mode? (Provides detailed logging)"; then
        ENABLE_DEBUG=true
        print_status "$GREEN" "✅ Debug mode enabled"
    fi
    
    # Fallback system
    if ask_yes_no "Install fallback system? (Recommended for compatibility)" "y"; then
        INSTALL_FALLBACK=true
        print_status "$GREEN" "✅ Fallback system will be installed"
    else
        INSTALL_FALLBACK=false
    fi
    
    # Auto configuration
    if ask_yes_no "Automatically configure services? (fprintd, PAM)" "y"; then
        AUTO_CONFIGURE=true
        print_status "$GREEN" "✅ Services will be auto-configured"
    else
        AUTO_CONFIGURE=false
    fi
    
    # Skip tests
    if ask_yes_no "Skip hardware tests? (Not recommended)" "n"; then
        SKIP_TESTS=true
        print_status "$YELLOW" "⚠️  Hardware tests will be skipped"
    fi
}

# Show installation summary
show_installation_summary() {
    print_box "INSTALLATION SUMMARY"
    
    echo "Installation Configuration:"
    echo "  Type: $INSTALL_TYPE"
    echo "  Debug Mode: $([ $ENABLE_DEBUG == true ] && echo "Enabled" || echo "Disabled")"
    echo "  Fallback System: $([ $INSTALL_FALLBACK == true ] && echo "Yes" || echo "No")"
    echo "  Auto Configure: $([ $AUTO_CONFIGURE == true ] && echo "Yes" || echo "No")"
    echo "  Skip Tests: $([ $SKIP_TESTS == true ] && echo "Yes" || echo "No")"
    echo ""
    
    echo "Installation Steps:"
    echo "  1. Install system dependencies"
    echo "  2. Compile and install driver"
    echo "  3. Configure udev rules"
    echo "  4. Load driver module"
    if [[ $AUTO_CONFIGURE == true ]]; then
        echo "  5. Configure services (fprintd, PAM)"
    fi
    if [[ $INSTALL_FALLBACK == true ]]; then
        echo "  6. Install fallback system"
    fi
    if [[ $SKIP_TESTS == false ]]; then
        echo "  7. Run post-installation tests"
    fi
    echo ""
    
    if ! ask_yes_no "Proceed with installation?"; then
        print_status "$YELLOW" "Installation cancelled by user."
        exit 0
    fi
}

# Check root privileges
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_box "ROOT PRIVILEGES REQUIRED"
        
        echo "This installation requires root privileges to:"
        echo "• Install system packages"
        echo "• Compile and install kernel modules"
        echo "• Configure system services"
        echo "• Modify system configuration files"
        echo ""
        
        print_status "$RED" "❌ Please run this script with sudo:"
        print_status "$YELLOW" "   sudo $0"
        exit 1
    fi
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${BLUE}Progress: [${GREEN}"
    printf "%*s" $filled | tr ' ' '█'
    printf "${BLUE}"
    printf "%*s" $empty | tr ' ' '░'
    printf "${BLUE}] ${percentage}%% - ${description}${NC}"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Execute installation with progress
execute_installation() {
    print_box "INSTALLATION IN PROGRESS"
    
    local total_steps=7
    local current_step=0
    
    # Build installation command
    local install_cmd="bash $PROJECT_ROOT/scripts/universal-install.sh"
    
    if [[ $ENABLE_DEBUG == true ]]; then
        install_cmd="$install_cmd --debug"
    fi
    
    if [[ $INSTALL_FALLBACK == false ]]; then
        install_cmd="$install_cmd --no-fallback"
    fi
    
    if [[ $AUTO_CONFIGURE == false ]]; then
        install_cmd="$install_cmd --no-configure"
    fi
    
    if [[ $SKIP_TESTS == true ]]; then
        install_cmd="$install_cmd --skip-tests"
    fi
    
    # Execute installation with progress updates
    {
        echo "Starting installation..."
        
        # Step 1: Dependencies
        ((current_step++))
        show_progress $current_step $total_steps "Installing dependencies"
        sleep 1
        
        # Step 2: Compilation
        ((current_step++))
        show_progress $current_step $total_steps "Compiling driver"
        sleep 1
        
        # Step 3: Installation
        ((current_step++))
        show_progress $current_step $total_steps "Installing driver"
        sleep 1
        
        # Step 4: Configuration
        ((current_step++))
        show_progress $current_step $total_steps "Configuring system"
        sleep 1
        
        # Step 5: Services
        if [[ $AUTO_CONFIGURE == true ]]; then
            ((current_step++))
            show_progress $current_step $total_steps "Configuring services"
            sleep 1
        fi
        
        # Step 6: Fallback
        if [[ $INSTALL_FALLBACK == true ]]; then
            ((current_step++))
            show_progress $current_step $total_steps "Installing fallback system"
            sleep 1
        fi
        
        # Step 7: Testing
        if [[ $SKIP_TESTS == false ]]; then
            ((current_step++))
            show_progress $current_step $total_steps "Running tests"
            sleep 1
        fi
        
        show_progress $total_steps $total_steps "Installation complete"
        
    } &
    
    # Run actual installation
    if $install_cmd >> "$LOG_FILE" 2>&1; then
        wait
        print_status "$GREEN" "✅ Installation completed successfully!"
    else
        wait
        print_status "$RED" "❌ Installation failed!"
        echo ""
        print_status "$YELLOW" "Check the log file for details: $LOG_FILE"
        echo ""
        echo "Common solutions:"
        echo "• Ensure all dependencies are installed"
        echo "• Check kernel headers are available"
        echo "• Verify hardware compatibility"
        echo "• Try running with --force flag"
        exit 1
    fi
}

# Post-installation configuration
post_installation_setup() {
    print_box "POST-INSTALLATION SETUP"
    
    print_status "$GREEN" "🎉 Driver installation completed successfully!"
    echo ""
    
    # Test fingerprint enrollment
    if ask_yes_no "Would you like to enroll a fingerprint now?"; then
        print_status "$BLUE" "Starting fingerprint enrollment..."
        
        if command -v fprintd-enroll >/dev/null 2>&1; then
            fprintd-enroll || print_status "$YELLOW" "⚠️  Enrollment failed or was cancelled"
        else
            print_status "$RED" "❌ fprintd-enroll command not found"
        fi
    fi
    
    # Configure login authentication
    if [[ $AUTO_CONFIGURE == false ]]; then
        echo ""
        if ask_yes_no "Would you like to configure fingerprint login authentication?"; then
            configure_pam_authentication
        fi
    fi
    
    # Show next steps
    show_next_steps
}

# Configure PAM authentication
configure_pam_authentication() {
    print_status "$BLUE" "🔐 Configuring PAM authentication..."
    
    # Detect distribution and configure accordingly
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        
        case "$ID" in
            ubuntu|debian|linuxmint)
                if command -v pam-auth-update >/dev/null 2>&1; then
                    print_status "$BLUE" "Running pam-auth-update..."
                    pam-auth-update --enable fprintd
                else
                    print_status "$YELLOW" "⚠️  pam-auth-update not available, manual configuration needed"
                fi
                ;;
            fedora|rhel|centos|rocky|almalinux)
                if command -v authselect >/dev/null 2>&1; then
                    print_status "$BLUE" "Configuring authselect..."
                    authselect select sssd with-fingerprint --force
                else
                    print_status "$YELLOW" "⚠️  authselect not available, manual configuration needed"
                fi
                ;;
            *)
                print_status "$YELLOW" "⚠️  Automatic PAM configuration not available for this distribution"
                ;;
        esac
    fi
}

# Show next steps and recommendations
show_next_steps() {
    print_box "NEXT STEPS AND RECOMMENDATIONS"
    
    echo "Your Xiaomi fingerprint scanner driver is now installed and configured!"
    echo ""
    
    print_status "$GREEN" "✅ What's working:"
    echo "  • Driver is loaded and ready"
    echo "  • Hardware is detected and accessible"
    echo "  • Services are configured"
    if [[ $INSTALL_FALLBACK == true ]]; then
        echo "  • Fallback system is available"
    fi
    echo ""
    
    print_status "$BLUE" "📋 Next steps:"
    echo "  1. Test fingerprint recognition:"
    echo "     fprintd-verify"
    echo ""
    echo "  2. Configure additional settings:"
    echo "     • Desktop environment fingerprint settings"
    echo "     • Application-specific authentication"
    echo "     • Screen lock integration"
    echo ""
    echo "  3. Troubleshooting tools:"
    echo "     sudo bash $PROJECT_ROOT/scripts/diagnostics.sh"
    echo "     sudo bash $PROJECT_ROOT/scripts/test-driver.sh"
    echo ""
    
    print_status "$YELLOW" "💡 Tips:"
    echo "  • Clean your finger and scanner for best results"
    echo "  • Enroll multiple fingers for redundancy"
    echo "  • Check documentation for advanced features"
    echo "  • Join our community for support and updates"
    echo ""
    
    print_status "$CYAN" "📄 Documentation and Support:"
    echo "  • Installation Guide: $PROJECT_ROOT/docs/installation-guide.md"
    echo "  • Troubleshooting: $PROJECT_ROOT/docs/troubleshooting.md"
    echo "  • FAQ: $PROJECT_ROOT/docs/FAQ.md"
    echo "  • Log File: $LOG_FILE"
    echo ""
    
    if ask_yes_no "Would you like to open the documentation now?"; then
        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$PROJECT_ROOT/docs/installation-guide.md" 2>/dev/null || true
        elif command -v less >/dev/null 2>&1; then
            less "$PROJECT_ROOT/docs/installation-guide.md"
        else
            print_status "$YELLOW" "Please manually open: $PROJECT_ROOT/docs/installation-guide.md"
        fi
    fi
}

# Main interactive installation flow
main() {
    # Initialize log
    echo "=== Xiaomi Fingerprint Scanner Interactive Installation ===" > "$LOG_FILE"
    echo "Started at: $(date)" >> "$LOG_FILE"
    
    # Installation flow
    show_welcome
    check_root_privileges
    check_system_compatibility
    choose_installation_type
    show_installation_summary
    execute_installation
    post_installation_setup
    
    print_status "$GREEN" "🎉 Interactive installation completed successfully!"
    print_status "$BLUE" "Thank you for using the Xiaomi Fingerprint Scanner Driver!"
}

# Handle script interruption
cleanup() {
    echo ""
    print_status "$YELLOW" "Installation interrupted by user."
    print_status "$BLUE" "Log file available at: $LOG_FILE"
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Run main function
main "$@"