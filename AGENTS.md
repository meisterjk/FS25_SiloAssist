# AGENTS.md - FS25_SiloAssist Mod

## Mod-Übersicht

**Name:** FS25_SiloAssist
**Typ:** Script-Mod (Assist-Mod für Bunkersilo-Verteilung)
**FS25 ModDesc Version:** 109
**Pfad:** `mods/FS25_SiloAssist/`

### Kern-Mechanik
- **Assist-Modus**: Spieler lenkt/fährt selbst, Mod steuert automatisch Werkzeughöhe (Schild/Schaufel) im Bunkersilo
- **Ein/Aus-Taste**: Toggle-Taste zum Aktivieren/Deaktivieren. Mod validiert: Werkzeug vorhanden + Fahrzeug im Silo
- **Auto-Detect Werkzeug**: Erkennt automatisch ob Leveler (Schild) oder Schaufel angebracht ist
- **Durchfahrtssilo**: Sanfter Anstieg am Anfang, gleichmäßige Höhe in der Mitte, sanftes Absteigen am Ende
- **Kopfende-Silo**: Gerade Keil-Steigung, wird mit jedem Durchlauf höher
- **Schaufel Auto-Auskippen**: Am Silo-Ende Schaufel automatisch auskippen, Mod deaktiviert Höhensteuerung kurz, Spieler fährt zurück
- **3-Punkt + Radlader**: Unterstützt `AttacherJointControl` (Traktor) und `Cylindered` (Radlader)

### Github Repository
- nicht selbst pushen, erst nach einer abgeschlossenen Aufgabe, dann zuerst nachfragen soll gepusht werden?, welcher Versionssprung?, neues Release erstellen?
- username: meisterjk
- token: siehe KeePass "github meisterjk"
- repo name: FS25_SiloAssist
- Release conventions:
  - Tag: `v<version>` (z.B. v0.1.0)
  - Release title: `FS25_SiloAssist` (immer gleich, kein Version-Suffix)
  - Release asset: die gepackte Mod-ZIP heißt `FS25_SiloAssist.zip`
  - ZIP erstellen: `cd FS25_SiloAssist && zip -r /tmp/FS25_SiloAssist.zip . -x ".git/*" ".gitignore" "AGENTS.md" "README.md" "LICENSE" "images/*"` (flache Struktur, kein umschließender Ordner)
  - Push: `git push -u origin main`
  - Token in Remote-URL: `git remote set-url origin https://<TOKEN>@github.com/meisterjk/FS25_SiloAssist.git`
  - Token aus Remote-URL entfernen: `git remote set-url origin https://github.com/meisterjk/FS25_SiloAssist.git`
  - Commit-Messages: Englisch, präzise

### Dateistruktur
```
FS25_SiloAssist/
├── modDesc.xml
├── icon_siloAssist.dds
├── scripts/
│   ├── siloAssistMain.lua                  (Main: EventListener, loadMap, Keybinding, Update-Loop)
│   ├── core/
│   │   ├── siloAssistConfig.lua            (Konfiguration: DEBUG, Steigungswinkel, Height-Offset)
│   │   └── siloAssistSiloDetector.lua      (Silo-Erkennung, Positions-Tracking, Füllstand)
│   ├── hooks/
│   │   ├── siloAssistHeightController.lua  (Höhensteuerung: AttacherJointControl + Cylindered)
│   │   └── siloAssistDumpController.lua    (Schaufel-Auskippen: Auto-Dump + Freigabe)
│   ├── gui/
│   │   ├── siloAssistInGameMenuIntegration.lua  (InGameMenu Tab-Registrierung)
│   │   └── siloAssistPage.lua              (Einstellungen: Silo-Typ, Parameter)
│   └── hud/
│       └── siloAssistHud.lua               (Kompaktes Info-HUD)
├── config/gui/
│   ├── siloAssistPage.xml
│   └── guiProfiles.xml
└── translations/
    ├── translation_en.xml
    └── translation_de.xml
```

