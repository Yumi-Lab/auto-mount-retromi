#!/usr/bin/env bash
# RetroMi — USB auto-mount
#
# Mounts USB drives on /home/pi/RetroPie.
# On first plug of a new drive, initializes the RetroMi ROM folder structure
# and drops a bilingual user README at the drive root.
#
# Called by systemd unit usb-mount@.service via udev rule 99-local.rules.
# Logs to /var/log/messages (tag: usb-mount).

PATH="$PATH:/usr/bin:/usr/local/bin:/usr/sbin:/usr/local/sbin:/bin:/sbin"
log="logger -t usb-mount -s"

MOUNT_POINT="/home/pi/RetroPie"
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

create_readme() {
    local base="$1"
    cat > "${base}/RetroMi-README.md" << 'EOF'
# RetroMi — USB ROMs Drive / Clé USB ROMs

---

## 🇫🇷 Français

### Bienvenue sur votre clé USB RetroMi !

Cette clé est reconnue automatiquement par RetroMi au branchement.
Les dossiers de ROMs ont été créés automatiquement.

### Comment ajouter des jeux

Copiez vos ROMs dans le dossier correspondant à la console :

| Dossier                | Console                     |
|------------------------|-----------------------------|
| `roms/nes/`            | Nintendo NES                |
| `roms/snes/`           | Super Nintendo              |
| `roms/megadrive/`      | Sega Mega Drive / Genesis   |
| `roms/mastersystem/`   | Sega Master System          |
| `roms/gb/`             | Game Boy                    |
| `roms/gbc/`            | Game Boy Color              |
| `roms/gba/`            | Game Boy Advance            |
| `roms/n64/`            | Nintendo 64                 |
| `roms/psx/`            | PlayStation 1               |
| `roms/psp/`            | PlayStation Portable        |
| `roms/arcade/`         | Arcade (FBNeo / MAME)       |
| `roms/neogeo/`         | Neo Geo                     |
| `roms/dreamcast/`      | Sega Dreamcast              |
| `roms/scummvm/`        | ScummVM (aventure PC)       |
| `roms/dosbox/`         | DOS (DOSBox)                |
| `roms/ports/`          | Ports (Doom, Quake…)        |

### Fichiers BIOS

Certains émulateurs nécessitent des fichiers BIOS dans le dossier `BIOS/` :

| Fichier           | Console          |
|-------------------|------------------|
| `scph1001.bin`    | PlayStation 1    |
| `dc_boot.bin`     | Sega Dreamcast   |
| `neogeo.zip`      | Neo Geo          |
| `gba_bios.bin`    | Game Boy Advance |

### Formats supportés (principaux)

| Console    | Extensions                        |
|------------|-----------------------------------|
| NES        | `.nes`                            |
| SNES       | `.sfc`, `.smc`                    |
| Mega Drive | `.md`, `.bin`, `.gen`             |
| GBA        | `.gba`                            |
| N64        | `.z64`, `.n64`, `.v64`            |
| PSX        | `.bin`+`.cue`, `.pbp`, `.chd`    |
| Arcade     | `.zip` (romset FBNeo ou MAME 0.78)|

### Débranchement sécurisé

Évitez de retirer la clé pendant qu'un jeu est en cours.
Éteignez la console depuis EmulationStation ou via le menu RetroPie.

---

## 🇬🇧 English

### Welcome to your RetroMi USB drive!

This drive is automatically detected by RetroMi when plugged in.
ROM folders have been created automatically.

### How to add games

Copy your ROMs into the folder matching the console:

| Folder                 | Console                     |
|------------------------|-----------------------------|
| `roms/nes/`            | Nintendo NES                |
| `roms/snes/`           | Super Nintendo              |
| `roms/megadrive/`      | Sega Mega Drive / Genesis   |
| `roms/mastersystem/`   | Sega Master System          |
| `roms/gb/`             | Game Boy                    |
| `roms/gbc/`            | Game Boy Color              |
| `roms/gba/`            | Game Boy Advance            |
| `roms/n64/`            | Nintendo 64                 |
| `roms/psx/`            | PlayStation 1               |
| `roms/psp/`            | PlayStation Portable        |
| `roms/arcade/`         | Arcade (FBNeo / MAME)       |
| `roms/neogeo/`         | Neo Geo                     |
| `roms/dreamcast/`      | Sega Dreamcast              |
| `roms/scummvm/`        | ScummVM (PC adventure games)|
| `roms/dosbox/`         | DOS games (DOSBox)          |
| `roms/ports/`          | Ports (Doom, Quake…)        |

### BIOS files

Some emulators require BIOS files placed in the `BIOS/` folder:

| File              | Console          |
|-------------------|------------------|
| `scph1001.bin`    | PlayStation 1    |
| `dc_boot.bin`     | Sega Dreamcast   |
| `neogeo.zip`      | Neo Geo          |
| `gba_bios.bin`    | Game Boy Advance |

### Supported formats (main)

| Console    | Extensions                        |
|------------|-----------------------------------|
| NES        | `.nes`                            |
| SNES       | `.sfc`, `.smc`                    |
| Mega Drive | `.md`, `.bin`, `.gen`             |
| GBA        | `.gba`                            |
| N64        | `.z64`, `.n64`, `.v64`            |
| PSX        | `.bin`+`.cue`, `.pbp`, `.chd`    |
| Arcade     | `.zip` (FBNeo or MAME 0.78 romset)|

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
        ${log} "Warning: ${DEVICE} is already mounted, skipping"
        exit 0
    fi

    # Guard: mountpoint already in use (multi-partition USB)
    if mount | grep -q " ${MOUNT_POINT} "; then
        ${log} "Info: ${MOUNT_POINT} already in use, skipping ${DEVICE}"
        exit 0
    fi

    # Get filesystem info
    eval "$(blkid -o udev "${DEVICE}" | grep -iE "ID_FS_LABEL|ID_FS_TYPE")"

    # Skip unsupported or unrecognized filesystems
    case "${ID_FS_TYPE}" in
        vfat|exfat|ext2|ext3|ext4) ;;
        *)
            ${log} "Unsupported filesystem '${ID_FS_TYPE}' on ${DEVICE}, skipping"
            exit 0
            ;;
    esac

    mkdir -p "${MOUNT_POINT}"

    OPTS="rw,relatime"
    if [[ "${ID_FS_TYPE}" == "vfat" ]]; then
        OPTS+=",users,gid=100,umask=000,shortname=mixed,utf8=1,flush"
    fi

    if ! mount -o "${OPTS}" "${DEVICE}" "${MOUNT_POINT}"; then
        ${log} "Error mounting ${DEVICE} (status=$?)"
        exit 1
    fi

    echo "${MOUNT_POINT}:${DEVBASE}" >> "${TRACK_FILE}"
    ${log} "Mounted ${DEVICE} (${ID_FS_TYPE}) at ${MOUNT_POINT}"

    # First-time initialization: create ROM structure if missing
    if [ ! -d "${MOUNT_POINT}/roms" ]; then
        ${log} "New drive — initializing RetroMi ROM structure..."

        for sys in "${ROM_DIRS[@]}"; do
            mkdir -p "${MOUNT_POINT}/roms/${sys}"
        done

        mkdir -p "${MOUNT_POINT}/BIOS"
        create_readme "${MOUNT_POINT}"
        chown -R pi:pi "${MOUNT_POINT}" 2>/dev/null || true

        ${log} "ROM structure initialized on ${DEVICE}"
    fi
}

do_unmount() {
    local current_mount
    current_mount=$(mount | grep "^${DEVICE} " | awk '{print $3}')

    if [[ -z "${current_mount}" ]]; then
        ${log} "Warning: ${DEVICE} is not mounted"
        exit 0
    fi

    umount -l "${DEVICE}"
    ${log} "Unmounted ${DEVICE} from ${current_mount}"
    sed -i.bak "\\@${current_mount}@d" "${TRACK_FILE}" 2>/dev/null || true
}

case "${ACTION}" in
    add)    do_mount ;;
    remove) do_unmount ;;
    *)
        ${log} "Unknown action '${ACTION}'"
        exit 1
        ;;
esac
