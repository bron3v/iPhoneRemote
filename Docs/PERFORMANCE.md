# Reattività

Nel campione locale sul dispositivo di riferimento, GET window/size ha richiesto
circa 243–318 ms. Il percorso iniziale lo eseguiva prima di ogni gesto. La versione
attuale memorizza la geometria e la aggiorna al cambio orientamento.

WDA viene configurato con waitForIdleTimeout e animationCoolOffTimeout a zero.
Il codice upstream attende altrimenti la stabilizzazione dopo alcune azioni:
sono limiti di attesa, non ritardi fissi garantiti per ciascun comando.

Lo swipe del mouse è riprodotto in 120–250 ms; la rotella genera swipe discreti
limitati e non accoda l’inerzia del trackpad. Il testo consecutivo viene raggruppato.
Le code hanno limiti e segnalano il rifiuto di un input; errori dall’esito incerto
non causano replay. Le impostazioni privilegiano l’interazione, non test UI basati
sulla quiescenza delle animazioni.

La sidebar mostra il tempo di esecuzione dell’ultimo comando. Non misura il
percorso completo mouse → XCTest → telefono → frame USB → display del Mac.
Non viene dichiarata una riduzione percentuale di questa latenza complessiva.
Il benchmark completo resta da eseguire su una schermata sicura e ripetibile.

Il video di anteprima usa AVCaptureVideoPreviewLayer senza ricodifica. La
registrazione H.264 è una funzione separata, fino a 30 fps; il suo impatto va
misurato sull’hardware e sulla risoluzione di interesse.

Auto-Lock va configurato nelle impostazioni dell’iPhone. L’app non genera tocchi
periodici per tenerlo sbloccato e non tenta di sbloccarlo dopo il tasto laterale.
