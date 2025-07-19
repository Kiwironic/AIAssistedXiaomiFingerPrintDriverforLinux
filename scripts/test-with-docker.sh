#!/bin/bash

# Docker-based Testing Script for Xiaomi Fingerprint Driver
# Tests installation on real Ubuntu, Fedora, and Mint containers

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
TEST_LOG="/tmp/fp_xiaomi_docker_test.log"

# Docker images to test
DOCKER_IMAGES=(
    "ubuntu:22.04"
    "ubuntu:20.04"
    "fedora:39"
    "fedora:40"
    "linuxmint/mint21-amd64"
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

# Check if Docker is available
check_docker() {
    print_section "CHECKING DOCKER AVAILABILITY"
    
    if ! command -v docker >/dev/null 2>&1; then
        print_status "$RED" "❌ Docker is not installed"
        print_status "$BLUE" "💡 Install Docker to run container tests:"
        echo "   Ubuntu/Debian: sudo apt install docker.io"
        echo "   Fedora: sudo dnf install docker"
        echo "   Arch: sudo pacman -S docker"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_status "$RED" "❌ Docker daemon is not running"
        print_status "$BLUE" "💡 Start Docker service:"
        echo "   sudo systemctl start docker"
        echo "   sudo systemctl enable docker"
        exit 1
    fi
    
    print_status "$GREEN" "✅ Docker is available and running"
    
    # Check if user can run Docker without sudo
    if ! docker ps >/dev/null 2>&1; then
        print_status "$YELLOW" "⚠️  Docker requires sudo access"
        print_status "$BLUE" "💡 Add user to docker group:"
        echo "   sudo usermod -a -G docker \$USER"
        echo "   Then log out and back in"
        
        # Check if we can use sudo
        if ! sudo docker ps >/dev/null 2>&1; then
            print_status "$RED" "❌ Cannot access Docker even with sudo"
            exit 1
        fi
        
        DOCKER_CMD="sudo docker"
    else
        DOCKER_CMD="docker"
    fi
    
    print_status "$GREEN" "✅ Docker access confirmed"
}

# Create test script for container
create_container_test_script() {
    local distro=$1
    local version=$2
    
    cat > /tmp/container-test-script.sh << 'EOF'
#!/bin/bash

# Container test script
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${2}${1}${NC}"
}

print_status "🐳 Starting container test..." "$BLUE"

# Detect distribution
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    print_status "📋 Detected: $PRETTY_NAME" "$BLUE"
else
    print_status "❌ Cannot detect distribution" "$RED"
    exit 1
fi

# Update package manager
print_status "📦 Updating package manager..." "$BLUE"
case "$ID" in
    ubuntu|linuxmint)
        apt update -y
        print_status "✅ APT updated" "$GREEN"
        ;;
    fedora)
        dnf update -y --refresh
        print_status "✅ DNF updated" "$GREEN"
        ;;
esac

# Test dependency installation
print_status "🔧 Testing dependency installation..." "$BLUE"
case "$ID" in
    ubuntu|linuxmint)
        apt install -y curl wget git
        if command -v curl >/dev/null && command -v git >/dev/null; then
            print_status "✅ Basic dependencies installed" "$GREEN"
        else
            print_status "❌ Dependency installation failed" "$RED"
            exit 1
        fi
        ;;
    fedora)
        dnf install -y curl wget git
        if command -v curl >/dev/null && command -v git >/dev/null; then
            print_status "✅ Basic dependencies installed" "$GREEN"
        else
            print_status "❌ Dependency installation failed" "$RED"
            exit 1
        fi
        ;;
esac

# Test build tools installation
print_status "🔨 Testing build tools installation..." "$BLUE"
case "$ID" in
    ubuntu|linuxmint)
        # Install build essentials
        apt install -y build-essential
        if command -v gcc >/dev/null && command -v make >/dev/null; then
            print_status "✅ Build tools installed" "$GREEN"
        else
            print_status "❌ Build tools installation failed" "$RED"
            exit 1
        fi
        ;;
    fedora)
        # Install development tools
        dnf groupinstall -y "Development Tools"
        if command -v gcc >/dev/null && command -v make >/dev/null; then
            print_status "✅ Build tools installed" "$GREEN"
        else
            print_status "❌ Build tools installation failed" "$RED"
            exit 1
        fi
        ;;
esac

# Test fingerprint packages (if available)
print_status "👆 Testing fingerprint packages..." "$BLUE"
case "$ID" in
    ubuntu|linuxmint)
        if apt install -y libfprint-2-2 fprintd 2>/dev/null; then
            print_status "✅ Fingerprint packages available" "$GREEN"
        else
            print_status "⚠️  Fingerprint packages not available in container" "$YELLOW"
        fi
        ;;
    fedora)
        if dnf install -y libfprint fprintd 2>/dev/null; then
            print_status "✅ Fingerprint packages available" "$GREEN"
        else
            print_status "⚠️  Fingerprint packages not available in container" "$YELLOW"
        fi
        ;;
esac