---

## FS25 Lua Scripting Referenz

### NICHT verfügbar (GIANTS Sandbox)

Standard Lua Libraries sind **nicht** zugänglich:

| Feature | Status | Ersatz |
|---------|--------|--------|
| `io.open` / `io.read` / `io.write` | **UNVERFÜGBAR** | `XMLFile`/`XMLSchema`, `createFile()` |
| `os.execute` / `os.getenv` | **UNVERFÜGBAR** | Kein Ersatz |
| `os.clock` | **UNVERFÜGBAR** | `getTime()` |
| `os.time` / `os.date` | **UNVERFÜGBAR** | `getDate("%Y/%m/%d %H:%M")` |
| `require()` | **UNVERFÜGBAR** | `source(filename, modEnv)` |
| `dofile()` / `loadfile()` | **UNVERFÜGBAR** | `source()` |
| `coroutine` library | **UNVERFÜGBAR** | `g_asyncTaskManager` |
| `package` library | **UNVERFÜGBAR** | - |
| `goto` statement | **UNVERFÜGBAR** | Boolean-Flags/Loops |

### Verfügbare GIANTS Globals

| Global | Zweck |
|--------|-------|
| `g_currentMission` | Aktive Mission - zentraler Zugriffspunkt |
| `g_currentMission.environment` | Zeit/Wetter-System |
| `g_currentMission.missionInfo` | Schwierigkeit, Einstellungen |
| `g_currentMission.aiSystem` | KI/Helfer-System |
| `g_currentMission.terrainRootNode` | Terrain-Root-Node (für getTerrainHeightAtWorldPos) |
| `g_currentMission.placeableSystem` | Placeable-System (`:getBunkerSilos()`) |
| `g_helperManager` | Helfer-Management |
| `g_client` | Client-Netzwerk |
| `g_server` | Server-Netzwerk |
| `g_messageCenter` | Event-Bus (Publish/Subscribe) |
| `g_gui` | GUI-Controller |
| `g_i18n` | Lokalisierung |
| `g_localPlayer` | Lokaler Spieler |
| `g_inGameMenu` | Das ESC-InGameMenu (TabbedMenu) |
| `g_inputBinding` | Eingabe/Aktionen |
| `g_baseUIFilename` | C++ Global — Pfad zur Base-UI-Textur |
| `g_colorBgUVs` | C++ Global — UV-Koordinaten des weißen Pixels |
| `g_languageSuffix` | C++ Global — aktueller Sprachsuffix (z.B. `"_de"`, `"_en"`) |

### Wichtige Klassen und APIs für SiloAssist

#### BunkerSilo (`dataS/scripts/objects/BunkerSilo.lua`)

| Property/Method | Typ | Beschreibung |
|-----------------|------|-------------|
| `bunkerSiloArea` | table | Silo-Bereich (start/width/height Nodes + Koordinaten) |
| `bunkerSiloArea.sx/sy/sz` | float | Start-Eckpunkt Weltkoordinaten |
| `bunkerSiloArea.wx/wy/wz` | float | Width-Eckpunkt Weltkoordinaten |
| `bunkerSiloArea.hx/hy/hz` | float | Height-Eckpunkt Weltkoordinaten |
| `bunkerSiloArea.dhx/dhy/dhz` | float | Height-Start-Vektor (= Längsachse) |
| `bunkerSiloArea.dwx/dwy/dwz` | float | Width-Start-Vektor (= Querachse) |
| `bunkerSiloArea.inner` | table | Innerer Bereich (gleiche Struktur) |
| `bunkerSiloArea.offsetFront` | float | Vorderer Versatz |
| `bunkerSiloArea.offsetBack` | float | Hinterer Versatz |
| `fillLevel` | float | Gesamtfüllstand in Litern |
| `compactedFillLevel` | float | Wie viel verdichtet wurde |
| `compactedPercent` | int | Verdichtungsprozent 0-100 |
| `state` | int | `STATE_FILL=0`, `STATE_CLOSED=1`, `STATE_FERMENTED=2`, `STATE_DRAIN=3` |
| `inputFillType` | int | Eingangs-FillType (Default: `FillType.CHAFF`) |
| `outputFillType` | int | Ausgangs-FillType (Default: `FillType.SILAGE`) |
| `isOpenedAtFront` | bool | Vorne geöffnet |
| `isOpenedAtBack` | bool | Hinten geöffnet |
| `vehiclesInRange` | table | Fahrzeuge im Interaktionstrigger |
| `playerInRange` | bool | Spieler im Interaktionstrigger |

