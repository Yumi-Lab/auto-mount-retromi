# auto-mount-retromi

USB auto-mount service for [RetroMi](https://github.com/Yumi-Lab/RetroMi) — the Armbian-based retro gaming OS for SmartPi One.

## What it does

- Automatically mounts USB drives on `/home/pi/RetroPie` when plugged in
- On first plug of a new drive: creates the full ROM folder structure and a bilingual (FR/EN) user README on the drive
- Handles multi-partition USB drives (only first mountable partition is used)
- Unmounts cleanly on unplug

## How it works

| Component | Role |
|---|---|
| `99-local.rules` | udev rule — triggers on USB block device plug/unplug |
| `usb-mount@.service` | systemd oneshot — calls `usb-mount.sh` |
| `usb-mount.sh` | mount/unmount logic + ROM structure initialization |

## Install

Installed automatically during the RetroMi image build. To install manually:

```bash
git clone https://github.com/Yumi-Lab/auto-mount-retromi.git
cd auto-mount-retromi/
sudo ./CONFIGURE.sh
```

## Uninstall

```bash
sudo ./REMOVE.sh
```

## ROM structure created on new drives

```
/  (USB root = /home/pi/RetroPie)
├── roms/
│   ├── nes/
│   ├── snes/
│   ├── megadrive/
│   ├── psx/
│   └── ... (all supported systems)
├── BIOS/
└── RetroMi-README.md   ← bilingual user guide
```

## Logs

```bash
journalctl -t usb-mount
# or
grep usb-mount /var/log/messages
```

Mount tracking: `/var/log/usb-mount.track`
