@echo off
REM Launch Symantec Ghost 11 from this USB (XP / Win7 / Win10).
REM Requires YOUR licensed Ghost32.exe in ..\ghost\

setlocal
cd /d "%~dp0.."
set GHOSTDIR=%CD%\ghost
set G32=%GHOSTDIR%\Ghost32.exe
set G64=%GHOSTDIR%\Ghost64.exe

set DESTFILE=%CD%\backups\ghost-images\SELECTED-DEST.txt

echo.
echo Symantec Ghost 11 launcher
echo Ghost folder: %GHOSTDIR%
echo.

if exist "%DESTFILE%" (
  echo Save .gho image to selected destination:
  type "%DESTFILE%"
  echo.
) else (
  echo No destination selected yet.
  echo Run: windows\choose-ghost-dest.bat  first
  echo ^(local disk, this USB, or \\network-pc\share^)
  echo.
)

if exist "%G64%" (
  echo Found Ghost64.exe
  echo Starting Ghost64.exe ...
  echo Use: Local - Disk - To Image  → browse to the folder above
  echo   or: Local - Disk - To Disk  (clone to another disk)
  echo.
  start "" "%G64%"
  goto done
)

if exist "%G32%" (
  echo Found Ghost32.exe
  echo Starting Ghost32.exe ...
  echo Use: Local - Disk - To Image  → browse to the folder above
  echo   or: Local - Disk - To Disk  (clone to another disk)
  echo.
  echo If Win10 blocks it: right-click Ghost32.exe - Properties -
  echo Compatibility - Windows XP SP3.
  echo.
  start "" "%G32%"
  goto done
)

echo Ghost32.exe NOT found.
echo.
echo Copy your licensed Symantec Ghost 11 files into:
echo   %GHOSTDIR%
echo.
echo See: %GHOSTDIR%\README.txt
echo.
notepad "%GHOSTDIR%\README.txt"
pause

:done
endlocal
exit /b 0
