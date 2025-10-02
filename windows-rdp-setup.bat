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

rem ================== EXTEND DISK ==================
echo [i] Checking and extending Disk C...
timeout /t 1 /nobreak >nul

rem Use PowerShell to extend partition C: to maximum available size
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $partition = Get-Partition -DriveLetter C -ErrorAction Stop; $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop; $maxSize = ($partition | Get-PartitionSupportedSize).SizeMax; $currentSize = $partition.Size; if ($maxSize -gt $currentSize) { Resize-Partition -DriveLetter C -Size $maxSize -ErrorAction Stop; Write-Host '[i] Disk C extended successfully'; exit 0 } else { Write-Host '[i] No unallocated space available - skipping'; exit 2 } } catch { Write-Host '[!] Error extending disk:' $_.Exception.Message; exit 1 }"

if errorlevel 2 (
    echo.
) else if errorlevel 1 (
    echo [!] Failed to extend disk - trying diskpart method...
    
    rem Fallback to diskpart method
    echo list disk > "%TEMP%\disk_info.txt"
    diskpart /s "%TEMP%\disk_info.txt" > "%TEMP%\disk_output.txt" 2>&1
    
    echo select volume C > "%TEMP%\disk_extend.txt"
    echo extend >> "%TEMP%\disk_extend.txt"
    
    diskpart /s "%TEMP%\disk_extend.txt" >nul 2>&1
    if errorlevel 1 (
        echo [!] Diskpart method also failed
    ) else (
        echo [i] Disk C extended using diskpart
    )
    
    del "%TEMP%\disk_info.txt" /f /q >nul 2>&1
    del "%TEMP%\disk_output.txt" /f /q >nul 2>&1
    del "%TEMP%\disk_extend.txt" /f /q >nul 2>&1
    echo.
) else (
    echo.
)

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

rem ================== CHROME INSTALLATION ==================
echo [i] Downloading Google Chrome...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$path_chrome = \"$env:TEMP\ChromeSetup.exe\"; $url_chrome = 'https://dl.google.com/chrome/install/latest/chrome_installer.exe'; try { Invoke-WebRequest -Uri $url_chrome -OutFile $path_chrome -UseBasicParsing; } catch { exit 1; }"

if errorlevel 1 (
    echo [!] Failed to download Chrome
    goto :skip_chrome
)

echo [i] Installing Google Chrome...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$installerPath = \"$env:TEMP\ChromeSetup.exe\"; if (Test-Path $installerPath) { Start-Process -FilePath $installerPath -ArgumentList '/silent', '/install' -Wait; Remove-Item -Path $installerPath -Force -ErrorAction SilentlyContinue; if (Get-Process -Name 'chrome' -ErrorAction SilentlyContinue) { Get-Process -Name 'chrome' | ForEach-Object { $_.Kill() }; }; if (Test-Path 'C:\Program Files\Google\Chrome\Application\chrome.exe') { exit 0; } else { exit 1; }; } else { exit 1; }"

if errorlevel 1 (
    echo [!] Chrome installation failed
) else (
    echo [i] Chrome successfully installed
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
pause
shutdown /r /t 5 /c "Successfully Setup Windows"
del "%~f0"

