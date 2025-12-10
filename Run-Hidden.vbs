' Run-Hidden.vbs
' Launches PowerShell script completely hidden (no flash)
Set WshShell = CreateObject("WScript.Shell")
scriptPath = Replace(WScript.ScriptFullName, WScript.ScriptName, "") & "Switch-Wallpapers.ps1"
WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """", 0, False
