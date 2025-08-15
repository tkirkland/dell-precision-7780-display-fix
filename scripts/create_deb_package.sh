#!/bin/bash

# Create Debian package for Dell Precision 7780 Display Priority Fix

set -e

PACKAGE_NAME="dell-precision-7780-display-fix"
VERSION="2.0.0"
ARCHITECTURE="amd64"
MAINTAINER="System Administrator <admin@example.com>"
DESCRIPTION="Display priority fix for Dell Precision 7780 with NVIDIA discrete graphics"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/deb-build"
PKG_DIR="$BUILD_DIR/${PACKAGE_NAME}_${VERSION}_${ARCHITECTURE}"

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

cleanup() {
    if [[ -d "$BUILD_DIR" ]]; then
        rm -rf "$BUILD_DIR"
    fi
}

create_package_structure() {
    log "Creating package structure..."
    
    mkdir -p "$PKG_DIR"/{DEBIAN,usr/local/bin,usr/local/lib,etc/systemd/system,usr/share/doc/$PACKAGE_NAME}
    
    # Create DEBIAN/control file
    cat > "$PKG_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCHITECTURE
Depends: systemd, plasma-workspace
Maintainer: $MAINTAINER
Description: $DESCRIPTION
 This package provides a fix for the display priority issue on Dell Precision 7780
 laptops with NVIDIA discrete graphics. The fix ensures that the internal display
 (eDP-1) is always set as the primary display on boot, preventing the external
 display from incorrectly becoming primary.
 .
 The fix includes:
  - Hardware detection to only activate on affected systems
  - Systemd service for automatic activation
  - Unified executable with multiple operation modes
  - ISO integration support for live/installation media
Homepage: https://github.com/example/dell-precision-display-fix
EOF

    # Create postinst script
    cat > "$PKG_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

case "$1" in
    configure)
        # Reload systemd and enable service
        systemctl daemon-reload
        
        # Test hardware detection
        if /usr/local/bin/display_priority_manager --mode check --force >/dev/null 2>&1; then
            echo "Dell Precision 7780 detected - enabling display priority fix"
            systemctl enable display-priority-fix.service
        else
            echo "Dell Precision 7780 not detected - service will remain disabled"
        fi
        
        # Update ld cache
        ldconfig
        ;;
esac

exit 0
EOF

    # Create prerm script
    cat > "$PKG_DIR/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e

case "$1" in
    remove|upgrade|deconfigure)
        # Disable and stop service
        if systemctl is-enabled display-priority-fix.service >/dev/null 2>&1; then
            systemctl disable display-priority-fix.service
        fi
        
        if systemctl is-active display-priority-fix.service >/dev/null 2>&1; then
            systemctl stop display-priority-fix.service
        fi
        ;;
esac

exit 0
EOF

    # Create postrm script
    cat > "$PKG_DIR/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

case "$1" in
    remove)
        # Clean up any remaining files
        rm -f /tmp/display_priority_manager.log
        rm -f /tmp/display_priority_manager.lock
        
        # Reload systemd
        systemctl daemon-reload
        
        # Update ld cache
        ldconfig
        ;;
    purge)
        # Remove configuration files
        rm -f /tmp/display_priority_manager.log
        rm -f /tmp/display_priority_manager.lock
        ;;
esac

exit 0
EOF

    chmod 755 "$PKG_DIR/DEBIAN"/{postinst,prerm,postrm}
}

