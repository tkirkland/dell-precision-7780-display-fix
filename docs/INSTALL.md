# Installation Guide

Complete installation guide for the Dell Precision 7780 Display Priority Fix.

## Prerequisites

### System Requirements
- Dell Precision 7780 laptop
- NVIDIA discrete graphics (Intel disabled in BIOS)
- Debian-based Linux distribution (Ubuntu, Kubuntu, etc.)
- KDE Plasma desktop environment
- systemd init system

### Build Dependencies
```bash
sudo apt-get update
sudo apt-get install build-essential gcc g++ libc6-dev make
```

## Installation Methods

### Method 1: Debian Package (Recommended)

Most users should use this method for automatic installation and management.

```bash
# 1. Download/clone the source
git clone <repository-url>
cd dell-precision-7780-display-fix

# 2. Build the Debian package
make all
./create_deb_package.sh

# 3. Install the package
sudo dpkg -i dell-precision-7780-display-fix_1.0.0_amd64.deb

# 4. Fix any dependency issues (if needed)
sudo apt-get install -f

# 5. Verify installation
systemctl status display-priority-fix.service
/usr/local/bin/display_priority_manager --mode check
```

**What this installs:**
- Unified display priority manager to `/usr/local/bin/display_priority_manager`
- Systemd service to `/etc/systemd/system/display-priority-fix.service`
- Documentation to `/usr/share/doc/dell-precision-7780-display-fix/`

**Automatic behavior:**
- Hardware detection runs during package installation
- Service is enabled automatically on compatible hardware
- Service starts automatically on boot

### Method 2: Manual Installation

For advanced users who want more control over the installation.

```bash
# 1. Build all components
make all

# 2. Install system-wide
sudo make install

# 3. Reload systemd and enable service
sudo systemctl daemon-reload

# 4. Test hardware detection
./build/display_priority_manager --mode check

# 5. Enable service if hardware is compatible
sudo systemctl enable display-priority-fix.service

# 6. Update library cache
sudo ldconfig
```

**Custom installation paths:**
```bash
# Install to custom prefix
sudo make install PREFIX=/opt/display-fix

# Install only specific components
sudo make install-scripts  # Scripts only
sudo make install-service  # Service only
```

### Method 3: Development Installation

For developers working on the fix.

```bash
# 1. Build in development mode
make dev

# 2. Test without installation
./build/display_priority_manager --mode check

# 3. Install for testing
make install PREFIX=/usr/local/dev

# 4. Test the fix manually
sudo /usr/local/dev/bin/display_priority_manager
```

### Method 4: ISO Integration

For distribution builders who want to include the fix in ISO images.

```bash
# 1. Prepare the source
make clean && make all

# 2. Integrate into ISO chroot
sudo ./install_to_iso.sh /path/to/iso/chroot

# 3. Complete ISO build process
# The fix will activate automatically on Dell Precision 7780 systems
```

## Post-Installation

### Verification Steps

1. **Check hardware detection:**
   ```bash
   /usr/local/bin/display_priority_manager --mode check
   ```
   Expected output:
   ```
   Hardware Detection Results:
     Dell Precision 7780: YES
     NVIDIA Discrete: YES
     Wayland Session: YES
     Multiple Displays: YES
     Should Apply Fix: YES
   ```

2. **Check service status:**
   ```bash
   systemctl status display-priority-fix.service
   ```
   Expected: `enabled` (if hardware compatible)

3. **Test display priorities:**
   ```bash
   kscreen-doctor -o
   ```
   Expected: eDP-1 should have priority 1

### Configuration

The fix works automatically without configuration on compatible hardware. However, you can customize behavior:

#### Enable/Disable Service
```bash
# Disable (even on compatible hardware)
sudo systemctl disable display-priority-fix.service

# Enable (force on any hardware)
sudo systemctl enable display-priority-fix.service

# Start immediately
sudo systemctl start display-priority-fix.service
```

#### Custom Hardware Detection
```bash
# Force enable on any hardware (for testing)
export FORCE_DISPLAY_FIX=1
sudo /usr/local/bin/display_priority_manager

# Force disable on compatible hardware
export DISABLE_DISPLAY_FIX=1
```

