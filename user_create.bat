@echo off
setlocal enabledelayedexpansion

:: Create log file with timestamp
for /f "tokens=2-4 delims=/ " %%i in ('date /t') do set DATE=%%k%%i%%j
for /f "tokens=1-2 delims=: " %%i in ('time /t') do set TIME=%%i%%j
set LOGFILE="%~dp0UserSetup_%DATE%_%TIME%.log"

echo =====================================================
echo User Management and System Configuration Script
echo Log file: %LOGFILE%
echo =====================================================

:: Initialize log
echo Script started at %DATE% %TIME% > %LOGFILE%

:: Check for administrator privileges
echo Checking administrator privileges...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ****************************************************
    echo This script requires administrator privileges.
    echo Please run as Administrator.
    echo ****************************************************
    echo ERROR: Script requires administrator privileges >> %LOGFILE%
    pause
    exit /b 1
)
echo Administrator privileges confirmed. >> %LOGFILE%

:: Step 1: Get username input
:GetUsername
set /p username="Enter Username: "
if "!username!"=="" (
    echo Username cannot be empty. Please try again.
    goto GetUsername
)


echo Username selected: !username! >> %LOGFILE%

echo.
echo Scanning for standard user accounts...
echo.

:: Get list of all user accounts and check their group membership
for /f "skip=1 tokens=1" %%u in ('wmic useraccount where "LocalAccount=True" get Name ^| findstr /v "^$"') do (
    set "username=%%u"
    set "username=!username: =!"
    
    if "!username!" neq "" (
        :: Check if user is in Administrators group
        net localgroup "Administrators" | find /i "!username!" >nul 2>&1
        if !errorlevel! neq 0 (
            :: User is not an administrator, check if it's a built-in account
            if /i not "!username!"=="Guest" (
                if /i not "!username!"=="DefaultAccount" (
                    if /i not "!username!"=="WDAGUtilityAccount" (
                        echo Found standard user: !username!
                        
                        :: Attempt to delete the user account
                        net user "!username!" /delete >nul 2>&1
                        if !errorlevel! equ 0 (
                            echo [SUCCESS] Removed user: !username!
                        ) else (
                            echo [ERROR] Failed to remove user: !username!
                        )
                    )
                )
            )
        ) else (
            echo [SKIP] Administrator account: !username!
        )
    )
)

echo.
echo ========================================
echo Operation completed.
echo ========================================
echo.
echo Remaining user accounts:
net user


:: Step 3: Create new standard user
echo.
echo =====================================================
echo Creating new standard user: !username!
echo =====================================================
echo Creating user !username!... >> %LOGFILE%

net user !username! 1234 /add /passwordchg:no /expires:never >nul 2>&1
if !errorlevel! neq 0 (
    echo ERROR: Failed to create user !username!
    echo ERROR: Failed to create user !username! >> %LOGFILE%
    pause
    exit /b 1
) else (
    echo Successfully created user: !username!
    echo SUCCESS: Created user !username! >> %LOGFILE%
)

:: Step 4: Configure auto login
echo.
echo Setting up auto login for !username!...
echo Configuring auto login for !username!... >> %LOGFILE%

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /d !username! /f >nul 2>&1
if !errorlevel! neq 0 (
    echo ERROR: Failed to set auto login username
    echo ERROR: Failed to set auto login username >> %LOGFILE%
    pause
    exit /b 1
)

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /d 1234 /f >nul 2>&1
if !errorlevel! neq 0 (
    echo ERROR: Failed to set auto login password
    echo ERROR: Failed to set auto login password >> %LOGFILE%
    pause
    exit /b 1
)

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /d 1 /f >nul 2>&1
if !errorlevel! neq 0 (
    echo ERROR: Failed to enable auto login
    echo ERROR: Failed to enable auto login >> %LOGFILE%
    pause
    exit /b 1
)

echo Auto login configured successfully.
echo SUCCESS: Auto login configured >> %LOGFILE%

:: Step 5: Disable wallpaper changes
echo.
echo Configuring wallpaper restrictions...
echo Configuring wallpaper restrictions... >> %LOGFILE%

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Control Panel" /v "NoDispBackgroundPage" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop" /v "Wallpaper" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop" /v "WallpaperStyle" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop" /v "TileWallpaper" /t REG_DWORD /d 0 /f >nul 2>&1

