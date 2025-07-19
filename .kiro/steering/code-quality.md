---
inclusion: always
---

# Code Quality and Best Practices Requirements

## Mandatory Code Quality Standards

All code in this project MUST meet these quality standards. No exceptions for "quick fixes" or "temporary code."

## Linux Kernel Coding Standards

### Style Requirements
- Follow Linux kernel coding style (Documentation/process/coding-style.rst)
- Use tabs for indentation (8 characters)
- Maximum line length: 80 characters
- Use descriptive variable and function names
- Follow kernel naming conventions

### Function Requirements
```c
// Good example
static int fp_device_initialize(struct fp_device *dev)
{
    int ret;
    
    if (!dev) {
        pr_err("fp_device: Invalid device pointer\n");
        return -EINVAL;
    }
    
    ret = fp_hardware_reset(dev);
    if (ret) {
        pr_err("fp_device: Hardware reset failed: %d\n", ret);
        return ret;
    }
    
    return 0;
}
```

## Comment Requirements

### Mandatory Comments
1. **File headers** - Every file must have a header describing its purpose
2. **Function headers** - Every function must document purpose, parameters, return values
3. **Complex logic** - Any non-obvious code must be explained
4. **Hardware interactions** - All hardware-specific code must be documented
5. **Protocol implementations** - Communication protocols must be thoroughly documented

### Comment Quality Standards
```c
/**
 * Initialize fingerprint scanner hardware
 * 
 * This function performs the complete initialization sequence for the
 * fingerprint scanner, including power-on, firmware loading (if required),
 * and sensor calibration. The initialization follows the protocol documented
 * in docs/hardware-protocol.md section 3.2.
 *
 * @dev: Pointer to the fingerprint device structure
 * 
 * Returns 0 on success, negative error code on failure:
 * -EINVAL: Invalid device pointer
 * -EIO: Hardware communication failure
 * -ETIMEDOUT: Initialization timeout
 * -ENOMEM: Memory allocation failure
 */
```

## Error Handling Requirements

### Mandatory Error Handling
1. **Check all return values** - Never ignore function return values
2. **Validate all inputs** - Check pointers, ranges, and validity
3. **Clean up on errors** - Free resources, reset state on failure paths
4. **Log errors appropriately** - Use proper kernel logging levels
5. **Return meaningful error codes** - Use standard Linux error codes

### Error Handling Pattern
```c
static int fp_capture_image(struct fp_device *dev, struct fp_image *img)
{
    int ret;
    void *buffer = NULL;
    
    // Input validation
    if (!dev || !img) {
        ret = -EINVAL;
        goto out;
    }
    
    // Resource allocation
    buffer = kmalloc(IMAGE_BUFFER_SIZE, GFP_KERNEL);
    if (!buffer) {
        ret = -ENOMEM;
        goto out;
    }
    
    // Hardware operation
    ret = fp_hw_capture(dev, buffer, IMAGE_BUFFER_SIZE);
    if (ret) {
        pr_err("fp_device: Image capture failed: %d\n", ret);
        goto out_free;
    }
    
    // Success path
    img->data = buffer;
    img->size = IMAGE_BUFFER_SIZE;
    return 0;
    
out_free:
    kfree(buffer);
out:
    return ret;
}
```

## Memory Management Requirements

### Allocation Rules
1. **Match allocations with deallocations** - Every kmalloc needs kfree
2. **Use appropriate allocation flags** - GFP_KERNEL, GFP_ATOMIC as needed
3. **Check allocation success** - Always check for NULL returns
4. **Clear sensitive data** - Zero memory containing sensitive information
5. **Use reference counting** - For shared resources

### Memory Safety Pattern
```c
// Allocation
data = kzalloc(sizeof(*data), GFP_KERNEL);
if (!data)
    return -ENOMEM;

// Use data...

// Cleanup
memset(data, 0, sizeof(*data));  // Clear sensitive data
kfree(data);
data = NULL;  // Prevent use-after-free
```

## Concurrency and Thread Safety

### Synchronization Requirements
1. **Protect shared data** - Use appropriate locking mechanisms
2. **Avoid deadlocks** - Consistent lock ordering
3. **Minimize lock scope** - Hold locks for minimum time
4. **Use atomic operations** - For simple shared variables
5. **Document locking** - Explain locking strategy

### Locking Pattern
```c
struct fp_device {
    struct mutex lock;  /* Protects device state and hardware access */
    // ... other fields
};

static int fp_device_operation(struct fp_device *dev)
{
    int ret;
    
    mutex_lock(&dev->lock);
    
    // Critical section - hardware access
    ret = fp_hw_operation(dev);
    
    mutex_unlock(&dev->lock);
    
    return ret;
}
```

## Performance Requirements

### Optimization Guidelines
1. **Avoid unnecessary allocations** - Reuse buffers when possible
2. **Minimize hardware operations** - Cache results when appropriate
3. **Use efficient algorithms** - Consider time and space complexity
4. **Profile critical paths** - Measure performance of key operations
5. **Optimize for common case** - Fast path for normal operations

## Security Requirements

### Security Practices
1. **Validate all inputs** - Especially from user space
2. **Prevent buffer overflows** - Use safe string functions
3. **Clear sensitive data** - Zero fingerprint data after use
4. **Limit privileges** - Use least privilege principle
5. **Audit security-critical code** - Extra review for security functions

### Security Pattern
```c
static long fp_device_ioctl(struct file *file, unsigned int cmd, 
                           unsigned long arg)
{
    struct fp_device *dev = file->private_data;
    void __user *argp = (void __user *)arg;
    int ret;
    
    // Validate device
    if (!dev)
        return -ENODEV;
    
    // Validate command
    if (_IOC_TYPE(cmd) != FP_IOC_MAGIC)
        return -ENOTTY;
    
    // Check permissions
    if (_IOC_DIR(cmd) & _IOC_READ) {
        if (!access_ok(argp, _IOC_SIZE(cmd)))
            return -EFAULT;
    }
    
    // Handle command...
}
```

## Code Review Requirements

### Self-Review Checklist
- [ ] All functions have proper documentation
- [ ] Error handling is complete and correct
- [ ] Memory management is safe
- [ ] Locking is appropriate and deadlock-free
- [ ] Code follows kernel style guidelines
- [ ] Performance implications are considered
- [ ] Security implications are addressed

### Peer Review Requirements
- Code must be reviewed by at least one other developer
- Security-critical code requires senior developer review
- Hardware-specific code requires hardware expert review
- Performance-critical code requires performance review

## Quality Metrics

### Minimum Standards
- Comment ratio: >20% of lines should be comments
- Function size: <50 lines per function (exceptions require justification)
- Cyclomatic complexity: <10 per function
- Test coverage: >80% for new code
- Static analysis: Zero warnings from sparse and other tools

## Tools and Automation

### Required Tools
- `sparse` for static analysis
- `checkpatch.pl` for style checking
- `coccinelle` for semantic patches
- `lockdep` for lock validation
- `kmemleak` for memory leak detection

### Automated Checks
All code must pass:
- Kernel style checker (checkpatch.pl)
- Static analysis (sparse)
- Memory leak detection
- Lock dependency validation
- Security vulnerability scanning