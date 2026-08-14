# Changelog — CardSync Pro

Tutte le modifiche rilevanti al progetto sono elencate qui, dalla più recente alla meno recente.

## v3.15 — 2026-08-14

### Novità
- **Aggiornamento obbligatorio**: l'estensione controlla da sola, prima ancora del login, se è disponibile una versione più recente — se sì, blocca l'accesso con un wizard a schermo intero (impossibile da chiudere) che guida passo passo all'aggiornamento. Fallisce in modo permissivo se offline (non blocca chi non ha connessione).
- **Script di aggiornamento (`aggiorna_cardsync.bat`)** riscritto: ora prova prima a rilevare da solo la cartella dell'estensione leggendo le impostazioni di Chrome (dove sono elencate le estensioni "non pacchettizzate" con il loro percorso reale), chiedendo all'utente solo come ultima risorsa. Corretto anche un bug per cui la cartella scelta non veniva ricordata correttamente tra un utilizzo e l'altro.
- Wizard di aggiornamento sul sito (pannello "Aggiorna estensione" nell'header) semplificato: rimossa l'opzione "a mano", tutto passa dal comando PowerShell copiabile.

## v3.4 – v3.14 — 2026-08-13/14

Riassunto (voci individuali non registrate singolarmente al momento):
- Conversione immagini via Supabase Storage estesa a tutti i flussi (wishlist, sealed, non solo carte) — prima solo il controllo prezzi la applicava.
- Contenuto tipo file ripulito prima dell'upload su Storage (evitava errori "Invalid Content-Type header").
- Corretto un crash del controllo prezzi su carte senza URL salvato.
- Corretto un loop infinito del controllo prezzi su collezioni piccole (la sessione non si fermava mai da sola).
- Riscritta la prenotazione delle carte durante il controllo prezzi in modo **atomico** lato database (funzione `reclama_carte_per_controllo_prezzi`, FOR UPDATE SKIP LOCKED) — eliminata una race condition per cui due dispositivi potevano finire per controllare le stesse carte.
- Corretti due bug per cui gli aggiornamenti di prezzo/data-controllo venivano silenziosamente ignorati quando un dispositivo processava le carte di un altro membro del gruppo.
- Unione automatica a un controllo prezzi già in corso nel gruppo (carte e wishlist), e avvio automatico "aiuta se non hai altro da fare" con pausa se arriva lavoro vero — entrambi dietro l'interruttore "Aiuta anche il gruppo" (mai attivo di default).

## v3.3 — 2026-08-13

### Fix
- **🔴 Carte di un altro finite nel database sbagliato** — quando l'estensione elabora una carta per conto di qualcun altro (coda condivisa dal sito), ora scrive sempre sul proprietario reale della richiesta, non su chi è loggato sul dispositivo che la esegue. Stessa correzione applicata separatamente anche al controllo prezzi ("solo le mie" filtrava sulle carte di chi esegue, non di chi ha creato la richiesta).
- **🔴 Lavoro non diviso tra dispositivi online** — sia l'aggiunta carte che il controllo prezzi finivano per essere elaborati quasi interamente da un solo dispositivo, anche con più PC online contemporaneamente. Ridotti i lotti reclamati per volta (1 carta per l'aggiunta, 3 per il controllo prezzi, con richiesta automatica del successivo), aggiunto un controllo di riserva basato su `chrome.alarms` per i dispositivi con la tab in background (rallentata da Chrome).
- **Regola di sicurezza mancante** per la lettura della collezione altrui durante il controllo prezzi condiviso — esistevano regole solo per Sealed e Scambio, non per il resto della collezione.
- **Permesso mancante** per eliminare righe dalla coda (bloccava la rimozione delle "Carte con problemi").
- **Crash "Cannot read properties of null"** durante il controllo prezzi — una carta senza URL salvato bloccava l'intera sessione invece di essere saltata.
- **Filtro location vuoto interpretato come "nessuna corrispondenza"** invece di "tutte le location" durante il controllo prezzi dal sito.
- Vincolo `NOT NULL` sulla colonna `tipo` che rifiutava le carte non-sealed.
- Content-Type non valido durante l'upload di alcune immagini su Storage (residui dall'era Google Apps Script).
- Nomi carta forzati in maiuscolo — ora restano con la capitalizzazione naturale.
- Scroll casuale anti-rilevamento: ora torna sempre in cima alla pagina alla fine.

