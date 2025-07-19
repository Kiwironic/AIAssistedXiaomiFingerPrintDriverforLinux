---
inclusion: always
---

# Project Context and Understanding Requirements

## Project Overview
You are working on a **Linux Fingerprint Scanner Driver** project that involves reverse engineering Windows drivers to create Linux kernel modules. This is a complex, hardware-specific project requiring deep understanding of:

- USB/Hardware communication protocols
- Linux kernel module development
- Device driver architecture
- Fingerprint scanner hardware specifications
- Reverse engineering methodologies

## Mandatory Context Verification

Before making ANY code changes, you MUST:

1. **Understand the Hardware Context**
   - Verify you know the target fingerprint scanner's VID/PID
   - Understand the communication protocol (USB, I2C, SPI, etc.)
   - Know the hardware capabilities and limitations
   - Review any existing hardware documentation

2. **Understand the Software Architecture**
   - Review the current driver architecture in `docs/architecture.md`
   - Understand the modular design principles
   - Know how components interact with each other
   - Verify alignment with Linux kernel standards

3. **Understand the Current Implementation**
   - Review existing code in the affected modules
   - Understand dependencies and relationships
   - Check for existing similar functionality
   - Verify the change fits the current patterns

## Project Objectives - Stay Focused

**PRIMARY OBJECTIVE**: Create a working Linux kernel driver for fingerprint scanners through reverse engineering.

**SECONDARY OBJECTIVES**:
- Maintain compatibility across multiple Linux distributions
- Follow Linux kernel development best practices
- Provide comprehensive documentation
- Ensure modular, maintainable code

## What This Project IS:
- A Linux kernel module for fingerprint scanner hardware
- A reverse engineering project for interoperability
- A driver that integrates with existing Linux biometric frameworks
- A modular, well-documented codebase

## What This Project IS NOT:
- A general-purpose biometric library
- A user-space application
- A Windows compatibility layer
- A machine learning or AI project

## Required Checks Before Any Changes

1. **Relevance Check**: Does this change directly contribute to fingerprint scanner driver functionality?
2. **Architecture Check**: Does this change align with the documented architecture?
3. **Duplication Check**: Does similar functionality already exist?
4. **Scope Check**: Is this change within the project's defined scope?
5. **Hardware Check**: Is this change compatible with the target hardware?

## Context Questions to Ask

Before implementing any feature or fix, ask:
- "How does this relate to fingerprint scanner operation?"
- "What hardware component does this interact with?"
- "How does this fit into the existing driver architecture?"
- "Are there existing patterns I should follow?"
- "What documentation needs to be updated?"

## Integration Points

This driver must integrate with:
- Linux USB subsystem (if USB device)
- Linux input subsystem
- libfprint framework
- PAM authentication system
- Kernel security frameworks

## Hardware-Specific Considerations

Always consider:
- Power management requirements
- Timing constraints for hardware operations
- Error handling for hardware failures
- Concurrency and thread safety
- Memory management for DMA operations
- Interrupt handling (if applicable)

## Failure to Follow Context Requirements

If you proceed without proper context understanding:
- Code changes may break existing functionality
- Architecture may become inconsistent
- Hardware compatibility may be compromised
- Documentation will become outdated
- Project scope may drift from objectives

## Context Verification Checklist

Before any significant change, verify:
- [ ] I understand what hardware this affects
- [ ] I've reviewed the relevant documentation
- [ ] I've checked for existing similar functionality
- [ ] I understand how this fits the architecture
- [ ] I know what documentation needs updating
- [ ] This change serves the driver's primary purpose