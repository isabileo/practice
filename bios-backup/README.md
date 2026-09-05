# BIOS + Disk USB Kit

Pendrive toolkit for **Windows XP, Windows 7, and Windows 10** PCs:

1. **Copy / Upload BIOS** (boot Linux from USB)  
2. **Disk tools** — list, format, wipe, fast clone  
3. **Symantec Ghost 11** — disk backup to USB / CD / other disk (your licensed Ghost files)

See **[OS-COMPAT.txt](OS-COMPAT.txt)** for the verified XP / 7 / 10 matrix.

## Quick start

1. Read **[START-HERE.txt](START-HERE.txt)**, **[BOOT-USB.md](BOOT-USB.md)**, **[OS-COMPAT.txt](OS-COMPAT.txt)**  
2. Create a Ventoy USB (**FAT32** data partition if XP must open the stick in Explorer)  
3. Copy a Linux live ISO onto Ventoy  
4. Install this kit:

   ```bash
   chmod +x prepare-usb.sh bios-menu.sh scripts/*.sh
   sudo ./prepare-usb.sh /path/to/mounted/usb
   ```

5. Optional — Ghost 11: copy **your licensed** `Ghost32.exe` (+ files) into `bios-backup/ghost/`  
   (Ghost is **not** included — proprietary; see `ghost/README.txt`)

### Boot Linux (BIOS + disk tools — works on XP / 7 / 10 machines)

```bash
sudo bash /path/to/usb/bios-backup/bios-menu.sh
```

### Inside Windows XP / 7 / 10 (Ghost + browse backups)

Run: `bios-backup\windows\RUN-MENU.bat`

## Menu options (Linux boot)

| Option | Action |
| --- | --- |
| 1 Copy BIOS | `flashrom` read → `backups/…/bios.bin` |
| 2 Upload BIOS | Restore `bios.bin` (type `YES`) |
| 3 Show info | SMBIOS + chip probe |
| 4 List backups | Show dumps on the USB |
| 5 Disk / Drives | Format / wipe / **clone** |
| 6 Symantec Ghost 11 | Show disks → connect **network PC** storage → **select** .gho destination → run Ghost |
| 7 Network & Transfer | Browse other PCs (SMB), copy to/from shares / CD / USB / local disks |
| 8 Exit | Quit |

### Ghost image destination (local or network)

Linux menu **6** or Windows `choose-ghost-dest.bat`:

1. **Show available disks** on this PC (size / free space)  
2. **Connect network PC storage** (SMB share)  
3. **Select destination** from the list (USB, local disk, CD mount, or network share)  
4. In Ghost: Local → Disk → To Image → save `.gho` into that folder  

### Clone (built-in)

- Same size → same-space bit copy (128 MiB `dd`, direct I/O, verify)  
- Source larger → proportionate partitions to fit  
- Source smaller → ask same-space **or** proportionate  

### Ghost 11 (licensed copy you provide)

- **Windows:** `windows\RUN-MENU.bat` → Ghost → Disk to Image (USB/CD/other disk) or Disk to Disk  
- **Win10:** set Ghost32.exe compatibility to Windows XP SP3 if needed  

## Layout

```text
bios-backup/
  bios-menu.sh
  prepare-usb.sh
  START-HERE.txt
  BOOT-USB.md
  OS-COMPAT.txt
  windows/
    RUN-MENU.bat
    choose-ghost-dest.bat   ← pick local disk or \\network\share for .gho
    run-ghost.bat
  ghost/
    README.txt          ← put Ghost32.exe here (your license)
  scripts/
    copy-bios.sh, upload-bios.sh, show-info.sh, list-backups.sh
    disk-menu.sh, clone-disk.sh, ghost-menu.sh, network-menu.sh, lib.sh
  backups/
    ghost-images/       ← default .gho folder + SELECTED-DEST.txt
```

## Limits

- Full BIOS flash / format / clone need **booting** the Linux live USB (not from inside Windows).  
- That boot path works the same on PCs whose installed OS is XP, 7, or 10.  
- Ghost binaries are not redistributed.  
- Dead board with no POST: Dual-BIOS / vendor recovery / SPI programmer.

## Legal

For machines you own or are authorized to service. Use only Ghost software you are licensed to use. Keep firmware dumps private.
