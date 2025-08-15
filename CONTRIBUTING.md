# Contributing to Dell Precision 7780 Display Priority Fix

Thank you for your interest in contributing! This project specifically targets Dell Precision 7780 laptops with NVIDIA discrete graphics, so testing requires specific hardware.

## 🔧 Development Setup

### Prerequisites
- Dell Precision 7780 laptop (for testing)
- NVIDIA discrete graphics enabled
- KDE Plasma desktop environment
- Debian-based Linux distribution

### Build Environment
```bash
sudo apt-get install build-essential gcc make
git clone https://github.com/yourusername/dell-precision-7780-display-fix.git
cd dell-precision-7780-display-fix
make
```

## 🧪 Testing

### Hardware Testing
- Test on actual Dell Precision 7780 hardware
- Test with external displays connected via HDMI
- Test with different display configurations

### Software Testing
```bash
# Test hardware detection
make test

# Test build system
make clean && make all

# Test packaging
make package
```

## 📝 Code Style

- Use consistent C coding style
- Add comments for complex logic
- Follow existing patterns in the codebase
- Test all changes on target hardware

## 🐛 Bug Reports

Include the following information:
- Hardware model and configuration
- Linux distribution and version
- KDE Plasma version
- Display configuration
- Relevant log files

## 💡 Feature Requests

- Explain the use case
- Consider hardware compatibility
- Provide implementation details if possible

## 📋 Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Test on actual hardware
4. Update documentation if needed
5. Submit pull request with detailed description

## ⚠️ Hardware Requirements

This project only supports Dell Precision 7780 laptops. Contributions for other hardware should create separate projects to avoid conflicts.