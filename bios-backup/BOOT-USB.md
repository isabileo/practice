# Make a bootable pendrive with Copy / Upload BIOS menu

You need a USB stick (4 GB+). The BIOS menu runs **after you boot Linux from the stick** — it does not run inside Windows 7.

## Option A — Ventoy (recommended)

1. On any working PC, download [Ventoy](https://www.ventoy.net/) and install it to the pendrive.
2. Copy a Linux live ISO onto the Ventoy USB, for example:
   - [SystemRescue](https://www.system-rescue.org/) (includes many recovery tools), or
   - Ubuntu Desktop LTS ISO
3. From this project, copy the kit onto the USB:

   ```bash
   sudo ./prepare-usb.sh /path/to/mounted/VentoyUSB
   ```

   Or manually copy the whole `bios-backup` folder to the USB root.
4. Plug the pendrive into the Windows 7 PC.
5. Power on → open the one-time boot menu (often **F12**, **F10**, **Esc**, or **F9**) → boot the USB.
6. In Ventoy, start the Linux ISO.
7. Open a terminal:

   ```bash
   # Find the USB (example)
   ls /media
   sudo bash /media/$(whoami)/*/bios-backup/bios-menu.sh
   ```

8. Menu:

   - **1) Copy BIOS** — saves `bios.bin` onto the pendrive under `bios-backup/backups/`
   - **2) Upload BIOS** — flashes a saved `bios.bin` back to the chip

If `flashrom` is missing (Ubuntu live):

```bash
sudo apt update && sudo apt install -y flashrom
```

## Option B — Rufus (from Windows)

1. On a working Windows PC, run [Rufus](https://rufus.ie/).
2. Select the pendrive + a Linux ISO (Ubuntu or SystemRescue) → Write in **ISO mode**.
3. After writing, copy the `bios-backup` folder onto the USB data area if the stick still mounts; with some ISOs you may need a second small FAT32 stick for backups, or use Ventoy instead (easier for keeping files).
4. Boot the target PC from the USB and run `bios-menu.sh` as above.

## When BIOS has “crashed”

| Situation | What to do |
| --- | --- |
| PC shows logo / beep but Windows won’t start | Boot this USB → **Upload BIOS** with a dump from this board |
| PC still runs Windows sometimes | Boot USB anyway → **Copy BIOS** first while it works |
| No display, no fans pattern, fully dead | USB cannot flash it — Dual-BIOS switch, vendor recovery pad, or SPI programmer |

## Safety

- Own / administer the PC.
- Restore only images dumped from the **same** board.
- Do not cut power during **Upload**.
- Keep the pendrive with the backup in a safe place.
