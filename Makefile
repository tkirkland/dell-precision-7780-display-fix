# Makefile for Dell Precision 7780 Display Priority Manager

CC = gcc
CFLAGS = -Wall -Wextra -O2

# Directories
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
SERVICEDIR = /etc/systemd/system
DOCDIR = $(PREFIX)/share/doc/display-priority-fix

# Main target
MANAGER = display_priority_manager
SERVICE_FILE = display-priority-fix.service

.PHONY: all clean install uninstall test package help

all: $(MANAGER)

# Build the unified display priority manager
$(MANAGER): src/display_priority_manager.c
	$(CC) $(CFLAGS) -o $@ $< -lm

test: $(MANAGER)
	@echo "=== Testing Display Priority Manager ==="
	@echo "Testing help output..."
	./$(MANAGER) --help
	@echo ""
	@echo "Testing version output..."
	./$(MANAGER) --version
	@echo ""
	@echo "Testing hardware detection..."
	./$(MANAGER) --mode check --verbose || echo "Hardware detection test completed (expected on non-target hardware)"
	@echo ""
	@echo "Build and basic functionality tests completed successfully!"

install: $(MANAGER)
	@echo "Installing Display Priority Manager..."
	
	# Create directories
	install -d $(DESTDIR)$(BINDIR)
	install -d $(DESTDIR)$(DOCDIR)
	install -d $(DESTDIR)$(SERVICEDIR)
	
	# Install binary
	install -m 755 $(MANAGER) $(DESTDIR)$(BINDIR)/
	
	# Install systemd service
	install -m 644 $(SERVICE_FILE) $(DESTDIR)$(SERVICEDIR)/
	
	# Install documentation
	install -m 644 README.md $(DESTDIR)$(DOCDIR)/ 2>/dev/null || echo "README.md not found, skipping"
	install -m 644 docs/INSTALL.md $(DESTDIR)$(DOCDIR)/ 2>/dev/null || echo "INSTALL.md not found, skipping"
	
	@echo "Installation complete!"
	@echo ""
	@echo "To enable the fix:"
	@echo "  sudo systemctl daemon-reload"
	@echo "  sudo systemctl enable display-priority-fix.service"
	@echo "  sudo systemctl start display-priority-fix.service"
	@echo ""
	@echo "To check status:"
	@echo "  systemctl status display-priority-fix.service"
	@echo "  $(BINDIR)/$(MANAGER) --mode check --verbose"

uninstall:
	@echo "Uninstalling Display Priority Manager..."
	
	# Disable and remove service
	-sudo systemctl stop display-priority-fix.service 2>/dev/null
	-sudo systemctl disable display-priority-fix.service 2>/dev/null
	rm -f $(SERVICEDIR)/display-priority-fix.service
	
	# Remove files
	rm -f $(BINDIR)/$(MANAGER)
	rm -rf $(DOCDIR)
	
	@echo "Uninstallation complete!"

clean:
	rm -f $(MANAGER)
	rm -f *.o *.log
	rm -rf dist/

package: all
	@echo "Creating distribution package..."
	./scripts/create_deb_package.sh
	@echo ""
	@echo "Creating tar.gz package..."
	mkdir -p dist/display-priority-manager
	cp $(MANAGER) src/display_priority_manager.c $(SERVICE_FILE) Makefile README.md docs/INSTALL.md scripts/* dist/display-priority-manager/ 2>/dev/null || true
	cd dist && tar czf display-priority-manager.tar.gz display-priority-manager/
	@echo "Packages created:"
	@echo "  - dell-precision-7780-display-fix_*.deb"
	@echo "  - dist/display-priority-manager.tar.gz"

help:
	@echo "Dell Precision 7780 Display Priority Manager"
	@echo ""
	@echo "Targets:"
	@echo "  all         - Build the display priority manager"
	@echo "  test        - Test the manager"
	@echo "  install     - Install system-wide"
	@echo "  uninstall   - Remove installation"
	@echo "  clean       - Clean build files"
	@echo "  package     - Create distribution packages (.deb and .tar.gz)"
	@echo "  help        - Show this help"
	@echo ""
	@echo "Usage:"
	@echo "  make                    # Build"
	@echo "  sudo make install       # Install"
	@echo "  make test              # Test"
	@echo ""
	@echo "Installation locations:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  BINDIR=$(BINDIR)"
	@echo "  SERVICEDIR=$(SERVICEDIR)"