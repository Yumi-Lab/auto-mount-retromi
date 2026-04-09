#!/usr/bin/env bash
# RetroMi — USB auto-mount
#
# Strategy:
#   1. Mount USB device on /media/retromi-DEVBASE
#   2. Initialize RetroMi/ subfolder on USB if missing (roms/, BIOS/, README)
#   3. Bind-mount USB/RetroMi/ → /home/pi/RetroPie so EmulationStation finds ROMs
#
# On the USB drive, the structure is:
#   USB/
#   └── RetroMi/
#       ├── roms/nes/, roms/snes/, ...
#       ├── BIOS/
#       └── RetroMi-README.md
#
# Called by systemd unit usb-mount@.service via udev rule 99-local.rules.
# Logs to /var/log/messages (tag: usb-mount).

PATH="$PATH:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin:/sbin"
log="logger -t usb-mount -s"

RETROPI_DIR="/home/pi/RetroPie"
MEDIA_BASE="/media"
TRACK_FILE="/var/log/usb-mount.track"

# ROM directories — mirrors RetroMi supported systems
ROM_DIRS=(
    nes snes megadrive mastersystem gamegear sega32x segacd sg-1000
    gb gbc gba nds n64
    psx psp
    atari2600 atari5200 atari7800 atarilynx atarist
    pcengine ngp ngpc wonderswan wonderswancolor
    arcade fba mame-libretro neogeo
    scummvm dosbox
    c64 msx zxspectrum amstradcpc amiga
    dreamcast saturn 3do jaguar
    vectrex coleco intellivision
    ports
)

