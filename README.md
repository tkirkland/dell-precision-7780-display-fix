# Dell Precision 7780 Display Priority Fix

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org/)
[![Desktop: KScreen Compatible](https://img.shields.io/badge/Desktop-KScreen%20Compatible-1d99f3.svg)](https://invent.kde.org/plasma/kscreen)

A hardware-specific fix for Dell Precision 7780 laptops that resolves display priority issues when using NVIDIA discrete graphics with KScreen-compatible desktop environments on Debian-based Linux distributions.

## 🔧 Problem

When booting a Dell Precision 7780 with an external display connected via HDMI, the display management system incorrectly assigns the external display as primary (priority 1) instead of the internal laptop display (eDP-1). This causes:

- Desktop appearing on external display instead of laptop screen
- Window management issues in multi-monitor setups  
- User interface elements appearing on wrong display

## ✨ Solution

This project provides a unified `display_priority_manager` executable that:

- **Automatically detects** Dell Precision 7780 + NVIDIA discrete graphics
- **Corrects display priorities** at boot via systemd service
- **Uses kscreen-doctor** for reliable priority management
- **Provides multiple operation modes** for different use cases
- **Includes comprehensive logging** and error handling

## 🚀 Quick Start

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/dell-precision-7780-display-fix.git
cd dell-precision-7780-display-fix

# Build and install
make
sudo make install

# Enable the fix
sudo systemctl daemon-reload
sudo systemctl enable display-priority-fix.service
```

### Verification

```bash
# Check if your hardware is supported
display_priority_manager --mode check --verbose

# View current display configuration
display_priority_manager --mode check --force --verbose
```

## 📋 Requirements

### Hardware Requirements
- **Dell Precision 7780** laptop
- **NVIDIA discrete graphics** (Intel graphics disabled in BIOS)
- **Multiple displays** connected (internal + external)

### Software Requirements
- **KScreen-compatible desktop environment** (KDE Plasma, or other DE with KScreen support)
- **kscreen-doctor** command-line tool (usually from kscreen or plasma-workspace packages)
- **systemd** for service management
- **Linux kernel** with DRM support

### Supported Distributions
- Ubuntu 22.04+ with KDE Plasma or KScreen support
- Debian 12+ with KDE Plasma or KScreen support  
- Other Debian-based distributions with KScreen-compatible desktop environments

## 🎛️ Usage

### Command Line Options

```bash
display_priority_manager [OPTIONS]

Options:
  -m, --mode MODE      Fix mode: auto, kscreen, check, config, library, daemon
  -v, --verbose        Enable verbose output
  -d, --debug          Enable debug output
  -f, --force          Force fix even if hardware doesn't match
  -n, --dry-run        Show what would be done without making changes
  -r, --retries N      Maximum retry attempts (default: 3)
  -w, --wait SECONDS   Wait time between retries (default: 5)
  -l, --log FILE       Log file path (default: /tmp/display_priority_manager.log)
  -s, --syslog         Use syslog for logging
  -h, --help           Show help message
  -V, --version        Show version information
```

### Operation Modes

- **auto** - Automatically select best method (default)
- **kscreen** - Use kscreen-doctor to set priorities
- **check** - Check current configuration without fixing
- **config** - Monitor and modify config files (future)
- **library** - Use LD_PRELOAD injection (future)
- **daemon** - Run as monitoring daemon (future)

### Examples

```bash
# Check current display setup
display_priority_manager --mode check --verbose

# Apply fix manually with verbose output
sudo display_priority_manager --verbose

# Test fix without making changes
display_priority_manager --dry-run --force

# Apply fix with custom retry settings
sudo display_priority_manager --retries 5 --wait 10
```

## 🔍 Troubleshooting

### Check Hardware Detection
```bash
display_priority_manager --mode check --verbose
```

### View Service Status
```bash
systemctl status display-priority-fix.service
```

### Check Logs
```bash
# Service logs
journalctl -u display-priority-fix.service

# Manager logs
tail -f /var/log/display_priority_manager.log
```

### Manual Fix
```bash
sudo display_priority_manager --force --verbose
```

## 📦 Installation Methods

### Method 1: From Source
```bash
git clone https://github.com/yourusername/dell-precision-7780-display-fix.git
cd dell-precision-7780-display-fix
make
sudo make install
```

### Method 2: Debian Package
```bash
# Build package
make package

# Install package
sudo dpkg -i dell-precision-7780-display-fix_*.deb
```

### Method 3: ISO Integration
```bash
# For system integrators
sudo ./scripts/install_to_iso.sh /path/to/chroot
```

## 🏗️ Development

### Building
```bash
make clean
make all
```

### Testing
```bash
make test
```

### Creating Packages
```bash
make package
```

## 📁 Project Structure

```
├── src/                     # Source code
│   └── display_priority_manager.c
├── scripts/                 # Build and deployment scripts
│   ├── create_deb_package.sh
│   └── install_to_iso.sh
├── docs/                    # Documentation
│   ├── INSTALL.md
│   └── CLAUDE.md
├── display-priority-fix.service  # Systemd service
├── Makefile                 # Build system
├── README.md               # This file
├── LICENSE                 # MIT License
└── .gitignore              # Git ignore rules
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This software is specifically designed for Dell Precision 7780 laptops with NVIDIA discrete graphics. Use on other hardware configurations is not supported and may have unintended effects.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/dell-precision-7780-display-fix/issues)
- **Documentation**: [docs/](docs/)
- **Hardware Requirements**: Dell Precision 7780 + NVIDIA discrete + KScreen support

---

**Note**: This fix only activates on hardware that meets ALL specified requirements. The solution includes comprehensive hardware detection to prevent activation on unsupported systems.