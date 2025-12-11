; AHK v2 script to click "Apply" button in LockscreenGif
#Requires AutoHotkey v2.0

; Wait for LockscreenGif window
WinWait("ahk_exe LockscreenGif.exe",, 10)
if !WinExist("ahk_exe LockscreenGif.exe") {
    ExitApp
}

; Activate the window
WinActivate("ahk_exe LockscreenGif.exe")
Sleep(1000)

; Get window position
WinGetPos(&X, &Y, &W, &H, "ahk_exe LockscreenGif.exe")

; The "Apply" button is in the bottom-left corner
; Based on screenshot: approximately 50px from left, 30px from bottom
ClickX := X + 50
ClickY := Y + H - 30

Click(ClickX, ClickY)
Sleep(3000)

ExitApp