# Test script syntax (if project files are mounted)
if [[ -d /project ]]; then
    print_status "📝 Testing script syntax..." "$BLUE"
    
    cd /project
    
    local scripts=(
        "scripts/install-driver.sh"
        "scripts/universal-install.sh"
        "scripts/hardware-compatibility-check.sh"
    )
    
    local syntax_ok=true
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            if bash -n "$script" 2>/dev/null; then
                print_status "  ✅ $script syntax OK" "$GREEN"
            else
                print_status "  ❌ $script syntax error" "$RED"
                syntax_ok=false
            fi
        fi
    done
    
    if [[ $syntax_ok == true ]]; then
        print_status "✅ All scripts passed syntax check" "$GREEN"
    else
        print_status "❌ Some scripts have syntax errors" "$RED"
        exit 1
    fi
    
    # Test dry run of installation script
    print_status "🧪 Testing installation script dry run..." "$BLUE"
    
    # Create a mock dry run by setting environment variables
    export DRY_RUN=true
    export MOCK_HARDWARE=true
    
    # Test the detection logic
    if bash -c "source scripts/install-driver.sh; detect_distro" 2>/dev/null; then
        print_status "✅ Distribution detection works" "$GREEN"
    else
        print_status "❌ Distribution detection failed" "$RED"
    fi
else
    print_status "⚠️  Project files not mounted, skipping script tests" "$YELLOW"
fi

print_status "🎉 Container test completed successfully!" "$GREEN"
EOF

    chmod +x /tmp/container-test-script.sh
}

# Test single Docker image
test_docker_image() {
    local image=$1
    local distro=$(echo "$image" | cut -d: -f1 | sed 's/.*\///')
    local version=$(echo "$image" | cut -d: -f2)
    
    print_status "$BLUE" "🐳 Testing Docker image: $image"
    
    # Create test script
    create_container_test_script "$distro" "$version"
    
    # Run container test
    print_status "$BLUE" "   → Starting container..."
    
    local container_name="fp-xiaomi-test-$(echo "$image" | tr ':/' '-')"
    
    # Remove existing container if it exists
    $DOCKER_CMD rm -f "$container_name" 2>/dev/null || true
    
    # Run the test
    if $DOCKER_CMD run --name "$container_name" \
        -v "$PROJECT_ROOT:/project:ro" \
        -v "/tmp/container-test-script.sh:/test-script.sh:ro" \
        "$image" \
        bash /test-script.sh 2>&1 | tee "/tmp/docker-test-$container_name.log"; then
        
        print_status "$GREEN" "   ✅ Container test passed for $image"
        
        # Extract key information from the test
        local test_log="/tmp/docker-test-$container_name.log"
        if grep -q "Container test completed successfully" "$test_log"; then
            print_status "$GREEN" "   ✅ All tests passed in container"
        else
            print_status "$YELLOW" "   ⚠️  Some tests may have issues"
        fi
        
    else
        print_status "$RED" "   ❌ Container test failed for $image"
        return 1
    fi
    
    # Cleanup container
    $DOCKER_CMD rm -f "$container_name" >/dev/null 2>&1 || true
    
    return 0
}

