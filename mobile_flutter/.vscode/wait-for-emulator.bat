@echo off
set ADB=C:\Users\jonat\AppData\Local\Android\sdk\platform-tools\adb.exe
set EMULATOR=C:\Users\jonat\AppData\Local\Android\sdk\emulator\emulator.exe
set AVD=Pixel_7
set SERIAL=emulator-5554

"%ADB%" devices | findstr /R /C:"%SERIAL%[ ]*device" >nul
if not errorlevel 1 exit /b 0

start "" "%EMULATOR%" -avd %AVD% -no-snapshot

for /L %%i in (1,1,30) do (
  timeout /t 2 /nobreak >nul
  "%ADB%" devices | findstr /R /C:"%SERIAL%[ ]*device" >nul
  if not errorlevel 1 exit /b 0
)

exit /b 1