### Novità
- **Immagini spostate su Supabase Storage** (prima base64 dentro il database) — alleggerisce il database, con deduplica automatica via hash del contenuto.
- **Sezione "Carte con problemi"** sul sito: vedi/correggi/riprova le carte che l'estensione non è riuscita a trovare, incluse le disambiguazioni (ora risolte via link diretto invece di una nuova ricerca per nome, che poteva restare ambigua).
- **Vista mobile compatta** per Visualizzazione/Scambio/Wishlist/Sealed/Inserimento — niente più scorrimento orizzontale su telefono.
- **Ricerca globale** sul sito (cerca su tutta la collezione, non solo la tab attiva).
- **Notifiche letto/non letto** per match trovati e avvisi prezzo wishlist.
- **Privacy match**: due interruttori per nascondere i propri Scambio/Wishlist dal matching automatico col gruppo.
- **Login semplificato**: solo nome utente, niente più email da scrivere per intero.
- **Icona profilo** al posto dell'email in header, con menu nome/email/logout.
- **Pulizia automatica dello storico prezzi** oltre i 30 giorni (gira da sola ogni notte).
- **Ambito controllo prezzi** ("solo le mie" / "tutto il gruppo") ora scelto esplicitamente sul sito al momento della richiesta, invece di dipendere da un'impostazione locale del dispositivo che la esegue.

## v3.2 — 2026-08-08

