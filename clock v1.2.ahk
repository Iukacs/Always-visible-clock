#Requires AutoHotkey v2.0
#SingleInstance Force

; Alapbeállítások
global defaultColor := "A68B70"
global defaultSize := 12

; Beállítások betöltése
global settingsFile := A_ScriptDir "\ora_beallitasok.ini"
global clockColor := IniRead(settingsFile, "Settings", "Color", defaultColor)
global fontSize := Integer(IniRead(settingsFile, "Settings", "FontSize", defaultSize))

; Globális változók
global clock
global clockText
global settingsGui
global fontSizeSlider
global sizeLabel
global T := GetTranslations()
global positionGui
global alarmGui
global alarmText
global alarmStage := 0
global alarmInterval := 0
global savedX := IniRead(settingsFile, "Settings", "X", "")
global savedY := IniRead(settingsFile, "Settings", "Y", "")
global alarmX := 0
global alarmY := 0
customAlarmMinutes := 0
customAlarmLoop := false
customAlarmTime := ""
global clockFormat := IniRead(settingsFile, "Settings", "ClockFormat", "24")

; Érvényes betűméret ellenőrzése
if (fontSize < 8 || fontSize > 18)
    fontSize := defaultSize

; Tálcaikon
TraySetIcon(A_ScriptDir "\ora_ikon.ico")

; Színválasztó almenü
colorMenu := Menu()
colorMenu.Add(T.brown, (*) => SetClockColor("A68B70"))
colorMenu.Add(T.white, (*) => SetClockColor("FFFFFF"))
colorMenu.Add(T.green, (*) => SetClockColor("00FF00"))
colorMenu.Add(T.blue, (*) => SetClockColor("0080FF"))
colorMenu.Add()
colorMenu.Add(T.custom, ChooseClockColor)

; Fő tálcamenü
A_TrayMenu.Delete()
A_TrayMenu.Add(T.toggle, ToggleClock)
A_TrayMenu.Add(T.color, ChooseClockColor)
A_TrayMenu.Add(T.size, ShowSizeSettings)
A_TrayMenu.Add(T.position, ShowPositionSettings)

; Ébresztő almenü
A_TrayMenu.Add()
A_TrayMenu.Add("Óraformátum: " (clockFormat = "24" ? "24-hour clock" : "12-hour clock (AM/PM)"), ToggleClockFormat)
alarmMenu := Menu()
alarmMenu.Add("1 perc", (*) => SetAlarmInterval(1))
alarmMenu.Add(T.alarm15, (*) => SetAlarmInterval(15))
alarmMenu.Add(T.alarm30, (*) => SetAlarmInterval(30))
alarmMenu.Add(T.alarm60, (*) => SetAlarmInterval(60))
alarmMenu.Add()
alarmMenu.Add("Egyedi idő...", ShowCustomAlarm)
alarmMenu.Add()
alarmMenu.Add(T.alarmOff, (*) => SetAlarmInterval(0))

A_TrayMenu.Add(T.alarm, alarmMenu)

A_TrayMenu.Add()
A_TrayMenu.Add(T.reset, ResetDefaults)
A_TrayMenu.Add(T.save, SaveSettings)
A_TrayMenu.Add()
A_TrayMenu.Add(T.exit, (*) => ExitApp())
A_TrayMenu.Default := T.toggle
A_TrayMenu.ClickCount := 1

; Óraablak
clock := Gui("+AlwaysOnTop -Caption +ToolWindow")
clock.BackColor := "010101"

clock.SetFont("s" fontSize " bold c" clockColor, "DS-Digital")
clockText := clock.AddText("x0 y0 w125 h20 Center", "")
alarmDot := clock.AddText("x130 y0 w15 h20 Center cRed Hidden", "●")
alarmDot.OnEvent("Click", (*) => alarmMenu.Show())

; Az óra azonnali feltöltése és másodpercenkénti frissítése
UpdateClock()
SetTimer(UpdateClock, 1000)

; Végleges pozíció
MonitorGetWorkArea(, &left, &top, &right, &bottom)

