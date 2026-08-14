@echo off
setlocal enabledelayedexpansion

REM ===========================================================================
REM CardSync Pro - Aggiornamento automatico estensione
REM
REM Cosa fa:
REM 1. La prima volta, chiede dove si trova la cartella dell'estensione
REM    (e se la ricorda per le volte dopo)
REM 2. Scarica l'ultima versione
REM 3. La estrae nella cartella giusta, sovrascrivendo i file vecchi
REM 4. Chiude e riavvia Chrome da solo, cosi' la nuova versione si carica
REM
REM IMPORTANTE: chiude TUTTE le finestre di Chrome aperte per completare
REM l'aggiornamento - salva il tuo lavoro prima di avviarlo.
REM ===========================================================================

REM --- DA MODIFICARE: metti qui il link reale allo zip sul tuo sito ---------
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

REM --- Passo 1: trova (o chiedi) la cartella dell'estensione ----------------
set "CARTELLA_ESTENSIONE="
if exist "%CONFIG_FILE%" (
    set /p CARTELLA_ESTENSIONE=<"%CONFIG_FILE%"
)

if not defined CARTELLA_ESTENSIONE (
    echo Prima volta: seleziona la cartella dove hai l'estensione CardSync Pro.
    echo (Si aprira' una finestra per scegliere la cartella)
    echo.
    for /f "usebackq delims=" %%F in (`powershell -NoProfile -Command ^
        "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Seleziona la cartella dell''estensione CardSync Pro (quella con manifest.json dentro)'; if ($f.ShowDialog() -eq 'OK') { Write-Output $f.SelectedPath }"`) do (
        set "CARTELLA_ESTENSIONE=%%F"
    )

    if not defined CARTELLA_ESTENSIONE (
        echo Nessuna cartella selezionata - annullato.
        pause
        exit /b 1
    )

    echo !CARTELLA_ESTENSIONE!> "%CONFIG_FILE%"
    echo Cartella salvata per le prossime volte: !CARTELLA_ESTENSIONE!
    echo.
)

if not exist "!CARTELLA_ESTENSIONE!\manifest.json" (
    echo ATTENZIONE: non trovo manifest.json in quella cartella.
    echo Cartella attuale: !CARTELLA_ESTENSIONE!
    echo Se e' sbagliata, cancella questo file e riprova:
    echo "%CONFIG_FILE%"
    echo.
    pause
    exit /b 1
)

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
echo Chiudo Chrome tra 5 secondi per completare l'aggiornamento...
echo (salva subito eventuali lavori in corso in altre schede)
timeout /t 5 >nul
taskkill /F /IM chrome.exe /T >nul 2>&1
timeout /t 2 >nul

REM --- Passo 4: estrae, sovrascrivendo la cartella esistente -----------------
echo Installo l'aggiornamento...
powershell -NoProfile -Command "Expand-Archive -Path '%TEMP_ZIP%' -DestinationPath '!CARTELLA_ESTENSIONE!' -Force"
del "%TEMP_ZIP%" >nul 2>&1
echo Fatto.
echo.

REM --- Passo 5: riavvia Chrome ------------------------------------------------
echo Riavvio Chrome...
start "" "chrome"
echo.
echo ================================================
echo Aggiornamento completato!
echo ================================================
echo.
timeout /t 3 >nul
exit /b 0