```lua
-- Silo-Maße berechnen:
local area = silo.bunkerSiloArea
local length = MathUtil.vector3Length(area.dhx, area.dhy, area.dhz)
local width = MathUtil.vector3Length(area.dwx, area.dwy, area.dwz)

-- Alle BunkerSilo-Placeables finden:
local silos = g_currentMission.placeableSystem:getBunkerSilos()
for _, placeable in ipairs(silos) do
    local silo = placeable.spec_bunkerSilo.bunkerSilo
    -- silo ist ein BunkerSilo-Objekt
end

-- Fahrzeug im Silo prüfen (2 Wege):
-- 1) Über vehiclesInRange:
if silo.vehiclesInRange[vehicle] ~= nil then ... end
-- 2) Point-in-Parallelogram:
MathUtil.isPointInParallelogram(px, pz, area.sx, area.sz, area.dwx, area.dwz, area.dhx, area.dhz)
```

#### DensityMapHeightUtil (Füllhöhe an Position)

```lua
-- Füllhöhe an Welt-Position (gibt terrainHeight + fillHeight zurück):
local terrainHeight, densityHeight = DensityMapHeightUtil.getHeightAtWorldPos(x, y, z)
-- terrainHeight = Boden-Höhe, densityHeight = Boden + Material darüber

-- Füllstand in einem Bereich:
local fillLevel, pixels, totalPixels = DensityMapHeightUtil.getFillLevelAtArea(fillType, sx, sz, wx, wz, hx, hz)

-- FillType an Position:
local fillTypeIndex = DensityMapHeightUtil.getFillTypeAtArea(sx, sz, wx, wz, hx, hz)

-- Terrain-Höhe (nur Boden, ohne Material):
local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, y, z)
```

#### Leveler-Spezialisierung (`dataS/scripts/vehicles/specializations/Leveler.lua`)

Die Leveler-Spezialisierung repräsentiert Schiebeschilde/Verteiler.

```lua
-- Prüfen ob Fahrzeug Leveler hat:
if vehicle.spec_leveler ~= nil then
    local nodes = vehicle.spec_leveler.nodes
    for _, levelerNode in ipairs(nodes) do
        -- levelerNode.node         - Szene-Graph-Node
        -- levelerNode.width        - Schild-Breite
        -- levelerNode.yOffset       - Y-Offset
        -- levelerNode.zOffset       - Z-Offset
        -- levelerNode.alignToWorldY - Ob auf Welt-Y ausgerichtet
    end
end

-- WICHTIG: Leveler überschreibt getIsAttacherJointControlDampingAllowed()
-- Gibt false zurück wenn Leveler über leerem Boden (height == 0)
-- Muss ggf. gehookt werden um konsistente Höhensteuerung zu gewährleisten
```

#### Werkzeug-Erkennung (Auto-Detect)

```lua
-- Leveler (Schild) erkennen:
function getAttachedToolType(vehicle)
    for _, implement in ipairs(vehicle:getAttachedImplements()) do
        local impl = implement.object
        if impl.spec_leveler ~= nil then
            return "leveler", impl
        end
        -- Schaufel:有多种Möglichkeiten
        -- 1) spec_dynamicMountAttacher (Din-Schaufel)
        -- 2) spec_shovel (falls vorhanden)
        -- 3) spec_cylindered mit dump-tool
        if impl.spec_shovel ~= nil then
            return "shovel", impl
        end
    end
    -- Radlader: Leveler direkt am Fahrzeug
    if vehicle.spec_leveler ~= nil then
        return "leveler", vehicle
    end
    return nil, nil
end
```

