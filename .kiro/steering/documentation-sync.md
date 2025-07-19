---
inclusion: always
---

# Documentation Synchronization Requirements

## Mandatory Documentation Updates

**CRITICAL RULE**: Every code change MUST be accompanied by corresponding documentation updates. No exceptions.

## Documentation That Must Stay Current

### 1. Architecture Documentation (`docs/architecture.md`)
**Update when**:
- Adding new modules or components
- Changing component interfaces
- Modifying data structures
- Changing communication protocols
- Adding new hardware support

**Required updates**:
- Component diagrams
- Interface specifications
- Data flow descriptions
- Integration points

### 2. API Documentation
**Update when**:
- Adding new functions or methods
- Changing function signatures
- Modifying return values or parameters
- Adding new data structures
- Changing error codes

**Required updates**:
- Function documentation
- Parameter descriptions
- Return value specifications
- Usage examples

### 3. Hardware Compatibility (`docs/hardware-support.md`)
**Update when**:
- Adding support for new devices
- Changing hardware requirements
- Modifying protocol implementations
- Adding new features or capabilities

**Required updates**:
- Supported device list
- Hardware requirements
- Protocol specifications
- Feature matrices

### 4. Installation and Usage Documentation
**Update when**:
- Changing build requirements
- Modifying installation procedures
- Adding new configuration options
- Changing user interfaces

**Required updates**:
- Installation instructions
- Configuration guides
- Usage examples
- Troubleshooting information

### 5. Code Comments and Inline Documentation
**Update when**:
- Adding new functions
- Modifying existing logic
- Implementing complex algorithms
- Adding hardware-specific code

**Required updates**:
- Function headers with purpose, parameters, return values
- Complex logic explanations
- Hardware protocol documentation
- Error handling descriptions

## Documentation Standards

### Code Comments Requirements
```c
/**
 * Brief description of function purpose
 * 
 * Detailed description of what the function does, including any
 * hardware interactions, protocol specifics, or important behavior.
 *
 * @param param1 Description of parameter 1
 * @param param2 Description of parameter 2
 * @return Description of return value and possible error codes
 * 
 * @note Any important notes about usage, limitations, or side effects
 * @warning Any warnings about potential issues or requirements
 */
```

### File Header Requirements
```c
/**
 * @file filename.c
 * @brief Brief description of file purpose
 * @author Project contributors
 * @date Creation/modification date
 * 
 * Detailed description of what this file contains, its role in the
 * driver architecture, and any important implementation notes.
 * 
 * Hardware interactions: Description of any hardware this file interacts with
 * Dependencies: List of major dependencies
 * Thread safety: Notes about thread safety considerations
 */
```

### Documentation Generation Rules

1. **Automatic Updates**: Documentation should be updated automatically when possible
2. **Template Generation**: New files should generate documentation templates
3. **Consistency Checking**: Documentation should be checked for consistency with code
4. **Cross-references**: Related documentation should be cross-referenced
5. **Version Tracking**: Documentation changes should be tracked with code changes

## Documentation Verification Checklist

Before any commit, verify:
- [ ] All new functions have proper documentation headers
- [ ] Complex logic has explanatory comments
- [ ] Architecture documentation reflects any structural changes
- [ ] Hardware documentation includes any new device support
- [ ] API documentation matches actual interfaces
- [ ] Installation docs reflect any new requirements
- [ ] Cross-references between docs are updated
- [ ] Examples and usage guides are current

## Documentation Quality Standards

### Clarity Requirements
- Use clear, concise language
- Avoid jargon without explanation
- Include examples where helpful
- Structure information logically

### Completeness Requirements
- Document all public interfaces
- Explain all parameters and return values
- Include error conditions and handling
- Provide usage examples

### Accuracy Requirements
- Documentation must match actual code behavior
- Examples must be tested and working
- Version information must be current
- Cross-references must be valid

## Automated Documentation Tools

Use these tools to maintain documentation:
- Doxygen for API documentation generation
- Markdown linting for documentation quality
- Link checking for cross-references
- Spell checking for content quality

## Documentation Failure Consequences

If documentation is not maintained:
- Code becomes unmaintainable
- New developers cannot understand the system
- Hardware integration becomes difficult
- Debugging becomes nearly impossible
- Project knowledge is lost

## Emergency Documentation Updates

If urgent fixes are needed without full documentation:
1. Add TODO comments with detailed explanations
2. Create documentation tickets for follow-up
3. Update at least inline comments
4. Schedule documentation sprint within 48 hours

## Documentation Review Process

1. **Self-review**: Author reviews their own documentation
2. **Peer review**: Another developer reviews documentation
3. **Technical review**: Senior developer reviews technical accuracy
4. **User review**: Documentation is tested by someone unfamiliar with the code