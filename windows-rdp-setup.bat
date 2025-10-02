@echo off
mode con cp select=437 >nul

rem ================== WINDOWS SETUP ==================
rem This script is only for DD installation method
rem Handles: computer renaming, system settings, and password change (if provided)
rem Environment variable: NewPassword (optional)

echo Starting Windows Setup...

rem ================== SYSTEM SETTINGS ==================
rem Disable automatic sleep (AC & DC) first to prevent sleep during the process
echo [i] Disabling automatic sleep...
powercfg -change -standby-timeout-ac 0
powercfg -change -standby-timeout-dc 0
echo Sleep settings have been disabled.
echo.

rem ================== LICENSE RESET ==================
echo [i] Resetting Windows License...
timeout /t 1 /nobreak >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'C:\Windows\System32\cscript.exe' -ArgumentList 'C:\Windows\System32\slmgr.vbs', '/rearm' -WindowStyle Hidden -Wait" >nul 2>&1
echo [i] License reset completed
echo.

rem ================== TIMEZONE SETTINGS ==================
echo [i] Setting Timezone to Jakarta...
tzutil /s "SE Asia Standard Time" >nul 2>&1
if errorlevel 1 (
    echo [!] Failed to set timezone
) else (
    echo [i] Timezone set to SE Asia Standard Time (Jakarta)
)

echo [i] Configuring NTP server...
set "ntpServer=time.google.com"
w32tm /config /manualpeerlist:"%ntpServer%" /syncfromflags:manual /reliable:YES /update >nul 2>&1
net stop w32time >nul 2>&1
net start w32time >nul 2>&1
echo [i] NTP server configured to %ntpServer%
echo.

rem ================== COMPUTER RENAME ==================
rem Rename computer before reboot
set "NEWNAME=AVION-STORE"
echo [i] Renaming computer to %NEWNAME%...

rem Check if name is already correct
if /I "%COMPUTERNAME%"=="%NEWNAME%" (
    echo [i] Computer name is already %NEWNAME%
    goto :skip_rename
)

rem Try PowerShell method with proper variable passing
powershell -NoProfile -ExecutionPolicy Bypass -Command "$newName = $env:NEWNAME; try { Rename-Computer -NewName $newName -Force -ErrorAction Stop; Write-Host '[i] Computer renamed to' $newName 'successfully'; exit 0 } catch { Write-Host '[!] PowerShell rename failed:' $_.Exception.Message; exit 1 }"

if errorlevel 1 (
    echo [!] Trying WMIC fallback...
    wmic computersystem where name="%COMPUTERNAME%" call rename name="%NEWNAME%" >nul 2>&1
    
    if errorlevel 1 (
        echo [!] Failed to rename computer
    ) else (
        echo [i] Computer renamed using WMIC
    )
) else (
    rem Success message already printed by PowerShell
)

:skip_rename
echo.

rem ================== CHROME INSTALLATION ==================
echo [i] Downloading Google Chrome...

set "chrome_url=https://dl.google.com/chrome/install/latest/chrome_installer.exe"
set "chrome_path=%TEMP%\ChromeSetup.exe"

rem Try method 1: bitsadmin
bitsadmin /transfer "ChromeDownload" /priority foreground "%chrome_url%" "%chrome_path%" >nul 2>&1
if not errorlevel 1 if exist "%chrome_path%" goto :install_chrome

rem Try method 2: PowerShell WebClient
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { (New-Object System.Net.WebClient).DownloadFile('%chrome_url%', '%chrome_path%'); exit 0 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 if exist "%chrome_path%" goto :install_chrome

rem Try method 3: certutil
certutil -urlcache -f -split "%chrome_url%" "%chrome_path%" >nul 2>&1
if not errorlevel 1 if exist "%chrome_path%" goto :install_chrome

echo [!] Failed to download Chrome - all methods failed
goto :skip_chrome

:install_chrome
echo [i] Installing Google Chrome...
start /wait "" "%chrome_path%" /silent /install

rem Cleanup
del "%chrome_path%" /f /q >nul 2>&1

rem Kill any remaining chrome processes
taskkill /F /IM chrome.exe >nul 2>&1

rem Verify installation
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    echo [i] Chrome successfully installed
) else if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" (
    echo [i] Chrome successfully installed
) else (
    echo [!] Chrome installation failed
)

:skip_chrome
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

rem ================== PASSWORD CHANGE ==================
rem Change Administrator password if provided
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
shutdown /r /t 0 /c "Successfully Setup Windows"
del "%~f0"

