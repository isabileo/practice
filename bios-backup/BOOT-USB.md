# Make a bootable pendrive (XP / Windows 7 / Windows 10)

One USB works on all three PC types. See **OS-COMPAT.txt**.

The BIOS / format / wipe / clone tools run after you **boot Linux** from the stick  
(they are not Windows programs). Ghost 11 runs from **Windows** (or a Ghost boot ISO)
after you place your licensed Ghost files on the stick.

## Option A — Ventoy (recommended)

1. Install [Ventoy](https://www.ventoy.net/) on the pendrive.  
   - Prefer **FAT32** for the data partition if **Windows XP** must open the USB in Explorer.  
   - Win7 / Win10 can also use exFAT.
2. Copy a Linux live ISO onto the Ventoy USB (SystemRescue or Ubuntu LTS).
3. Install this kit:

   ```bash
   sudo ./prepare-usb.sh /path/to/mounted/VentoyUSB
   ```

4. Optional: copy your licensed **Symantec Ghost 11** files into:

   ```text
   bios-backup/ghost/Ghost32.exe   (+ DLLs / support files)
   ```

   See `ghost/README.txt`. Ghost is **not** shipped with this kit.

5. Use:

   | Goal | What to do |
   | --- | --- |
   | BIOS copy/upload, format, wipe, clone | Boot USB → Linux → `sudo bash …/bios-menu.sh` |
   | Ghost disk → USB / CD / other disk | In XP/7/10: `bios-backup\windows\RUN-MENU.bat` |

6. Linux menu highlights:

   - **1–2)** Copy / Upload BIOS  
   - **5)** Disk / Drives (format, wipe, clone)  
   - **6)** Symantec Ghost 11 helper  

If `flashrom` is missing on Ubuntu live:

```bash
sudo apt update && sudo apt install -y flashrom
```

NTFS format support:

```bash
sudo apt install -y ntfs-3g
```

## Option B — Rufus

1. Run [Rufus](https://rufus.ie/) → Linux ISO → write USB.  
2. Copy `bios-backup` onto the stick if it still mounts (Ventoy is easier for keeping files).  
3. Boot Linux for BIOS/disk tools; use `windows\RUN-MENU.bat` for Ghost under Windows.

## When BIOS has crashed

| Situation | Action |
| --- | --- |
| Logo/beep but Windows won’t start | Boot USB → Upload BIOS |
| Windows still runs sometimes | Boot USB → Copy BIOS first |
| Fully dead (no POST) | Dual-BIOS / vendor pad / SPI programmer |

## Safety

- Own / administer the PC.  
- Restore only dumps from the **same** board.  
- Use only licensed Ghost software.  
- Do not pick the wrong disk for format / clone / Ghost.
