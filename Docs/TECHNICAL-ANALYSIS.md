# Architettura e decisioni tecniche

## Separazione dei componenti

Il target macOS SwiftUI usa API pubbliche. `CaptureService` scopre sorgenti schermo
USB con la proprietà CoreMediaIO `kCMIOHardwarePropertyAllowScreenCaptureDevices`
e AVFoundation. Le sorgenti Continuity Camera sono escluse. La presenza di frame
reali determina disponibilità e frequenza, non il semplice avvio di una sessione.
QuickTime non fornisce il flusso dell’app.

`AVCaptureVideoPreviewLayer` mostra il video senza ricodifica. I campioni della
stessa acquisizione alimentano `CaptureArchive` per PNG e MOV locali. La coda di
acquisizione serializza lo stato del writer; i file vengono finalizzati prima
della chiusura. La registrazione è limitata a 30 fps e si ferma alla rotazione.

`DeviceMonitor` controlla il bus USB con IOKit: un dispositivo accoppiato disponibile
solo via rete non è considerato un iPhone USB. Il video usa pixel fisici, WDA punti
iOS. `ScreenGeometry` applica aspect-fit e rifiuta clic nelle bande nere.
L’app ammette un solo iPhone; la correlazione completa tra identità video e runner
non è certificata per scenari multi-dispositivo.

`WDAClient` comunica esclusivamente con `http://127.0.0.1:8100`. iproxy seleziona
esplicitamente l’UDID e il trasporto USB. Il runner sul dispositivo conserva il
comportamento di rete upstream: vedi SECURITY.md.

## WebDriverAgent e licenze

Dipendenza fissata al commit `3d6a4e03cdd673e540289c610f7e189f8ffea434` di
[Appium/WebDriverAgent](https://github.com/appium/WebDriverAgent), package 16.15.3.
Il bootstrap non segue automaticamente master. Il progetto Xcode viene compilato
senza richiedere il server Appium/npm per il percorso usato qui.

WDA utilizza header e simboli privati XCTest. Questo è un requisito dichiarato del
runner di sviluppo, non un’API pubblica di controllo generale dell’iPhone.
Il Mac non aggiunge API private proprie. La preparazione pubblica non trasforma
questa architettura in una candidata automaticamente compatibile con Mac App Store.

Upstream contiene BSD e file con header Apache-2.0, con metadati non uniformi:
THIRD_PARTY_NOTICES.md conserva i riferimenti senza rietichettare tutta la dipendenza.
DimCyan/iOS-remote è stato consultato come confronto architetturale, senza copiarne
codice GPL. `Research/` e i prodotti WDA non fanno parte dei sorgenti pubblicati.

## Input e ciclo di vita

Le pillole native intercettano i clic senza passarli al video sottostante. La
pillola Home distingue singolo e doppio clic con annullamento su disabilitazione
e perdita del focus.

Tocchi, swipe e pressioni usano W3C pointer actions. Home utilizza
`wda/pressButton` con `home`; app aperte usa il trascinamento nativo XCTest dal
bordo inferiore, che nella prova fisica ha funzionato dove lo swipe W3C non apriva
il selettore. I pannelli di sistema usano swipe dal bordo superiore.

`RemoteModel` mantiene ordine e limiti della coda; errori, interruzioni e task
obsoleti non causano replay. Il testo non confermato rimane locale in memoria.
La riconnessione rispetta lo scollegamento volontario e può essere disattivata.
Le attese idle/animazioni WDA sono impostate a zero; la geometria è memorizzata
tra gesti a orientamento stabile.

La vista implementa `NSTextInputClient`: composizione locale e commit del testo.
Invio verifica un’app chat conosciuta e un unico pulsante Invia visibile e abilitato;
un cambio app prima del clic annulla il tentativo. Non è un’implementazione
universale di tastiera hardware né di invio nelle chat.

La guida numerica disegna una griglia normalizzata, non osserva i tasti protetti,
non invia cifre e sospende l’input. Le sue coordinate non sono state calibrate
sulle schermate nascoste del dispositivo.

`LocalAutomation` legge una configurazione privata presente solo nel pacchetto
personale. Gestisce i processi che avvia, preserva le firme del bundle lavorando su
una copia del runner in Application Support e legge la scadenza del provisioning.
Il rinnovo usa Xcode e i servizi Apple, senza memorizzare credenziali nel repository.

## Alternative e limiti

ScreenCaptureKit della finestra QuickTime, ReplayKit e MJPEG WDA non sono fallback
implementati. Non viene dichiarato un flusso funzionante quando quello USB manca.
Il progetto non disabilita SIP, non usa jailbreak e non aggira autorizzazioni,
codici o superfici protette. Vedi VERIFICATION.md per le prove realmente eseguite.
