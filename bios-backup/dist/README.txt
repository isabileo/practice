SINGLE FILE FOR VENTOY / RUFUS
==============================

Use ONE of these files from the dist/ folder:

  BIOS-USB-KIT.sh   ← recommended (self-extracting)
  BIOS-USB-KIT.zip  ← optional (Windows Explorer extract)

--------------------------------------------------------------------
VENTOY
--------------------------------------------------------------------
1. Copy BIOS-USB-KIT.sh onto the Ventoy USB (same place as your Linux ISO).
2. Boot the Linux ISO from Ventoy.
3. Open Terminal:

     bash /media/*/BIOS-USB-KIT.sh

   (or find the USB path and run bash BIOS-USB-KIT.sh there)

4. Start the menu:

     sudo bash /media/*/bios-backup/bios-menu.sh

--------------------------------------------------------------------
RUFUS
--------------------------------------------------------------------
1. Write a Linux ISO with Rufus as usual.
2. If the USB still mounts with free space, copy BIOS-USB-KIT.sh onto it.
   (If not, use Ventoy — easier for keeping files.)
3. Boot Linux, then same commands as above.

--------------------------------------------------------------------
WINDOWS XP / 7 / 10 (USB already has the kit extracted)
--------------------------------------------------------------------
Open:  bios-backup\windows\RUN-MENU.bat

Or extract BIOS-USB-KIT.zip with Explorer, then use RUN-MENU.bat.

--------------------------------------------------------------------
Rebuild the single file after changing the kit
--------------------------------------------------------------------
  cd bios-backup
  bash build-single-file.sh
  # outputs dist/BIOS-USB-KIT.sh and dist/BIOS-USB-KIT.zip