startX := (savedX = "") ? (right - 250) : Integer(savedX)
startY := (savedY = "") ? (top + 10) : Integer(savedY)

clock.Show("NA x" startX " y" startY " w145 h20")

; Átlátszó háttér
WinSetTransColor("010101", clock.Hwnd)

; Ébresztőablak
alarmGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
alarmGui.BackColor := "010101"
alarmGui.SetFont("s48 cFF0000", "DS-Digital")
alarmText := alarmGui.AddText("x0 y0 w420 h100 Center", "")
WinSetTransColor("010101", alarmGui.Hwnd)

; Mozgathatóság az egész óra területén
OnMessage(0x201, WM_LBUTTONDOWN)

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global clock, clockText

    if (hwnd = clock.Hwnd || hwnd = clockText.Hwnd) {
        PostMessage(0xA1, 2,,, "ahk_id " clock.Hwnd)
    }
}

; Idő frissítése
UpdateClock() {
    global clockText, clockFormat

    if (clockFormat = "24")
        clockText.Value := FormatTime(, "HH:mm:ss")
    else
        clockText.Value := FormatTime(, "hh:mm:ss tt")
}

; Ébresztő időközének beállítása
SetAlarmInterval(minutes, *) {
    global alarmInterval, customAlarmMinutes, customAlarmLoop, T

    SetTimer(AlarmTrigger, 0)

    customAlarmMinutes := 0
    customAlarmLoop := false
    alarmInterval := minutes

    if (minutes = 0) {
        TrayTip(T.alarmOff, T.alarm, 2)
    } else {
        ScheduleNextAlarm()
        TrayTip(minutes " perc múlva ébresztő", T.alarm, 2)
    }
}

; Következő pontos időpont kiszámítása
ScheduleNextAlarm() {
    global alarmInterval

    if (alarmInterval = 0)
        return

    currentMinute := Integer(FormatTime(, "m"))
    currentSecond := Integer(FormatTime(, "s"))

    minutesLeft := alarmInterval - Mod(currentMinute, alarmInterval)
    secondsLeft := minutesLeft * 60 - currentSecond

    SetTimer(AlarmTrigger, -secondsLeft * 1000)
}

