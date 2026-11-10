# Changelog

## 0.5.1

- Riproduzione facoltativa dell’audio della sorgente USB sul Mac, con volume nella
  barra degli strumenti. Le registrazioni restano senza audio.
- Guida a VoiceOver per display guasti: il rettangolo di selezione di iOS può
  restare visibile nel video USB anche quando le cifre del tastierino sono nascoste.

## 0.5.0

- Pillole sottili traslucide sopra orario e indicatori di rete/batteria.
- Un solo comando inferiore centrato: clic singolo Home, doppio clic app aperte.
- Distinzione dei clic secondo l’intervallo macOS, con annullamento di Home alla
  seconda pressione, perdita del focus o disabilitazione del controllo.
- Scala e opacità dei comandi conservano le preferenze precedenti.
- Test di layout e interazione nativa; nessuna sostituzione Face ID/Touch ID implementata.

## 0.4.1 — Anteprima dei sorgenti

Prima versione preparata per pubblicazione come sorgenti. Non implica una release
binaria universale, notarizzata o approvata per App Store.

- Video USB nativo e controllo attraverso runner WDA firmato dall’utente.
- Gestione clic, swipe, pressione lunga, rotella, digitazione e composizione macOS.
- Navigazione Home, app aperte, notifiche e Centro di Controllo.
- Invio prudente nelle chat supportate, con ⇧Invio per andare a capo.
- Modalità compatta, primo piano, geometria salvata e scorciatoie personalizzabili.
- Screenshot PNG e video MOV H.264 senza audio, finalizzazione su interruzione.
- Riconnessione con backoff e nessun replay automatico di input dall’esito incerto.
- Avvisi per overflow, conservazione locale del testo non confermato e scadenza firma.
- Guida numerica indicativa regolabile che sospende l’input remoto.
- MIT per il codice originale, attribuzioni BSD/Apache per WDA, guide, CI e audit
  dell’archivio sorgenti. Configurazioni e build personali restano escluse.

Il controllo resta dipendente da Xcode, provisioning e limiti di iOS/XCTest.
La guida numerica non è una calibrazione del tastierino protetto.