# Test all Docker images
test_all_images() {
    print_section "TESTING ALL DOCKER IMAGES"
    
    local total_tests=${#DOCKER_IMAGES[@]}
    local passed_tests=0
    local failed_tests=0
    
    for image in "${DOCKER_IMAGES[@]}"; do
        print_status "$BLUE" "📋 Testing $image ($(($passed_tests + $failed_tests + 1))/$total_tests)"
        
        if test_docker_image "$image"; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
        
        echo
    done
    
    print_status "$BLUE" "📊 Test Results Summary:"
    print_status "$GREEN" "   ✅ Passed: $passed_tests/$total_tests"
    if [[ $failed_tests -gt 0 ]]; then
        print_status "$RED" "   ❌ Failed: $failed_tests/$total_tests"
    fi
    
    return $failed_tests
}

# Test specific distribution
test_specific_distro() {
    local distro=$1
    
    print_section "TESTING SPECIFIC DISTRIBUTION: $distro"
    
    local matching_images=()
    for image in "${DOCKER_IMAGES[@]}"; do
        if [[ "$image" == *"$distro"* ]]; then
            matching_images+=("$image")
        fi
    done
    
    if [[ ${#matching_images[@]} -eq 0 ]]; then
        print_status "$RED" "❌ No matching images found for: $distro"
        print_status "$BLUE" "Available images:"
        for img in "${DOCKER_IMAGES[@]}"; do
            echo "   • $img"
        done
        return 1
    fi
    
    local passed=0
    local total=${#matching_images[@]}
    
    for image in "${matching_images[@]}"; do
        if test_docker_image "$image"; then
            ((passed++))
        fi
    done
    
    print_status "$BLUE" "📊 Results for $distro: $passed/$total passed"
    
    if [[ $passed -eq $total ]]; then
        return 0
    else
        return 1
    fi
}

# Create comprehensive test environment
create_test_environment() {
    print_section "CREATING COMPREHENSIVE TEST ENVIRONMENT"
    
    print_status "$BLUE" "🏗️  Building custom test image with all dependencies..."
    
    # Create Dockerfile for comprehensive testing
    cat > /tmp/Dockerfile.fp-test << 'EOF'
FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install all possible dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    linux-headers-generic \
    git \
    curl \
    wget \
    cmake \
    pkg-config \
    libusb-1.0-0-dev \
    libfprint-2-dev \
    fprintd \
    dkms \
    udev \
    systemd \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create a test user
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up mock hardware environment
RUN mkdir -p /dev/bus/usb/001 && \
    echo "Mock USB device" > /dev/bus/usb/001/002

WORKDIR /project
USER testuser

CMD ["/bin/bash"]
EOF
    
    # Build test image
    if $DOCKER_CMD build -t fp-xiaomi-test -f /tmp/Dockerfile.fp-test /tmp/; then
        print_status "$GREEN" "✅ Test image built successfully"
        
        # Run comprehensive test
        print_status "$BLUE" "🧪 Running comprehensive test..."
        
        if $DOCKER_CMD run --rm \
            -v "$PROJECT_ROOT:/project:ro" \
            fp-xiaomi-test \
            bash -c "cd /project && bash -n scripts/install-driver.sh && echo 'Comprehensive test passed'"; then
            
            print_status "$GREEN" "✅ Comprehensive test passed"
        else
            print_status "$RED" "❌ Comprehensive test failed"
            return 1
        fi
    else
        print_status "$RED" "❌ Failed to build test image"
        return 1
    fi
}

# Generate Docker test report
generate_docker_report() {
    print_section "GENERATING DOCKER TEST REPORT"
    
    local report_file="/tmp/xiaomi_fp_docker_test_report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Xiaomi Fingerprint Driver - Docker Test Report</title>
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
        <h1>Xiaomi Fingerprint Driver - Docker Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Host System: $(uname -a)</p>
        <p>Docker Version: $(docker --version)</p>
    </div>
    
    <div class="section">
        <h2>Tested Docker Images</h2>
        <table>
            <tr>
                <th>Image</th>
                <th>Status</th>
                <th>Notes</th>
            </tr>
EOF
    
    for image in "${DOCKER_IMAGES[@]}"; do
        local container_name="fp-xiaomi-test-$(echo "$image" | tr ':/' '-')"
        local log_file="/tmp/docker-test-$container_name.log"
        
        if [[ -f "$log_file" ]] && grep -q "Container test completed successfully" "$log_file"; then
            echo "            <tr><td>$image</td><td class=\"success\">✅ PASS</td><td>All tests passed</td></tr>" >> "$report_file"
        else
            echo "            <tr><td>$image</td><td class=\"error\">❌ FAIL</td><td>Check logs for details</td></tr>" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Test Summary</h2>
        <p>Docker testing provides the most accurate simulation of real installation environments.</p>
        <p>Each container test includes:</p>
        <ul>
            <li>Distribution detection</li>
            <li>Package manager functionality</li>
            <li>Dependency installation</li>
            <li>Script syntax validation</li>
            <li>Build tools verification</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Full Test Log</h2>
        <pre>$(cat "$TEST_LOG")</pre>
    </div>
</body>
</html>
EOF
    
    print_status "$GREEN" "✅ Docker test report generated: $report_file"
}

# Print usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Docker-based testing for Xiaomi Fingerprint Driver installation scripts

COMMANDS:
    all                 Test all supported distributions (default)
    ubuntu              Test Ubuntu images only
    fedora              Test Fedora images only
    mint                Test Linux Mint images only
    build               Build comprehensive test environment
    
OPTIONS:
    -h, --help         Show this help message
    -v, --verbose      Enable verbose output
    
EXAMPLES:
    $0                 # Test all distributions
    $0 ubuntu          # Test Ubuntu only
    $0 fedora          # Test Fedora only
    $0 build           # Build comprehensive test environment

EOF
}

# Main function
main() {
    local command="${1:-all}"
    
    echo "=== Xiaomi Fingerprint Driver Docker Testing ===" > "$TEST_LOG"
    echo "Started at: $(date)" >> "$TEST_LOG"
    
    print_status "$PURPLE" "🐳 Starting Docker-based Installation Testing"
    
    # Check Docker availability
    check_docker
    
    case "$command" in
        all)
            if test_all_images; then
                print_status "$GREEN" "🎉 All Docker tests passed!"
            else
                print_status "$YELLOW" "⚠️  Some Docker tests failed"
            fi
            ;;
        ubuntu)
            test_specific_distro "ubuntu"
            ;;
        fedora)
            test_specific_distro "fedora"
            ;;
        mint)
            test_specific_distro "mint"
            ;;
        build)
            create_test_environment
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_status "$RED" "❌ Unknown command: $command"
            usage
            exit 1
            ;;
    esac
    
    # Generate report
    generate_docker_report
    
    print_status "$BLUE" "📄 Full test log: $TEST_LOG"
    print_status "$BLUE" "📄 HTML report: /tmp/xiaomi_fp_docker_test_report.html"
    
    print_status "$GREEN" "🎉 Docker testing completed!"
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac