# Dokumentacja Deweloperska - Uruchamianie Projektu WolfGodot

## Przegląd
Projekt WolfGodot to implementacja silnika Wolfenstein 3D w Godot Engine z obsługą ładowania zewnętrznych plików danych gry.

## Wymagania Systemowe

### Narzędzia
- **Godot Engine** 4.x (zalecana najnowsza stabilna wersja)
- **Kompletny zestaw plików danych gry** Wolfenstein 3D

### Wymagane Pliki Danych Gry

Wszystkie 9 plików binárnych są **obowiązkowe** dla prawidłowego działania gry:
```
AUDIOHED.WL6    - Nagłówki audio
AUDIOT.WL6      - Dane audio (muzyka i efekty dźwiękowe)
CONFIG.WL6      - Konfiguracja gry
GAMEMAPS.WL6    - Dane poziomów/map
MAPHEAD.WL6     - Nagłówki map
VGADICT.WL6     - Słownik kompresji grafiki
VGAGRAPH.WL6    - Dane graficzne (tekstury, sprite'y)
VGAHEAD.WL6     - Nagłówki grafiki
VSWAP.WL6       - Swap file (główny plik zasobów)
```

## Struktura Projektu
```
wolfgodot/
├── data/                    # Opcjonalny folder z danymi gry
│   └── wolf3d/             # Pliki Wolfenstein 3D
│       ├── AUDIOHED.WL6
│       ├── AUDIOT.WL6
│       ├── CONFIG.WL6
│       ├── GAMEMAPS.WL6
│       ├── MAPHEAD.WL6
│       ├── VGADICT.WL6
│       ├── VGAGRAPH.WL6
│       ├── VGAHEAD.WL6
│       └── VSWAP.WL6
├── scripts/
│   ├── GameState.gd        # System zarządzania stanem gry
│   └── extract_wolf3d.gd   # Ekstraktor zasobów
├── project.godot
└── [inne pliki projektu]
```

## Instalacja i Uruchomienie

### Tryb Deweloperski (Edytor Godot)

1. **Sklonuj/pobierz repozytorium**
```bash
   git clone [URL_REPOZYTORIUM]
   cd wolfgodot
```

2. **Przygotuj pliki danych gry**
   
   Utwórz strukturę folderów w katalogu projektu:
```bash
   mkdir -p data/wolf3d
```

3. **Skopiuj WSZYSTKIE pliki gry**
   
   Umieść **wszystkie 9 plików** w folderze `data/wolf3d/`:
```
   ✓ AUDIOHED.WL6
   ✓ AUDIOT.WL6
   ✓ CONFIG.WL6
   ✓ GAMEMAPS.WL6
   ✓ MAPHEAD.WL6
   ✓ VGADICT.WL6
   ✓ VGAGRAPH.WL6
   ✓ VGAHEAD.WL6
   ✓ VSWAP.WL6
```

4. **Otwórz projekt w Godot**
   - Uruchom Godot Engine
   - Wybierz "Import" i wskaż plik `project.godot`
   - Kliknij "Import & Edit"

5. **Uruchom grę**
   - Naciśnij **F5** lub kliknij przycisk "Play" w edytorze

### Tryb Produkcyjny (Wyeksportowana Gra)

#### Eksport z Godot

1. **Skonfiguruj eksport**
   - W Godot: `Project → Export`
   - Dodaj szablon eksportu dla docelowej platformy (Windows/Linux)
   - Skonfiguruj ustawienia eksportu

2. **Wyeksportuj projekt**
   - Wybierz "Export Project"
   - Zapisz jako `wolfgodot.exe` (Windows) lub odpowiednią nazwę dla innej platformy

#### Uruchomienie wyeksportowanej gry

**Opcja 1: Pliki obok pliku wykonywalnego (ZALECANE)**
```
game_folder/
├── wolfgodot.exe
└── data/
    └── wolf3d/
        ├── AUDIOHED.WL6
        ├── AUDIOT.WL6
        ├── CONFIG.WL6
        ├── GAMEMAPS.WL6
        ├── MAPHEAD.WL6
        ├── VGADICT.WL6
        ├── VGAGRAPH.WL6
        ├── VGAHEAD.WL6
        └── VSWAP.WL6
```

