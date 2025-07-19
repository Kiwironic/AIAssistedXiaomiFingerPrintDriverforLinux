---
inclusion: always
---

# Modularity and Architecture Requirements

## Critical File Size Limit: 300 Lines Maximum

**ABSOLUTE RULE**: No source file may exceed 300 lines of code. This includes comments but excludes blank lines.

### File Size Enforcement
- **Warning at 250 lines**: Suggest refactoring
- **Error at 300 lines**: MUST refactor before proceeding
- **No exceptions**: Even "almost done" files must be split

### When Approaching Limit
1. **Identify logical boundaries** - Look for natural separation points
2. **Extract helper functions** - Move utility functions to separate files
3. **Separate concerns** - Split different responsibilities
4. **Create header files** - Move declarations to appropriate headers

## Modular Design Principles

### Separation of Concerns
Each file should have a single, well-defined responsibility:

```
src/
├── core/
│   ├── fp_device.c          # Device management (< 300 lines)
│   ├── fp_protocol.c        # Communication protocol (< 300 lines)
│   └── fp_buffer.c          # Buffer management (< 300 lines)
├── hardware/
│   ├── fp_usb.c             # USB-specific code (< 300 lines)
│   ├── fp_i2c.c             # I2C-specific code (< 300 lines)
│   └── fp_spi.c             # SPI-specific code (< 300 lines)
├── algorithms/
│   ├── fp_capture.c         # Image capture logic (< 300 lines)
│   ├── fp_process.c         # Image processing (< 300 lines)
│   └── fp_match.c           # Template matching (< 300 lines)
└── interfaces/
    ├── fp_chardev.c         # Character device interface (< 300 lines)
    ├── fp_sysfs.c           # Sysfs interface (< 300 lines)
    └── fp_debugfs.c         # Debug interface (< 300 lines)
```

### Module Boundaries
Each module should:
1. **Have clear interfaces** - Well-defined function signatures
2. **Hide implementation details** - Use static functions for internals
3. **Minimize dependencies** - Reduce coupling between modules
4. **Export only necessary symbols** - Keep internal functions private

### Interface Design Pattern
```c
// fp_device.h - Public interface
struct fp_device;  // Opaque structure

int fp_device_create(struct fp_device **dev, struct device *parent);
void fp_device_destroy(struct fp_device *dev);
int fp_device_start(struct fp_device *dev);
int fp_device_stop(struct fp_device *dev);

// fp_device.c - Implementation (< 300 lines)
struct fp_device {
    struct device *parent;
    struct mutex lock;
    enum fp_state state;
    // ... other private fields
};

static int fp_device_init_hardware(struct fp_device *dev)
{
    // Implementation details hidden from other modules
}
```

## Refactoring Strategies

### When a File Gets Too Large

#### 1. Extract Utility Functions
```c
// Before: fp_main.c (350 lines)
static int validate_input(...)
static int parse_config(...)
static int setup_hardware(...)
int main_function(...)

// After: Split into multiple files
// fp_validation.c (< 100 lines)
int fp_validate_input(...)

// fp_config.c (< 150 lines)  
int fp_parse_config(...)

// fp_hardware.c (< 200 lines)
int fp_setup_hardware(...)

// fp_main.c (< 100 lines)
int main_function(...)
```

#### 2. Separate by Functionality
```c
// Before: fp_protocol.c (400 lines)
// Contains: USB handling, I2C handling, protocol parsing

// After: Split by transport
// fp_protocol_core.c (< 200 lines) - Common protocol logic
// fp_protocol_usb.c (< 150 lines) - USB-specific implementation
// fp_protocol_i2c.c (< 100 lines) - I2C-specific implementation
```

#### 3. Extract State Machines
```c
// Before: fp_device.c (350 lines)
// Contains: Device management + state machine

// After: Separate concerns
// fp_device.c (< 200 lines) - Device lifecycle management
// fp_state.c (< 150 lines) - State machine implementation
```

## Architecture Patterns

### Layered Architecture
```
┌─────────────────────────────────────┐
│          User Interface Layer       │ (< 300 lines per file)
├─────────────────────────────────────┤
│         Protocol Layer              │ (< 300 lines per file)
├─────────────────────────────────────┤
│         Hardware Abstraction        │ (< 300 lines per file)
├─────────────────────────────────────┤
│         Transport Layer             │ (< 300 lines per file)
└─────────────────────────────────────┘
```

### Plugin Architecture
```c
// Core system (< 300 lines)
struct fp_driver_ops {
    int (*init)(struct fp_device *dev);
    int (*capture)(struct fp_device *dev, struct fp_image *img);
    int (*cleanup)(struct fp_device *dev);
};

// Device-specific plugins (each < 300 lines)
// fp_driver_validity.c
// fp_driver_synaptics.c
// fp_driver_elan.c
```

## Dependency Management

### Minimize Coupling
1. **Use interfaces, not implementations** - Depend on abstractions
2. **Avoid circular dependencies** - Clear dependency hierarchy
3. **Limit include depth** - Minimize nested includes
4. **Use forward declarations** - Reduce compilation dependencies

### Dependency Hierarchy
```
Level 1: Core utilities (no dependencies)
├── fp_types.h
├── fp_error.h
└── fp_utils.c

Level 2: Hardware abstraction (depends on Level 1)
├── fp_hardware.h
└── fp_transport.c

Level 3: Protocol implementation (depends on Level 1-2)
├── fp_protocol.h
└── fp_commands.c

Level 4: Device drivers (depends on Level 1-3)
├── fp_device.c
└── fp_interface.c
```

## Code Organization Rules

### File Naming Conventions
- **Prefix all files** with `fp_` for fingerprint
- **Use descriptive names** that indicate purpose
- **Group related files** in subdirectories
- **Separate interface from implementation** (.h and .c files)

### Function Organization Within Files
```c
// 1. Includes and defines (< 50 lines)
#include <linux/module.h>
#define FP_MAX_DEVICES 8

// 2. Type definitions (< 50 lines)
struct fp_private_data {
    // ...
};

// 3. Static function declarations (< 30 lines)
static int fp_internal_function(void);

// 4. Static variables (< 20 lines)
static struct fp_device *fp_devices[FP_MAX_DEVICES];

// 5. Static function implementations (< 120 lines total)
static int fp_internal_function(void)
{
    // Implementation
}

// 6. Public function implementations (< 80 lines total)
int fp_public_function(void)
{
    // Implementation
}

// 7. Module initialization/cleanup (< 30 lines)
static int __init fp_module_init(void)
{
    // Initialization
}
```

## Quality Checks for Modularity

### Pre-commit Checks
- [ ] No file exceeds 300 lines
- [ ] Each file has single responsibility
- [ ] Interfaces are well-defined
- [ ] Dependencies are minimized
- [ ] Code is properly organized within files

### Refactoring Triggers
- File approaching 250 lines
- Function exceeding 50 lines
- High cyclomatic complexity
- Multiple responsibilities in one file
- Tight coupling between modules

### Architecture Review Points
- Adding new major functionality
- Changing module interfaces
- Adding new dependencies
- Modifying core abstractions
- Performance optimization changes

## Benefits of Modular Design

### Maintainability
- Easier to understand individual components
- Simpler debugging and testing
- Reduced risk of introducing bugs
- Easier code reviews

### Scalability
- Easy to add new hardware support
- Simple to extend functionality
- Parallel development possible
- Reusable components

### Quality
- Better test coverage
- Clearer interfaces
- Reduced complexity
- Improved documentation