# BIOS Copy / Upload — Bootable USB Kit

Bootable-pendrive toolkit with a simple menu:

1. **Copy BIOS** — dump this PC’s firmware to the USB  
2. **Upload BIOS** — restore a previous dump if firmware is damaged  
3. **Disk / Drives** — list disks, select one, show partitions & free space, format, or wipe all partitions  

Designed for older PCs (including Windows 7 machines) where you boot Linux from USB, then run the menu. Does not modify Windows itself.

## Quick start

1. Read **[START-HERE.txt](START-HERE.txt)** and **[BOOT-USB.md](BOOT-USB.md)**  
2. Create a Ventoy (or Rufus) bootable USB with a Linux live ISO  
3. Install this kit onto the USB:

   ```bash
   chmod +x prepare-usb.sh bios-menu.sh scripts/*.sh
   sudo ./prepare-usb.sh /path/to/mounted/usb
   ```

4. Boot the target PC from the pendrive → open Terminal → run:

   ```bash
   sudo bash /path/to/usb/bios-backup/bios-menu.sh
   ```

5. Choose **Copy**, **Upload**, or **Disk / Drives**

## Menu options

| Option | Action |
| --- | --- |
| 1 Copy BIOS | `flashrom` read → `backups/<timestamp>_…/bios.bin` |
| 2 Upload BIOS | Pick a `bios.bin` → `flashrom` write (type `YES` to confirm) |
| 3 Show info | SMBIOS + chip probe |
| 4 List backups | Show dumps on the USB |
| 5 Disk / Drives | List disks → select → partitions & space → format or wipe partitions |
| 6 Exit | Quit |

### Disk / Drives submenu

1. Show all disk drives  
2. Select a disk → then:

   - Refresh partitions & available space  
   - **Format** this disk (GPT + one partition: NTFS / FAT32 / exFAT / ext4)  
   - **Delete all partitions** (empty disk, no partitions)  
   - Select another disk / back to main menu  

Destructive steps ask you to type the disk name (e.g. `sda`) and `YES`.

## Layout

```text
bios-backup/
  bios-menu.sh       ← main menu (run as root)
  prepare-usb.sh     ← copy kit onto a mounted pendrive
  START-HERE.txt
  BOOT-USB.md
  scripts/
    copy-bios.sh
    upload-bios.sh
    show-info.sh
    list-backups.sh
    disk-menu.sh
    lib.sh
  backups/           ← created on the USB; holds bios.bin dumps
```

## Requirements

- Bootable Linux live environment with root access  
- [`flashrom`](https://flashrom.org/) (preinstalled on many rescue ISOs; else `apt install flashrom`)  
- Internal SPI flash readable/writable on that motherboard (some vendors lock this)

## Limits

- If the board does **not POST at all**, this USB menu cannot talk to the chip — use Dual-BIOS, the vendor’s emergency USB recovery, or a hardware programmer.  
- **Upload** only a dump from the **same** motherboard. Wrong firmware can brick the PC.  
- This kit does not bypass Secure Boot, TPM, or vendor locks, and does not patch firmware.

## Legal / intended use

For backing up and restoring firmware on computers you own or are authorized to service. Keep dumps private (they may include serials and vendor IP).
