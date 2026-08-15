#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

Running      := false
SequenceMode := false
SeqIndex     := 1
ClickType    := "Left"
Interval     := 100        ; ms

HK_Toggle := "F6"
HK_Record := "F7"
HK_Exit   := "F12"

Positions := []

CP := Gui("+AlwaysOnTop +MinimizeBox", "Autoclicker")
CP.SetFont("s10", "Segoe UI")
CP.MarginX := 12
CP.MarginY := 10
CP.OnEvent("Close", (*) => ExitApp())

grpStatus := CP.AddGroupBox("xm w320 h54", "Status")
lblMode   := CP.AddText("xp+10 yp+18 w140 Center +Border", "Click-at-mouse")
lblStatus := CP.AddText("x+10 w140 h22 Center +Border cCC0000", "STOPPED")

btnToggle := CP.AddButton("xm y+14 w320 h34", "▶  Start")
btnToggle.SetFont("s11 Bold")
btnToggle.OnEvent("Click", ToggleClicker)

CP.AddGroupBox("xm y+10 w320 h56", "Mode")
radMouse := CP.AddRadio("xp+10 yp+18 Checked", "Click at mouse position")
radMouse.OnEvent("Click", (*) => SetMode(false))
radSeq   := CP.AddRadio("x+16", "Sequence mode")
radSeq.OnEvent("Click",  (*) => SetMode(true))

CP.AddGroupBox("xm y+10 w320 h56", "Action")
ddAction := CP.AddDropDownList("xp+10 yp+18 w110 Choose1", ["Left","Right","Middle"])
ddAction.OnEvent("Change", (*) => (ClickType := ddAction.Text, edCustom.Value := ""))
edCustom := CP.AddEdit("x+8 w100", "")
edCustom.SetFont("", "Consolas")
CP.AddText("x+6 yp+4 c808080", "custom key")
edCustom.OnEvent("Change", (*) => (Trim(edCustom.Value) != "" ? ClickType := Trim(edCustom.Value) : ""))

CP.AddGroupBox("xm y+10 w320 h76", "Interval")
slInterval := CP.AddSlider("xp+10 yp+22 w200 ToolTip Range1-5000", Interval)
edInterval := CP.AddEdit("x+8 w58", Interval)
CP.AddText("x+4 yp+4", "ms")
slInterval.OnEvent("Change", SyncSliderToEdit)
edInterval.OnEvent("Change", SyncEditToSlider)
lblHuman := CP.AddText("xp-70 y+6 w200 c0055CC", IntervalToHuman(Interval))

CP.AddGroupBox("xm y+10 w320 h56", "Hotkeys")
CP.AddText("xp+10 yp+20", "Start/Stop:")
btnHKToggle := CP.AddButton("x+8 w100 h22", HK_Toggle)
btnHKToggle.OnEvent("Click", (*) => CaptureHotkey("toggle"))

CP.AddText("x+14", "Record:")
btnHKRecord := CP.AddButton("x+8 w100 h22", HK_Record)
btnHKRecord.OnEvent("Click", (*) => CaptureHotkey("record"))

CP.AddGroupBox("xm y+10 w320 h240", "Sequence Positions")
lv := CP.AddListView("xp+10 yp+18 w300 h118 Grid", ["#","X","Y","Button","Delay (ms)"])
lv.ModifyCol(1, 28)
lv.ModifyCol(2, 50)
lv.ModifyCol(3, 50)
lv.ModifyCol(4, 60)
lv.ModifyCol(5, 72)
lv.OnEvent("DoubleClick", EditSequenceRow)

btnRecord  := CP.AddButton("xm+10 y+6 w144", "⊕  Record pos  (" . HK_Record . ")")
btnRecord.OnEvent("Click", RecordPosition)
btnDelRow  := CP.AddButton("x+8 w144", "✕  Remove selected")
btnDelRow.OnEvent("Click", RemoveSelected)

