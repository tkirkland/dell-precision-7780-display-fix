# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This is a hardware-specific fix for Dell Precision 7780 laptops that incorrectly prioritize external displays over internal displays when using KDE Plasma with NVIDIA discrete graphics. The fix ensures the internal display (eDP-1) always gets priority 1.

## Build Commands

```bash
# Build all components
make all

# Build and test hardware detection
make test

# Development testing with LD_PRELOAD
make dev-test

# Create Debian package
./create_deb_package.sh

# Create tar.gz distribution
make package

# Clean build artifacts
make clean
```

## Installation Commands

```bash
# Install system-wide
sudo make install

# Uninstall completely
sudo make uninstall

# Install from Debian package
sudo dpkg -i dell-precision-7780-display-fix_*.deb

# Integrate into ISO chroot
sudo ./install_to_iso.sh /path/to/chroot
```

## Testing Commands

```bash
# Test hardware detection
./hardware_detection_test

# Analyze current display setup
./analyze_display_priority.sh

# Test fix manually
sudo /usr/local/bin/display_priority_fix.sh

# Check service status
systemctl status display-priority-fix.service

# View logs
tail -f /tmp/display_priority_fix.log
journalctl -u display-priority-fix.service
```

## Architecture Overview

The solution implements a **three-layer approach** with **hardware-specific activation**:

### Layer 1: Hardware Detection (`hardware_detection.c`)
- DMI-based detection for Dell Precision 7780
- NVIDIA discrete GPU validation  
- Multi-display connection verification
- Only activates fix when ALL conditions are met

### Layer 2: Priority Correction Mechanisms
Three complementary approaches:

1. **Script-based Fix** (`display_priority_fix.sh`) - Primary approach
   - Uses `kscreen-doctor` to correct display priorities
   - Runs via systemd service at boot
   - Most reliable and tested method

2. **Library Interception** (`display_priority_override.c`) - Advanced
   - LD_PRELOAD library that intercepts KScreen function calls
   - Runtime priority override for experimental use
   - Hooks into `_ZNK7KScreen6Output8priorityEv` and related functions

3. **Configuration Monitor** (`kscreen_config_override.cpp`) - Alternative  
   - Monitors KScreen config files for changes
   - Modifies JSON configs before KScreen applies them
   - C++ implementation with inotify filesystem watching

### Layer 3: System Integration
- **Systemd Service**: Automatic activation at graphical session start
- **Debian Packaging**: Professional package with dependency management
- **ISO Integration**: Embeds fix into installation media for affected hardware

## Key Design Principles

**Hardware-Specific Activation**: Fix only runs on Dell Precision 7780 + NVIDIA discrete graphics to avoid affecting other systems.

**Multiple Fallback Approaches**: If the primary script-based fix fails, advanced users can try library interception or config monitoring.

**Zero Configuration**: Automatically detects hardware and activates - no user configuration required.

**Boot-Time Correction**: Runs early in boot process before user sees desktop to ensure correct display priorities from first login.

## Build Targets

The Makefile produces three main executables:
- `hardware_detection_test` - Standalone hardware detection binary
- `libdisplay_priority_override.so` - LD_PRELOAD shared library
- `kscreen_config_override` - Config file monitoring daemon

## Development Environment Variables

```bash
# Force hardware detection for testing on non-target systems
export FORCE_DELL_PRECISION_7780=1
export FORCE_NVIDIA_DISCRETE=1  
export FORCE_MULTIPLE_DISPLAYS=1

# Enable debug logging in scripts
export DEBUG=1
export VERBOSE=1

# Override fix behavior
export FORCE_DISPLAY_FIX=1      # Force enable
export DISABLE_DISPLAY_FIX=1    # Force disable
```

## Log File Locations

- `/tmp/display_priority_fix.log` - Main fix script output
- `/tmp/kscreen_priority_override.log` - Config monitor output  
- `/var/log/first-boot-display-fix.log` - ISO integration logs
- System journal: `journalctl -u display-priority-fix.service`

## Critical Implementation Details

**KScreen Priority Range**: Valid priorities are 1-100, with 1 being primary display.

**Target Display Names**: 
- Internal: `eDP-1`, `eDP-2`, `LVDS-1`
- External: `HDMI-A-1`, `HDMI-A-2`, `DP-1`, `DP-2`

**Systemd Service Timing**: Runs after `graphical-session.target` but before `plasma-workspace.service` to catch the display configuration early.

**Library Symbol Interception**: Hooks mangled C++ symbols from KScreen library using `dlsym` interception in the LD_PRELOAD approach.