# Driver Architecture

## Overview

This document describes the technical architecture of the FPC Fingerprint Scanner Driver for Linux.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Applications                        │
├─────────────────────────────────────────────────────────────┤
│                  Authentication Layer                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│  │     PAM     │ │   fprintd   │ │  libfprint  │          │
│  └─────────────┘ └─────────────┘ └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│                    Driver Layer                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐          │
│  │ User-Space  │ │  libfprint  │ │   Kernel    │          │
│  │   Library   │ │ Integration │ │   Module    │          │
│  └─────────────┘ └─────────────┘ └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│                   Hardware Layer                           │
│  ┌─────────────┐ ┌─────────────┐                          │
│  │   FPC1020   │ │   FPC1155   │                          │
│  └─────────────┘ └─────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Kernel Module (`fp_xiaomi_driver.c`)

**Purpose**: Core kernel driver for hardware communication
**Size**: 298 lines (under 300-line limit)

### 2. Error Recovery System (`fp_xiaomi_recovery.c`)

**Purpose**: Advanced error detection and recovery
**Size**: 287 lines

### 3. libfprint Integration (`fp_xiaomi_libfprint.c`)

**Purpose**: Integration with libfprint framework
**Size**: 245 lines

### 4. User-Space Library (`libfp_xiaomi.c`)

**Purpose**: User-space library for applications
**Size**: 234 lines

## Data Flow

### Enrollment Process

```
User Application → Desktop GUI → fprintd → libfprint → Kernel Module → Hardware
```

### Verification Process

```
PAM Module → fprintd → libfprint → Kernel Module → Hardware
```

## USB Protocol

The driver communicates with the fingerprint scanner using a custom USB protocol with command and response structures.

## Security Features

1. **Template Encryption**: Fingerprint templates are encrypted
2. **Secure Memory**: Sensitive data is cleared after use
3. **Access Control**: Proper permissions and user group management

## Error Handling

The driver includes comprehensive error detection and recovery mechanisms to ensure reliable operation.

## Build System

The driver is built using standard Linux kernel module build system and includes user-space components built with standard C toolchains.

## Installation Components

1. **Kernel Module**: Installed to kernel modules directory
2. **User-Space Library**: Installed to system libraries
3. **libfprint Plugin**: Integrated with libfprint
4. **Configuration**: udev rules and PAM configuration