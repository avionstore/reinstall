@echo off
mode con cp select=437 >nul

rem ================== DD METHOD SETUP ==================
rem This script is only for DD installation method
rem Handles: computer renaming, system settings, and password change (if provided)
rem Environment variable: NewPassword (optional)

echo Starting DD method setup...

rem ================== SYSTEM SETTINGS ==================
rem 1. Disable automatic sleep (AC & DC) first to prevent sleep during the process
echo [i] Disabling automatic sleep...
powercfg -change -standby-timeout-ac 0
powercfg -change -standby-timeout-dc 0
echo Sleep settings have been disabled.
echo.

rem ================== COMPUTER RENAME ==================
rem 2. Rename computer before reboot
set "NEWNAME=AVION-STORE"
echo [i] Renaming computer to %NEWNAME%...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "try { Rename-Computer -NewName '%NEWNAME%' -Force -ErrorAction Stop | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo [!] Failed to rename computer with PowerShell, trying WMIC fallback...
    wmic computersystem where name="%COMPUTERNAME%" call rename "%NEWNAME%" >nul 2>&1
)

if errorlevel 1 (
    echo [!] Failed to rename computer
) else (
    echo [i] Computer name successfully changed to %NEWNAME%
)
echo.

rem ================== PASSWORD CHANGE ==================
rem 3. Change Administrator password if provided
if defined NewPassword (
    if not "%NewPassword%"=="" (
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
        set "PASSWORD_CHANGED=1"
    ) else (
        echo [i] Password variable is empty - skipping password change
        set "PASSWORD_CHANGED=0"
    )
) else (
    echo [i] Password not specified - skipping password change
    set "PASSWORD_CHANGED=0"
)
echo.

rem ================== RESTART RDP SERVICE ==================
rem Restart Terminal Service to apply any RDP-related changes
echo.
echo [i] Restarting Remote Desktop service...

sc query TermService >nul 2>&1
if %errorlevel%==1060 goto :do_reboot

set retryCount=5
:restartRDP
if %retryCount% LEQ 0 goto :do_reboot
net stop TermService /y && net start TermService || (
    set /a retryCount-=1
    timeout 10 >nul
    goto :restartRDP
)

:do_reboot
echo.
echo ================== SETUP COMPLETE ==================
echo [i] DD method setup script execution finished
echo Computer Name: %NEWNAME%
if "%PASSWORD_CHANGED%"=="1" (
    echo Password: Changed
) else (
    echo Password: Not changed
)
echo.
echo [i] Scheduling reboot to apply changes...
shutdown /r /t 5 /c "Applied: Rename=AVION-STORE, Password, Sleep=Never"
del "%~f0"

