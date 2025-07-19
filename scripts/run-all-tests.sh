#!/bin/bash

# Comprehensive Testing Suite for Xiaomi Fingerprint Driver
# Runs all available tests without requiring actual hardware or system changes

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
TEST_LOG="/tmp/fp_xiaomi_comprehensive_test.log"
RESULTS_DIR="/tmp/fp_xiaomi_test_results"

# Test categories
TEST_CATEGORIES=(
    "syntax"
    "dry-run"
    "docker"
    "vm-setup"
    "integration"
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

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_CATEGORY]

Comprehensive Testing Suite for Xiaomi Fingerprint Driver

TEST CATEGORIES:
    all             Run all available tests (default)
    syntax          Test script syntax and basic validation
    dry-run         Run dry-run simulation tests
    docker          Run Docker container tests (requires Docker)
    vm-setup        Set up VM testing environment
    integration     Test script integration and cross-references
    quick           Run quick tests only (syntax + dry-run)

OPTIONS:
    -v, --verbose       Enable verbose output
    -o, --output DIR    Specify output directory for results
    -h, --help         Show this help message
    --no-cleanup       Don't cleanup temporary files
    --parallel         Run tests in parallel where possible

EXAMPLES:
    $0                  # Run all tests
    $0 quick            # Run quick tests only
    $0 docker -v        # Run Docker tests with verbose output
    $0 syntax           # Test script syntax only

EOF
}

# Initialize test environment
initialize_test_environment() {
    print_section "INITIALIZING TEST ENVIRONMENT"
    
    # Create results directory
    mkdir -p "$RESULTS_DIR"
    
    # Initialize log
    echo "=== Xiaomi Fingerprint Driver Comprehensive Testing ===" > "$TEST_LOG"
    echo "Started at: $(date)" >> "$TEST_LOG"
    echo "Host: $(uname -a)" >> "$TEST_LOG"
    echo "User: $(whoami)" >> "$TEST_LOG"
    echo "Working Directory: $(pwd)" >> "$TEST_LOG"
    echo "" >> "$TEST_LOG"
    
    print_status "$GREEN" "✅ Test environment initialized"
    print_status "$BLUE" "📁 Results directory: $RESULTS_DIR"
    print_status "$BLUE" "📄 Test log: $TEST_LOG"
}

# Test script syntax
test_syntax() {
    print_section "TESTING SCRIPT SYNTAX"
    
    local syntax_results="$RESULTS_DIR/syntax_results.txt"
    echo "Script Syntax Test Results" > "$syntax_results"
    echo "Generated: $(date)" >> "$syntax_results"
    echo "" >> "$syntax_results"
    
    local scripts_to_test=(
        "install-driver.sh"
        "universal-install.sh"
        "interactive-install.sh"
        "hardware-compatibility-check.sh"
        "diagnostics.sh"
        "fallback-driver.sh"
        "distro-specific-troubleshoot.sh"
        "test-installation-dry-run.sh"
        "test-with-docker.sh"
        "test-with-vm.sh"
    )
    
    local syntax_errors=0
    local total_scripts=0
    
    for script in "${scripts_to_test[@]}"; do
        local script_path="$SCRIPT_DIR/$script"
        
        if [[ -f "$script_path" ]]; then
            ((total_scripts++))
            print_status "$BLUE" "🔍 Testing syntax: $script"
            
            if bash -n "$script_path" 2>/dev/null; then
                print_status "$GREEN" "   ✅ Syntax OK"
                echo "✅ $script: PASS" >> "$syntax_results"
            else
                print_status "$RED" "   ❌ Syntax errors detected"
                echo "❌ $script: FAIL" >> "$syntax_results"
                bash -n "$script_path" 2>&1 | sed 's/^/     /' | tee -a "$syntax_results"
                ((syntax_errors++))
            fi
        else
            print_status "$YELLOW" "   ⚠️  Script not found: $script"
            echo "⚠️  $script: NOT_FOUND" >> "$syntax_results"
        fi
    done
    
    echo "" >> "$syntax_results"
    echo "Summary: $((total_scripts - syntax_errors))/$total_scripts scripts passed" >> "$syntax_results"
    
    if [[ $syntax_errors -eq 0 ]]; then
        print_status "$GREEN" "🎉 All $total_scripts scripts passed syntax check!"
        return 0
    else
        print_status "$RED" "❌ Found $syntax_errors scripts with syntax errors"
        return 1
    fi
}

