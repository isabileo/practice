@echo off
REM Works on Windows XP, Windows 7, and Windows 10 (cmd.exe).
REM Run from the USB: bios-backup\windows\RUN-MENU.bat

setlocal
cd /d "%~dp0.."
set KIT=%CD%

:menu
cls
echo ========================================
echo   BIOS + Disk USB Kit  (Windows menu)
echo ========================================
echo.
echo  Kit folder: %KIT%
echo.
echo  This Windows menu is for Ghost + browsing backups.
echo  For Copy/Upload BIOS, Format, Wipe, Clone: BOOT this USB
echo  (Linux live) — works on XP / Win7 / Win10 PCs. See OS-COMPAT.txt
echo.
echo   1) Choose Ghost image destination (local disk / network PC)
echo   2) Symantec Ghost 11 — disk backup to USB / CD / other disk / network
echo   3) Open BIOS backups folder
echo   4) Open OS compatibility notes
echo   5) Open Ghost setup instructions
echo   6) Exit
echo.
set /p CHOICE=Choose [1-6]: 

if "%CHOICE%"=="1" goto dest
if "%CHOICE%"=="2" goto ghost
if "%CHOICE%"=="3" goto backups
if "%CHOICE%"=="4" goto compat
if "%CHOICE%"=="5" goto ghosthelp
if "%CHOICE%"=="6" goto end
echo Invalid choice.
pause
goto menu

:dest
call "%~dp0choose-ghost-dest.bat"
goto menu

:ghost
call "%~dp0run-ghost.bat"
goto menu

:backups
if not exist "%KIT%\backups" mkdir "%KIT%\backups"
explorer "%KIT%\backups"
goto menu

:compat
if exist "%KIT%\OS-COMPAT.txt" (
  notepad "%KIT%\OS-COMPAT.txt"
) else (
  echo OS-COMPAT.txt not found.
  pause
)
goto menu

:ghosthelp
if exist "%KIT%\ghost\README.txt" (
  notepad "%KIT%\ghost\README.txt"
) else (
  echo ghost\README.txt not found.
  pause
)
goto menu

:end
endlocal
exit /b 0