**Opcja 2: Folder użytkownika**

Wszystkie 9 plików można również umieścić w folderze użytkownika:
- **Windows**: `%APPDATA%/Godot/app_userdata/[nazwa_projektu]/data/wolf3d/`
- **Linux**: `~/.local/share/godot/app_userdata/[nazwa_projektu]/data/wolf3d/`

**Opcja 3: Wbudowane w grę**

Wszystkie 9 plików można również wbudować bezpośrednio w eksportowaną grę umieszczając je w `res://data/wolf3d/` przed eksportem.

## System Ładowania Danych

### Hierarchia Priorytetów

System automatycznie wyszukuje pliki danych w następującej kolejności:

1. **`res://data/wolf3d/`** - Dane wbudowane w aplikację
2. **`user://data/wolf3d/`** - Folder użytkownika (Godot user data)
3. **`[EXE_DIR]/data/wolf3d/`** - Folder obok pliku wykonywalnego

### Wykrywanie Gry

System automatycznie wykrywa dostępną grę na podstawie obecności pliku `VSWAP.WL6`.

**Ważne**: Mimo że system wykrywa grę po pliku VSWAP, wszystkie 9 plików są niezbędne do prawidłowego działania!

## Weryfikacja i Debugowanie

### Checklist Plików

Przed uruchomieniem gry upewnij się, że wszystkie pliki są na miejscu:
```bash
# W folderze data/wolf3d/ powinno być dokładnie 9 plików:
□ AUDIOHED.WL6  (nagłówki audio)
□ AUDIOT.WL6    (dane audio)
□ CONFIG.WL6    (konfiguracja)
□ GAMEMAPS.WL6  (mapy poziomów)
□ MAPHEAD.WL6   (nagłówki map)
□ VGADICT.WL6   (słownik grafiki)
□ VGAGRAPH.WL6  (dane graficzne)
□ VGAHEAD.WL6   (nagłówki grafiki)
□ VSWAP.WL6     (główny plik swap)
```

### Logi Konsoli

Po uruchomieniu gry sprawdź konsolę/logi. Powinieneś zobaczyć:
```
Found WOLF3D data files in: [ścieżka_do_plików]
Extracting assets from: [ścieżka]
```

Jeśli pliki nie zostały znalezione:
```
Wolf3D data files not found in any location
```

### Typowe Problemy

| Problem | Możliwa Przyczyna | Rozwiązanie |
|---------|-------------------|-------------|
| "Data files not found" | Brak pliku VSWAP.WL6 | Sprawdź czy wszystkie 9 plików są w folderze |
| Brak dźwięku | Brak AUDIOHED.WL6 lub AUDIOT.WL6 | Skopiuj brakujące pliki audio |
| Brak tekstur/grafiki | Brak plików VGA*.WL6 | Skopiuj wszystkie pliki VGADICT, VGAGRAPH, VGAHEAD |
| Nie ładują się poziomy | Brak GAMEMAPS.WL6 lub MAPHEAD.WL6 | Skopiuj pliki map |
| Błędy wielkości liter | Linux są case-sensitive | Upewnij się że nazwy są WIELKIE LITERY |
| Gra crashuje przy starcie | Uszkodzone pliki danych | Pobierz ponownie oryginalne pliki gry |

### Włączanie Szczegółowych Logów

W pliku `extract_wolf3d.gd` można dodać szczegółowe logi:
```gdscript
func _detect_available_games() -> void:
    var paths = GameState.get_external_data_paths("wolf3d")
    for path in paths:
        print("Checking: ", path)
        if FileAccess.file_exists(path + "VSWAP.WL6"):
            print("✓ Found VSWAP at: ", path)
            # Sprawdź pozostałe pliki
            var required_files = [
                "AUDIOHED", "AUDIOT", "CONFIG", 
                "GAMEMAPS", "MAPHEAD", "VGADICT", 
                "VGAGRAPH", "VGAHEAD", "VSWAP"
            ]
            for file in required_files:
                var full_path = path + file + ".WL6"
                if FileAccess.file_exists(full_path):
                    print("  ✓ ", file)
                else:
                    print("  ✗ MISSING: ", file)
```