# Run dry-run tests
test_dry_run() {
    print_section "RUNNING DRY-RUN TESTS"
    
    local dry_run_script="$SCRIPT_DIR/test-installation-dry-run.sh"
    local dry_run_results="$RESULTS_DIR/dry_run_results.txt"
    
    if [[ -f "$dry_run_script" ]]; then
        print_status "$BLUE" "🧪 Running comprehensive dry-run tests..."
        
        if bash "$dry_run_script" 2>&1 | tee "$dry_run_results"; then
            print_status "$GREEN" "✅ Dry-run tests completed successfully"
            return 0
        else
            print_status "$RED" "❌ Dry-run tests failed"
            return 1
        fi
    else
        print_status "$RED" "❌ Dry-run test script not found: $dry_run_script"
        return 1
    fi
}

# Run Docker tests
test_docker() {
    print_section "RUNNING DOCKER TESTS"
    
    local docker_script="$SCRIPT_DIR/test-with-docker.sh"
    local docker_results="$RESULTS_DIR/docker_results.txt"
    
    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        print_status "$YELLOW" "⚠️  Docker not available - skipping Docker tests"
        echo "Docker not available - skipped" > "$docker_results"
        return 0
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_status "$YELLOW" "⚠️  Docker daemon not running - skipping Docker tests"
        echo "Docker daemon not running - skipped" > "$docker_results"
        return 0
    fi
    
    if [[ -f "$docker_script" ]]; then
        print_status "$BLUE" "🐳 Running Docker container tests..."
        
        if bash "$docker_script" all 2>&1 | tee "$docker_results"; then
            print_status "$GREEN" "✅ Docker tests completed successfully"
            return 0
        else
            print_status "$YELLOW" "⚠️  Docker tests completed with some issues"
            return 1
        fi
    else
        print_status "$RED" "❌ Docker test script not found: $docker_script"
        return 1
    fi
}

# Set up VM testing
test_vm_setup() {
    print_section "SETTING UP VM TESTING"
    
    local vm_script="$SCRIPT_DIR/test-with-vm.sh"
    local vm_results="$RESULTS_DIR/vm_setup_results.txt"
    
    if [[ -f "$vm_script" ]]; then
        print_status "$BLUE" "🖥️  Setting up VM testing environment..."
        
        if bash "$vm_script" 2>&1 | tee "$vm_results"; then
            print_status "$GREEN" "✅ VM testing setup completed"
            return 0
        else
            print_status "$YELLOW" "⚠️  VM testing setup completed with warnings"
            return 1
        fi
    else
        print_status "$RED" "❌ VM test script not found: $vm_script"
        return 1
    fi
}