; Ébresztő elindítása
AlarmTrigger() {
    global alarmGui, alarmText, alarmStage, alarmX, alarmY
    global alarmInterval, customAlarmMinutes, customAlarmLoop

    alarmText.Value := FormatTime(, "HH:mm:ss")

    MonitorGetWorkArea(, &left, &top, &right, &bottom)

    alarmX := left + ((right - left - 420) // 2)
    alarmY := top + ((bottom - top - 100) // 2)

    alarmStage := 0
    AlarmFlashStep()

    if (customAlarmMinutes > 0) {
        if (customAlarmLoop) {
            SetTimer(AlarmTrigger, -customAlarmMinutes * 60000)
        } else {
            customAlarmMinutes := 0
        }
    } else {
        ScheduleNextAlarm()
    }
}

RepeatCustomTimeAlarm() {
    global customAlarmTime, customAlarmLoop

    if (customAlarmLoop)
        ScheduleCustomTimeAlarm()
}

; Lassabb, nagyobb villogás – összesen 1,5 másodperc
AlarmFlashStep() {
    global alarmGui, alarmStage, alarmX, alarmY

    alarmStage += 1

    switch alarmStage {
        case 1:
            alarmGui.Show("NA x" alarmX " y" alarmY " w700 h180")
        case 2:
            alarmGui.Hide()
        case 3:
            alarmGui.Show("NA")
        case 4:
            alarmGui.Hide()
        case 5:
            alarmGui.Show("NA")
        case 6:
            alarmGui.Hide()
        case 7:
            return
    }

    SetTimer(AlarmFlashStep, -250)
}

; Szín módosítása
SetClockColor(newColor) {
    global clockColor, fontSize, clockText

    clockColor := newColor
    clockText.SetFont("s" fontSize " bold c" clockColor, "DS-Digital")
    SaveSettings()
}

; Betűméret módosítása
SetClockSize(newSize) {
    global fontSize, clockColor, clockText, sizeLabel, T

    fontSize := Max(8, Min(18, Round(newSize)))

    clockText.SetFont("s" fontSize " c" clockColor, "DS-Digital")

    if IsSet(sizeLabel)
        sizeLabel.Value := T.currentSize " " fontSize

    SaveSettings()
}

; Betűméret-beállító ablak
ShowSizeSettings(*) {
    global settingsGui, fontSizeSlider, sizeLabel, fontSize, T

    fontSizeSlider.Value := fontSize
    sizeLabel.Value := T.currentSize " " fontSize

    pos := GetSettingsPosition(310, 125)
    settingsGui.Show("NA x" pos[1] " y" pos[2] " w310 h125")
}

; Csúszka eseménye
OnSliderChange(ctrl, *) {
    SetClockSize(ctrl.Value)
}

; Alapbeállítások visszaállítása
ResetDefaults(*) {
    global defaultColor, defaultSize, clockColor, fontSize
    global settingsFile, clock, clockText, savedX, savedY

    ; Alapértelmezett szín és méret
    clockColor := defaultColor
    fontSize := defaultSize

    ; Mentett pozíció törlése
    savedX := ""
    savedY := ""
    IniDelete(settingsFile, "Settings", "X")
    IniDelete(settingsFile, "Settings", "Y")

    ; Óra visszahelyezése az eredeti pozícióba
    MonitorGetWorkArea(, &left, &top, &right, &bottom)
    clock.Move(right - 250, top + 10)

    ; Beállítások frissítése
    clockText.SetFont("s" fontSize " c" clockColor)
    IniWrite(clockColor, settingsFile, "Settings", "Color")
    IniWrite(fontSize, settingsFile, "Settings", "FontSize")
}


; Egyéni szín kiválasztása
ChooseClockColor(*) {
    global clockColor

    pos := GetSettingsPosition(300, 450)

    cc := Buffer(9 * A_PtrSize, 0)
    customColors := Buffer(64, 0)

    initialColor := Integer("0x" clockColor)

    r := (initialColor >> 16) & 0xFF
    g := (initialColor >> 8) & 0xFF
    b := initialColor & 0xFF

    rgbColor := (b << 16) | (g << 8) | r

    NumPut("UInt", cc.Size, cc, 0)
    NumPut("Ptr", A_ScriptHwnd, cc, A_PtrSize)
    NumPut("UInt", rgbColor, cc, 3 * A_PtrSize)
    NumPut("Ptr", customColors.Ptr, cc, 4 * A_PtrSize)
    NumPut("UInt", 0x00000003, cc, 5 * A_PtrSize)

    ; A színválasztó ablak megnyitása előtt elindítjuk a pozicionálást
    global colorDialogX := pos[1]
    global colorDialogY := pos[2]
    SetTimer(AlarmFlashStep, -125)

    if DllCall("Comdlg32\ChooseColorW", "Ptr", cc, "Int") {
        selected := NumGet(cc, 3 * A_PtrSize, "UInt")

        newColor := Format(
            "{:02X}{:02X}{:02X}",
            selected & 0xFF,
            (selected >> 8) & 0xFF,
            (selected >> 16) & 0xFF
        )

        SetClockColor(newColor)
    }

    SetTimer(PositionColorDialog, 0)
}


; Színválasztó ablak pozicionálása
PositionColorDialog() {
    global colorDialogX, colorDialogY

    hwnd := WinExist("A")

    if !hwnd
        return

    if (WinGetClass(hwnd) = "#32770") {
        WinMove(colorDialogX, colorDialogY,,, hwnd)
        SetTimer(PositionColorDialog, 0)
    }
}

; Beállítások mentése
SaveSettings(*) {
    global settingsFile, clockColor, fontSize

    IniWrite(clockColor, settingsFile, "Settings", "Color")
    IniWrite(fontSize, settingsFile, "Settings", "FontSize")
}

; Óra elrejtése / megjelenítése
ToggleClock(*) {
    global clock

    if (WinGetStyle(clock.Hwnd) & 0x10000000)
        clock.Hide()
    else
        clock.Show()
}

; Betűméret-beállító ablak létrehozása
settingsGui := Gui("+AlwaysOnTop", T.sizeTitle)

sizeLabel := settingsGui.AddText(
    "x20 y15 w270 h20",
    T.currentSize " " fontSize
)

fontSizeSlider := settingsGui.Add(
    "Slider",
    "x20 y42 w270 Range8-18 ToolTip",
    fontSize
)

fontSizeSlider.OnEvent("Change", OnSliderChange)

resetButton := settingsGui.AddButton(
    "x20 y80 w120 h28",
    T.reset
)
resetButton.OnEvent("Click", ResetDefaults)

closeButton := settingsGui.AddButton(
    "x170 y80 w120 h28",
    T.close
)
closeButton.OnEvent("Click", (*) => settingsGui.Hide())

settingsGui.OnEvent("Close", (*) => settingsGui.Hide())

; Pozícióállító ablak
positionGui := Gui("+AlwaysOnTop", T.position)
positionGui.SetFont("s12")

upButton := positionGui.AddButton("x65 y10 w50 h35", "↑")
upButton.OnEvent("Click", (*) => MoveClock(0, -10))

leftButton := positionGui.AddButton("x10 y55 w50 h35", "←")
leftButton.OnEvent("Click", (*) => MoveClock(-10, 0))

rightButton := positionGui.AddButton("x120 y55 w50 h35", "→")
rightButton.OnEvent("Click", (*) => MoveClock(10, 0))

downButton := positionGui.AddButton("x65 y100 w50 h35", "↓")
downButton.OnEvent("Click", (*) => MoveClock(0, 10))

savePositionButton := positionGui.AddButton(
    "x10 y145 w160 h30",
    T.savePosition
)
savePositionButton.OnEvent("Click", SaveClockPosition)

positionGui.OnEvent("Close", (*) => positionGui.Hide())


; Pozícióállító ablak megnyitása
ShowPositionSettings(*) {
    global positionGui

    pos := GetSettingsPosition(180, 185)
    positionGui.Show("NA x" pos[1] " y" pos[2] " w180 h185")
}

; Óra mozgatása
MoveClock(dx, dy) {
    global clock

    WinGetPos(&x, &y,,, clock.Hwnd)

    clock.Move(x + dx, y + dy)
}


; Pozíció mentése
SaveClockPosition(*) {
    global clock, settingsFile, savedX, savedY, T

    WinGetPos(&x, &y,,, clock.Hwnd)

    savedX := x
    savedY := y

    IniWrite(x, settingsFile, "Settings", "X")
    IniWrite(y, settingsFile, "Settings", "Y")

    TrayTip(T.positionSaved, T.position, 2)
}

; Beállítóablak pozíciójának meghatározása
GetSettingsPosition(guiW, guiH) {
    global clock

    WinGetPos(&x, &y, &w, &h, clock.Hwnd)

    MonitorGetWorkArea(, &left, &top, &right, &bottom)

    margin := 10

    posX := x + w + margin
    posY := y

    if (posX + guiW > right)
        posX := x - guiW - margin

    posX := Max(left, Min(posX, right - guiW))
    posY := Max(top, Min(posY, bottom - guiH))

    return [posX, posY]
}

; Egyedi ébresztő ablakának megnyitása
ShowCustomAlarm(*) {
    customGui := Gui("+AlwaysOnTop", "Egyedi ébresztő")
    customGui.SetFont("s10")

    modeChoice := customGui.Add("DropDownList", "w220 Choose1", ["Perc", "Időpont"])
    modeChoice.OnEvent("Change", (ctrl, *) => UpdateCustomAlarmMode(ctrl, inputField))

    inputField := customGui.Add("Edit", "xm y+12 w220 Number", "11")

    loopCheck := customGui.Add("Checkbox", "xm y+12", "loop")

    startButton := customGui.Add("Button", "xm y+15 w100 Default", "Indítás")
    startButton.OnEvent("Click", (*) => StartCustomAlarm(customGui, inputField, modeChoice, loopCheck))

    customGui.Show()
    inputField.Focus()
}

UpdateCustomAlarmMode(ctrl, inputField) {
    if (ctrl.Value = 1) {
        inputField.Value := "11"
        inputField.Opt("+Number")
    } else {
        inputField.Value := FormatTime(, "HH:mm")
        inputField.Opt("-Number")
    }
}

; Egyedi ébresztő indítása
StartCustomAlarm(customGui, inputField, modeChoice, loopCheck) {
    global alarmInterval, customAlarmMinutes, customAlarmLoop

    SetTimer(AlarmTrigger, 0)
    alarmInterval := 0

    customAlarmLoop := loopCheck.Value
    customAlarmMinutes := 0

    if (modeChoice.Value = 1) {
        minutes := Integer(inputField.Value)

        if (minutes < 1) {
            MsgBox("Legalább 1 percet adj meg!")
            return
        }

        customAlarmMinutes := minutes

        currentSecond := Integer(FormatTime(, "s"))
        delay := (60 - currentSecond) * 1000 + (minutes - 1) * 60000

        SetTimer(AlarmTrigger, -delay)
        TrayTip(minutes " perc múlva ébresztő", "Egyedi ébresztő", 2)

    } else {
        time := inputField.Value

        if !RegExMatch(time, "^(?:[01]\d|2[0-3]):[0-5]\d$") {
            MsgBox("Érvényes időpontot adj meg, például: 18:45")
            return
        }

        customAlarmTime := time
        ScheduleCustomTimeAlarm()

        TrayTip(time " időpont beállítva", "Egyedi ébresztő", 2)
    }

    customGui.Destroy()
}

if (customAlarmMinutes > 0) {
    if (customAlarmLoop) {
        currentSecond := Integer(FormatTime(, "s"))
        delay := (60 - currentSecond) * 1000 + (customAlarmMinutes - 1) * 60000
        SetTimer(AlarmTrigger, -delay)
    } else {
        customAlarmMinutes := 0
    }
} else if (customAlarmTime != "") {
    RepeatCustomTimeAlarm()
} else {
    ScheduleNextAlarm()
}

ScheduleCustomTimeAlarm() {
    global customAlarmTime

    now := A_Now
    target := SubStr(now, 1, 8) StrReplace(customAlarmTime, ":", "")

    if (target <= now)
        target := DateAdd(target, 1, "Days")

    delay := DateDiff(target, now, "Seconds")
    SetTimer(AlarmTrigger, -delay * 1000)
}


ToggleClockFormat(*) {
    global clockFormat, settingsFile, T, alarmMenu

    clockFormat := (clockFormat = "24") ? "12" : "24"

    IniWrite(clockFormat, settingsFile, "Settings", "ClockFormat")

    UpdateClock()

    A_TrayMenu.Delete()

    A_TrayMenu.Add(T.toggle, ToggleClock)
    A_TrayMenu.Add(T.color, ChooseClockColor)
    A_TrayMenu.Add(T.size, ShowSizeSettings)
    A_TrayMenu.Add("Óraformátum: " (clockFormat = "24" ? "24-hour clock" : "12-hour clock (AM/PM)"), ToggleClockFormat)
    A_TrayMenu.Add(T.position, ShowPositionSettings)
    A_TrayMenu.Add(T.alarm, alarmMenu)
    A_TrayMenu.Add()
    A_TrayMenu.Add(T.reset, ResetDefaults)
    A_TrayMenu.Add(T.save, SaveSettings)
    A_TrayMenu.Add()
    A_TrayMenu.Add(T.exit, (*) => ExitApp())

    A_TrayMenu.Default := T.toggle
    A_TrayMenu.ClickCount := 1
}

; Windows nyelvének felismerése és fordítások
GetTranslations() {
    lang := DllCall("GetUserDefaultUILanguage", "UShort") & 0x3FF

    switch lang {

        case 0x0E: ; Magyar
            return {
                toggle: "Óra elrejtése / megjelenítése",
                color: "Betűszín",
                size: "Betűméret",
                save: "Beállítások mentése",
                reset: "Alapbeállítások visszaállítása",
                exit: "Kilépés",
                brown: "Barna",
                white: "Fehér",
                green: "Zöld",
                blue: "Kék",
                custom: "Egyéni szín...",
                sizeTitle: "Betűméret beállítása",
                currentSize: "Betűméret:",
                close: "Bezárás",
                position: "Pozíció beállítása",
                savePosition: "Pozíció mentése",
                positionSaved: "A pozíció elmentve!",
                alarm: "Ébresztő",
                alarm15: "15 percenként",
                alarm30: "30 percenként",
                alarm60: "60 percenként",
                alarmOff: "Kikapcsolás"
            }

        case 0x07: ; Német
            return {
                toggle: "Uhr ausblenden / anzeigen",
                color: "Schriftfarbe",
                size: "Schriftgröße",
                save: "Einstellungen speichern",
                reset: "Standardeinstellungen wiederherstellen",
                exit: "Beenden",
                brown: "Braun",
                white: "Weiß",
                green: "Grün",
                blue: "Blau",
                custom: "Eigene Farbe...",
                sizeTitle: "Schriftgröße einstellen",
                currentSize: "Schriftgröße:",
                close: "Schließen",
                position: "Position einstellen",
                savePosition: "Position speichern",
                positionSaved: "Position gespeichert!",
                alarm: "Erinnerung",
                alarm15: "Alle 15 Minuten",
                alarm30: "Alle 30 Minuten",
                alarm60: "Alle 60 Minuten",
                alarmOff: "Ausschalten"
            }

        case 0x0C: ; Francia
            return {
                toggle: "Masquer / afficher l’horloge",
                color: "Couleur du texte",
                size: "Taille du texte",
                save: "Enregistrer les paramètres",
                reset: "Restaurer les paramètres par défaut",
                exit: "Quitter",
                brown: "Marron",
                white: "Blanc",
                green: "Vert",
                blue: "Bleu",
                custom: "Couleur personnalisée...",
                sizeTitle: "Régler la taille du texte",
                currentSize: "Taille du texte :",
                close: "Fermer",
                position: "Régler la position",
                savePosition: "Enregistrer la position",
                positionSaved: "Position enregistrée !",
                alarm: "Rappel",
                alarm15: "Toutes les 15 minutes",
                alarm30: "Toutes les 30 minutes",
                alarm60: "Toutes les 60 minutes",
                alarmOff: "Désactiver"
            }

        case 0x15: ; Lengyel
            return {
                toggle: "Ukryj / pokaż zegar",
                color: "Kolor tekstu",
                size: "Rozmiar tekstu",
                save: "Zapisz ustawienia",
                reset: "Przywróć ustawienia domyślne",
                exit: "Zamknij",
                brown: "Brązowy",
                white: "Biały",
                green: "Zielony",
                blue: "Niebieski",
                custom: "Własny kolor...",
                sizeTitle: "Ustaw rozmiar tekstu",
                currentSize: "Rozmiar tekstu:",
                close: "Zamknij",
                position: "Ustaw pozycję",
                savePosition: "Zapisz pozycję",
                positionSaved: "Pozycja zapisana!",
                alarm: "Przypomnienie",
                alarm15: "Co 15 minut",
                alarm30: "Co 30 minut",
                alarm60: "Co 60 minut",
                alarmOff: "Wyłącz"
            }

        default: ; Angol
            return {
                toggle: "Hide / show clock",
                color: "Text color",
                size: "Font size",
                save: "Save settings",
                reset: "Reset defaults",
                exit: "Exit",
                brown: "Brown",
                white: "White",
                green: "Green",
                blue: "Blue",
                custom: "Custom color...",
                sizeTitle: "Font size settings",
                currentSize: "Font size:",
                close: "Close",
                position: "Set position",
                savePosition: "Save position",
                positionSaved: "Position saved!",
                alarm: "Alarm",
                alarm15: "Every 15 minutes",
                alarm30: "Every 30 minutes",
                alarm60: "Every 60 minutes",
                alarmOff: "Turn off",
                alarm: "Alarm",
                alarm15: "Every 15 minutes",
                alarm30: "Every 30 minutes",
                alarm60: "Every 60 minutes",
                alarmOff: "Turn off"
            }
    }
}