## Konfiguracja dla Zespołu

### .gitignore

Dodaj do `.gitignore`:
```gitignore
# Game data files - all Wolf3D binaries
data/wolf3d/*.WL6
data/wolf3d/*.wl6

# Specifically exclude all required files
data/wolf3d/AUDIOHED.WL6
data/wolf3d/AUDIOT.WL6
data/wolf3d/CONFIG.WL6
data/wolf3d/GAMEMAPS.WL6
data/wolf3d/MAPHEAD.WL6
data/wolf3d/VGADICT.WL6
data/wolf3d/VGAGRAPH.WL6
data/wolf3d/VGAHEAD.WL6
data/wolf3d/VSWAP.WL6

# User data
user://

# Godot imported assets
.godot/
.import/
```

### README.txt dla Użytkowników Końcowych

Dołącz plik z instrukcją:
```
WYMAGANE PLIKI GRY
==================

Aby uruchomić WolfGodot, potrzebujesz WSZYSTKICH 9 plików z oryginalnej gry
Wolfenstein 3D. Umieść je w folderze 'data/wolf3d/' obok pliku wykonywalnego:

data/
  wolf3d/
    AUDIOHED.WL6
    AUDIOT.WL6
    CONFIG.WL6
    GAMEMAPS.WL6
    MAPHEAD.WL6
    VGADICT.WL6
    VGAGRAPH.WL6
    VGAHEAD.WL6
    VSWAP.WL6

Wszystkie pliki są wymagane! Brakujące pliki spowodują błędy.

Gdzie znaleźć te pliki?
- Jeśli posiadasz oryginalną grę na Steam/GOG, znajdziesz je w folderze instalacyjnym
- Shareware wersja jest dostępna legalnie online
```

## Deployment Checklist

- [ ] Wyeksportuj projekt przez Godot
- [ ] Utwórz folder `data/wolf3d/` obok pliku wykonywalnego
- [ ] Skopiuj **WSZYSTKIE 9 plików** `.WL6`:
  - [ ] AUDIOHED.WL6
  - [ ] AUDIOT.WL6
  - [ ] CONFIG.WL6
  - [ ] GAMEMAPS.WL6
  - [ ] MAPHEAD.WL6
  - [ ] VGADICT.WL6
  - [ ] VGAGRAPH.WL6
  - [ ] VGAHEAD.WL6
  - [ ] VSWAP.WL6
- [ ] Przetestuj uruchomienie na czystym systemie
- [ ] Sprawdź logi pod kątem błędów
- [ ] Zweryfikuj że działają:
  - [ ] Dźwięk i muzyka
  - [ ] Wszystkie tekstury
  - [ ] Sprite'y przeciwników
  - [ ] Mapy poziomów
- [ ] Przygotuj plik README.txt z listą wymaganych plików
- [ ] Przetestuj na różnych systemach operacyjnych

## Szybki Start - Dla Niecierpliwych
```bash
# 1. Sklonuj repo
git clone [URL] && cd wolfgodot

# 2. Utwórz folder
mkdir -p data/wolf3d

# 3. Skopiuj 9 plików .WL6 do data/wolf3d/

# 4. Otwórz w Godot i naciśnij F5
```

## Kontakt i Wsparcie

W przypadku problemów:
1. ✓ Sprawdź czy **wszystkie 9 plików** są na miejscu
2. ✓ Sprawdź logi Godot pod kątem brakujących plików
3. ✓ Zweryfikuj wielkość liter w nazwach plików (Linux)
4. ✓ Upewnij się, że pliki nie są uszkodzone

---

**Uwaga Prawna**: Wszystkie pliki danych Wolfenstein 3D są chronione prawami autorskimi id Software. Upewnij się, że posiadasz legalną kopię gry przed używaniem jej zasobów. Te pliki NIE są częścią projektu WolfGodot i muszą być dostarczone przez użytkownika.