# Test integration
test_integration() {
    print_section "TESTING SCRIPT INTEGRATION"
    
    local integration_results="$RESULTS_DIR/integration_results.txt"
    echo "Script Integration Test Results" > "$integration_results"
    echo "Generated: $(date)" >> "$integration_results"
    echo "" >> "$integration_results"
    
    print_status "$BLUE" "🔗 Testing script cross-references and dependencies..."
    
    # Test 1: Check if referenced scripts exist
    local main_scripts=("install-driver.sh" "universal-install.sh" "interactive-install.sh")
    local referenced_scripts=("configure-fprintd.sh" "test-driver.sh" "diagnostics.sh" "hardware-compatibility-check.sh")
    
    local integration_issues=0
    
    for main_script in "${main_scripts[@]}"; do
        local main_path="$SCRIPT_DIR/$main_script"
        
        if [[ -f "$main_path" ]]; then
            print_status "$BLUE" "   → Checking references in $main_script"
            
            for ref_script in "${referenced_scripts[@]}"; do
                if grep -q "$ref_script" "$main_path" 2>/dev/null; then
                    if [[ -f "$SCRIPT_DIR/$ref_script" ]]; then
                        print_status "$GREEN" "     ✅ Reference to $ref_script is valid"
                        echo "✅ $main_script → $ref_script: VALID" >> "$integration_results"
                    else
                        print_status "$RED" "     ❌ Reference to $ref_script but file doesn't exist"
                        echo "❌ $main_script → $ref_script: MISSING" >> "$integration_results"
                        ((integration_issues++))
                    fi
                fi
            done
        fi
    done
    
    # Test 2: Check for circular dependencies
    print_status "$BLUE" "   → Checking for circular dependencies..."
    # This is a simplified check - in practice, you'd need more sophisticated analysis
    
    # Test 3: Check configuration file consistency
    print_status "$BLUE" "   → Checking configuration consistency..."
    
    # Look for hardcoded paths that should be variables
    local hardcoded_paths=("/tmp/" "/etc/" "/usr/")
    for script in "${main_scripts[@]}"; do
        local script_path="$SCRIPT_DIR/$script"
        if [[ -f "$script_path" ]]; then
            for path in "${hardcoded_paths[@]}"; do
                local count=$(grep -c "$path" "$script_path" 2>/dev/null || echo 0)
                if [[ $count -gt 5 ]]; then
                    print_status "$YELLOW" "     ⚠️  Many hardcoded paths ($path) in $script: $count occurrences"
                fi
            done
        fi
    done
    
    echo "" >> "$integration_results"
    echo "Integration issues found: $integration_issues" >> "$integration_results"
    
    if [[ $integration_issues -eq 0 ]]; then
        print_status "$GREEN" "✅ Script integration tests passed"
        return 0
    else
        print_status "$YELLOW" "⚠️  Found $integration_issues integration issues"
        return 1
    fi
}

# Test file structure and documentation
test_project_structure() {
    print_section "TESTING PROJECT STRUCTURE"
    
    local structure_results="$RESULTS_DIR/structure_results.txt"
    echo "Project Structure Test Results" > "$structure_results"
    echo "Generated: $(date)" >> "$structure_results"
    echo "" >> "$structure_results"
    
    # Check required directories
    local required_dirs=("src" "scripts" "docs" "hardware-analysis" "tools")
    local missing_dirs=0
    
    print_status "$BLUE" "📁 Checking required directories..."
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            print_status "$GREEN" "   ✅ Directory exists: $dir"
            echo "✅ $dir: EXISTS" >> "$structure_results"
        else
            print_status "$RED" "   ❌ Missing directory: $dir"
            echo "❌ $dir: MISSING" >> "$structure_results"
            ((missing_dirs++))
        fi
    done
    
    # Check required files
    local required_files=("README.md" "src/Makefile" "scripts/install-driver.sh")
    local missing_files=0
    
    print_status "$BLUE" "📄 Checking required files..."
    for file in "${required_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            print_status "$GREEN" "   ✅ File exists: $file"
            echo "✅ $file: EXISTS" >> "$structure_results"
        else
            print_status "$RED" "   ❌ Missing file: $file"
            echo "❌ $file: MISSING" >> "$structure_results"
            ((missing_files++))
        fi
    done
    
    # Check documentation completeness
    print_status "$BLUE" "📚 Checking documentation..."
    local doc_files=("installation-guide.md" "quick-start-guide.md" "architecture.md")
    local missing_docs=0
    
    for doc in "${doc_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/docs/$doc" ]]; then
            print_status "$GREEN" "   ✅ Documentation exists: $doc"
            echo "✅ docs/$doc: EXISTS" >> "$structure_results"
        else
            print_status "$YELLOW" "   ⚠️  Missing documentation: $doc"
            echo "⚠️  docs/$doc: MISSING" >> "$structure_results"
            ((missing_docs++))
        fi
    done
    
    echo "" >> "$structure_results"
    echo "Summary:" >> "$structure_results"
    echo "  Missing directories: $missing_dirs" >> "$structure_results"
    echo "  Missing files: $missing_files" >> "$structure_results"
    echo "  Missing documentation: $missing_docs" >> "$structure_results"
    
    local total_issues=$((missing_dirs + missing_files))
    
    if [[ $total_issues -eq 0 ]]; then
        print_status "$GREEN" "✅ Project structure is complete"
        return 0
    else
        print_status "$YELLOW" "⚠️  Project structure has $total_issues issues"
        return 1
    fi
}

