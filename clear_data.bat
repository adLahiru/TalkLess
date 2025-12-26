@echo off
echo Clearing TalkLess application data...

REM Clear registry entries
reg delete "HKCU\Software\TalkLess" /f 2>nul

REM Clear application data directories
rmdir /s /q "%APPDATA%\TalkLess" 2>nul
rmdir /s /q "%LOCALAPPDATA%\TalkLess" 2>nul
rmdir /s /q "%PROGRAMDATA%\TalkLess" 2>nul

echo TalkLess data cleared successfully!
pause