### Fix
- **🔒 Credenziali Telegram esposte in `notify_update.js`** — il token del
  bot e il chat/thread ID usati per le notifiche di aggiornamento erano
  scritti in chiaro come valore di default nel file (attivo per chiunque
  eseguisse lo script senza impostare le variabili d'ambiente), invece di
  essere richiesti solo tramite `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID`/
  `TELEGRAM_THREAD_ID`. Chiunque avesse accesso al file poteva usare quel
  token per mandare messaggi nel canale/gruppo configurato. Rimossi i
  default "veri": le variabili vanno ora sempre impostate via ambiente.
  Corretto anche il controllo di avvio in `main()`, che confrontava contro
  dei placeholder mai effettivamente usati come default (quindi non
  scattava mai) — ora verifica semplicemente che le variabili non siano
  vuote. **Se il token era già stato distribuito/versionato, va comunque
  rigenerato da BotFather (`/revoke`): sostituire il file da solo non lo
  invalida.**
- **Pulizia codice morto** — rimossa `_fermaKeepAlive()` in `background.js`
  (mai chiamata da nessun punto del file) e `CONDIZIONI_MAP` in `popup.js`
  (mai referenziata), individuate con un controllo incrociato su tutte le
  dichiarazioni di funzione/costante del progetto.

## v3.1 — 2026-08-01

### Novità
- **➕ Aggiungi carte: tabella a righe invece della sola textarea** — la
  pagina "Carte" ha ora un tab "🧾 Riga per riga": scrivi il codice o
  nome+numero, Invio conferma la riga (Lingua/Condizione — incluse tutte le
  varianti `+`/`-` — RH/1ED/Qty/Note come controlli diretti, non più token
  da ricordare) e se ne apre subito una nuova, senza aspettare. Le carte
  vengono processate una alla volta con lo stesso ritmo anti-blocco di
  sempre; quelle riuscite spariscono dalla tabella dopo un breve ✅ (restano
  nel log), quelle non trovate/ambigue vanno dritte nel pannello di
  correzione manuale esistente. Il vecchio campo bulk resta disponibile in
  un secondo tab "📝 Incolla lista" (stessa sintassi di sempre), ora anche
  con caricamento diretto di un file `.txt` (bottone o trascinamento).
- **Ripresa sessione interrotta rivista** — salva la coda non ancora
  completata (non più il testo grezzo) e la ripopola nella tabella al click
  su "Riprendi".

### Fix
- **Coda che poteva bloccarsi per sempre** — lo step di scrittura sul
  foglio non era protetto da un controllo errori: un fallimento isolato
  (es. service worker riavviato in quel momento) avrebbe interrotto
  silenziosamente l'intera coda, senza messaggio d'errore né modo di
  ripartire se non ricaricando la pagina. Ora un fallimento lì viene
  trattato come una carta non trovata (log + pannello di correzione).
- **Conteggio "pausa ogni N carte" leggermente sfalsato dopo uno stop
  durante un rate-limit** — fermandosi proprio mentre una carta era in
  pausa per Error 1015, veniva comunque contata come completata pur
  tornando in coda per la ripresa. Il contatore ora avanza solo per le
  carte davvero concluse.

## v3.0 — 2026-07-26

### Novità
- **Hub unico in una tab** (`app.html`) — Controllo prezzi, Carte, Sealed,
  Wishlist e Anteprima vivono ora come iframe in un'unica tab con una
  tab-bar interna, invece di aprire fino a 5 tab separate del browser.
  Header comune (profilo/⚙/📜/🎨/🎛️), footer unico e cambio sezione senza
  ricaricare pagina. Le singole pagine restano invariate internamente e
  restano apribili anche da sole.
- **📍 Gestisci location** — nuovo popover nell'header dell'hub per
  aggiungere, rinominare ed eliminare le location della scheda dedicata
  "LOCATION" (quella collegata alla tendina Location dell'Inventario), con
  propagazione automatica alle righe dell'Inventario che le usano
  (rinomina le aggiorna, elimina le riporta a "?"). Richiede
  `apps_script_location_snippet.gs` (nuove azioni `elencaLocationTab`/
  `aggiungiLocationTab`/`rinominaLocationTab`/`eliminaLocationTab`).
- **🎛️ Comportamento e 👤 Profilo centralizzati nell'hub** — Ritardo
  min/max, Timeout Cloudflare, Pausa ogni N carte e Avviso sonoro, prima
  duplicati in ogni pagina bulk, vivono ora in un unico popover
  raggiungibile da qualunque sezione; stesso discorso per la scelta del
  profilo condiviso, non più legata alla sola pagina "Controllo prezzi".

### Fix
- **Worker tab non riusata nei fallback Cloudflare** — i percorsi di
  fallback per carte e sealed (`_risolviNomeEPrezzoUnicaTab`,
  `_risolviProdottoSealedTab`) aprivano sempre una tab nuova invece di
  riusare quella `about:blank` già pronta per la sessione, vanificando in
  parte l'ottimizzazione "una sola tab per sessione". Ora il tabId passato
  viene sempre riusato via `tabIdEsterno`, propagato attraverso tutta la
  catena di risoluzione.
- **Sessioni lunghe (▶ Avvia / bulk Carte-Sealed-Wishlist / 🔄 Aggiorna
  prezzi) si bloccavano se la tab restava per ore fuori dal primo piano**
  (finestra minimizzata, coperta da altre finestre, lasciata aperta durante
  la notte…) — riprendevano da sole solo tornando a mettere la tab in
  focus. Causa: il "background tab timer throttling" di Chrome, che
  rallenta drasticamente `setTimeout`/`setInterval` in una tab non
  visibile/non attiva dopo pochi minuti — e tutta l'attesa tra una carta e
  l'altra si basa su questi timer. Fix: ogni sessione lunga avvia ora un
  audio in loop a volume quasi impercettibile (nuovo
  `avviaAudioKeepAlive()`/`fermaAudioKeepAlive()` in `shared.js`, nessun
  file esterno), che esclude la tab dal throttling per tutta la propria
  durata — fermato automaticamente alla fine (successo, stop manuale o
  errore).

## v2.23 — 2026-07-19

### Novità
- **👁️ Anteprima foglio** — nuova pagina (icona 👁️ nell'header, accanto a
  📜/⚙) che mostra il Google Sheet configurato in una tabella scorrevole:
  ricerca testuale su tutte le colonne, filtro Location, link Cardmarket
  cliccabili, modifica inline della Location (salva subito nel foglio),
  simbolo € accanto ai prezzi.
- **👤 Cambio profilo da Carte/Sealed/Wishlist** — le tre pagine bulk hanno
  ora la stessa tendina "Profilo" del popup principale nel pannello ⚙️
  Impostazioni, senza dover tornare al popup principale per cambiarlo.

### Fix
- **👁️ Anteprima foglio: righe mancanti, disallineate o mostrate a partire
  dalla riga sbagliata** — tre cause distinte, tutte corrette:
  1. La tabella partiva dalla riga 1, mostrando anche le eventuali righe di
     intestazione — ora parte sempre da una riga fissa (4).
  2. La riga di partenza veniva letta da `rigaInizio` in storage, che però
     è il puntatore di *ripresa* del controllo prezzi (sovrascritto a ogni
     riga elaborata) — l'anteprima ora usa una soglia fissa, indipendente.
  3. La causa più insidiosa: la lettura passava dall'export CSV pubblico di
     Google (`gviz/tq`), che **esclude del tutto le righe nascoste
     manualmente** dal risultato (limite di Google, nessun parametro URL
     per aggirarlo) — ogni riga dopo una riga nascosta scalava di
     posizione, facendo sparire/disallineare esattamente le righe vicino
     all'inizio. Risolto alla radice: la lettura ora passa dalla Web App
     (nuova azione `leggiAnteprima` in `webapp_scrivi_prezzi.gs`, da
     ridistribuire), che legge con `SpreadsheetApp`/`getDisplayValues()` e
     include sempre tutte le righe reali, comprese quelle nascoste.
     Richiede quindi l'URL Web App configurato anche solo per visualizzare
     l'anteprima (prima serviva solo per modificare la Location).
- **👁️ Anteprima foglio: la seconda modifica alla Location non veniva
  salvata** — il click sulla cella catturava il valore da modificare solo
  al primo caricamento della tabella; dopo un salvataggio riuscito la cella
  non veniva ridisegnata, quindi ogni click successivo continuava a
  proporre il valore ORIGINARIO invece di quello appena salvato — se il
  nuovo valore desiderato coincideva per caso con quello originario (es.
  alternando tra due location), veniva scambiato per "nessun cambiamento" e
  scartato in silenzio. Ora il valore attuale viene riletto a ogni click,
  non più congelato al primo render.

## v2.22 — 2026-07-18

### Novità
- **🗂️ Wishlist** — nuovo terzo flusso, accanto a "➕ Carte" e "📦 Sealed":
  una pagina dedicata per registrare le carte che vuoi comprare (non che
  possiedi già), su una scheda separata dello stesso Google Sheet
  dell'Inventario. Stessa sintassi bulk delle carte (codice/nome, lingua,
  condizione, RH, 1ED, formato con virgola per nomi tipo "Mew EX"), con in
  più un **prezzo obiettivo** opzionale: aggiungi `@PREZZO` in qualunque
  punto della riga (es. `MEW008 @15`) per segnare la soglia sotto cui
  conviene comprare — le carte scese sotto quella soglia vengono
  evidenziate in verde nel pannello "📋 Wishlist attuale".
- **🔄 Aggiorna prezzi** (Wishlist) — ricontrolla in sequenza il prezzo di
  tutte le carte già in wishlist, riusando la stessa infrastruttura di
  lettura prezzo già collaudata nel controllo prezzi principale — nessuna
  modifica al service worker.
- **✓ Comprata** (Wishlist) — sposta con un click la carta dalla Wishlist
  all'Inventario (stessa configurazione Web App/Sheet ID già impostata nel
  popup principale), svuotando la riga di origine. **🗑️ Rimuovi** elimina
  la riga senza spostarla, per le carte che non interessano più.
- Richiede due nuove azioni lato Apps Script (`leggiWishlist`,
  `svuotaRiga`) — vedi `apps_script_wishlist_snippet.gs` e Parte 10 di
  `ISTRUZIONI.md` per il setup.

## v2.21 — 2026-07-17

### Modifiche
- **Badge "profilo attivo" nell'header sostituito con testo semplice** — la
  pill colorata introdotta in v2.20 ("👤 NOME" con sfondo proprio) è stata
  sostituita da una riga di testo sobria, coerente con lo stile del
  sottotitolo già presente nell'header: **"Connesso come: NOME"**, solo il
  nome in grassetto, nessuno sfondo/bordo. Stessa logica di aggiornamento
  (boot + `chrome.storage.onChanged`, sincronizzato tra tutte le pagine),
  solo l'aspetto visivo è cambiato.

## v2.20 — 2026-07-17

### Novità
- **Badge "profilo attivo" sempre visibile nell'header** — finora l'unico
  punto in cui si vedeva quale profilo condiviso fosse in uso era il
  modale mostrato prima di avviare una sessione (v2.19), quindi bisognava
  aprire un popup o passare da un avvio per accorgersene. Ora un piccolo
  badge ("👤 NOME") compare sempre sotto il titolo, in tutte e tre le
  pagine (popup principale, "Aggiungi carte", "Aggiungi sealed") — sparisce
  da solo se nessun profilo è selezionato. Si aggiorna in tempo reale anche
  quando il profilo cambia da un'ALTRA pagina dell'estensione (es. lo si
  cambia dal popup principale mentre una pagina bulk è già aperta), tramite
  `chrome.storage.onChanged`, coerente con la stessa logica già usata per
  far ripresentare il promemoria di conferma (v2.19). Sfondo bianco
  semi-trasparente indipendente dal colore dell'header, così resta
  leggibile anche nel tema Pokéball (dove l'header è tinta unita identica
  al colore accent).

## v2.19 — 2026-07-17

### Novità
- **Conferma del profilo attivo prima di controlli/aggiunte** — con più
  persone che condividono la stessa estensione (profilo condiviso, v2.16),
  mancava un modo per accorgersi di avviare una sessione col profilo di
  un'ALTRA persona ancora selezionato nella tendina. Il modale "🚀 Recluta
  il Team Rocket!" (già mostrato prima di ▶ Avvia / 📋 Aggiungi tutte / 📦
  Aggiungi al foglio) ora mostra anche un riquadro con il **nome del
  profilo attivo** ("👤 Profilo attivo: NOME — sei tu?"), o un avviso se
  nessun profilo è selezionato. A differenza della sola conferma login
  (mostrata una volta per apertura pagina), questo promemoria si
  **ripresenta ogni volta che il profilo attivo cambia** rispetto
  all'ultima conferma data — anche a metà sessione, es. se il profilo
  viene cambiato dalla tendina nel popup principale mentre una pagina bulk
  è già aperta altrove.

## v2.18 — 2026-07-17

### Fix
- **L'ultimo profilo scelto non restava selezionato riaprendo il popup** —
  la tendina "Profilo" si ripopolava sempre da capo su "— scegli un profilo
  —", anche se i dati di quel profilo (URL Web App/ID Sheet/Nome scheda)
  erano già in storage e già in uso. Ora, all'apertura del popup, la tendina
  mostra subito l'ultimo profilo caricato — senza rifare la chiamata al
  registro, solo per mostrare visivamente quale profilo è attivo — così non
  serve più sceglierlo di nuovo a ogni apertura.

## v2.17 — 2026-07-17

### Modifiche
- **Riquadri "👤 Profilo condiviso" e "⚡ Connessione Google" uniti in uno
  solo** — dopo l'introduzione del profilo condiviso (v2.16), avere due
  riquadri separati sempre entrambi in vista era più confusione visiva del
  necessario, specie ora che l'uso quotidiano richiede solo scegliere un
  nome da una tendina. Il nuovo riquadro unico **"⚡ Connessione"**, aperto,
  mostra subito la tendina "Profilo" — un solo campo — e nasconde i dettagli
  tecnici (URL Web App, ID Sheet, Nome scheda, "🔌 Controlla connessione",
  "💾 Salva come profilo…", URL registro) dietro un secondo toggle nidificato
  **"⚙️ Configura manualmente"**, da aprire solo la prima volta che si crea
  un profilo o per un controllo puntuale.

## v2.16 — 2026-07-16

### Novità
- **Profilo condiviso** — nuovo riquadro "👤 Profilo condiviso" nel popup
  principale (accanto a "⚡ Connessione Google") pensato per chi usa la
  stessa estensione su più PC/account (es. con un amico): un secondo Google
  Sheet, separato dall'inventario, funge da "registro profili" con una riga
  per persona (URL Web App, ID Sheet, Nome scheda, colonne). Basta
  configurare una volta l'URL del registro su ogni PC, poi scegliere il
  profilo dalla tendina e cliccare "📥 Carica" per compilare in automatico
  tutta la connessione — niente più copia/incolla manuale di 4-5 campi ogni
  volta che cambia la persona che usa l'estensione. Il bottone "💾 Salva
  connessione attuale…" scrive la configurazione corrente nel registro con
  il nome scelto. La tendina profili si aggiorna da sola all'apertura del
  riquadro e sceglierne uno lo carica subito — nessun bottone "Carica" o
  "Aggiorna elenco" separato da capire. L'URL del registro condiviso è
  precompilato di default nel codice (stesso registro per tutti): non serve
  incollarlo su ogni PC, resta comunque un campo modificabile. Nuovo script
  `webapp_registro_profili.gs` da incollare nel secondo Sheet (setup
  descritto in `ISTRUZIONI.md`, Parte 4bis) — il foglio dell'inventario e
  il suo `webapp_scrivi_prezzi.gs` restano invariati.

## v2.15 — 2026-07-15

### Novità
- **Nota libera nel bulk "Aggiungi carte"** — nel formato con virgola (già
  usato per nomi tipo "Mew EX"), qualunque parola dopo la virgola che non è
  un modificatore noto (lingua/condizione/RH/1ED) veniva prima scartata
  silenziosamente. Ora viene scritta nella colonna Note: `FST007, NM error`
  → codice FST007, condizione NM, nota "ERROR". Utile in particolare per le
  carte più vecchie il cui link Cardmarket non contiene il codice (vedi fix
  v2.14) e per cui una nota manuale aiuta a ricordare perché quella riga
  richiede attenzione. La nota si combina con quelle automatiche
  (RH/1ED/condizione +/-) sia nell'inserimento diretto sia nel pannello di
  correzione manuale, e sopravvive alla lista "carte fallite" da ricopiare
  per riprovare. Il formato storico (senza virgola) resta invariato: non
  supporta note libere, perché non c'è modo affidabile di distinguere una
  parola in più del nome da una nota senza un separatore esplicito.

## v2.14 — 2026-07-15