#### AttacherJointControl (3-Punkt-Steuerung, Traktor)

**Datei:** `dataS/scripts/vehicles/specializations/AttacherJointControl.lua`

```lua
-- Auf dem Anbaugerät (Schild/Schaufel):
local spec = implement.spec_attacherJointControl
local jointDesc = spec.jointDesc

-- Aktuelle Position (Alpha 0-1):
-- 0 = upperAlpha (gehoben), 1 = lowerAlpha (abgesenkt)
local currentAlpha = spec.heightController.moveAlpha

-- Ziel-Position setzen (glattes Bewegen):
spec.heightTargetAlpha = targetAlpha  -- wird in onUpdate() verarbeitet

-- Direkte Alpha-Manipulation (sofort):
implement:controlAttacherJointHeight(moveAlpha)

-- Höhen-Bereich des Gelenks:
jointDesc.upperAlpha                    -- Alpha wenn ganz oben
jointDesc.lowerAlpha                     -- Alpha wenn ganz unten
jointDesc.upperDistanceToGround          -- Abstand zum Boden wenn oben (Meter)
jointDesc.lowerDistanceToGround          -- Abstand zum Boden wenn unten (Meter)
jointDesc.moveTime                       -- Zeit für volle Traverse (ms)

-- Heben/Senken (boolean):
tractor:setJointMoveDown(jointDescIndex, moveDown, noEventSend)
tractor:getJointMoveDown(jointDescIndex)

-- Neigung steuern (Schild-Kippen):
jointDesc.upperRotationOffset            -- Aktueller oberer Rotations-Offset
jointDesc.upperRotationOffsetBackup     -- Original-Wert (wiederherstellbar)
jointDesc.lowerRotationOffset
jointDesc.lowerRotationOffsetBackup
-- Ändern: jointDesc.upperRotationOffset = jointDesc.upperRotationOffsetBackup - angle
```

#### Cylindered (Radlader-Schaufel-Steuerung)

**Datei:** `dataS/scripts/vehicles/specializations/Cylindered.lua`

```lua
-- MovingTools finden:
local spec = vehicle.spec_cylindered
for i, movingTool in ipairs(spec.movingTools) do
    -- movingTool.axis              - "AXIS_FRONTLOADER_ARM" oder "AXIS_FRONTLOADER_TOOL"
    -- movingTool.curRot            - Aktuelle Rotation pro Achse
    -- movingTool.rotMin            - Min. Rotation
    -- movingTool.rotMax            - Max. Rotation
    -- movingTool.rotSpeed          - Rotationsgeschwindigkeit
    -- movingTool.node              - Szene-Graph-Node
end

-- MovingTool steuern:
Cylindered.actionEventInput(vehicle, "", direction, movingToolIndex, isAnalog)
-- direction: 1 = ausfahren, -1 = einfahren

-- Typische Achsen:
-- "AXIS_FRONTLOADER_ARM"  - Arm höhe
-- "AXIS_FRONTLOADER_TOOL" - Werkzeug kippen/auskippen
```

#### Fahrzeug-Position und -Höhe

```lua
-- Fahrzeug-Position:
local x, y, z = getWorldTranslation(vehicle.components[1].node)
-- oder:
local x, y, z = getWorldTranslation(vehicle.rootNode)

-- Bodenfreiheit berechnen:
local _, vy, _ = getWorldTranslation(vehicle.components[1].node)
local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
local clearance = vy - terrainHeight

-- Höhe über Material (inkl. Silage-Haufen):
local terrainH, densityH = DensityMapHeightUtil.getHeightAtWorldPos(x, y, z)
local clearanceAboveMaterial = vy - densityH

-- Leveler/Schaufel-Position:
local levelerNode = vehicle.spec_leveler.nodes[1]
local lx, ly, lz = getWorldTranslation(levelerNode.node)
```