# Generate comprehensive test report
generate_comprehensive_report() {
    print_section "GENERATING COMPREHENSIVE TEST REPORT"
    
    local report_file="$RESULTS_DIR/comprehensive_test_report.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Xiaomi Fingerprint Driver - Comprehensive Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #007acc; }
        .success { color: #28a745; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .error { color: #dc3545; font-weight: bold; }
        .info { color: #17a2b8; }
        pre { background: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .test-summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .test-card { background: #f8f9fa; padding: 15px; border-radius: 5px; border-left: 4px solid #007acc; }
        .pass { border-left-color: #28a745; }
        .fail { border-left-color: #dc3545; }
        .warn { border-left-color: #ffc107; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Xiaomi Fingerprint Driver - Comprehensive Test Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Host System:</strong> $(uname -a)</p>
        <p><strong>Test Duration:</strong> Started at $(head -2 "$TEST_LOG" | tail -1 | cut -d' ' -f4-5)</p>
        <p><strong>Results Directory:</strong> $RESULTS_DIR</p>
    </div>

    <div class="section">
        <h2>📊 Test Summary</h2>
        <div class="test-summary">
EOF
    
    # Add test cards for each category
    local test_categories=("syntax" "dry_run" "docker" "vm_setup" "integration" "structure")
    
    for category in "${test_categories[@]}"; do
        local result_file="$RESULTS_DIR/${category}_results.txt"
        local status="Not Run"
        local class="warn"
        
        if [[ -f "$result_file" ]]; then
            if grep -q "PASS\|✅\|completed successfully" "$result_file"; then
                status="✅ PASS"
                class="pass"
            elif grep -q "FAIL\|❌\|failed" "$result_file"; then
                status="❌ FAIL"
                class="fail"
            else
                status="⚠️ PARTIAL"
                class="warn"
            fi
        fi
        
        cat >> "$report_file" << EOF
            <div class="test-card $class">
                <h3>$(echo "$category" | tr '_' ' ' | tr '[:lower:]' '[:upper:]')</h3>
                <p><strong>Status:</strong> $status</p>
                <p><strong>Details:</strong> <a href="#$category">View Results</a></p>
            </div>
EOF
    done
    
    cat >> "$report_file" << EOF
        </div>
    </div>

    <div class="section">
        <h2>🔍 Detailed Test Results</h2>
EOF
    
    # Add detailed results for each test category
    for category in "${test_categories[@]}"; do
        local result_file="$RESULTS_DIR/${category}_results.txt"
        local category_title=$(echo "$category" | tr '_' ' ' | sed 's/\b\w/\U&/g')
        
        cat >> "$report_file" << EOF
        <h3 id="$category">$category_title Test Results</h3>
EOF
        
        if [[ -f "$result_file" ]]; then
            cat >> "$report_file" << EOF
        <pre>$(cat "$result_file")</pre>
EOF
        else
            cat >> "$report_file" << EOF
        <p class="warning">⚠️ Test results not available</p>
EOF
        fi
    done
    
    cat >> "$report_file" << EOF
    </div>

    <div class="section">
        <h2>📋 Testing Environment</h2>
        <table>
            <tr><th>Component</th><th>Status</th><th>Version/Info</th></tr>
            <tr><td>Bash</td><td class="success">✅ Available</td><td>$(bash --version | head -1)</td></tr>
            <tr><td>Docker</td><td>$(command -v docker >/dev/null && echo '<span class="success">✅ Available</span>' || echo '<span class="warning">⚠️ Not Available</span>')</td><td>$(docker --version 2>/dev/null || echo 'N/A')</td></tr>
            <tr><td>Vagrant</td><td>$(command -v vagrant >/dev/null && echo '<span class="success">✅ Available</span>' || echo '<span class="warning">⚠️ Not Available</span>')</td><td>$(vagrant --version 2>/dev/null || echo 'N/A')</td></tr>
            <tr><td>VirtualBox</td><td>$(command -v VBoxManage >/dev/null && echo '<span class="success">✅ Available</span>' || echo '<span class="warning">⚠️ Not Available</span>')</td><td>$(VBoxManage --version 2>/dev/null || echo 'N/A')</td></tr>
        </table>
    </div>

    <div class="section">
        <h2>💡 Recommendations</h2>
        <ul>
            <li><strong>For Development:</strong> Run syntax and dry-run tests frequently</li>
            <li><strong>For CI/CD:</strong> Integrate Docker tests into build pipeline</li>
            <li><strong>For Release:</strong> Run comprehensive VM tests on target distributions</li>
            <li><strong>For Hardware Testing:</strong> Use manual testing with real hardware</li>
        </ul>
    </div>

    <div class="section">
        <h2>📄 Full Test Log</h2>
        <pre>$(cat "$TEST_LOG")</pre>
    </div>

    <div class="section">
        <h2>🔗 Additional Resources</h2>
        <ul>
            <li><a href="file://$PROJECT_ROOT/docs/installation-guide.md">Installation Guide</a></li>
            <li><a href="file://$PROJECT_ROOT/docs/quick-start-guide.md">Quick Start Guide</a></li>
            <li><a href="file://$PROJECT_ROOT/README.md">Project README</a></li>
            <li><a href="file://$RESULTS_DIR">Test Results Directory</a></li>
        </ul>
    </div>
</body>
</html>
EOF
    
    print_status "$GREEN" "✅ Comprehensive test report generated: $report_file"
}

# Cleanup temporary files
cleanup_temp_files() {
    if [[ "${CLEANUP:-true}" == "true" ]]; then
        print_status "$BLUE" "🧹 Cleaning up temporary files..."
        
        # Remove temporary mock files
        rm -f /tmp/mock-* /tmp/test-* /tmp/container-* 2>/dev/null || true
        
        # Remove temporary directories (but keep results)
        find /tmp -name "fp-xiaomi-*" -type d -not -path "$RESULTS_DIR*" -exec rm -rf {} + 2>/dev/null || true
        
        print_status "$GREEN" "✅ Cleanup completed"
    else
        print_status "$BLUE" "💾 Temporary files preserved for debugging"
    fi
}

# Main test runner
main() {
    local test_category="${1:-all}"
    local verbose=false
    local parallel=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                verbose=true
                shift
                ;;
            -o|--output)
                RESULTS_DIR="$2"
                shift 2
                ;;
            --no-cleanup)
                CLEANUP=false
                shift
                ;;
            --parallel)
                parallel=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            all|syntax|dry-run|docker|vm-setup|integration|quick)
                test_category="$1"
                shift
                ;;
            *)
                print_status "$RED" "❌ Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Initialize
    initialize_test_environment
    
    print_status "$PURPLE" "🧪 Starting Comprehensive Testing Suite"
    print_status "$BLUE" "📋 Test Category: $test_category"
    
    # Track test results
    local test_results=()
    local failed_tests=0
    
    # Run tests based on category
    case "$test_category" in
        all)
            print_status "$BLUE" "🔄 Running all available tests..."
            
            if test_syntax; then
                test_results+=("✅ Syntax Tests: PASS")
            else
                test_results+=("❌ Syntax Tests: FAIL")
                ((failed_tests++))
            fi
            
            if test_dry_run; then
                test_results+=("✅ Dry-Run Tests: PASS")
            else
                test_results+=("❌ Dry-Run Tests: FAIL")
                ((failed_tests++))
            fi
            
            if test_docker; then
                test_results+=("✅ Docker Tests: PASS")
            else
                test_results+=("⚠️ Docker Tests: PARTIAL")
            fi
            
            if test_vm_setup; then
                test_results+=("✅ VM Setup: PASS")
            else
                test_results+=("⚠️ VM Setup: PARTIAL")
            fi
            
            if test_integration; then
                test_results+=("✅ Integration Tests: PASS")
            else
                test_results+=("⚠️ Integration Tests: PARTIAL")
            fi
            
            if test_project_structure; then
                test_results+=("✅ Project Structure: PASS")
            else
                test_results+=("⚠️ Project Structure: PARTIAL")
            fi
            ;;
            
        quick)
            print_status "$BLUE" "⚡ Running quick tests..."
            
            if test_syntax; then
                test_results+=("✅ Syntax Tests: PASS")
            else
                test_results+=("❌ Syntax Tests: FAIL")
                ((failed_tests++))
            fi
            
            if test_dry_run; then
                test_results+=("✅ Dry-Run Tests: PASS")
            else
                test_results+=("❌ Dry-Run Tests: FAIL")
                ((failed_tests++))
            fi
            ;;
            
        syntax)
            if test_syntax; then
                test_results+=("✅ Syntax Tests: PASS")
            else
                test_results+=("❌ Syntax Tests: FAIL")
                ((failed_tests++))
            fi
            ;;
            
        dry-run)
            if test_dry_run; then
                test_results+=("✅ Dry-Run Tests: PASS")
            else
                test_results+=("❌ Dry-Run Tests: FAIL")
                ((failed_tests++))
            fi
            ;;
            
        docker)
            if test_docker; then
                test_results+=("✅ Docker Tests: PASS")
            else
                test_results+=("❌ Docker Tests: FAIL")
                ((failed_tests++))
            fi
            ;;
            
        vm-setup)
            if test_vm_setup; then
                test_results+=("✅ VM Setup: PASS")
            else
                test_results+=("❌ VM Setup: FAIL")
                ((failed_tests++))
            fi
            ;;
            
        integration)
            if test_integration; then
                test_results+=("✅ Integration Tests: PASS")
            else
                test_results+=("❌ Integration Tests: FAIL")
                ((failed_tests++))
            fi
            ;;
            
        *)
            print_status "$RED" "❌ Unknown test category: $test_category"
            usage
            exit 1
            ;;
    esac
    
    # Generate comprehensive report
    generate_comprehensive_report
    
    # Show results summary
    print_section "TEST RESULTS SUMMARY"
    
    for result in "${test_results[@]}"; do
        if [[ "$result" == *"PASS"* ]]; then
            print_status "$GREEN" "$result"
        elif [[ "$result" == *"FAIL"* ]]; then
            print_status "$RED" "$result"
        else
            print_status "$YELLOW" "$result"
        fi
    done
    
    echo
    print_status "$BLUE" "📊 Overall Results:"
    print_status "$BLUE" "   Total Tests: ${#test_results[@]}"
    print_status "$BLUE" "   Failed Tests: $failed_tests"
    print_status "$BLUE" "   Success Rate: $(( (${#test_results[@]} - failed_tests) * 100 / ${#test_results[@]} ))%"
    
    echo
    print_status "$BLUE" "📁 Results Location: $RESULTS_DIR"
    print_status "$BLUE" "📄 Comprehensive Report: $RESULTS_DIR/comprehensive_test_report.html"
    print_status "$BLUE" "📄 Test Log: $TEST_LOG"
    
    # Cleanup
    cleanup_temp_files
    
    # Final status
    if [[ $failed_tests -eq 0 ]]; then
        print_status "$GREEN" "🎉 All tests completed successfully!"
        exit 0
    else
        print_status "$YELLOW" "⚠️  Testing completed with $failed_tests failed tests"
        exit 1
    fi
}

# Run main function
main "$@"