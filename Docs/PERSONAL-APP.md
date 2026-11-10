# Installazione e uso personale

## Account, dispositivo e firma

Installa Xcode completo, aggiungi il tuo Apple Account in Settings → Accounts e
collega l’iPhone con un cavo dati. Autorizza il Mac sul telefono, abilita Modalità
sviluppatore e automazione UI. Il runner si esegue come test XCTest, non come una
normale app iOS. Il codice del dispositivo non va mai inserito nel progetto.

Gli script usano `DEVELOPER_DIR` senza cambiare la selezione globale degli strumenti.
Il valore predefinito è `/Applications/Xcode.app/Contents/Developer`.
`Scripts/diagnose.sh` elenca ambiente e dispositivi: l’output può contenere
identificativi e dati dell’account, quindi non pubblicarlo integralmente.

- **IPHONE_UDID**: identificatore del dispositivo in Xcode → Window → Devices and
  Simulators, oppure nell’output locale di `xcrun devicectl list devices`.
- **WDA_TEAM_ID**: Team di sviluppo del tuo account, non il suo nome visualizzato.
- **WDA_BUNDLE_ID**: identificatore reverse-DNS univoco scelto da te, per esempio
  `com.yourname.iphoneremote.wda`.

Se non conosci il Team ID, prepara il checkout con `Scripts/bootstrap-wda.sh`,
apri `Research/WebDriverAgent/WebDriverAgent.xcodeproj` in Xcode e consulta
Signing & Capabilities del target **WebDriverAgentRunner**. Seleziona il tuo Team
con firma automatica; il valore `DEVELOPMENT_TEAM` è visibile nelle Build Settings.
Queste modifiche restano nel checkout ignorato. Successivamente
`configure-wda.py` copia il checkout in `build/wda-source` e configura il bundle ID.

Copia `Config/Local.env.example` in `.local/development.env`, inserisci i tuoi valori
e caricali con `source .local/development.env`. Non pubblicare la copia compilata.

## Preparazione automatizzata

```sh
brew install libusbmuxd
source .local/development.env
Scripts/setup-personal-app.sh
```

Lo script scarica WDA al commit fissato, compila con `build-for-testing` e
provisioning automatico, quindi esegue l’installer personale. Xcode deve poter
accedere al tuo account e riconoscere il dispositivo. Eventuali problemi di firma
vanno risolti in Xcode. Non sono richieste credenziali in chat o file pubblici.

L’installer incorpora runner e sorgenti, verifica che il profilo includa il tuo
iPhone e firma il contenitore Mac con un certificato di sviluppo disponibile.
Installa `/Applications/iPhone Remote.app`; una precedente copia della stessa app
viene conservata in Application Support/Backups. Non sostituisce un’app diversa
con lo stesso nome. Puoi cambiare destinazione con
`Scripts/install-personal-app.sh --destination '/percorso/iPhone Remote.app'`.

Questa copia contiene una configurazione personale e **non va caricata come
release pubblica**. Il certificato di sviluppo non rende la copia un installer
universale, notarizzato o approvato per App Store.

## Avvio e autorizzazioni

Apri l’app da Applicazioni con un solo iPhone USB collegato. L’app usa la sorgente
video salvata o l’unica sorgente schermo disponibile e prepara iproxy e WDA.
Seleziona una sorgente manualmente quando necessario. Se compare la richiesta
Fotocamera sul Mac, serve per la cattura USB, non per una videocamera nascosta.

La fiducia nello sviluppatore può essere richiesta in Impostazioni → Generali →
VPN e gestione dispositivo. Le richieste di codice/XCTest si completano fisicamente
sull’iPhone: il tastierino può essere nascosto nel video. Non vengono aggirate.
Se il display è guasto, non presumere che ogni conferma sia completabile dal Mac.

Il controllo si abilita solo con video recente, WDA collegato e un singolo iPhone.
La guida numerica sospende l’input remoto: è un riferimento manuale, approssimativo,
non una ricostruzione delle posizioni del tastierino protetto.

## Uso quotidiano

La barra offre modalità compatta, primo piano, screenshot, registrazione e guida
numerica. Posizione e dimensioni della finestra sono memorizzate. La sidebar
permette di cambiare scala/opacità delle pillole, scorciatoie e cartella dei file.

| Azione | Scorciatoia predefinita |
| --- | --- |
| Home | ⌥⌘1 |
| App aperte | ⌥⌘2 |
| Notifiche | ⌥⌘3 |
| Centro di Controllo | ⌥⌘4 |
| Sospendi / riprendi controllo | ⌥⌘0 |
| Screenshot | ⌥⌘5 |
| Avvia / ferma registrazione | ⌥⌘6 |
| Mostra / nascondi sidebar | ⌃⌘S |

Le scorciatoie sono locali all’app attiva. Per cambiarle premi il pulsante della
combinazione; Esc annulla. Invio tenta di premere un unico pulsante Invia nelle
chat riconosciute; ⇧Invio va a capo. Nessuna compatibilità universale è promessa.