#### Position im Silo berechnen

```lua
-- Position entlang der Silo-Längsachse (0.0 = Start, 1.0 = Ende):
function getPositionInSilo(vehicle, silo)
    local area = silo.bunkerSiloArea
    local vx, _, vz = getWorldTranslation(vehicle.rootNode)

    -- Projektion auf Längsachse
    local dx = vx - area.sx
    local dz = vz - area.sz
    local length = MathUtil.vector3Length(area.dhx, area.dhy, area.dhz)

    -- Skalarprodukt mit normierter Längsrichtung
    local dot = dx * area.dhx + dz * area.dhz
    local progress = dot / (length * length)  -- 0.0 bis ~1.0

    return math.clamp(progress, 0, 1)
end

-- Position entlang der Silo-Querachse (0.0 = eine Seite, 1.0 = andere):
function getLateralPositionInSilo(vehicle, silo)
    local area = silo.bunkerSiloArea
    local vx, _, vz = getWorldTranslation(vehicle.rootNode)
    local dx = vx - area.sx
    local dz = vz - area.sz
    local width = MathUtil.vector3Length(area.dwx, area.dwy, area.dwz)
    local dot = dx * area.dwx + dz * area.dwz
    return math.clamp(dot / (width * width), 0, 1)
end
```

---

## Höhensteuerung: Architektur

### Update-Loop (jeden Frame wenn aktiv)

```
1. Silo-Erkennung: Ist das Fahrzeug noch im Silo?
   → g_currentMission.placeableSystem:getBunkerSilos() iterieren
   → Point-in-Parallelogram mit bunkerSiloArea-Coords
   → Wenn nicht mehr im Silo → Mod deaktiviert automatisch

2. Position im Silo berechnen:
   → getPositionInSilo() → progress (0.0 = Start, 1.0 = Ende)

3. Füllhöhe an Fahrzeug-Position:
   → DensityMapHeightUtil.getHeightAtWorldPos(x, y, z)

4. Ziel-Höhe berechnen je nach Modus:

   DURCHFAHRTSSILO:
   → Rampen-Funktion:
     - Anfang (0 - RAMP_START_PCT): Niedrig starten, ansteigen auf Füllhöhe
     - Mitte (RAMP_START_PCT - RAMP_END_PCT): Füllhöhe + Offset halten
     - Ende (RAMP_END_PCT - 1.0): Sanft absteigen
   → targetHeight = ramp(progress) + config.HEIGHT_OFFSET

   KOPFENDE-SILO:
   → Gerade Steigung von hinten nach vorne:
     - Keil wird höher je mehr Material im Silo
     - targetHeight = progress * currentWedgeHeight + config.HEIGHT_OFFSET
     - currentWedgeHeight steigt mit Füllstand / Durchläufen

5. Höhendifferenz berechnen:
   → heightDiff = targetHeight - currentBladeHeight
   → Wenn |heightDiff| < HEIGHT_THRESHOLD → nichts tun

6. Alpha anpassen (inkrementell):
   → if heightDiff > 0 → blade muss tiefer → alpha + ALPHA_STEP
   → if heightDiff < 0 → blade muss höher → alpha - ALPHA_STEP
   → spec.heightTargetAlpha = clampedAlpha

7. Für Cylindered (Radlader):
   → direction = heightDiff > 0 and 1 or -1
   → Cylindered.actionEventInput(vehicle, "", direction, armToolIndex)
```

### Durchfahrtssilo: Rampen-Funktion

```
targetHeight =
  if progress < RAMP_START_PCT:
    fillHeight * (progress / RAMP_START_PCT)    -- Sanft ansteigen
  elseif progress > RAMP_END_PCT:
    fillHeight * (1.0 - (progress - RAMP_END_PCT) / (1.0 - RAMP_END_PCT))  -- Sanft absteigen
  else:
    fillHeight                                      -- Konstant halten
+ HEIGHT_OFFSET
```