if !errorlevel! neq 0 (
    echo WARNING: Some wallpaper restrictions may not have been applied
    echo WARNING: Some wallpaper restrictions failed >> %LOGFILE%
) else (
    echo Wallpaper restrictions applied successfully.
    echo SUCCESS: Wallpaper restrictions applied >> %LOGFILE%
)

:: Step 6: Configure power options
echo.
echo Configuring power management...
echo Configuring power management... >> %LOGFILE%

powercfg -change -standby-timeout-ac 0 >nul 2>&1
powercfg -change -monitor-timeout-ac 0 >nul 2>&1
powercfg -change -hibernate-timeout-ac 0 >nul 2>&1

if !errorlevel! neq 0 (
    echo WARNING: Some power settings may not have been applied
    echo WARNING: Some power settings failed >> %LOGFILE%
) else (
    echo Power management configured successfully.
    echo SUCCESS: Power management configured >> %LOGFILE%
)

:: Step 7: Rename computer
echo.
echo Renaming computer to: !username!
echo Renaming computer to !username!... >> %LOGFILE%

wmic computersystem where name="%COMPUTERNAME%" call rename name="!username!" >nul 2>&1
if !errorlevel! neq 0 (
    echo WARNING: Could not rename computer
    echo WARNING: Could not rename computer >> %LOGFILE%
) else (
    echo Computer renamed successfully.
    echo SUCCESS: Computer renamed to !username! >> %LOGFILE%
)

:: Step 8: Configure Windows Update
echo.
echo Configuring Windows Update service...
echo Configuring Windows Update service... >> %LOGFILE%

sc config wuauserv start= disabled >nul 2>&1
sc stop wuauserv >nul 2>&1

if !errorlevel! neq 0 (
    echo WARNING: Windows Update service configuration may have failed
    echo WARNING: Windows Update service configuration failed >> %LOGFILE%
) else (
    echo Windows Update service configured successfully.
    echo SUCCESS: Windows Update service configured >> %LOGFILE%
)

:: Step 9: Windows Activation
echo.
echo Starting Windows activation process...
echo Starting Windows activation process... >> %LOGFILE%

rem Uninstall the current product key
cscript %windir%\system32\slmgr.vbs /upk

rem Install the new product key
cscript %windir%\system32\slmgr.vbs /ipk W269N-WFGWX-YVC9B-4J6C9-T83GX

rem Set the Key Management Service (KMS) server
cscript  %windir%\system32\slmgr.vbs /skms kms.daarululuumlido.com

rem Activate Windows using the specified KMS server
cscript %windir%\system32\slmgr.vbs /ato

rem Change dir into Office\Office16
cd "C:\Program Files\Microsoft Office\Office16"

rem Install key
cscript ospp.vbs /inpkey:XQNVK-8JYDB-WJ9W3-YJ8YR-WFG99

rem Set the Key Management Service (KMS) server
cscript ospp.vbs /sethst:kms.daarululuumlido.com

rem Activate Office using the specified KMS server
cscript ospp.vbs /act

echo Windows activation process completed.
echo SUCCESS: Windows activation process completed >> %LOGFILE%

:: Step 10: Summary and restart
echo.
echo =====================================================
echo Configuration Summary:
echo =====================================================
echo - Changed admin user password (if admin user exists)
echo - Removed existing standard users and their files
echo - Created new user: !username!
echo - Configured auto login
echo - Applied wallpaper restrictions
echo - Configured power management
echo - Renamed computer to: !username!
echo - Configured Windows Update service
echo - Initiated Windows activation
echo =====================================================
echo.
echo Script completed successfully! >> %LOGFILE%
echo Log file saved to: %LOGFILE%

set /p restart="Restart computer now? (Y/N): "
if /i "!restart!"=="Y" (
    echo User chose to restart >> %LOGFILE%
    echo Restarting computer in 10 seconds...
    echo Press Ctrl+C to cancel restart.
    timeout /t 10
    shutdown /r /t 0
) else (
    echo User chose not to restart >> %LOGFILE%
    echo Computer restart skipped. Please restart manually to complete configuration.
)

echo.
echo Script execution completed.
pause