Il pulsante altoparlante nella barra apre il controllo del volume. Attiva
**Riproduci audio USB sul Mac** per ascoltare la traccia della sorgente video
selezionata. L’app non seleziona un microfono separato. La presenza della traccia
non garantisce che iOS trasmetta l’audio di ogni schermata protetta.

Se il display è guasto ma il touch risponde, usa VoiceOver sull’iPhone per
esplorare il tastierino. Nella prova il video USB mostrava il rettangolo di
selezione disegnato da iOS anche con le cifre nascoste. Ascolta la cifra prima
di confermarla con un doppio tocco sul telefono. Il rettangolo indica il tasto
selezionato, ma da solo non ti dice quale cifra sia. Segui i passaggi nella
[guida VoiceOver del README](../README.it.md#voiceover-se-il-display-delliphone-è-guasto).

Screenshot PNG e video MOV H.264 fino a 30 fps sono salvati inizialmente in
`~/Movies/iPhone Remote`, senza audio né controlli sovrapposti. Il video viene
finalizzato su stop, chiusura, interruzione della sorgente e cambio orientamento.
La finestra attende la finalizzazione prima di terminare normalmente.

Il tempo dell’ultimo comando misura l’esecuzione HTTP/XCTest, non la latenza
completa mouse-display. Gli errori non causano replay. Il testo non confermato
rimane in memoria e può essere copiato: controlla prima il telefono, perché una
richiesta interrotta potrebbe essere stata eseguita parzialmente.

## Firma e rinnovo

La scadenza dipende dal profilo dell’utente e viene letta dai dati firmati; non
esiste una data universale nel repository. Il Personal Team gratuito ha limiti
e può richiedere rinnovi frequenti. Apple Account e Xcode devono rimanere
configurati. [Apple: account sviluppatore](https://developer.apple.com/help/account/basics/about-your-developer-account).

L’app mostra un avviso entro due giorni e offre Tenta rinnovo firma. Il comando
compila i sorgenti WDA con provisioning automatico e riavvia il controllo. Può
richiedere rete verso Apple e azioni fisiche. Apple può mantenere un profilo ancora
valido: non viene garantita una nuova data. Il rinnovo alla futura scadenza reale
non è ancora stato collaudato.

## File locali e riconnessione

`~/Library/Application Support/iPhone Remote` contiene la copia eseguibile del
runner, i prodotti di rinnovo, i backup e i log. Le preferenze sono locali al Mac.
I log Xcode possono contenere identificativi personali: oscurali prima di condividerli.

L’app termina solo i processi che ha avviato. Riutilizza un runner già disponibile
senza acquisirne la proprietà. Scollega impedisce il ricollegamento volontario fino
a Collega WDA. Le richieste di autenticazione sospendono i tentativi automatici.
Il pulsante Riprova è disponibile dopo un errore che richiede intervento.
Per riutilizzare una sessione ancora attiva, nascondi iPhone Remote con **⌘H**
invece di uscire e lascia l’iPhone collegato. Uscire dall’app arresta il runner
che ha avviato; un nuovo avvio può richiedere di nuovo il codice. La richiesta
è gestita da iOS e la sessione può comunque interrompersi.

## Avvio manuale per sviluppatori

Dopo aver caricato la configurazione locale:

```sh
Scripts/run-wda.sh
```

In un secondo Terminale, con la stessa configurazione:

```sh
source .local/development.env
Scripts/usb-tunnel.sh
```

Apri una build Debug dell’app Mac, seleziona il video e premi Collega WDA.
Non eseguire `smoke-wda.py`, `verify-first-tap.py` o altri strumenti che creano
sessioni mentre usi l’app: possono sostituire la sessione attiva. Questi strumenti
sono diagnostici espliciti, non parte dei test automatici senza dispositivo.


## Pillole di navigazione (0.5.0)

Notifiche e Centro di Controllo sono pillole sottili con materiale traslucido,
allineate rispettivamente sopra la zona dell’orario e sopra gli indicatori di
rete/batteria del video verticale. Seguono il rettangolo dell’immagine durante il
ridimensionamento e lasciano libera la zona centrale. La geometria è progettata
sull’iPhone di riferimento, non rilevata dalle icone iOS di ogni schermata.

La pillola in basso al centro combina Home (clic singolo) e app aperte (doppio clic).
Home attende l’intervallo di doppio clic configurato in macOS per non essere
eseguito prima delle app aperte. Una seconda pressione annulla Home già al
mouse-down, anche se tenuta premuta. Perdere il focus, disabilitare il controllo
o rimuovere la vista annulla l’azione pendente. Le pillole superiori non hanno
questa attesa. Restano disponibili pulsanti e scorciatoie separati nella sidebar.

Face ID dell’iPhone non viene sostituito con Touch ID del Mac nel percorso USB/WDA.
Apple documenta un’autenticazione companion per app che adottano la policy prevista
nell’ambito di iPhone Mirroring, non una sostituzione generale applicabile a terzi
da questo client: [TN3210](https://developer.apple.com/documentation/technotes/tn3210-optimizing-your-app-for-iphone-mirroring).