### Kopfende-Silo: Keil-Funktion

```
currentWedgeHeight = min(WEDGE_MAX_HEIGHT, baseWedgeHeight + wedgePassCount * WEDGE_INCREMENT)
targetHeight = fillHeight + (1.0 - progress) * currentWedgeHeight + HEIGHT_OFFSET
-- (1.0 - progress): Am hinteren Ende (0) am höchsten, am vorderen Ende (1) am niedrigsten

wedgePassCount erhöht sich wenn:
  - Fahrzeug erreicht Silo-Ende (progress >= 0.95)
  - Und fährt dann zurück (progress wird kleiner)
```

### Schaufel-Modus: Auto-Auskippen

```
1. Erkennen ob Schaufel (nicht Leveler):
   → toolType == "shovel"

2. Am Silo-Ende (progress >= DUMP_POSITION_PCT):
   → Schaufel auskippen: Cylindered MovingTool "AXIS_FRONTLOADER_TOOL" ausfahren
   → Mod wechselt in DUMPING-Status
   → Höhensteuerung pausiert

3. DUMPING-Status:
   → Warten bis Schaufel ausgekippt ist
   → Spieler fährt zurück (manuell)
   → Wenn progress < DUMP_POSITION_PCT - 0.1:
     → Schaufel zurücksetzen
     → DUMPING-Status beendet
     → Höhensteuerung wieder aktiv
```

---

## Konfiguration (`siloAssistConfig.lua`)

```lua
siloAssistConfig = {
    DEBUG = false,
    DEBUG_SHOW_HEIGHT = false,

    -- Durchfahrtssilo: Rampen-Parameter
    RAMP_START_PCT = 0.15,      -- Anfang: 0-15% Sanft ansteigen
    RAMP_END_PCT = 0.85,        -- Ende: 85-100% Sanft absteigen

    -- Höhe
    HEIGHT_OFFSET = 0.05,       -- 5cm über Füllstand
    ALPHA_STEP = 0.03,          -- Inkrementelle Alpha-Anpassung pro Frame
    HEIGHT_THRESHOLD = 0.04,     -- Höhendifferenz bevor angepasst wird (4cm)

    -- Kopfende-Silo: Keil-Parameter
    WEDGE_MAX_HEIGHT = 1.5,     -- Max. Keilhöhe in Metern
    WEDGE_INCREMENT = 0.02,     -- Keil wird pro Durchlauf um 2cm höher

    -- Schaufel-Auskippen
    DUMP_AT_SILO_END = true,     -- Automatisch auskippen am Ende
    DUMP_POSITION_PCT = 0.95,   -- Ab 95% Silolänge auskippen
}
```

---

## HUD (kompakt)

```
┌──────────────────────────────┐
│ SiloAssist    [● AKTIV]      │
│ ──────────────────────────── │
│ Modus:   Durchfahrt          │
│ Fill:    ███████░░░  72%     │
│ Soll:    0.45m  Ist: 0.42m   │
│ Werkzeug: Schaufel (Schild) │
└──────────────────────────────┘
```

## InGameMenu-Tab Einstellungen

- **Silo-Typ**: Dropdown "Durchfahrtssilo" / "Kopfende-Silo"
- **Höhen-Offset**: Slider (0-20cm)
- **Rampen-Steigung**: Slider (sanft/mittel/agressiv → RAMP_START/END_PCT)
- **Keil-Höhe**: Slider (0.5-3.0m)
- **Auto-Auskippen**: An/Aus (nur bei Schaufel sichtbar)

## Tastenbelegung

| Action-Name | Aktion |
|-------------|--------|
| `SILOASSIST_TOGGLE` | Assist An/Aus |

## Zustandsmaschine

