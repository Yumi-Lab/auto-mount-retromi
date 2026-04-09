#!/usr/bin/env bash
# RetroMi — USB auto-mount installer
# Run as root to install the USB auto-mount service.

set -e

PATH="$PATH:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin:/sbin"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: run as root (sudo ./CONFIGURE.sh)"
    exit 1
fi

chmod 755 ./*.sh

# Install mount script
cp ./usb-mount.sh /usr/local/bin/usb-mount.sh
chmod 755 /usr/local/bin/usb-mount.sh

# Install systemd unit
cp ./usb-mount@.service /etc/systemd/system/usb-mount@.service

# Install udev rule (append only if not already present)
RULES_FILE="/etc/udev/rules.d/99-local.rules"
if ! grep -q "usb-mount" "${RULES_FILE}" 2>/dev/null; then
    cat ./99-local.rules.usb-mount >> "${RULES_FILE}"
fi

# Create mountpoint
mkdir -p /home/pi/RetroPie
chown pi:pi /home/pi/RetroPie

# Reload systemd and udev
systemctl daemon-reload
udevadm control --reload-rules

echo "RetroMi USB auto-mount installed."
echo "Plug in a USB drive to test."