if [[ $# -ne 2 ]]; then
    ${log} "Usage: $0 {add|remove} device_name (e.g. sda1)"
    exit 1
fi

ACTION=$1
DEVBASE=$2
DEVICE="/dev/${DEVBASE}"
MEDIA_MOUNT="${MEDIA_BASE}/retromi-${DEVBASE}"

create_readme() {
    local base="$1"
    cat > "${base}/RetroMi-README.md" << 'EOF'
# RetroMi — USB ROMs Drive / Clé USB ROMs

---

## 🇫🇷 Français

### Bienvenue sur votre clé USB RetroMi !

Cette clé est reconnue automatiquement par RetroMi au branchement.
Les jeux placés dans les dossiers ci-dessous apparaîtront dans EmulationStation.

### Comment ajouter des jeux

Copiez vos ROMs dans `RetroMi/roms/` sur cette clé :

| Dossier                      | Console                     |
|------------------------------|-----------------------------|
| `RetroMi/roms/nes/`          | Nintendo NES                |
| `RetroMi/roms/snes/`         | Super Nintendo              |
| `RetroMi/roms/megadrive/`    | Sega Mega Drive / Genesis   |
| `RetroMi/roms/mastersystem/` | Sega Master System          |
| `RetroMi/roms/gb/`           | Game Boy                    |
| `RetroMi/roms/gbc/`          | Game Boy Color              |
| `RetroMi/roms/gba/`          | Game Boy Advance            |
| `RetroMi/roms/n64/`          | Nintendo 64                 |
| `RetroMi/roms/psx/`          | PlayStation 1               |
| `RetroMi/roms/psp/`          | PlayStation Portable        |
| `RetroMi/roms/arcade/`       | Arcade (FBNeo / MAME)       |
| `RetroMi/roms/neogeo/`       | Neo Geo                     |
| `RetroMi/roms/dreamcast/`    | Sega Dreamcast              |
| `RetroMi/roms/scummvm/`      | ScummVM (aventure PC)       |
| `RetroMi/roms/dosbox/`       | DOS (DOSBox)                |
| `RetroMi/roms/ports/`        | Ports (Doom, Quake…)        |

### Fichiers BIOS

Placez les fichiers BIOS dans `RetroMi/BIOS/` :

| Fichier           | Console          |
|-------------------|------------------|
| `scph1001.bin`    | PlayStation 1    |
| `dc_boot.bin`     | Sega Dreamcast   |
| `neogeo.zip`      | Neo Geo          |
| `gba_bios.bin`    | Game Boy Advance |

### Formats supportés (principaux)

| Console    | Extensions                         |
|------------|------------------------------------|
| NES        | `.nes`                             |
| SNES       | `.sfc`, `.smc`                     |
| Mega Drive | `.md`, `.bin`, `.gen`              |
| GBA        | `.gba`                             |
| N64        | `.z64`, `.n64`, `.v64`             |
| PSX        | `.bin`+`.cue`, `.pbp`, `.chd`     |
| Arcade     | `.zip` (romset FBNeo ou MAME 0.78) |

### Débranchement sécurisé

Évitez de retirer la clé pendant qu'un jeu est en cours.
Éteignez la console depuis EmulationStation ou via le menu RetroPie.

---

## 🇬🇧 English

### Welcome to your RetroMi USB drive!

This drive is automatically detected by RetroMi when plugged in.
Games placed in the folders below will appear in EmulationStation.

### How to add games

Copy your ROMs into `RetroMi/roms/` on this drive:

| Folder                       | Console                     |
|------------------------------|-----------------------------|
| `RetroMi/roms/nes/`          | Nintendo NES                |
| `RetroMi/roms/snes/`         | Super Nintendo              |
| `RetroMi/roms/megadrive/`    | Sega Mega Drive / Genesis   |
| `RetroMi/roms/mastersystem/` | Sega Master System          |
| `RetroMi/roms/gb/`           | Game Boy                    |
| `RetroMi/roms/gbc/`          | Game Boy Color              |
| `RetroMi/roms/gba/`          | Game Boy Advance            |
| `RetroMi/roms/n64/`          | Nintendo 64                 |
| `RetroMi/roms/psx/`          | PlayStation 1               |
| `RetroMi/roms/psp/`          | PlayStation Portable        |
| `RetroMi/roms/arcade/`       | Arcade (FBNeo / MAME)       |
| `RetroMi/roms/neogeo/`       | Neo Geo                     |
| `RetroMi/roms/dreamcast/`    | Sega Dreamcast              |
| `RetroMi/roms/scummvm/`      | ScummVM (PC adventure games)|
| `RetroMi/roms/dosbox/`       | DOS games (DOSBox)          |
| `RetroMi/roms/ports/`        | Ports (Doom, Quake…)        |

### BIOS files

Place BIOS files in `RetroMi/BIOS/`:

| File              | Console          |
|-------------------|------------------|
| `scph1001.bin`    | PlayStation 1    |
| `dc_boot.bin`     | Sega Dreamcast   |
| `neogeo.zip`      | Neo Geo          |
| `gba_bios.bin`    | Game Boy Advance |

### Supported formats (main)

| Console    | Extensions                         |
|------------|------------------------------------|
| NES        | `.nes`                             |
| SNES       | `.sfc`, `.smc`                     |
| Mega Drive | `.md`, `.bin`, `.gen`              |
| GBA        | `.gba`                             |
| N64        | `.z64`, `.n64`, `.v64`             |
| PSX        | `.bin`+`.cue`, `.pbp`, `.chd`     |
| Arcade     | `.zip` (FBNeo or MAME 0.78 romset) |

### Safe removal

Avoid unplugging the drive while a game is running.
Power off from EmulationStation or the RetroPie menu.

---
RetroMi — https://github.com/Yumi-Lab/RetroMi
EOF
}

do_mount() {
    # Guard: device already mounted
    if mount | grep -q "^${DEVICE} "; then
        ${log} "Warning: ${DEVICE} already mounted, skipping"
        exit 0
    fi

    # Guard: RetroPie bind already active (multi-partition USB)
    if mount | grep -q " ${RETROPI_DIR} "; then
        ${log} "Info: ${RETROPI_DIR} already bound, skipping ${DEVICE}"
        exit 0
    fi

    # Get filesystem info
    eval "$(blkid -o udev "${DEVICE}" | grep -iE "ID_FS_LABEL|ID_FS_TYPE")"

    case "${ID_FS_TYPE}" in
        vfat|exfat|ext2|ext3|ext4) ;;
        *)
            ${log} "Unsupported filesystem '${ID_FS_TYPE}' on ${DEVICE}, skipping"
            exit 0
            ;;
    esac

    # Step 1: mount USB on /media/retromi-DEVBASE
    mkdir -p "${MEDIA_MOUNT}"
    OPTS="rw,relatime"
    if [[ "${ID_FS_TYPE}" == "vfat" ]]; then
        OPTS+=",users,gid=100,umask=000,shortname=mixed,utf8=1,flush"
    fi

    if ! mount -o "${OPTS}" "${DEVICE}" "${MEDIA_MOUNT}"; then
        ${log} "Error mounting ${DEVICE} (status=$?)"
        rmdir "${MEDIA_MOUNT}" 2>/dev/null
        exit 1
    fi
    ${log} "Mounted ${DEVICE} (${ID_FS_TYPE}) at ${MEDIA_MOUNT}"

    # Step 2: initialize RetroMi/ subfolder if missing
    local retromi_usb="${MEDIA_MOUNT}/RetroMi"
    if [ ! -d "${retromi_usb}/roms" ]; then
        ${log} "New drive — initializing RetroMi/ structure..."
        for sys in "${ROM_DIRS[@]}"; do
            mkdir -p "${retromi_usb}/roms/${sys}"
        done
        mkdir -p "${retromi_usb}/BIOS"
        create_readme "${retromi_usb}"
        chown -R pi:pi "${retromi_usb}" 2>/dev/null || true
        ${log} "RetroMi/ structure initialized"
    fi

    # Step 3: bind-mount USB/RetroMi/ → /home/pi/RetroPie
    mkdir -p "${RETROPI_DIR}"
    if ! mount --bind "${retromi_usb}" "${RETROPI_DIR}"; then
        ${log} "Error bind-mounting ${retromi_usb} → ${RETROPI_DIR}"
        umount "${MEDIA_MOUNT}"
        rmdir "${MEDIA_MOUNT}" 2>/dev/null
        exit 1
    fi
    ${log} "Bind-mounted ${retromi_usb} → ${RETROPI_DIR}"

    echo "${MEDIA_MOUNT}:${DEVBASE}" >> "${TRACK_FILE}"
}

do_unmount() {
    # Unbind /home/pi/RetroPie first
    if mount | grep -q " ${RETROPI_DIR} "; then
        umount -l "${RETROPI_DIR}"
        ${log} "Unbound ${RETROPI_DIR}"
    fi

    # Unmount USB from /media/retromi-DEVBASE
    if mount | grep -q " ${MEDIA_MOUNT} "; then
        umount -l "${MEDIA_MOUNT}"
        ${log} "Unmounted ${MEDIA_MOUNT}"
        rmdir "${MEDIA_MOUNT}" 2>/dev/null || true
    fi

    sed -i.bak "\\@${MEDIA_MOUNT}@d" "${TRACK_FILE}" 2>/dev/null || true
}

case "${ACTION}" in
    add)    do_mount ;;
    remove) do_unmount ;;
    *)
        ${log} "Unknown action '${ACTION}'"
        exit 1
        ;;
esac
