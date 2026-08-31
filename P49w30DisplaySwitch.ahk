#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 1

; Lenovo ThinkVision P49w-30 laptop/right-pane input switch.
; Copy p49w30-switch.ini.example to p49w30-switch.ini to override defaults.

global HDMI1_VALUE := 4401       ; 0x1131: right HDMI 1, left USB-C
global DISPLAYPORT_VALUE := 3889 ; 0x0F31: right DisplayPort, left USB-C
global VCP_CODE := 60
global STABILITY_WAIT_MS := 6000

global ConfigFile := A_ScriptDir "\p49w30-switch.ini"
global ControlMyMonitorPath := IniRead(
    ConfigFile,
    "P49w30",
    "ControlMyMonitorPath",
    "C:\Tools\ControlMyMonitor\ControlMyMonitor.exe"
)
global MonitorTarget := IniRead(ConfigFile, "P49w30", "MonitorTarget", "Primary")
global ReadFile := A_Temp "\p49w30-ddc60-" DllCall("GetCurrentProcessId") ".txt"

if (A_Args.Length > 0 && A_Args[1] = "--self-test") {
    RunSelfTests()
    ExitApp(0)
}

OnExit(CleanupReadFile)

^!d::ToggleLaptopPane()

ToggleLaptopPane() {
    global ControlMyMonitorPath, MonitorTarget, STABILITY_WAIT_MS
    global VCP_CODE, DISPLAYPORT_VALUE

    if !FileExist(ControlMyMonitorPath) {
        NotifyError("ControlMyMonitor was not found. Check p49w30-switch.ini.")
        return
    }

    ; A valid-looking value can still be stale immediately after a switch. Requiring
    ; the same exact full 16-bit value on both sides of the unsafe window prevents it
    ; from authorizing a write.
    first := ReadInputValue()
    if !IsKnownValue(first) {
        NotifyError("Unsafe DDC read (" FormatRead(first) "). No write was made; retry later.")
        return
    }

    Sleep(STABILITY_WAIT_MS)

    second := ReadInputValue()
    if !IsKnownValue(second) || second != first {
        NotifyError("DDC value was not stable. No write was made; retry later.")
        return
    }

    nextValue := ToggleValue(second)
    if !IsKnownValue(nextValue) {
        NotifyError("Unexpected input state. No write was made.")
        return
    }

    command := Quote(ControlMyMonitorPath)
        . " /SetValue " . Quote(MonitorTarget)
        . " " . VCP_CODE . " " . nextValue
    try exitCode := RunWait(command, , "Hide")
    catch as err {
        NotifyError("ControlMyMonitor could not run: " err.Message)
        return
    }

    if (exitCode != 0) {
        NotifyError("ControlMyMonitor write failed (exit " exitCode ").")
        return
    }

    destination := (nextValue = DISPLAYPORT_VALUE) ? "DisplayPort" : "HDMI 1"
    TrayTip("Laptop pane switch requested: " destination, "P49w-30", 2)
}

ReadInputValue() {
    global ControlMyMonitorPath, MonitorTarget, ReadFile, VCP_CODE

    try FileDelete(ReadFile)

    command := Quote(ControlMyMonitorPath)
        . " /GetValueValue " . Quote(MonitorTarget)
        . " " . VCP_CODE . " /stext " . Quote(ReadFile)
    try exitCode := RunWait(command, , "Hide")
    catch {
        return -1
    }

    if (exitCode != 0 || !FileExist(ReadFile))
        return -1

    try output := Trim(FileRead(ReadFile, "UTF-8"))
    catch {
        return -1
    }

    ; Anchoring the complete file avoids accepting a stale/error message containing digits.
    if !RegExMatch(output, "^\d{1,5}$")
        return -1

    return Integer(output)
}

IsKnownValue(value) {
    global HDMI1_VALUE, DISPLAYPORT_VALUE
    return value = HDMI1_VALUE || value = DISPLAYPORT_VALUE
}

ToggleValue(value) {
    global HDMI1_VALUE, DISPLAYPORT_VALUE

    if !IsKnownValue(value)
        return -1

    lowByte := Mod(value, 256)
    highByte := Floor(value / 256)
    nextHighByte := (highByte = 0x11) ? 0x0F : 0x11
    return lowByte + nextHighByte * 256
}

Quote(value) {
    ; Config values are local operator-controlled strings. Double embedded quotes so
    ; Windows command-line parsing cannot truncate an otherwise valid path/name.
    return '"' StrReplace(value, '"', '""') '"'
}

FormatRead(value) {
    return (value = -1) ? "missing/invalid" : String(value)
}

NotifyError(message) {
    TrayTip(message, "P49w-30 — no change", 3)
}

CleanupReadFile(*) {
    global ReadFile
    try FileDelete(ReadFile)
}

RunSelfTests() {
    global HDMI1_VALUE, DISPLAYPORT_VALUE

    Assert(ToggleValue(HDMI1_VALUE) = DISPLAYPORT_VALUE, "HDMI 1 -> DisplayPort")
    Assert(ToggleValue(DISPLAYPORT_VALUE) = HDMI1_VALUE, "DisplayPort -> HDMI 1")
    Assert(Mod(ToggleValue(HDMI1_VALUE), 256) = 49, "preserves low byte from HDMI")
    Assert(Mod(ToggleValue(DISPLAYPORT_VALUE), 256) = 49, "preserves low byte from DP")
    Assert(ToggleValue(0) = -1, "rejects zero")
    Assert(ToggleValue(4402) = -1, "rejects wrong low byte")
    Assert(ToggleValue(4145) = -1, "rejects unknown high byte")
    FileAppend("All P49w-30 pure-logic tests passed.`n", "*")
}

Assert(condition, description) {
    if !condition {
        FileAppend("FAILED: " description "`n", "**")
        ExitApp(1)
    }
}
