#!/bin/bash

# Master Test Runner for Xiaomi Fingerprint Driver
# Orchestrates all testing methods and provides comprehensive validation

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
MASTER_LOG="/tmp/fp_xiaomi_master_test.log"
RESULTS_DIR="/tmp/fp_xiaomi_master_results"
START_TIME=$(date +%s)

# Test configuration
ENABLE_DOCKER=${ENABLE_DOCKER:-true}
ENABLE_VM=${ENABLE_VM:-false}
ENABLE_HARDWARE=${ENABLE_HARDWARE:-false}
PARALLEL_TESTS=${PARALLEL_TESTS:-true}
CLEANUP_AFTER=${CLEANUP_AFTER:-true}

# Print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$MASTER_LOG"
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
Master Test Runner for Xiaomi Fingerprint Driver

USAGE:
    $0 [OPTIONS] [TEST_SUITE]

TEST SUITES:
    quick           Fast validation (syntax + dry-run)
    standard        Standard testing (syntax + dry-run + docker)
    comprehensive   Full testing suite (all methods)
    ci              CI/CD optimized testing
    development     Development-focused testing
    release         Release validation testing

OPTIONS:
    --no-docker         Disable Docker testing
    --enable-vm         Enable VM testing (requires setup)
    --enable-hardware   Enable hardware testing (requires hardware)
    --no-parallel       Disable parallel test execution
    --no-cleanup        Don't cleanup temporary files
    --results-dir DIR   Custom results directory
    --verbose           Enable verbose output
    --help              Show this help message

EXAMPLES:
    $0 quick                    # Quick validation
    $0 standard --verbose       # Standard tests with verbose output
    $0 comprehensive --no-docker # Full tests without Docker
    $0 ci                       # CI/CD optimized testing

ENVIRONMENT VARIABLES:
    ENABLE_DOCKER=false         Disable Docker testing
    ENABLE_VM=true             Enable VM testing
    ENABLE_HARDWARE=true       Enable hardware testing
    PARALLEL_TESTS=false       Disable parallel execution
    CLEANUP_AFTER=false        Don't cleanup after tests

EOF
}

# Initialize master test environment
initialize_master_environment() {
    print_section "INITIALIZING MASTER TEST ENVIRONMENT"
    
    # Create results directory
    mkdir -p "$RESULTS_DIR"
    
    # Initialize master log
    cat > "$MASTER_LOG" << EOF
=== Xiaomi Fingerprint Driver Master Test Runner ===
Started: $(date)
Host: $(uname -a)
User: $(whoami)
Working Directory: $(pwd)
Test Suite: ${TEST_SUITE:-standard}
Configuration:
  Docker: $ENABLE_DOCKER
  VM: $ENABLE_VM
  Hardware: $ENABLE_HARDWARE
  Parallel: $PARALLEL_TESTS
  Cleanup: $CLEANUP_AFTER

EOF
    
    print_status "$GREEN" "✅ Master test environment initialized"
    print_status "$BLUE" "📁 Results directory: $RESULTS_DIR"
    print_status "$BLUE" "📄 Master log: $MASTER_LOG"
}