build_and_copy_files() {
    log "Building source files..."
    
    # Build in the project root directory
    cd "$PROJECT_DIR"
    make clean
    make all
    
    # Copy binary
    cp display_priority_manager "$PKG_DIR/usr/local/bin/"
    
    # Copy systemd service
    cp display-priority-fix.service "$PKG_DIR/etc/systemd/system/"
    
    # Set permissions
    chmod 755 "$PKG_DIR/usr/local/bin"/*
    chmod 644 "$PKG_DIR/etc/systemd/system"/*.service
}

create_documentation() {
    log "Creating documentation..."
    
    cat > "$PKG_DIR/usr/share/doc/$PACKAGE_NAME/README.Debian" << 'EOF'
Dell Precision 7780 Display Priority Fix
========================================

This package provides a fix for a display priority issue on Dell Precision 7780
laptops with NVIDIA discrete graphics in KDE Plasma environments.

Problem
-------
When booting with an external display connected via HDMI, the system incorrectly
sets the external display as primary instead of the internal laptop display.

Solution
--------
The package provides a unified display_priority_manager executable with multiple modes:

1. Auto mode (default)
   - Automatically detects and applies the best fix method
   - Runs at boot via systemd service
   - Uses kscreen-doctor to correct priorities

2. Check mode
   - Shows current display configuration without making changes
   - Useful for troubleshooting and verification

3. Additional modes for advanced users
   - Config monitoring (future implementation)
   - Library injection (future implementation)
   - Daemon mode (future implementation)

Hardware Detection
------------------
The fix only activates on systems that meet ALL criteria:
- Dell Precision 7780 laptop
- NVIDIA discrete graphics (Intel disabled in BIOS)
- Multiple displays connected
- KDE Plasma desktop environment

Usage
-----
After installation, the fix will automatically activate if the hardware
requirements are met. No manual configuration is required.

To check if your hardware is supported and view current display configuration:
    /usr/local/bin/display_priority_manager --mode check --verbose

To view logs:
    journalctl -u display-priority-fix.service
    tail -f /var/log/display_priority_manager.log

Manual Control
--------------
Enable/disable the service manually:
    sudo systemctl enable display-priority-fix.service
    sudo systemctl disable display-priority-fix.service

Test the fix manually:
    sudo /usr/local/bin/display_priority_manager --verbose

Apply fix manually with force mode (for testing):
    sudo /usr/local/bin/display_priority_manager --force --verbose

Troubleshooting
---------------
If the fix doesn't work:
1. Check hardware detection: /usr/local/bin/display_priority_manager --mode check --verbose
2. Check service status: systemctl status display-priority-fix.service
3. Check logs: /var/log/display_priority_manager.log
4. Try manual execution: sudo /usr/local/bin/display_priority_manager --force --verbose

For support, please check the project homepage or contact your system administrator.
EOF

    cat > "$PKG_DIR/usr/share/doc/$PACKAGE_NAME/changelog.Debian" << EOF
$PACKAGE_NAME ($VERSION) unstable; urgency=low

  * Initial release
  * Fixed display priority issue on Dell Precision 7780
  * Added hardware detection
  * Added systemd service integration
  * Added ISO integration support

 -- $MAINTAINER  $(date -R)
EOF

    gzip -9 "$PKG_DIR/usr/share/doc/$PACKAGE_NAME/changelog.Debian"
    
    # Create copyright file
    cat > "$PKG_DIR/usr/share/doc/$PACKAGE_NAME/copyright" << 'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: dell-precision-7780-display-fix
Source: https://github.com/example/dell-precision-display-fix

Files: *
Copyright: 2024 System Administrator <admin@example.com>
License: GPL-3+

License: GPL-3+
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 .
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <https://www.gnu.org/licenses/>.
 .
 On Debian systems, the complete text of the GNU General
 Public License version 3 can be found in "/usr/share/common-licenses/GPL-3".
EOF
}

build_package() {
    log "Building Debian package..."
    
    cd "$BUILD_DIR"
    dpkg-deb --build "${PACKAGE_NAME}_${VERSION}_${ARCHITECTURE}"
    
    local deb_file="${PACKAGE_NAME}_${VERSION}_${ARCHITECTURE}.deb"
    
    if [[ -f "$deb_file" ]]; then
        log "Package built successfully: $deb_file"
        
        # Move to project root directory
        mv "$deb_file" "$PROJECT_DIR/"
        
        # Show package info
        log "Package information:"
        dpkg-deb --info "$PROJECT_DIR/$deb_file"
        
        log "Package contents:"
        dpkg-deb --contents "$PROJECT_DIR/$deb_file"
        
        return 0
    else
        log "Package build failed"
        return 1
    fi
}

main() {
    log "Creating Debian package for Dell Precision 7780 Display Priority Fix"
    
    # Clean up any previous builds
    cleanup
    
    create_package_structure
    build_and_copy_files
    create_documentation
    build_package
    
    # Clean up build directory
    cleanup
    
    log "Debian package creation completed successfully!"
    log "Package file: $PROJECT_DIR/${PACKAGE_NAME}_${VERSION}_${ARCHITECTURE}.deb"
    log ""
    log "To install:"
    log "  sudo dpkg -i ${PACKAGE_NAME}_${VERSION}_${ARCHITECTURE}.deb"
    log "  sudo apt-get install -f  # if dependencies are missing"
}

main "$@"