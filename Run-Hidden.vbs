' Run-Hidden.vbs
' Launches PowerShell script completely hidden (no flash)
' Usage: wscript Run-Hidden.vbs [Day|Night]

Set WshShell = CreateObject("WScript.Shell")
scriptFolder = Replace(WScript.ScriptFullName, WScript.ScriptName, "")
scriptPath = scriptFolder & "Switch-Wallpapers.ps1"

' Get optional Period argument
period = ""
If WScript.Arguments.Count > 0 Then
    period = " -Period " & WScript.Arguments(0)
End If

WshShell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptPath & """" & period, 0, False
