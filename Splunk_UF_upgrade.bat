@echo off
setlocal enabledelayedexpansion

REM Set the URL where splunkforwarder.msi can be downloaded 
SET SPLUNKFWD_URL=http://<ip-address>/splunkforwarder-9.3.0-51ccf43db5bd-x64-release.msi

REM Set the path where splunkforwarder.msi will be downloaded to
SET SPLUNKFWD_DOWNLOAD_PATH=%TEMP%\splunkforwarder-9.3.0-51ccf43db5bd-x64-release.msi

REM Set the path where splunk.exe is expected to be found
SET SPLUNKFWD_PATH=%ProgramFiles%\SplunkUniversalForwarder\bin\splunk.exe

REM Temporary file to store uninstall command
SET UNINSTALL_FILE=%TEMP%\uninstall.txt

REM add /qn for slient uninstall
SET UNINSTALL_SILENT_SWITCH=/qn

REM Check if the MSI package is already downloaded
IF EXIST "%SPLUNKFWD_DOWNLOAD_PATH%" (
    echo MSI package already exists at %SPLUNKFWD_DOWNLOAD_PATH%. Skipping download...
) ELSE (
    REM Download splunkforwarder.msi
    echo Downloading splunkforwarder from %SPLUNKFWD_URL%...
    powershell -Command "Invoke-WebRequest -Uri %SPLUNKFWD_URL% -OutFile %SPLUNKFWD_DOWNLOAD_PATH%"

    REM Check if the download was successful
    IF EXIST "%SPLUNKFWD_DOWNLOAD_PATH%" (
        echo splunkforwarder downloaded successfully.
    ) ELSE (
        echo Failed to download splunkforwarder.
        exit /b 1
    )
)

REM Check if splunk.exe is already installed
IF EXIST "%SPLUNKFWD_PATH%" (
    echo splunkforwarder is installed. Fetching uninstall command...

    REM Clear the temporary file before running PowerShell command
    IF EXIST "%UNINSTALL_FILE%" DEL /F /Q "%UNINSTALL_FILE%"

    REM Run PowerShell command and save the output to a temporary file
    powershell -NoProfile -command "Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*Universal*' } | Select-Object -ExpandProperty UninstallString" > %UNINSTALL_FILE%
	
	REM cat the uninstall file
	echo reading the file: %UNINSTALL_FILE%
	powershell -command "Get-Content %UNINSTALL_FILE%"
	
	REM Adding a dely to ensure the file is accessible
	timeout /t 1 >null
	
	REM populate the env variable with the uninstall command
    SET /P UNINSTALL_CMD=<!UNINSTALL_FILE!
	
	REM Echo the uninstall command for debugging
    echo Uninstall command: !UNINSTALL_CMD!
	
	REM Check if ProductID is empty
    IF "!UNINSTALL_CMD!"=="" (
        echo Failed to retrieve uninstall command. Exiting...
		exit /b 1
    )

    REM Stop the SplunkForwarder service
    NET STOP SplunkForwarder

    REM Uninstall the Splunk Universal Forwarder using the fetched uninstall command
    !UNINSTALL_CMD! %UNINSTALL_SILENT_SWITCH%
	
    REM Confirm if the uninstallation is successful
    IF NOT EXIST "%SPLUNKFWD_PATH%" (
        echo Uninstallation successful.
    ) ELSE (
        echo Uninstallation failed.
        exit /b 1
    )

) ELSE (
    echo splunkforwarder is not installed. Proceeding with installation...
)

REM Install the new version of splunkforwarder set the ip address of the deployment server
echo Installing the latest version of splunkforwarder...
msiexec.exe /i "%SPLUNKFWD_DOWNLOAD_PATH%" AGREETOLICENSE=yes SPLUNKUSERNAME=admin GENRANDOMPASSWORD=1 DEPLOYMENT_SERVER="<ip-address>:8089" /quiet

echo Installation complete.
endlocal

