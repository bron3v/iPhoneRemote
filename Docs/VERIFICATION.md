# Verifiche e limiti delle prove

## Ambiente di riferimento

Prove locali su Apple Silicon M4, macOS 27.2, Xcode 27.2, iPhone 14 Pro con iOS 27.2.
Swift in modalità linguaggio 5; target minimo macOS 14. Non è una matrice di
compatibilità con tutte le versioni dichiarate compilabili.

Identificativi di dispositivo, Team, account, percorsi personali e schermate
private sono esclusi da questo documento. I log originali e le evidenze rimangono
in directory locali ignorate. Nessuna prova di autenticazione richiede di
condividere il codice del telefono.

## Verifiche ripetibili senza iPhone

`Scripts/verify.sh` esegue 19 test RemoteCore: geometria, protocollo WDA con risposte
simulate, cache e rotazione, testo Unicode, errori, selezione prudente del pulsante
Invia e geometria della guida. Compila l’app Mac e controlla la firma ad hoc.

Lo stesso script verifica il modello di produzione: ordine testo/Invio, limiti
e overflow visibile, recupero del testo non confermato, cancellazione dei task
obsoleti, guida che sospende l’input, scollegamento volontario e riconnessione senza
replay. I test usano URLProtocol e non inviano comandi a un telefono.

`Scripts/verify-experience.sh`, in una sessione desktop Mac, verifica composizione
marcata, commit Unicode, annullamento, Invio non ripetuto, scorciatoie, conflitti,
persistenza, proporzioni della finestra e primo piano. Genera campioni sintetici,
salva/decodifica PNG, produce un MOV H.264 riproducibile e verifica la chiusura del
file al cambio orientamento. Non richiede accesso al contenuto del display Mac.

I test Python in `Tests/Publication` verificano i controlli del pacchetto sorgenti
con valori sensibili fabbricati. L’audit non è una prova matematica di assenza di
segreti: il diff e le immagini degli asset richiedono comunque revisione.

## Verifiche eseguite sul dispositivo di riferimento

- Video USB reale, campioni di 55–60 fps e frame di circa 1180×2556.
- WDA firmato con provisioning dell’utente, tunnel USB e sessione 393×852 punti.
- Navigazione sicura in Impostazioni, Home, Centro di Controllo, notifiche e app aperte.
- Impostazioni waitForIdleTimeout e animationCoolOffTimeout a zero.
- Avvio della copia installata con tunnel/runner gestiti dall’app.
- PNG 1180×2556 e MOV H.264 della stessa dimensione, circa 3,035 secondi, finalizzati
  e leggibili dalla copia Release. Modalità compatta e primo piano confermati.
- Richiesta XCTest riapparsa dopo un riavvio: rilevata come azione fisica necessaria;
  dopo conferma dell’utente WDA e sessione dell’app sono tornati disponibili.
- Guida numerica renderizzata e ispezionata senza inviare cifre. Le posizioni reali
  del tastierino nascosto non sono dichiarate conosciute o verificate.

## Cosa non viene dichiarato verificato

- Rinnovo del provisioning alla futura scadenza reale.
- Compatibilità con tutti i modelli iPhone, Mac Intel o tutte le release macOS/iOS.
- Invio effettivo di messaggi reali come test automatico: le prove di invio sono simulate.
- Latenza completa mouse-fotogramma, stabilità prolungata e ogni variante di IME/chat.
- Disattivazione delle protezioni che nascondono tastiere e altre superfici sicure.
- Firma Developer ID, notarizzazione, approvazione App Store o installazione universale.

GitHub Actions è predisposto per audit, test e build Mac senza dispositivo.
L’esecuzione sul servizio GitHub va confermata dopo la pubblicazione; i risultati
locali non vengono presentati come una CI remota già passata.

## Preparazione del repository pubblico

- Repository locale inizializzato su `main`; 74 file sorgente/documentazione/asset
  preparati nell’indice, senza commit autore o remote impostati automaticamente.
- Sei test Python di pubblicazione superati; l’audit dell’indice non segnala le
  categorie di artefatti o i pattern sensibili controllati. Revisione aggiuntiva
  dei riferimenti locali noti e dei metadati PNG degli asset completata.
- Build Mac, 16 test RemoteCore e verifica del modello superati nel workspace e
  da una copia estratta dell’archivio sorgenti, senza build WDA o configurazione
  personale del workspace originale. Anche i sei test Python passano nella copia.
- Archivio sorgenti e manifest SHA-256 creati da un tree Git dell’indice. I file
  estratti sono stati confrontati con gli hash del manifest e i permessi degli
  script sono conservati. Non sono inclusi runner, profili, account o log locali.
- YAML delle workflow verificato localmente; le action sono fissate a SHA letti
  dai repository ufficiali. L’esecuzione remota della CI resta da confermare al
  primo push. Non vengono dichiarati commit, upload o release remoti già eseguiti.
- Documenti storici originali conservati soltanto nella cartella locale ignorata;
  l’app personale già installata e la sua configurazione non sono state modificate.


## 0.5.0 — pillole di navigazione

- Build Debug e Release completate; app personale 0.5.0 installata e riaperta.
  Dopo il riavvio, lo stato WDA riporta disponibilità e sessione attiva.
- Tre test aggiuntivi di layout: allineamento sopra le zone della barra di stato,
  area centrale libera, pillole sottili dentro il video aspect-fit a diverse scale
  e assenza di controlli quando manca geometria video. Totale: 19 test RemoteCore.
- Verifica AppKit aggiuntiva: clic singolo differito; doppio clic senza Home;
  seconda pressione tenuta premuta che cancella Home; annullamento; attivazione
  immediata dei comandi superiori; hit testing nativo e accessibilità disabilitata
  insieme al controllo. I callback sono simulati e non toccano il telefono.
- Anteprima SwiftUI ispezionata con una barra di stato sintetica, senza contenuti
  personali. Non viene dichiarato un rilevamento delle icone reali di iOS.
- Non è implementata un’autenticazione Face ID tramite Touch ID Mac: la
  documentazione Apple sul companion riguarda un’integrazione iPhone Mirroring
  delle app coinvolte, distinta dal controllo USB/WDA.

## 0.5.1 — ascolto audio USB

- Build Debug e Release e 19 test RemoteCore superati. Versione personale
  installata e riaperta.
- Su iPhone 14 Pro collegato via USB, una prova AVFoundation ha ricevuto
  campioni audio e fotogrammi video insieme, con l’uscita di anteprima audio
  attiva. La prova ha contato i campioni senza salvarli né riprodurli.
- La prova d’uso ha confermato l’ascolto di VoiceOver tramite iPhone Remote e
  la visibilità del rettangolo di selezione su un tastierino nascosto. Il
  rettangolo viene disegnato da iOS e le cifre restano nascoste. Non è stata
  verificata la compatibilità con ogni schermata di autenticazione.
