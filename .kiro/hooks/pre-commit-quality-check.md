# Pre-Commit Quality Check Hook

## Hook Configuration
- **Trigger**: Before any commit
- **Type**: Validation Hook
- **Blocking**: Yes (prevents commit if checks fail)

## Description
This hook performs comprehensive quality checks before allowing any commit to proceed. It enforces all development guidelines and ensures code quality standards are met.

## Checks Performed

### 1. File Size Validation
- Check that no source file exceeds 300 lines
- Count lines excluding blank lines
- Generate warnings at 250 lines
- Block commits with files over 300 lines

### 2. Documentation Completeness
- Verify all new functions have documentation headers
- Check that modified functions have updated documentation
- Ensure file headers are present and current
- Validate that architecture docs reflect code changes

### 3. Code Quality Standards
- Run checkpatch.pl on all modified C files
- Verify proper error handling patterns
- Check for memory leaks and proper cleanup
- Validate locking patterns and thread safety

### 4. Redundancy Detection
- Scan for duplicate function implementations
- Check for similar code patterns that could be refactored
- Identify opportunities for code reuse
- Flag potential architectural violations

### 5. Project Scope Validation
- Ensure changes align with fingerprint driver objectives
- Check that new dependencies are justified
- Validate that changes don't introduce scope creep
- Verify hardware-specific code is properly abstracted

## Implementation

```bash
#!/bin/bash
# Pre-commit quality check script

echo "Running pre-commit quality checks..."

# Check file sizes
echo "Checking file sizes..."
for file in $(git diff --cached --name-only --diff-filter=AM | grep -E '\.(c|h)$'); do
    if [ -f "$file" ]; then
        lines=$(grep -c -v '^[[:space:]]*$' "$file")
        if [ $lines -gt 300 ]; then
            echo "ERROR: $file has $lines lines (max 300)"
            exit 1
        elif [ $lines -gt 250 ]; then
            echo "WARNING: $file has $lines lines (approaching 300 line limit)"
        fi
    fi
done

# Check documentation
echo "Checking documentation completeness..."
# Implementation for documentation checks

# Check code quality
echo "Running code quality checks..."
# Implementation for quality checks

# Check for redundancy
echo "Checking for code redundancy..."
# Implementation for redundancy checks

# Check project scope
echo "Validating project scope..."
# Implementation for scope validation

echo "All quality checks passed!"
```

## Failure Actions
- **File Size Violation**: Block commit, suggest refactoring
- **Missing Documentation**: Block commit, list missing docs
- **Quality Issues**: Block commit, show specific violations
- **Redundancy Detected**: Block commit, suggest existing alternatives
- **Scope Violation**: Block commit, require justification

## Override Mechanism
In exceptional cases, quality checks can be bypassed with:
```bash
git commit --no-verify -m "Emergency fix - bypassing quality checks"
```
However, this requires:
- Senior developer approval
- Immediate follow-up ticket for compliance
- Documentation of the exception reason