#### Logging Configuration
```bash
# Enable debug logging
sudo systemctl edit display-priority-fix.service

# Add these lines:
[Service]
Environment="DEBUG=1"
Environment="VERBOSE=1"

# Apply changes
sudo systemctl daemon-reload
sudo systemctl restart display-priority-fix.service
```

## First Boot Behavior

### Live USB / Installation Media
If integrated into an ISO:
1. Hardware detection runs during boot
2. Service is enabled automatically on compatible systems
3. Display priorities are corrected before user sees desktop
4. Status is logged to `/var/log/first-boot-display-fix.log`

### Installed System
After installation on target hardware:
1. Service starts automatically with graphical session
2. Display priorities are checked and corrected if needed
3. Service runs once per boot (Type=oneshot)
4. Results logged to `/tmp/display_priority_fix.log`

## Troubleshooting Installation

### Build Failures

**Missing dependencies:**
```bash
# Install build tools
sudo apt-get install build-essential

# For C++ components
sudo apt-get install g++

# For systemd integration
sudo apt-get install systemd-dev
```

**Permission errors:**
```bash
# Ensure proper permissions
chmod +x *.sh
sudo chown root:root /etc/systemd/system/display-priority-fix.service
```

### Installation Issues

**Service not enabling:**
```bash
# Check systemd syntax
systemd-analyze verify display-priority-fix.service

# Manual enable
sudo systemctl enable display-priority-fix.service --force
```

**Library not found:**
```bash
# Update library cache
sudo ldconfig

# Check library path
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/local.conf
sudo ldconfig
```

**Permission denied:**
```bash
# Fix binary permissions
sudo chmod 755 /usr/local/bin/display_priority_manager

# Fix service permissions
sudo chmod 644 /etc/systemd/system/display-priority-fix.service
```

### Runtime Issues

**Hardware not detected:**
```bash
# Check DMI information
sudo dmidecode -s system-manufacturer
sudo dmidecode -s system-product-name

# Check NVIDIA driver
nvidia-smi
lsmod | grep nvidia
```

**Display priorities not changing:**
```bash
# Check KDE session
echo $XDG_SESSION_TYPE
echo $XDG_CURRENT_DESKTOP

# Test kscreen-doctor manually
kscreen-doctor output.eDP-1.priority.1

# Check for conflicting processes
ps aux | grep kscreen
```

## Uninstallation

### Debian Package
```bash
# Remove package
sudo apt-get remove dell-precision-7780-display-fix

# Remove configuration (purge)
sudo apt-get purge dell-precision-7780-display-fix

# Clean up any remaining files
sudo apt-get autoremove
```

### Manual Installation
```bash
# Use the uninstall target
sudo make uninstall

# Or remove manually
sudo systemctl disable display-priority-fix.service
sudo rm -f /etc/systemd/system/display-priority-fix.service
sudo rm -f /usr/local/bin/display_priority_manager
sudo systemctl daemon-reload
sudo ldconfig
```

### Clean Removal
```bash
# Remove all traces
sudo rm -f /tmp/display_priority_fix.log
sudo rm -f /tmp/display_priority_fix.lock
sudo rm -f /tmp/kscreen_priority_override.log
sudo rm -rf /usr/share/doc/dell-precision-7780-display-fix
```

## Maintenance

### Updates
```bash
# Pull latest changes
git pull

# Rebuild and reinstall
make clean && make all

# For Debian package users
./create_deb_package.sh
sudo dpkg -i dell-precision-7780-display-fix_*.deb
```

### Log Rotation
```bash
# Set up logrotate for fix logs
sudo tee /etc/logrotate.d/display-priority-fix << 'EOF'
/tmp/display_priority_fix.log {
    weekly
    missingok
    rotate 4
    compress
    notifempty
    create 644 root root
}
EOF
```

### Monitoring
```bash
# Monitor service status
sudo systemctl status display-priority-fix.service

# Monitor logs in real-time
tail -f /tmp/display_priority_fix.log

# Check system journal
journalctl -u display-priority-fix.service -f
```