CP.AddText("xm+10 y+6", "X")
edX      := CP.AddEdit("x+4 w50", "")
CP.AddText("x+6 yp+4", "Y")
edY      := CP.AddEdit("x+4 w50", "")
CP.AddText("x+6 yp+4", "Btn")
ddSeqBtn := CP.AddDropDownList("x+4 w80 Choose1", ["Left","Right","Middle"])
CP.AddText("x+6 yp+4", "Delay")
edSeqDly := CP.AddEdit("x+4 w50", Interval)
CP.AddText("x+3 yp+4", "ms")
btnAddRow := CP.AddButton("xm+10 y+6 w300", "Add to sequence")
btnAddRow.OnEvent("Click", AddManualEntry)

CP.AddButton("xm y+12 w320", "Exit  (" . HK_Exit . ")").OnEvent("Click", (*) => ExitApp())

CP.Show("w344")

Hotkey HK_Toggle, ToggleClicker
Hotkey HK_Record, RecordPosition
Hotkey HK_Exit,   (*) => ExitApp()

CaptureHotkey(which) {
    global HK_Toggle, HK_Record

    ; Show which button is waiting
    if which = "toggle"
        btnHKToggle.Text := "Press a key..."
    else
        btnHKRecord.Text := "Press a key..."

    ; Suspend active hotkeys so they don't fire during capture
    Suspend true

    ih := InputHook("L1 M T5")   ; 1 key, allow modifiers, 5s timeout
    ih.KeyOpt("{All}", "SE")      ; End on any key, include special keys
    ih.Start()
    ih.Wait()

    Suspend false

    if ih.EndReason = "Timeout" || ih.EndKey = "" {
        if which = "toggle"
            btnHKToggle.Text := HK_Toggle
        else
            btnHKRecord.Text := HK_Record
        return
    }

    ; Build modifier prefix from held keys at time of capture
    mods := ""
    if GetKeyState("LWin",  "P") || GetKeyState("RWin",  "P")
        mods .= "#"
    if GetKeyState("LAlt",  "P") || GetKeyState("RAlt",  "P")
        mods .= "!"
    if GetKeyState("LCtrl", "P") || GetKeyState("RCtrl", "P")
        mods .= "^"
    if GetKeyState("LShift","P") || GetKeyState("RShift","P")
        mods .= "+"

    newKey := mods . ih.EndKey

    try {
        if which = "toggle" {
            Hotkey HK_Toggle, "Off"
            Hotkey newKey, ToggleClicker
            HK_Toggle := newKey
            btnHKToggle.Text := newKey
            btnToggle.Text   := "▶  Start  (" . newKey . ")"
        } else {
            Hotkey HK_Record, "Off"
            Hotkey newKey, RecordPosition
            HK_Record := newKey
            btnHKRecord.Text := newKey
            btnRecord.Text   := "⊕  Record pos  (" . newKey . ")"
        }
    } catch as e {
        MsgBox "Could not bind key: " . newKey . "`n" . e.Message, "Error", 48
        if which = "toggle"
            btnHKToggle.Text := HK_Toggle
        else
            btnHKRecord.Text := HK_Record
    }
}


IntervalToHuman(ms) {
    if ms < 1000
        return ms . " ms"
    if ms < 60000
        return Round(ms / 1000, 2) . " s"
    if ms < 3600000
        return Round(ms / 60000, 2) . " min"
    return Round(ms / 3600000, 2) . " hr"
}

SyncSliderToEdit(*) {
    global Interval
    Interval := slInterval.Value
    edInterval.Value := Interval
    lblHuman.Text := IntervalToHuman(Interval)
}

SyncEditToSlider(*) {
    global Interval
    v := Trim(edInterval.Value)
    if IsInteger(v) && Integer(v) >= 1 {
        Interval := Integer(v)
        slInterval.Value := Min(Interval, 5000)
        lblHuman.Text := IntervalToHuman(Interval)
    }
}


SetMode(seq) {
    global SequenceMode
    if Running {
        if seq
            radMouse.Value := 1
        else
            radSeq.Value := 1
        MsgBox "Stop the clicker before switching modes.", "Autoclicker", 48
        return
    }
    SequenceMode := seq
    lblMode.Text := seq ? "Sequence" : "Click-at-mouse"
}

