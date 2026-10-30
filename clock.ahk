
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
global savedX := IniRead(settingsFile, "Settings", "X", "")
global savedY := IniRead(settingsFile, "Settings", "Y", "")

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

clock.SetFont("s" fontSize " c" clockColor, "DS-Digital")
clockText := clock.AddText("x0 y0 w85 h20 Center", "")

; Végleges pozíció
MonitorGetWorkArea(, &left, &top, &right, &bottom)

startX := (savedX = "") ? (right - 250) : Integer(savedX)
startY := (savedY = "") ? (top + 10) : Integer(savedY)

clock.Show("NA x" startX " y" startY " w85 h20")

; Átlátszó háttér
WinSetTransColor("010101", clock.Hwnd)

; Mozgathatóság az egész óra területén
OnMessage(0x201, WM_LBUTTONDOWN)

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global clock, clockText

    if (hwnd = clock.Hwnd || hwnd = clockText.Hwnd) {
        PostMessage(0xA1, 2,,, "ahk_id " clock.Hwnd)
    }
}

; Idő frissítése
UpdateClock()
SetTimer(UpdateClock, 1000)

UpdateClock() {
    global clockText
    clockText.Value := FormatTime(, "HH:mm:ss")
}

; Szín módosítása
SetClockColor(newColor) {
    global clockColor, fontSize, clockText

    clockColor := newColor
    clockText.SetFont("s" fontSize " c" clockColor, "DS-Digital")
    SaveSettings()
}

; Betűméret módosítása
SetClockSize(newSize) {
    global fontSize, clockColor, clockText, sizeLabel

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
    global settingsFile, clock, savedX, savedY

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
    SetTimer(PositionColorDialog, 50)

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
        clock.Show("NA")
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
                positionSaved: "A pozíció elmentve!"
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
                positionSaved: "Position gespeichert!"
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
                positionSaved: "Position enregistrée !"
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
                positionSaved: "Pozycja zapisana!"
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
                positionSaved: "Position saved!"
            }
    }
}
