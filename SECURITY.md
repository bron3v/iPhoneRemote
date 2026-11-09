# Sicurezza e trattamento locale dei dati

## Modello di fiducia

Questa app richiede un iPhone di cui hai il controllo, il suo sblocco e le
approvazioni previste da iOS. WDA è un runner di sviluppo che utilizza API private
XCTest; non aggira Developer Mode, fiducia, provisioning o autenticazione.
La guida del tastierino è solo un disegno manuale: non rivela i tasti protetti,
non verifica un codice e non certifica l’allineamento.

Il client Mac e il tunnel iproxy usano `127.0.0.1:8100` e selezionano USB/UDID
esplicitamente. Questo limita il listener sul Mac, **non garantisce da solo che
il server WDA sul telefono sia limitato al loopback**. Il runner conserva il
comportamento upstream e può ascoltare sulle interfacce del dispositivo.
Non esporre WDA con port forwarding o usarlo come servizio remoto pubblico.
Non è un servizio di controllo autenticato per reti non fidate.

Non vengono aggiunti daemon, login item o modifiche globali a xcode-select.
L’app termina i processi che avvia, non quelli di altri strumenti. Se il processo
Mac viene terminato forzatamente, può essere necessario chiudere helper rimasti
attivi. La chiusura normale finalizza le registrazioni e arresta gli helper propri.

## Dati

- Video e comandi passano localmente; non c’è telemetria o backend applicativo.
- Screenshot e video vengono salvati solo su richiesta, nella cartella scelta.
- Il testo non confermato resta in memoria e può essere copiato esplicitamente.
- Il pacchetto personale contiene identificativo del dispositivo, Team e profilo;
  non è l’archivio sorgenti da condividere.
- Firma e rinnovo possono contattare Apple; il bootstrap scarica WDA da GitHub.
- I log Xcode e le diagnostiche possono contenere identità, UDID, percorsi o
  altri dati personali. Non allegarli integralmente alle issue.

## Segnalare problemi

Non pubblicare chiavi, token, profili, Apple Account, codici o contenuto del
telefono in un’issue. Se il repository abilita la segnalazione privata di
vulnerabilità di GitHub, usa quel canale. Se non è disponibile, apri una richiesta
neutra per concordare un canale privato, senza dettagli sfruttabili o dati sensibili.
La segnalazione privata va abilitata dal titolare dopo la creazione del repository;
non viene dichiarata già attiva.

Prima di pubblicare esegui `python3 Scripts/publication_audit.py` sui file staged
e rivedi il diff. Il controllo rileva alcuni pattern e file rischiosi, ma non
sostituisce una revisione. Se una credenziale è stata esposta, revocala: eliminarla
soltanto dall’ultima versione non la rimuove dalla cronologia di Git.
