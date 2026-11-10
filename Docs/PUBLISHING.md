# Pubblicare i sorgenti su GitHub

La preparazione crea un repository locale e un archivio dei soli sorgenti.
Non crea automaticamente un repository remoto, non carica dati su GitHub e non
pubblica l’app installata in Applicazioni.

## Contenuto pubblico

Codice Swift, progetto Xcode, script generici, test, documentazione, icona originale,
licenza MIT e attribuzioni delle dipendenze. Sono esclusi `build/`, `.build/`,
`Research/`, `.local/`, profili, certificati, pacchetti app, registrazioni e log.
Il bootstrap scarica WDA al commit fissato quando l’utente prepara il proprio runner.

La configurazione privata va in `.local/development.env`; l’esempio pubblico è
`Config/Local.env.example`. Ogni utente firma il runner per il proprio dispositivo.
Il repository non contiene una credenziale o un runner universale.

## Revisione locale

```sh
git status --short
git diff --cached --stat
python3 -m unittest discover -s Tests/Publication -v
python3 Scripts/publication_audit.py --report build/logs/publication-audit.json
Scripts/verify.sh
```

L’audit ispeziona l’indice Git, non solo la working tree. Dopo una modifica,
rivedila e aggiungila di nuovo con `git add` prima di ripetere l’audit.
Non aggirare `.gitignore` con `git add -f` per includere build o dati personali.
Il diff completo e le immagini in Assets richiedono comunque revisione manuale.

La licenza scelta per il codice originale è MIT; il titolare può cambiarla prima
della prima pubblicazione. I testi delle dipendenze non vanno rietichettati o rimossi.

## Archivio sorgenti

```sh
python3 Scripts/prepare-source-release.py
```

Genera `build/releases/iPhoneRemote-0.5.1-source.zip` e un manifest con hash SHA-256
dei file e dell’archivio. L’esportazione usa esattamente il tree dell’indice Git:
non include modifiche non staged, cronologia, account o prodotti locali.
Lo script rifiuta l’esportazione se l’audit fallisce.

I sorgenti estratti devono compilare senza il workspace originale. Per l’app Mac:

```sh
Scripts/verify.sh
```

La configurazione del runner personale è un’operazione distinta, documentata nel
README. L’archivio è codice sorgente, non un’app pronta da avviare.

## Primo commit e pubblicazione

Prima del commit, controlla il nome e l’email autore che Git utilizzerà. Per
proteggere l’email personale puoi configurare l’indirizzo noreply mostrato nelle
impostazioni GitHub del tuo account; non inventarne uno. La preparazione non cambia
la tua identità Git e non crea un commit a tuo nome automaticamente.

Dopo aver verificato identità e contenuto:

```sh
git commit -m "Prepare iPhone Remote source preview"
```

Scegli nome e visibilità del repository. Puoi crearlo con l’interfaccia GitHub,
poi seguire i comandi proposti da GitHub per collegare e inviare il repository
esistente. Non inizializzarlo con un secondo README/licenza se vuoi evitare una
cronologia iniziale separata.

In alternativa, se hai già autenticato GitHub CLI e hai scelto un repository pubblico:

```sh
gh repo create iPhoneRemote --public --source=. --remote=origin --push
```

Questo ultimo comando **pubblica**: non fa parte della preparazione automatica.
Per un repository privato scegli `--private`. Verifica il destinatario se
l’account CLI appartiene a un’organizzazione o usi più account.

## Dopo il primo push

1. Controlla il risultato di GitHub Actions; la CI predisposta non è dichiarata
   già eseguita finché non gira su GitHub.
2. Abilita private vulnerability reporting e le protezioni del branch desiderate.
3. Rivedi README, licenza e file visibili dal sito come visitatore.
4. Una release può contenere l’archivio sorgenti e il suo manifest. Non allegare
   la tua app personale, i prodotti WDA firmati, i log o i profili.

La CI ha permesso `contents: read`, action fissate a SHA e nessun accesso al tuo
Apple Account. Non firma runner iOS e non pubblica automaticamente release.
I log trattenuti dagli artefatti CI provengono dalla macchina GitHub, non da prove
sul tuo telefono. Non caricare evidenze hardware personali nella workflow.

## Eventuale distribuzione binaria futura

Servono installazione/configurazione iniziale per utenti diversi, verifica delle
licenze dei componenti inclusi, strategia di firma e aggiornamento. Un normale
pacchetto Mac scaricabile può richiedere Developer ID, Hardened Runtime e
notarizzazione per l’esperienza di distribuzione desiderata. Il runner iOS resta
personale; il progetto non è automaticamente compatibile con Mac App Store.
Questa preparazione riguarda la pubblicazione dei sorgenti.
