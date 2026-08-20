@echo off
setlocal enabledelayedexpansion

:: Debug Mode (set to 1 to enable)
set "DEBUG=0"
set "SERVER_JSON=%TEMP%\gofile_server_%RANDOM%%RANDOM%.json"
set "UPLOAD_JSON=%TEMP%\gofile_upload_%RANDOM%%RANDOM%.json"

:: Check if curl is installed
where curl >nul 2>&1
if errorlevel 1 (
    echo ERROR: curl is not installed or not in PATH.
    pause
    exit /b 1
)

:: Check if jq is installed
where jq >nul 2>&1
if errorlevel 1 (
    echo ERROR: jq is not installed or not in PATH.
    pause
    exit /b 1
)

:: Check if a file argument is provided
if "%~1"=="" (
    echo ERROR: No file specified!
    echo Usage: %~nx0 file_to_upload
    pause
    exit /b 1
)

:: Check if the file exists
set "FILE=%~1"
if not exist "%FILE%" (
    echo ERROR: File "%FILE%" not found!
    pause
    exit /b 1
)

:: Query GoFile API for the best server
echo Getting GoFile upload server...
curl -fsS "https://api.gofile.io/getServer" -o "%SERVER_JSON%"
if errorlevel 1 (
    echo ERROR: Failed to query GoFile server API.
    call :cleanup
    pause
    exit /b 1
)

:: Debug: Show API response
if "%DEBUG%"=="1" (
    echo Server Response:
    type "%SERVER_JSON%"
)

:: Validate JSON before parsing it
jq -e . "%SERVER_JSON%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: GoFile server API returned invalid JSON.
    call :cleanup
    pause
    exit /b 1
)

:: Extract the correct server name
set "SERVER="
for /f "usebackq delims=" %%i in (`jq -re ".data.server // empty" "%SERVER_JSON%" 2^>nul`) do (
    set "SERVER=%%i"
)

:: Debug: Show selected server
if "%DEBUG%"=="1" (
    echo Selected Server: !SERVER!
)

:: Check if server was retrieved
if not defined SERVER (
    echo ERROR: Failed to retrieve a server from GoFile API.
    if "%DEBUG%"=="1" type "%SERVER_JSON%"
    call :cleanup
    pause
    exit /b 1
)

:: Upload the file with a progress bar
echo Uploading file, please wait...
curl -fS --progress-bar -F "file=@%FILE%" "https://!SERVER!.gofile.io/uploadFile" -o "%UPLOAD_JSON%"
if errorlevel 1 (
    echo ERROR: Upload request failed.
    if "%DEBUG%"=="1" if exist "%UPLOAD_JSON%" type "%UPLOAD_JSON%"
    call :cleanup
    pause
    exit /b 1
)

:: Debug: Show upload response
if "%DEBUG%"=="1" (
    echo Upload Response:
    type "%UPLOAD_JSON%"
)

:: Validate JSON before parsing it
jq -e . "%UPLOAD_JSON%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Upload API returned invalid JSON.
    call :cleanup
    pause
    exit /b 1
)

:: Extract the download link
set "LINK="
for /f "usebackq delims=" %%i in (`jq -re ".data.downloadPage // empty" "%UPLOAD_JSON%" 2^>nul`) do (
    set "LINK=%%i"
)

:: Check if upload was successful
if not defined LINK (
    echo ERROR: Upload failed or download link not retrieved.
    if "%DEBUG%"=="1" type "%UPLOAD_JSON%"
    call :cleanup
    pause
    exit /b 1
)

:: Show the download link
echo.
echo Upload successful! Download link:
echo !LINK!
call :cleanup
pause
exit /b 0

:cleanup
del "%SERVER_JSON%" "%UPLOAD_JSON%" >nul 2>&1
exit /b 0