```
OFF ──[Toggle-Taste + Validierung]──> ACTIVE
ACTIVE ──[Toggle-Taste]──> OFF
ACTIVE ──[Silo verlassen]──> OFF
ACTIVE ──[Werkzeug abgehängt]──> OFF
ACTIVE ──[Schaufel + Silo-Ende]──> DUMPING
DUMPING ──[Zurückgefahren]──> ACTIVE
DUMPING ──[Toggle-Taste]──> OFF
```

## Netzwerk / Multiplayer

- Höhensteuerung ist **Client-seitig** (wie manuelle Werkzeugsteuerung)
- Silo-Daten (Füllstand etc.) sind Server-Daten, Clients lesen sie
- Keine Netzwerk-Events nötig für die Kern-Logik
- Settings-Sync via `xmlSchema` beim Savegame

---

## Bekannte Gotchas (FS25)

1. **`g_currentMission:getCurrentDay()` gibt es NICHT** -> `g_currentMission.environment.currentDay`
2. **`io.open` gibt es NICHT** -> `XMLFile`/`XMLSchema` verwenden
3. **`require()` gibt es NICHT** -> `source()` verwenden
4. **XMLFile-Handle IMMER mit `xmlFile:delete()` aufräumen**
5. **`g_currentModDirectory` ist nil nach Lade-Phase** -> in lokale Variable speichern
6. **`goto` ist in FS25 Lua verboten** -> Boolean-Flags/Loops verwenden
7. **`g_currentMission.terrainRootNode`** (NICHT `g_terrainNode`!)
8. **`DensityMapHeightUtil.getHeightAtWorldPos(x,y,z)` gibt zwei Werte zurück**: terrainHeight, fillHeight
9. **`Leveler.getIsAttacherJointControlDampingAllowed`** gibt false über leerem Boden → muss ggf. gehookt werden
10. **Alpha → Höhe ist nicht-linear** → inkrementelle Anpassung (+/-ALPHA_STEP) statt Ziel-Alpha-Berechnung
11. **Radlader-Schaufeln nutzen `Cylindered`** statt `AttacherJointControl` → zweiter Code-Pfad nötig
12. **`Cylindered.actionEventInput`** benötigt korrekten movingToolIndex → muss zur Laufzeit ermittelt werden
13. **FS25-Font unterstützt keine Unicode-Sonderzeichen** → ASCII nutzen
14. **`g_inputBinding:setShowMouseCursor(true)`** MUSS aufgerufen werden wenn HUD sichtbar
15. **`g_localPlayer:getCurrentVehicle()`** um das aktuell gesteuerte Fahrzeug zu ermitteln (NICHT `g_currentMission.controlledVehicle`)
16. **`MathUtil.isPointInParallelogram(px, pz, sx, sz, dwx, dwz, dhx, dhz)`** für Silo-Position-Check

---

## Offizielle GIANTS Dokumentation

| Ressource | URL |
|-----------|-----|
| GDN Hauptseite | https://gdn.giants-software.com/ |
| **FS25 Lua Script API** | https://gdn.giants-software.com/documentation_scripting_fs25.php |
| modDesc XSD online | https://validation.gdn.giants-software.com/xml/fs25/modDesc.xsd |

### Lokale Spielquellen (für Referenz)
- **BunkerSilo:** `dataS/scripts/objects/BunkerSilo.lua`
- **Leveler:** `dataS/scripts/vehicles/specializations/Leveler.lua`
- **AttacherJointControl:** `dataS/scripts/vehicles/specializations/AttacherJointControl.lua`
- **AttacherJoints:** `dataS/scripts/vehicles/specializations/AttacherJoints.lua`
- **Cylindered:** `dataS/scripts/vehicles/specializations/Cylindered.lua`
- **DensityMapHeightUtil:** `dataS/scripts/utils/DensityMapHeightUtil.lua`
- **PlaceableBunkerSilo:** `dataS/scripts/placeables/BunkerSiloPlaceable.lua`