ToggleClicker(*) {
    global Running, SeqIndex

    Running := !Running
    SeqIndex := 1

    if Running {
        if SequenceMode && Positions.Length = 0 {
            Running := false
            MsgBox "Add at least one position before starting sequence mode.", "Autoclicker", 48
            return
        }
        btnToggle.Text := "⏹  Stop  (" . HK_Toggle . ")"
        lblStatus.Text := "RUNNING"
        lblStatus.Opt("cFFFFFF Background008800")
        if SequenceMode
            SetTimer SequenceStep, 50
        else
            SetTimer ClickStep, Interval
    } else {
        SetTimer ClickStep, 0
        SetTimer SequenceStep, 0
        btnToggle.Text := "▶  Start  (" . HK_Toggle . ")"
        lblStatus.Text := "STOPPED"
        lblStatus.Opt("cCC0000 BackgroundDefault")
    }
}

ClickStep() {
    global Running, ClickType, Interval
    if !Running {
        SetTimer ClickStep, 0
        return
    }
    DoAction(ClickType)
    SetTimer ClickStep, Interval
}

SequenceStep() {
    global Running, Positions, SeqIndex, Interval
    if !Running || Positions.Length = 0 {
        SetTimer SequenceStep, 0
        return
    }
    entry := Positions[SeqIndex]
    MouseMove entry.x, entry.y
    DoAction entry.button
    delay := entry.HasOwnProp("delay") ? entry.delay : Interval
    SeqIndex := (SeqIndex >= Positions.Length) ? 1 : SeqIndex + 1
    SetTimer SequenceStep, delay
}

DoAction(action) {
    if action = "Left"
        Click
    else if action = "Right"
        Click "Right"
    else if action = "Middle"
        Click "Middle"
    else
        Send "{" . action . "}"
}

RecordPosition(*) {
    global Positions, Interval, ClickType
    MouseGetPos &mx, &my
    btn := ClickType
    dly := Interval
    Positions.Push({x: mx, y: my, button: btn, delay: dly})
    n := Positions.Length
    lv.Add("", n, mx, my, btn, dly)
}

RemoveSelected(*) {
    global Positions
    row := lv.GetNext(0)
    if !row
        return
    lv.Delete(row)
    Positions.RemoveAt(row)
    loop lv.GetCount()
        lv.Modify(A_Index, "", A_Index)
}

EditSequenceRow(LV, row) {
    global Positions
    if row = 0
        return

    p := Positions[row]

    eg := Gui("+AlwaysOnTop +Owner" . CP.Hwnd, "Edit Position #" . row)
    eg.SetFont("s10", "Segoe UI")
    eg.MarginX := 12
    eg.MarginY := 10

    eg.AddText("xm", "X:")
    eX := eg.AddEdit("xm w100", p.x)
    eg.AddText("xm", "Y:")
    eY := eg.AddEdit("xm w100", p.y)
    eg.AddText("xm", "Button / key:")
    eBt := eg.AddEdit("xm w100", p.button)
    eg.AddText("xm", "Delay (ms):")
    eDl := eg.AddEdit("xm w100", p.delay)

    eg.AddButton("xm w92 Default", "Save").OnEvent("Click", SaveRow)
    eg.AddButton("x+8 w92", "Cancel").OnEvent("Click", (*) => eg.Destroy())
    eg.Show()

    SaveRow(*) {
        nx := Trim(eX.Value)
        ny := Trim(eY.Value)
        nb := Trim(eBt.Value)
        nd := Trim(eDl.Value)
        if !IsInteger(nx) || !IsInteger(ny) || !IsInteger(nd) {
            MsgBox "X, Y, and Delay must be integers.", "Invalid input", 48
            return
        }
        Positions[row] := {x: Integer(nx), y: Integer(ny), button: nb, delay: Integer(nd)}
        lv.Modify(row, "", row, nx, ny, nb, nd)
        eg.Destroy()
    }
}

AddManualEntry(*) {
    global Positions, Interval
    x   := Trim(edX.Value)
    y   := Trim(edY.Value)
    btn := ddSeqBtn.Text
    dly := Trim(edSeqDly.Value)
    if !IsInteger(x) || !IsInteger(y) {
        MsgBox "X and Y must be integers.", "Invalid entry", 48
        return
    }
    dly := IsInteger(dly) ? Integer(dly) : Interval
    Positions.Push({x: Integer(x), y: Integer(y), button: btn, delay: dly})
    n := Positions.Length
    lv.Add("", n, x, y, btn, dly)
    edX.Value := ""
    edY.Value := ""
}
