@echo off
REM Pick where to store Ghost .gho images: USB, local disk, or network PC.
REM XP / Win7 / Win10. Saves path to backups\ghost-images\SELECTED-DEST.txt

setlocal enableextensions
cd /d "%~dp0.."
set KIT=%CD%
set DESTFILE=%KIT%\backups\ghost-images\SELECTED-DEST.txt
if not exist "%KIT%\backups\ghost-images" mkdir "%KIT%\backups\ghost-images"

:menu
cls
echo ========================================
echo   Ghost image destination
echo ========================================
echo.
echo  Kit: %KIT%
echo.
if exist "%DESTFILE%" (
  echo  Current selection:
  type "%DESTFILE%"
  echo.
) else (
  echo  Current selection: (none)
  echo.
)
echo   1) This USB  (bios-backup\backups\ghost-images)
echo   2) Local disk folder  (shows drives, then type path)
echo   3) Network PC storage (\\PC\share — shows tip, then type UNC)
echo   4) Show available disks / drives on this PC
echo   5) Open selected folder
echo   6) Back
echo.
set /p CHOICE=Choose [1-6]: 

if "%CHOICE%"=="1" goto usb
if "%CHOICE%"=="2" goto local
if "%CHOICE%"=="3" goto net
if "%CHOICE%"=="4" goto drives
if "%CHOICE%"=="5" goto open
if "%CHOICE%"=="6" goto end
echo Invalid.
pause
goto menu

:usb
echo %KIT%\backups\ghost-images>"%DESTFILE%"
echo Selected: %KIT%\backups\ghost-images
pause
goto menu

:local
echo.
echo Available disks / drives:
echo.
wmic logicaldisk get DeviceID,DriveType,FileSystem,FreeSpace,Size,VolumeName 2>nul
echo.
echo DriveType: 2=Removable(USB)  3=Local disk  4=Network  5=CD-ROM
echo.
set /p LPATH=Type folder path (example D:\GhostImages): 
if "%LPATH%"=="" goto menu
if not exist "%LPATH%" mkdir "%LPATH%"
echo %LPATH%>"%DESTFILE%"
echo Selected: %LPATH%
pause
goto menu

:net
echo.
echo Store Ghost image on another PC over the network.
echo First map or use a shared folder, for example:
echo   \\OFFICE-PC\Backup
echo   \\192.168.1.20\Data
echo.
echo Available network drives (if already mapped):
wmic logicaldisk where "DriveType=4" get DeviceID,ProviderName,FreeSpace,Size 2>nul
echo.
set /p NPATH=Network folder UNC or mapped drive path: 
if "%NPATH%"=="" goto menu
if not exist "%NPATH%\GhostImages" mkdir "%NPATH%\GhostImages" 2>nul
if exist "%NPATH%\GhostImages" (
  echo %NPATH%\GhostImages>"%DESTFILE%"
  echo Selected: %NPATH%\GhostImages
) else (
  echo %NPATH%>"%DESTFILE%"
  echo Selected: %NPATH%
  echo NOTE: Could not create GhostImages subfolder — using path as-is.
)
pause
goto menu

:drives
echo.
echo All disks / storage visible on this PC:
echo.
wmic logicaldisk get DeviceID,DriveType,FileSystem,FreeSpace,Size,VolumeName 2>nul
echo.
echo DriveType: 2=Removable  3=Local  4=Network  5=CD-ROM
echo FreeSpace/Size are in bytes.
echo.
pause
goto menu

:open
if not exist "%DESTFILE%" (
  echo No destination selected yet.
  pause
  goto menu
)
set /p OP=<"%DESTFILE%"
explorer "%OP%"
goto menu

:end
endlocal
exit /b 0
