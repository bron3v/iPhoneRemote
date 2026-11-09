# Contribuire

Il progetto è un’anteprima per sviluppo locale. Prima di proporre modifiche, leggi
README.md, SECURITY.md e Docs/TECHNICAL-ANALYSIS.md.

## Ambiente

Serve un Mac con Xcode completo, Git e Python 3. Il target Mac non ha dipendenze
Swift Package esterne. Per i soli test simulati non servono iPhone né Apple Account.
WDA viene scaricato separatamente da `Scripts/bootstrap-wda.sh` al commit fissato.

```sh
Scripts/verify.sh
python3 -m unittest discover -s Tests/Publication -v
```

Su un Mac con sessione desktop puoi inoltre eseguire `Scripts/verify-experience.sh`.
Le prove hardware sono distinte: descrivi modello, versioni e comportamento
osservato senza pubblicare identificativi o contenuti personali.

## Modifiche

- Mantieni il Mac su API pubbliche; dichiara esplicitamente la dipendenza privata XCTest di WDA.
- Non aggiungere disabilitazione SIP, aggiramenti di codici o false conferme di successo.
- Evita replay automatici di azioni dal risultato incerto e mantieni i limiti della coda.
- I test per testo/chat devono usare risposte simulate; non inviare messaggi reali a terzi.
- Aggiungi verifiche utili per modifiche di comportamento, distinguendole dai test hardware.
- Se aggiungi file Swift, esegui `python3 Scripts/generate-project.py` e includi il progetto aggiornato.
- Se aggiorni WDA, verifica il commit, le API usate, il provisioning e le licenze di tutti i file interessati.
- Non aggiungere runner compilati, profili, schermate personali o configurazioni locali.

Per una pull request descrivi problema, risultato, verifiche eseguite e limiti.
Non presentare come collaudata una configurazione che hai soltanto compilato.

## Licenza dei contributi

I contributi originali vengono proposti sotto la licenza MIT del progetto.
Indica provenienza e licenza di qualsiasi materiale esterno; non ricopiare codice
senza diritti o attribuzioni. Le dipendenze mantengono le loro condizioni.
