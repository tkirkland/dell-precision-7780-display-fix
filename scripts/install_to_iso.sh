#!/bin/bash

# ISO Integration Script for Dell Precision 7780 Display Priority Fix
# This script integrates the fix into a Debian-based ISO build process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_CHROOT=""
FIX_NAME="display-priority-fix"

usage() {
    echo "Usage: $0 [OPTIONS] <iso-chroot-path>"
    echo ""
    echo "Integrates Dell Precision 7780 display priority fix into ISO"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo "  -v, --verbose Enable verbose output"
    echo ""
    echo "Arguments:"
    echo "  iso-chroot-path  Path to the ISO chroot environment"
    echo ""
    echo "Example:"
    echo "  $0 /tmp/iso-build/chroot"
}

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

error() {
    echo "ERROR: $*" >&2
    exit 1
}

check_chroot() {
    local chroot_path="$1"
    
    if [[ ! -d "$chroot_path" ]]; then
        error "Chroot directory does not exist: $chroot_path"
    fi
    
    if [[ ! -f "$chroot_path/bin/bash" ]]; then
        error "Invalid chroot environment: $chroot_path"
    fi
    
    log "Chroot environment validated: $chroot_path"
}

install_to_chroot() {
    local chroot_path="$1"
    
    log "Installing display priority fix to chroot..."
    
    # Create temporary directory in chroot
    local temp_dir="$chroot_path/tmp/$FIX_NAME"
    mkdir -p "$temp_dir"
    
    # Copy source files
    cp "$SCRIPT_DIR"/*.c "$temp_dir/"
    cp "$SCRIPT_DIR"/*.cpp "$temp_dir/"
    cp "$SCRIPT_DIR"/*.sh "$temp_dir/"
    cp "$SCRIPT_DIR"/*.service "$temp_dir/"
    cp "$SCRIPT_DIR"/Makefile "$temp_dir/"
    
    # Create build script for chroot
    cat > "$temp_dir/build_in_chroot.sh" << 'EOF'
#!/bin/bash
set -e

cd /tmp/display-priority-fix

# Install build dependencies
apt-get update
apt-get install -y build-essential gcc g++ libc6-dev

# Build the fix
make all

# Install system-wide
make install

# Enable the systemd service
systemctl enable display-priority-fix.service

# Create ld.so.conf entry for the library
echo "/usr/local/lib" > /etc/ld.so.conf.d/display-priority-fix.conf
ldconfig

# Clean up build files
make clean

echo "Display Priority Fix installed successfully in chroot"
EOF
    
    chmod +x "$temp_dir/build_in_chroot.sh"
    
    # Execute build in chroot
    log "Building and installing in chroot environment..."
    chroot "$chroot_path" /tmp/$FIX_NAME/build_in_chroot.sh
    
    # Clean up
    rm -rf "$temp_dir"
    
    log "Installation to chroot completed successfully"
}

create_iso_hook() {
    local chroot_path="$1"
    
    log "Creating ISO customization hook..."
    
    # Create hook script that runs on first boot
    cat > "$chroot_path/usr/local/bin/first-boot-display-fix.sh" << 'EOF'
#!/bin/bash

# First boot hook for display priority fix
LOG_FILE="/var/log/first-boot-display-fix.log"

{
    echo "=== First Boot Display Priority Fix Setup ==="
    echo "Date: $(date)"
    echo "Hardware: $(cat /sys/class/dmi/id/sys_vendor) $(cat /sys/class/dmi/id/product_name)"
    
    # Test hardware detection
    if /usr/local/bin/hardware_detection_test; then
        echo "Hardware check passed - fix will be active"
        
        # Ensure service is enabled for all users
        systemctl enable display-priority-fix.service
        
        # Create user-specific service instances if needed
        if [[ -d /home ]]; then
            for user_home in /home/*; do
                if [[ -d "$user_home" ]]; then
                    username=$(basename "$user_home")
                    echo "Setting up display fix for user: $username"
                    
                    # The main service should handle this, but we can add user-specific
                    # configuration here if needed
                fi
            done
        fi
    else
        echo "Hardware check failed - fix will not be active"
    fi
    
    echo "First boot setup completed"
    
    # Remove this script after first run
    rm -f /usr/local/bin/first-boot-display-fix.sh
    systemctl disable first-boot-display-fix.service
    rm -f /etc/systemd/system/first-boot-display-fix.service
    
} >> "$LOG_FILE" 2>&1
EOF
    
    chmod +x "$chroot_path/usr/local/bin/first-boot-display-fix.sh"
    
    # Create systemd service for first boot
    cat > "$chroot_path/etc/systemd/system/first-boot-display-fix.service" << 'EOF'
[Unit]
Description=First Boot Display Priority Fix Setup
After=multi-user.target
Before=display-manager.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/first-boot-display-fix.sh
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable first boot service
    chroot "$chroot_path" systemctl enable first-boot-display-fix.service
    
    log "First boot hook created successfully"
}

validate_installation() {
    local chroot_path="$1"
    
    log "Validating installation..."
    
    # Check if files are installed
    local files=(
        "/usr/local/bin/display_priority_fix.sh"
        "/usr/local/bin/hardware_detection_test"
        "/usr/local/lib/libdisplay_priority_override.so"
        "/etc/systemd/system/display-priority-fix.service"
    )
    
    for file in "${files[@]}"; do
        if [[ ! -f "$chroot_path$file" ]]; then
            error "Missing file in chroot: $file"
        fi
    done
    
    # Test hardware detection binary
    if ! chroot "$chroot_path" /usr/local/bin/hardware_detection_test >/dev/null 2>&1; then
        log "Warning: Hardware detection test failed in chroot (expected if not Dell hardware)"
    fi
    
    log "Installation validation completed"
}

main() {
    local verbose=0
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                verbose=1
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [[ -z "$ISO_CHROOT" ]]; then
                    ISO_CHROOT="$1"
                else
                    error "Too many arguments"
                fi
                shift
                ;;
        esac
    done
    
    if [[ -z "$ISO_CHROOT" ]]; then
        error "ISO chroot path required"
    fi
    
    if [[ $verbose -eq 1 ]]; then
        set -x
    fi
    
    log "Starting ISO integration for Dell Precision 7780 Display Priority Fix"
    log "Target chroot: $ISO_CHROOT"
    
    check_chroot "$ISO_CHROOT"
    install_to_chroot "$ISO_CHROOT"
    create_iso_hook "$ISO_CHROOT"
    validate_installation "$ISO_CHROOT"
    
    log "ISO integration completed successfully!"
    log ""
    log "The display priority fix is now integrated into the ISO."
    log "On Dell Precision 7780 systems with NVIDIA discrete graphics,"
    log "the fix will automatically activate during first boot."
}

main "$@"