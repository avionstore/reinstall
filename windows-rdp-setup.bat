@echo off
mode con cp select=437 >nul

rem ================== DD METHOD SETUP ==================
rem Handles password change, computer rename, and system configuration
rem This script is ONLY for DD method installations
rem Environment variables: NewPassword (optional)

echo Starting DD method setup...

rem ================== PASSWORD CHANGE ==================
rem Change Administrator password if provided
rem NewPassword is optional - only set for DD installations
if not defined NewPassword (
    echo [i] Password not specified - skipping password change
    echo [i] Password will be managed by autounattend.xml or remain unchanged
    goto :skip_password_change
)

if "%NewPassword%"=="" (
    echo [i] Password variable is empty - skipping password change
    goto :skip_password_change
)

echo Changing Administrator password...
net user Administrator "%NewPassword%"
if errorlevel 1 (
    echo [!] Failed to change Administrator password
) else (
    echo [i] Administrator password changed successfully
)

rem Disable account lockout policy
net accounts /lockoutthreshold:0
echo [i] Account lockout policy disabled

:skip_password_change

echo.

rem ================== COMPUTER RENAME ==================
rem Rename computer to AVION STORE
set "NEWNAME=AVION-STORE"
echo [i] Renaming computer to %NEWNAME%...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "try { Rename-Computer -NewName '%NEWNAME%' -Force -ErrorAction Stop | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
  echo [!] PowerShell rename failed, trying WMIC fallback...
  wmic computersystem where name="%COMPUTERNAME%" call rename "%NEWNAME%" >nul 2>&1
)

if errorlevel 1 (
    echo [!] Computer rename failed
) else (
    echo [i] Computer renamed successfully to %NEWNAME%
)

echo.

rem ================== SYSTEM SETTINGS ==================
rem Disable automatic sleep (AC & DC)
echo [i] Disabling automatic Sleep...
powercfg -change -standby-timeout-ac 0
powercfg -change -standby-timeout-dc 0

echo.
echo Sleep settings disabled.
echo.

:script_complete
echo [i] DD method setup script execution completed
echo Computer Name: %NEWNAME%
if defined NewPassword (
    echo Password: Changed
) else (
    echo Password: Not changed
)
del "%~f0"