# Check test prerequisites
check_prerequisites() {
    print_section "CHECKING TEST PREREQUISITES"
    
    local missing_tools=()
    local available_tools=()
    
    # Check basic tools
    local basic_tools=("bash" "git" "make" "gcc")
    for tool in "${basic_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            available_tools+=("$tool")
            print_status "$GREEN" "   ✅ $tool: $(which $tool)"
        else
            missing_tools+=("$tool")
            print_status "$RED" "   ❌ $tool: Not found"
        fi
    done
    
    # Check Docker
    if [[ "$ENABLE_DOCKER" == "true" ]]; then
        if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
            available_tools+=("docker")
            print_status "$GREEN" "   ✅ Docker: $(docker --version)"
        else
            print_status "$YELLOW" "   ⚠️  Docker: Not available (will skip Docker tests)"
            ENABLE_DOCKER=false
        fi
    fi
    
    # Check VM tools
    if [[ "$ENABLE_VM" == "true" ]]; then
        local vm_tools=("vagrant" "VBoxManage" "qemu-system-x86_64")
        local vm_available=false
        
        for tool in "${vm_tools[@]}"; do
            if command -v "$tool" >/dev/null 2>&1; then
                available_tools+=("$tool")
                print_status "$GREEN" "   ✅ $tool: Available"
                vm_available=true
                break
            fi
        done
        
        if [[ "$vm_available" == false ]]; then
            print_status "$YELLOW" "   ⚠️  VM tools: Not available (will skip VM tests)"
            ENABLE_VM=false
        fi
    fi
    
    # Check hardware
    if [[ "$ENABLE_HARDWARE" == "true" ]]; then
        if lsusb | grep -E "(2717|10a5)" >/dev/null 2>&1; then
            print_status "$GREEN" "   ✅ Hardware: Xiaomi fingerprint device detected"
        else
            print_status "$YELLOW" "   ⚠️  Hardware: No Xiaomi device detected (will skip hardware tests)"
            ENABLE_HARDWARE=false
        fi
    fi
    
    # Summary
    print_status "$BLUE" "📊 Prerequisites Summary:"
    print_status "$BLUE" "   Available tools: ${#available_tools[@]}"
    print_status "$BLUE" "   Missing tools: ${#missing_tools[@]}"
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_status "$YELLOW" "   Missing: ${missing_tools[*]}"
    fi
    
    # Check if we can proceed
    if [[ ${#missing_tools[@]} -gt 2 ]]; then
        print_status "$RED" "❌ Too many missing prerequisites"
        return 1
    fi
    
    return 0
}

# Run test suite with timing
run_timed_test() {
    local test_name=$1
    local test_command=$2
    local start_time=$(date +%s)
    
    print_status "$BLUE" "🚀 Starting: $test_name"
    
    if eval "$test_command" 2>&1 | tee "$RESULTS_DIR/${test_name,,}_output.log"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_status "$GREEN" "✅ Completed: $test_name (${duration}s)"
        echo "$test_name:PASS:${duration}s" >> "$RESULTS_DIR/test_summary.txt"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_status "$RED" "❌ Failed: $test_name (${duration}s)"
        echo "$test_name:FAIL:${duration}s" >> "$RESULTS_DIR/test_summary.txt"
        return 1
    fi
}

# Run parallel tests
run_parallel_tests() {
    local test_jobs=()
    
    print_section "RUNNING PARALLEL TESTS"
    
    # Start background jobs
    if [[ "$ENABLE_DOCKER" == "true" ]]; then
        print_status "$BLUE" "🐳 Starting Docker tests in background..."
        bash "$SCRIPT_DIR/test-with-docker.sh" all > "$RESULTS_DIR/docker_parallel.log" 2>&1 &
        test_jobs+=($!)
    fi
    
    # Run syntax tests in foreground
    run_timed_test "Syntax Tests" "bash '$SCRIPT_DIR/run-all-tests.sh' syntax"
    
    # Run dry-run tests in foreground
    run_timed_test "Dry Run Tests" "bash '$SCRIPT_DIR/test-installation-dry-run.sh'"
    
    # Wait for background jobs
    for job in "${test_jobs[@]}"; do
        if wait $job; then
            print_status "$GREEN" "✅ Background job completed successfully"
        else
            print_status "$RED" "❌ Background job failed"
        fi
    done
}

# Run sequential tests
run_sequential_tests() {
    print_section "RUNNING SEQUENTIAL TESTS"
    
    local tests_passed=0
    local tests_failed=0
    
    # Syntax tests
    if run_timed_test "Syntax Tests" "bash '$SCRIPT_DIR/run-all-tests.sh' syntax"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Dry run tests
    if run_timed_test "Dry Run Tests" "bash '$SCRIPT_DIR/test-installation-dry-run.sh'"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Docker tests
    if [[ "$ENABLE_DOCKER" == "true" ]]; then
        if run_timed_test "Docker Tests" "bash '$SCRIPT_DIR/test-with-docker.sh' all"; then
            ((tests_passed++))
        else
            ((tests_failed++))
        fi
    fi
    
    # VM tests
    if [[ "$ENABLE_VM" == "true" ]]; then
        if run_timed_test "VM Tests" "bash '$SCRIPT_DIR/test-with-vm.sh'"; then
            ((tests_passed++))
        else
            ((tests_failed++))
        fi
    fi
    
    # PowerShell tests (if on Windows or WSL)
    if command -v powershell.exe >/dev/null 2>&1 || command -v pwsh >/dev/null 2>&1; then
        if run_timed_test "PowerShell Tests" "powershell.exe -File '$SCRIPT_DIR/test-scripts-powershell.ps1' -TestCategory all"; then
            ((tests_passed++))
        else
            ((tests_failed++))
        fi
    fi
    
    # Hardware tests
    if [[ "$ENABLE_HARDWARE" == "true" ]]; then
        if run_timed_test "Hardware Tests" "bash '$SCRIPT_DIR/test-driver.sh' --hardware"; then
            ((tests_passed++))
        else
            ((tests_failed++))
        fi
    fi
    
    print_status "$BLUE" "📊 Sequential Tests Summary: $tests_passed passed, $tests_failed failed"
    return $tests_failed
}

# Quick test suite
run_quick_tests() {
    print_section "RUNNING QUICK TEST SUITE"
    
    local quick_tests=(
        "Syntax Validation:bash '$SCRIPT_DIR/run-all-tests.sh' syntax"
        "Basic Dry Run:bash '$SCRIPT_DIR/test-installation-dry-run.sh'"
    )
    
    local failed=0
    
    for test_spec in "${quick_tests[@]}"; do
        local test_name=$(echo "$test_spec" | cut -d: -f1)
        local test_cmd=$(echo "$test_spec" | cut -d: -f2-)
        
        if ! run_timed_test "$test_name" "$test_cmd"; then
            ((failed++))
        fi
    done
    
    return $failed
}

# Standard test suite
run_standard_tests() {
    print_section "RUNNING STANDARD TEST SUITE"
    
    if [[ "$PARALLEL_TESTS" == "true" ]]; then
        run_parallel_tests
    else
        run_sequential_tests
    fi
}

# Comprehensive test suite
run_comprehensive_tests() {
    print_section "RUNNING COMPREHENSIVE TEST SUITE"
    
    # Force enable all available testing methods
    ENABLE_DOCKER=true
    ENABLE_VM=true
    
    # Run all tests
    run_sequential_tests
    
    # Additional comprehensive tests
    run_timed_test "Integration Tests" "bash '$SCRIPT_DIR/run-all-tests.sh' integration"
    run_timed_test "Project Structure" "bash '$SCRIPT_DIR/run-all-tests.sh' structure"
    
    # Generate comprehensive report
    run_timed_test "Report Generation" "bash '$SCRIPT_DIR/run-all-tests.sh' export"
}

# CI/CD optimized test suite
run_ci_tests() {
    print_section "RUNNING CI/CD OPTIMIZED TESTS"
    
    # Optimized for CI environments
    PARALLEL_TESTS=true
    ENABLE_VM=false  # VMs not available in most CI
    
    # Run core tests
    run_parallel_tests
    
    # Additional CI-specific tests
    run_timed_test "Security Scan" "bash '$SCRIPT_DIR/security-scan.sh' || true"
    run_timed_test "Documentation Check" "bash '$SCRIPT_DIR/check-docs.sh' || true"
}

# Development test suite
run_development_tests() {
    print_section "RUNNING DEVELOPMENT TEST SUITE"
    
    # Fast feedback for developers
    local dev_tests=(
        "Syntax Check:bash '$SCRIPT_DIR/run-all-tests.sh' syntax"
        "Quick Dry Run:timeout 60 bash '$SCRIPT_DIR/test-installation-dry-run.sh'"
        "Structure Check:bash '$SCRIPT_DIR/run-all-tests.sh' structure"
    )
    
    local failed=0
    
    for test_spec in "${dev_tests[@]}"; do
        local test_name=$(echo "$test_spec" | cut -d: -f1)
        local test_cmd=$(echo "$test_spec" | cut -d: -f2-)
        
        if ! run_timed_test "$test_name" "$test_cmd"; then
            ((failed++))
        fi
    done
    
    return $failed
}

# Release test suite
run_release_tests() {
    print_section "RUNNING RELEASE TEST SUITE"
    
    # Comprehensive testing for releases
    ENABLE_DOCKER=true
    PARALLEL_TESTS=false  # Sequential for reliability
    
    # Run comprehensive tests
    run_comprehensive_tests
    
    # Additional release-specific validation
    run_timed_test "Version Consistency" "bash '$SCRIPT_DIR/check-versions.sh' || true"
    run_timed_test "Documentation Completeness" "bash '$SCRIPT_DIR/check-docs-complete.sh' || true"
    run_timed_test "Package Validation" "bash '$SCRIPT_DIR/validate-packages.sh' || true"
}

# Generate master test report
generate_master_report() {
    print_section "GENERATING MASTER TEST REPORT"
    
    local report_file="$RESULTS_DIR/master_test_report.html"
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Xiaomi Fingerprint Driver - Master Test Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 15px; margin-bottom: 30px; text-align: center; }
        .section { margin: 25px 0; padding: 20px; border-left: 5px solid #667eea; background: #f8f9fa; border-radius: 10px; }
        .success { color: #28a745; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .error { color: #dc3545; font-weight: bold; }
        .info { color: #17a2b8; }
        .test-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(350px, 1fr)); gap: 20px; margin: 20px 0; }
        .test-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); border-left: 5px solid #667eea; }
        .pass { border-left-color: #28a745; }
        .fail { border-left-color: #dc3545; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
        .metric { background: white; padding: 15px; border-radius: 8px; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        pre { background: #f1f3f4; padding: 15px; border-radius: 8px; overflow-x: auto; border-left: 4px solid #667eea; }
        .timeline { border-left: 3px solid #667eea; padding-left: 20px; margin: 20px 0; }
        .timeline-item { margin-bottom: 15px; padding: 10px; background: white; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 Master Test Report</h1>
        <h2>Xiaomi Fingerprint Driver</h2>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Total Duration:</strong> ${total_duration}s</p>
        <p><strong>Test Suite:</strong> ${TEST_SUITE:-standard}</p>
    </div>

    <div class="section">
        <h2>📊 Test Metrics</h2>
        <div class="metrics">
EOF
    
    # Add test metrics
    if [[ -f "$RESULTS_DIR/test_summary.txt" ]]; then
        local total_tests=$(wc -l < "$RESULTS_DIR/test_summary.txt")
        local passed_tests=$(grep -c ":PASS:" "$RESULTS_DIR/test_summary.txt" || echo 0)
        local failed_tests=$(grep -c ":FAIL:" "$RESULTS_DIR/test_summary.txt" || echo 0)
        local success_rate=0
        
        if [[ $total_tests -gt 0 ]]; then
            success_rate=$(( (passed_tests * 100) / total_tests ))
        fi
        
        cat >> "$report_file" << EOF
            <div class="metric">
                <h3>Total Tests</h3>
                <div style="font-size: 2em; color: #667eea;">$total_tests</div>
            </div>
            <div class="metric">
                <h3>Passed</h3>
                <div style="font-size: 2em; color: #28a745;">$passed_tests</div>
            </div>
            <div class="metric">
                <h3>Failed</h3>
                <div style="font-size: 2em; color: #dc3545;">$failed_tests</div>
            </div>
            <div class="metric">
                <h3>Success Rate</h3>
                <div style="font-size: 2em; color: $([ $success_rate -ge 80 ] && echo '#28a745' || echo '#ffc107');">$success_rate%</div>
            </div>
EOF
    fi
    
    cat >> "$report_file" << EOF
        </div>
    </div>

    <div class="section">
        <h2>🔍 Test Results</h2>
        <div class="test-grid">
EOF
    
    # Add individual test results
    if [[ -f "$RESULTS_DIR/test_summary.txt" ]]; then
        while IFS=: read -r test_name status duration; do
            local card_class="pass"
            local status_icon="✅"
            
            if [[ "$status" == "FAIL" ]]; then
                card_class="fail"
                status_icon="❌"
            fi
            
            cat >> "$report_file" << EOF
            <div class="test-card $card_class">
                <h3>$status_icon $test_name</h3>
                <p><strong>Status:</strong> $status</p>
                <p><strong>Duration:</strong> $duration</p>
            </div>
EOF
        done < "$RESULTS_DIR/test_summary.txt"
    fi
    
    cat >> "$report_file" << EOF
        </div>
    </div>

    <div class="section">
        <h2>📋 Test Configuration</h2>
        <ul>
            <li><strong>Docker Testing:</strong> $ENABLE_DOCKER</li>
            <li><strong>VM Testing:</strong> $ENABLE_VM</li>
            <li><strong>Hardware Testing:</strong> $ENABLE_HARDWARE</li>
            <li><strong>Parallel Execution:</strong> $PARALLEL_TESTS</li>
            <li><strong>Cleanup After:</strong> $CLEANUP_AFTER</li>
        </ul>
    </div>

    <div class="section">
        <h2>📄 Full Test Log</h2>
        <pre>$(cat "$MASTER_LOG")</pre>
    </div>

    <div class="section">
        <h2>🔗 Additional Resources</h2>
        <ul>
            <li><a href="file://$PROJECT_ROOT/docs/testing-guide.md">Testing Guide</a></li>
            <li><a href="file://$PROJECT_ROOT/docs/installation-guide.md">Installation Guide</a></li>
            <li><a href="file://$PROJECT_ROOT/README.md">Project README</a></li>
            <li><a href="file://$RESULTS_DIR">Test Results Directory</a></li>
        </ul>
    </div>
</body>
</html>
EOF
    
    print_status "$GREEN" "✅ Master test report generated: $report_file"
}

# Cleanup function
cleanup_tests() {
    if [[ "$CLEANUP_AFTER" == "true" ]]; then
        print_section "CLEANING UP TEST ENVIRONMENT"
        
        # Remove temporary files but keep results
        find /tmp -name "fp_xiaomi_*" -type f -not -path "$RESULTS_DIR*" -delete 2>/dev/null || true
        find /tmp -name "mock-*" -type f -delete 2>/dev/null || true
        
        # Clean up Docker containers
        if [[ "$ENABLE_DOCKER" == "true" ]]; then
            docker container prune -f >/dev/null 2>&1 || true
        fi
        
        print_status "$GREEN" "✅ Cleanup completed"
    else
        print_status "$BLUE" "💾 Temporary files preserved for debugging"
    fi
}

# Main execution function
main() {
    local test_suite="${1:-standard}"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-docker)
                ENABLE_DOCKER=false
                shift
                ;;
            --enable-vm)
                ENABLE_VM=true
                shift
                ;;
            --enable-hardware)
                ENABLE_HARDWARE=true
                shift
                ;;
            --no-parallel)
                PARALLEL_TESTS=false
                shift
                ;;
            --no-cleanup)
                CLEANUP_AFTER=false
                shift
                ;;
            --results-dir)
                RESULTS_DIR="$2"
                shift 2
                ;;
            --verbose)
                set -x
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            quick|standard|comprehensive|ci|development|release)
                test_suite="$1"
                shift
                ;;
            *)
                print_status "$RED" "❌ Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    TEST_SUITE="$test_suite"
    
    # Initialize
    initialize_master_environment
    
    # Check prerequisites
    if ! check_prerequisites; then
        print_status "$RED" "❌ Prerequisites check failed"
        exit 1
    fi
    
    print_status "$PURPLE" "🚀 Starting Master Test Runner"
    print_status "$BLUE" "📋 Test Suite: $test_suite"
    
    # Initialize test summary
    echo "# Test Summary" > "$RESULTS_DIR/test_summary.txt"
    
    # Run selected test suite
    local exit_code=0
    
    case "$test_suite" in
        quick)
            run_quick_tests || exit_code=$?
            ;;
        standard)
            run_standard_tests || exit_code=$?
            ;;
        comprehensive)
            run_comprehensive_tests || exit_code=$?
            ;;
        ci)
            run_ci_tests || exit_code=$?
            ;;
        development)
            run_development_tests || exit_code=$?
            ;;
        release)
            run_release_tests || exit_code=$?
            ;;
        *)
            print_status "$RED" "❌ Unknown test suite: $test_suite"
            usage
            exit 1
            ;;
    esac
    
    # Generate master report
    generate_master_report
    
    # Cleanup
    cleanup_tests
    
    # Final summary
    local end_time=$(date +%s)
    local total_duration=$((end_time - START_TIME))
    
    print_section "MASTER TEST RUNNER SUMMARY"
    
    print_status "$BLUE" "📊 Execution Summary:"
    print_status "$BLUE" "   Test Suite: $test_suite"
    print_status "$BLUE" "   Total Duration: ${total_duration}s"
    print_status "$BLUE" "   Results Directory: $RESULTS_DIR"
    print_status "$BLUE" "   Master Report: $RESULTS_DIR/master_test_report.html"
    
    if [[ $exit_code -eq 0 ]]; then
        print_status "$GREEN" "🎉 All tests in suite '$test_suite' completed successfully!"
    else
        print_status "$YELLOW" "⚠️  Test suite '$test_suite' completed with some failures"
    fi
    
    exit $exit_code
}

# Handle script interruption
trap cleanup_tests EXIT

# Run main function
main "$@"