### Fix
- **Carte vecchie segnate come "non trovata"** (es. `FST095` → Tynamo,
  Fusion Strike) — alcune espansioni datate non includono affatto il
  codice set+numero nello slug dell'URL Cardmarket (es.
  `.../Singles/Fusion-Strike/Tynamo`, senza "FST095" da nessuna parte).
  La verifica anti-carta-sbagliata (introdotta per il bug "MEW 8 → apriva
  Wartortle") si basava solo sullo slug e scartava sempre questi link,
  anche quando erano l'unico risultato restituito da Cardmarket e quindi
  quasi certamente corretti. Ora, quando la ricerca produce un solo
  risultato il cui slug non conferma né smentisce la query, l'estensione
  **apre/legge davvero la pagina candidata** e verifica il codice
  effettivo dall'h1 (fonte molto più affidabile dello slug) prima di
  accettarla — nessun costo aggiuntivo, quella pagina andava comunque
  fetchata per leggere nome/prezzo. Corretto sia nel percorso normale
  (fetch statico) sia nel fallback via tab (usato quando Cloudflare blocca
  il fetch statico), mantenendo invariata la protezione contro i falsi
  positivi: se il codice reale non combacia, la carta va comunque in
  correzione manuale invece di essere accettata alla cieca.

## v2.13 — 2026-07-14

### Documentazione
- **`ISTRUZIONI.md` riscritto** — era rimasto fermo alla versione "base" del
  progetto (popup singolo, nessuna colonna Location/Variazione, nessun
  accenno a bulk carte/sealed, temi, controllo login, changelog viewer).
  Ora riflette lo stato reale del prodotto: setup Sheet/Web App, guida
  completa ai due flussi bulk (sintassi righe, formato con virgola per nomi
  tipo "Mew EX", quantità sealed), login su Cardmarket, filtro Location,
  temi, struttura file aggiornata.

### Novità
- **Scrollbar a tema estesa a tutta l'estensione** — dopo l'introduzione
  nella pagina Changelog (v2.12), lo stesso stile (colori presi dalle
  variabili del tema attivo invece della scrollbar di sistema) è stato
  applicato anche a: il log sessione (`.log-body`) nel popup principale e
  in entrambe le pagine bulk; il dettaglio "🔺 Carte salite"/"🔻 Carte scese"
  nel popup principale; il pannello di correzione manuale in modalità-tab
  nelle pagine bulk carte/sealed; l'elenco delle varianti candidate nel
  pannello di correzione carte (nuova classe riusabile `.themed-scroll` per
  gli elementi creati dinamicamente via JS).

### Pulizia codice morto
- Rimossi in `background.js` due handler di messaggi mai invocati da nessun
  punto del progetto: `FETCH_IMMAGINE` (superato dall'estrazione immagine
  inline già usata altrove) e `LEGGI_NOME_SEALED` (duplicato incompleto di
  `LEGGI_SEALED` — mancava il collegamento al watchdog anti-blocco
  `requestId`/`_touchRichiesta`: se mai richiamato per errore avrebbe
  silenziosamente disattivato quella protezione).
- Rimosse due funzioni intere mai chiamate in `background.js`:
  `_risolviSinglesENome()` e `_leggiNomeDaSingles()` — entrambe aprivano una
  propria tab bypassando il riuso della worker tab, superate rispettivamente
  da `_risolviNomeEPrezzoUnicaTab()` (risoluzione+prezzo in un'unica tab) e
  dalla lettura nome integrata nelle funzioni di risoluzione esistenti.
- Rimossa `verificaCartaNellUrl()` (e la sua unica dipendenza `slugify()`)
  in `popup.js` — il vecchio approccio "indovina dallo slug dell'URL",
  superato da `verificaCartaNelDom()` che verifica sul DOM reale della
  pagina.
- Rimosse `oloTypeFromUrl()`/`firstEdFromUrl()` in `aggiungi_carta_popup.js`
  — residuo del controllo duplicati rimosso in una versione precedente dal
  flusso bulk per velocizzare le sessioni.
- Rimossa `_accodaCorrezione()` in `aggiungi_carta_popup.js` — mai chiamata:
  l'unico punto che accoda carte da correggere lo fa apposta in blocco
  (non una alla volta) per mostrare subito il totale corretto nel pannello.

## v2.12 — 2026-07-13

### Novità
- **Scrollbar a tema nella pagina Changelog** — lo scrolling introdotto in
  v2.11 usava la scrollbar di sistema (grigia), stonando soprattutto con i
  temi scuri (Dark Type, Team Rocket) e col tema Pokéball. Ora la scrollbar
  usa i colori del tema attivo (`--accent-dim`/`--surface`), cambiando
  automaticamente insieme al tema — nessuna regola aggiuntiva da mantenere
  per i temi "normali"; Wise Glasses e Pokéball hanno un piccolo tocco
  dedicato per restare coerenti col loro stile a bordi netti.

## v2.11 — 2026-07-13

### Novità
- **Scrolling nella pagina Changelog** — prima l'unico modo per leggere un
  changelog lungo era scorrere l'intera pagina del browser, portando via
  dalla vista anche l'header e il footer. Ora la pagina occupa esattamente
  il viewport: header e footer restano sempre visibili, e solo il testo del
  changelog scorre nel proprio riquadro — stesso pattern di scroll già usato
  altrove nell'estensione (es. il log delle sessioni bulk).

## v2.10 — 2026-07-13

### Fix
- **Race condition sulla worker tab riusata dal link 🔗 "Apri ricerca
  Cardmarket"** — il fix di v2.9 faceva riusare la worker tab a quel
  bottone, ma senza passare dalla coda `_accodaSuWorkerTab` già introdotta
  apposta per serializzare ogni uso della worker tab tra flussi diversi
  (bulk automatico, ricontrollo prezzo mancante, correzioni manuali). Un
  click su 🔗 mentre un'altra di queste operazioni era ancora in corso sulla
  stessa worker tab poteva navigarla a metà di quella lettura, facendo
  leggere all'altro task la pagina sbagliata — lo stesso tipo di bug che la
  coda era nata per prevenire. Ora anche questo ramo si accoda, come tutti
  gli altri usi di `usaWorkerTab`.
- **Micro-leak di memoria in `_righeGiaConfermate`** — il tracker anti-duplicato
  per carte volutamente identiche era un `Set` mai svuotato per tutta la vita
  del service worker: su bulk molto lunghi o tante sessioni ravvicinate
  cresceva senza limiti. Convertito in una `Map` riga→timestamp con pulizia
  periodica (voci più vecchie di 60 minuti, ben oltre una sessione bulk
  plausibile) agganciata allo stesso alarm `sw-keepalive` già usato per
  `_pulisciRichiesteVecchie` — nessun cambiamento di comportamento per i
  chiamanti, stessa logica di prima.

## v2.9 — 2026-07-13

### Fix
- **Il link 🔗 "Apri ricerca Cardmarket" nel pannello di correzione manuale
  apriva sempre una tab nuova** — su una sessione bulk con più carte/prodotti
  da correggere a mano, ognuna accumulava la propria tab in aggiunta a quella
  già usata per la lettura automatica: lo stesso pattern di navigazione
  "meccanico" già identificato altrove come segnale per l'anti-bot di
  Cloudflare. Ora riusa la worker tab già aperta per la sessione bulk
  (stesso comportamento per l'utente, una tab in meno da gestire). Corretto
  sia nel pannello carte sia in quello sealed.

## v2.8 — 2026-07-13

### Modifiche
- **Il modale "Team Rocket" ora verifica per davvero il login** — prima si
  fidava solo del click su "Sì, Boss Giovanni!". Ora, subito dopo la
  conferma, esegue un controllo reale e silenzioso su Cardmarket (stesso
  segnale DOM verificato del bottone "🔌 Controlla connessione":
  `account-dropdown` presente = loggato, `login-signup` presente = non
  loggato). Il controllo è silenzioso — nessuna tab visibile se sei già
  loggato — e porta la tab in primo piano SOLO se risulti non loggato, così
  puoi accedere subito invece di scoprirlo a sessione già iniziata. Se non
  sei loggato, l'avvio viene bloccato per davvero, non solo scoraggiato dal
  promemoria. Vale per ▶ Avvia, 📋 Aggiungi tutte, 📦 Aggiungi al foglio e la
  ripresa di una sessione interrotta.
- Il modale resta comunque utile come promemoria proattivo (mostrato una
  volta per apertura del popup) — ora ha anche un riscontro oggettivo dietro.

---

## v2.7 — 2026-07-13

### Novità
- **Bottone "🔌 Controlla connessione"** nel popup principale (dentro il
  riquadro "⚡ Connessione Google"): un solo click verifica prima di lanciare
  una sessione lunga.
- **Web App + foglio raggiungibili** — controllo automatico e affidabile,
  riusa l'azione `elencaLocation` già esistente e già testata, nessuna nuova
  chiamata inventata verso Apps Script.
- **Login su Cardmarket** — controllo affidabile basato su un segnale
  verificato dal DOM reale (2026-07): `<a id="account-dropdown">` presente
  nell'header = loggato, `<div id="login-signup">` presente = non loggato
  (i due elementi sono mutuamente esclusivi, sempre uno dei due presente).
  La tab resta comunque attiva dopo il controllo, così si può accedere
  subito se il risultato è "non loggato".

---

## v2.6 — 2026-07-13

### Refactor
- **Eliminata la triplice duplicazione del filtro righe offerta** — la logica
  che legge il DOM (mappa lingua→aria-label, rank condizione, marker Reverse
  Holo/Prima Edizione, controllo "carrello cliccabile") viveva copiata quasi
  identica in `content.js` e in due punti diversi di `background.js`
  (necessario perché `chrome.scripting.executeScript` non può referenziare
  funzioni esterne dell'estensione). Ora vive in un'unica fonte di verità in
  `shared.js` (`rigaSoddisfaFiltriShared`), iniettato dichiarativamente su
  ogni pagina Cardmarket insieme a `content.js` — Chrome condivide lo stesso
  "mondo isolato" tra script dichiarativi e injection imperative della stessa
  estensione sulla stessa tab, quindi `background.js` può richiamare la
  funzione condivisa invece di riscriverla. Aggiunto un fallback fail-open
  (nessun filtro, mai un blocco totale) nell'improbabile caso in cui
  `shared.js` non fosse ancora pronto, per non ripetere l'incidente "tutte le
  carte Esaurita" di una versione precedente.
- Un bug futuro in questa logica richiederà ora **un solo fix**, non tre
  sincronizzati a mano.

---

## v2.5 — 2026-07-13

### Novità
- **Changelog visibile nel popup** — nuova icona 📜 nell'header (popup
  principale + pagine bulk carte/sealed) che apre `changelog.html` in una
  tab: legge e mostra `CHANGELOG.md` formattato, con lo stesso tema
  scelto dall'utente. Basta continuare ad aggiornare questo file per
  vederlo comparire lì senza toccare altro.

### Modifiche
- **Bottone "Segnala un bug" spostato dall'header al footer** — prima
  aveva lo stesso peso visivo di 📜/⚙ nell'header pur essendo un'azione
  usata raramente. Ora è un link testuale piccolo e attenuato (opacità
  0.45, sale a 0.9 al passaggio del mouse) subito sotto la riga di
  copyright in fondo alla pagina — sempre raggiungibile in un click, ma
  senza competere visivamente con i controlli usati più spesso.

---

## v2.4 — 2026-07-13

### Fix
- **"Tutte le carte risultano Esaurita"** — il controllo "carrello cliccabile"
  (`rigaCarrelloCliccabile`, introdotto per scartare offerte non acquistabili)
  era un'**allowlist troppo rigida**: richiedeva una corrispondenza esatta
  `<button data-id-amount>` per accettare una riga. Bastava un piccolo
  scostamento (tab non ancora autenticata su Cardmarket al momento della
  lettura, markup leggermente diverso) per far scartare *ogni* riga di *ogni*
  carta, risultando sistematicamente in "Esaurita". Ora la funzione esclude
  solo il pattern esplicito "non cliccabile" osservato nel DOM reale
  (`<a class="btn-grey" role="button">` senza `data-id-amount`) — fail-safe
  invece di allowlist rigida. Corretto in `content.js` e nelle due copie
  inline in `background.js`.

### Novità
- **Promemoria login prima di avviare** — un modale bloccante ("🚀 Recluta il
  Team Rocket! ... hai ricordato di loggarti con l'account secondario?")
  compare ora prima di ▶ Avvia (popup principale), 📋 Aggiungi tutte (carte) e
  📦 Aggiungi al foglio (sealed), oltre che prima di riprendere una sessione
  interrotta. Va confermato cliccando "😈 Sì, Boss Giovanni!" prima che il
  flusso parta davvero — il controllo carrello richiede infatti di essere
  loggati su Cardmarket, altrimenti si ripresenta il bug sopra. La conferma
  vale solo per l'apertura corrente del popup/tab: si richiede di nuovo ogni
  volta che viene riaperto. Il "🧪 Prova" (dry run) non è gate-ato, visto che
  non apre tab reali.
- **Nuovo tema "Team Rocket"** — tema scuro nero/rosso aggiunto al selettore
  aspetto del popup principale, disponibile anche nelle pagine bulk
  carte/sealed (sincronizzato via `chrome.storage`).

### Modifiche
- Riordinato il selettore temi: **Dark Type** ora compare subito dopo
  **Grass Type** (prima era in fondo, dopo Wise Glasses).

---

## v2.3 e precedenti
Cronologia non tracciata in questo file — vedi i commenti `FIX:` inline nel
codice sorgente (content.js, background.js, popup.js, aggiungi_carta_popup.js,
aggiungi_sealed_popup.js), che documentano ogni correzione con il motivo del
bug originale.