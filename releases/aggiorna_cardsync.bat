@echo off
setlocal enabledelayedexpansion

REM ===========================================================================
REM CardSync Pro - Aggiornamento automatico estensione
REM
REM Cosa fa:
REM 1. Cerca da solo la cartella dell'estensione leggendo le impostazioni di
REM    Chrome (dove sono elencate tutte le estensioni caricate "non
REM    pacchettizzate", con il loro percorso reale sul disco)
REM 2. Se non la trova da solo, chiede all'utente UNA volta sola e se la
REM    ricorda per le volte dopo (per PC - ogni computer ha la sua copia)
REM 3. Scarica l'ultima versione
REM 4. La estrae nella cartella giusta, sovrascrivendo i file vecchi
REM 5. Chiude e riavvia Chrome da solo, cosi' la nuova versione si carica
REM
REM IMPORTANTE: chiude TUTTE le finestre di Chrome aperte per completare
REM l'aggiornamento - salva il tuo lavoro prima di avviarlo.
REM ===========================================================================

set "URL_ZIP=https://claudio-git-poke.github.io/CardSyncProOnline/releases/cardsync-extension.zip"
set "CONFIG_DIR=%APPDATA%\CardSyncPro"
set "CONFIG_FILE=%CONFIG_DIR%\cartella_estensione.txt"
set "TEMP_ZIP=%TEMP%\cardsync-extension-update.zip"

echo.
echo ================================================
echo CardSync Pro - Aggiornamento estensione
echo ================================================
echo.

if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%" >nul 2>&1

REM --- Passo 1: prova a rilevarla da solo dalle impostazioni di Chrome ------
REM NOTA TECNICA: questo blocco usa "goto" invece di if(...)else(...) di
REM proposito - il comando PowerShell incorporato qui sotto contiene molte
REM parentesi al suo interno, che dentro un blocco if/else confondono
REM l'interprete di Windows (non riesce a distinguere le SUE parentesi da
REM quelle del comando). Con goto il problema non si presenta mai.

echo Cerco la cartella dell'estensione nelle impostazioni di Chrome...
set "CARTELLA_ESTENSIONE="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command ^
    "$basi = @(\"$env:LOCALAPPDATA\Google\Chrome\User Data\") ; foreach ($base in $basi) { if (-not (Test-Path $base)) { continue } ; Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' } | ForEach-Object { $pref = Join-Path $_.FullName 'Preferences' ; if (-not (Test-Path $pref)) { $pref = Join-Path $_.FullName 'Secure Preferences' } ; if (Test-Path $pref) { try { $json = Get-Content $pref -Raw -ErrorAction Stop | ConvertFrom-Json ; $json.extensions.settings.PSObject.Properties | ForEach-Object { $m = $_.Value.manifest ; $p = $_.Value.path ; if ($m -and $m.name -eq 'CardSync Pro' -and $p -and (Test-Path (Join-Path $p 'manifest.json'))) { Write-Output $p } } } catch {} } } }"`) do (
    set "CARTELLA_ESTENSIONE=%%F"
)

if defined CARTELLA_ESTENSIONE goto :trovata_automaticamente
goto :non_trovata_automaticamente

:trovata_automaticamente
echo Trovata automaticamente: !CARTELLA_ESTENSIONE!
echo !CARTELLA_ESTENSIONE!>"%CONFIG_FILE%"
echo.
goto :cartella_pronta

:non_trovata_automaticamente
echo Non trovata automaticamente.
echo.

REM --- Passo 1b: prova a leggere quella salvata da una volta precedente -----
if exist "%CONFIG_FILE%" (
    for /f "usebackq delims=" %%L in ("%CONFIG_FILE%") do set "CARTELLA_ESTENSIONE=%%L"
)

if not defined CARTELLA_ESTENSIONE goto :chiedi_cartella
if not exist "!CARTELLA_ESTENSIONE!\manifest.json" goto :chiedi_cartella
echo Uso la cartella salvata da un utilizzo precedente: !CARTELLA_ESTENSIONE!
echo (Se non e' quella giusta, cancella questo file e riprova: "%CONFIG_FILE%")
echo.
goto :cartella_pronta

:chiedi_cartella
echo Seleziona a mano la cartella dove hai l'estensione CardSync Pro.
echo (Si aprira' una finestra per scegliere la cartella)
echo.
set "CARTELLA_ESTENSIONE="
for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command ^
    "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Seleziona la cartella dell''estensione CardSync Pro (quella con manifest.json dentro)'; if ($f.ShowDialog() -eq 'OK') { Write-Output $f.SelectedPath }"`) do (
    set "CARTELLA_ESTENSIONE=%%F"
)

if not defined CARTELLA_ESTENSIONE (
    echo Nessuna cartella selezionata - annullato.
    pause
    exit /b 1
)

echo !CARTELLA_ESTENSIONE!>"%CONFIG_FILE%"
echo Cartella salvata per le prossime volte: !CARTELLA_ESTENSIONE!
echo.

:cartella_pronta

REM Non blocca piu' se manifest.json non c'e' ancora - per la primissima
REM installazione e' normale che la cartella sia vuota o nuova: la si
REM installa li', semplicemente. Ricordiamo solo se e' un'installazione
REM nuova o un aggiornamento, per il messaggio finale.
set "PRIMA_INSTALLAZIONE=0"
if not exist "!CARTELLA_ESTENSIONE!\manifest.json" set "PRIMA_INSTALLAZIONE=1"

REM --- Passo 2: scarica l'ultima versione ------------------------------------
echo Scarico l'ultima versione...
powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%URL_ZIP%' -OutFile '%TEMP_ZIP%' -UseBasicParsing } catch { Write-Output 'ERRORE_DOWNLOAD'; exit 1 }"

if not exist "%TEMP_ZIP%" (
    echo Download fallito - controlla la connessione e riprova.
    pause
    exit /b 1
)
echo Fatto.
echo.

REM --- Passo 3: chiude Chrome (con un breve avviso) --------------------------
echo Chiudo Chrome tra 5 secondi per completare l'installazione...
echo (salva subito eventuali lavori in corso in altre schede)
timeout /t 5 >nul
taskkill /F /IM chrome.exe /T >nul 2>&1
timeout /t 2 >nul

REM --- Passo 4: estrae (crea la cartella se non esiste ancora) ---------------
echo Installo...
if not exist "!CARTELLA_ESTENSIONE!" mkdir "!CARTELLA_ESTENSIONE!" >nul 2>&1
powershell -NoProfile -Command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '!CARTELLA_ESTENSIONE!' -Force"
del "%TEMP_ZIP%" >nul 2>&1
echo Fatto.
echo.

REM --- Passo 5: riavvia Chrome ------------------------------------------------
echo Riavvio Chrome...
start "" "chrome"
echo.
echo ================================================
echo Installazione completata!
echo ================================================
echo.

if "%PRIMA_INSTALLAZIONE%"=="1" (
    echo ATTENZIONE - ultimo passo, SOLO la prima volta:
    echo Chrome non sa ancora che questa cartella e' un'estensione - vai su
    echo chrome://extensions, attiva "Modalita' sviluppatore" in alto a destra
    echo se non e' gia' attiva, poi "Carica estensione non pacchettizzata" e
    echo seleziona questa cartella:
    echo !CARTELLA_ESTENSIONE!
    echo.
    echo Le prossime volte non servira' piu' - questo script bastera' da solo.
    echo.
)

timeout /t 3 >nul
exit /b 0
