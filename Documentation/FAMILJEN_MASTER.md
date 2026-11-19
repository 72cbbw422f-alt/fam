# FAMILJEN — Masterdokumentation

> Samlad projektöversikt för produktbeslut, aktuell kodstatus, verifiering och nästa steg.
> Senast sammanställd: 2026-11-19.
> Dokumentet kompletterar `DEVELOPMENT_LOG.md` (detaljerad ändringslogg), `ROADMAP.md` (prioriterad plan), `ARCHITECTURE.md` (teknisk struktur) och testplanen.

## 1. Projektets mål

Familjen är en native iOS-app för Niklas och Villemo med fokus på att samla familjens kalender, bokningar, födelsedagar, hälsorelaterade tider och inköpsplanering i ett lugnt, lättanvänt gränssnitt.

### Produktprinciper
- Scandinavian Premium möter Modern iOS.
- Behåll den befintliga visuella identiteten: varm ljus/paper-bas, champagne/sand, marinblått, rundade kort och tydliga kategorisymboler.
- Prioritera läsbarhet, snabb överblick och få tryck.
- Barn ska kunna representeras med profiler utan egna inloggningskonton.
- Skilj tydligt på vem en aktivitet gäller och vem som ansvarar för den.
- Importerade uppgifter ska granskas och godkännas innan de sparas.
- Visa tydligt när information bara finns lokalt på en enhet.
- Inga hushållssysslor eller generella att-göra-listor.

## 2. Historiska och aktuella produktbeslut

### Ursprunglig teknisk riktning
Tidigt diskuterades Sign in with Apple, inbjudan av Villemo med kod, Supabase som första backend och en senare övergång till iCloud/CloudKit.

### Nuvarande beta-riktning
Den aktiva utvecklingsgrenen `local-first-beta` är medvetet omarbetad till en local-first-app:
- Ingen inloggning eller backend i denna beta.
- Ingen gemensam synkronisering mellan två telefoner.
- Familjeuppgifter sparas lokalt på respektive iPhone.
- Repository-abstraktionen ska göra ett framtida byte till CloudKit möjligt utan att SwiftUI-vyerna behöver skrivas om.
- CloudKit/CKShare och säker migrering är framtida arbete och ska inte påbörjas utan ett uttryckligt produktbeslut.

Detta är en viktig skillnad mot den äldre `main`-grenen. Utgå från local-first-betan för fortsatt utveckling, men slå inte ihop PR:n eller ändra standardgren utan beslut.

## 3. Design och användarupplevelse

### Fastslaget
- Scandinavian Premium / Modern iOS.
- Champagne, sand, marinblått och varm ljus bakgrund.
- Befintliga kategorispecifika ikoner och färger ska behållas konsekventa.
- Förbättra hierarkin mellan rubrik, aktivitet, datum/tid, plats, berörda personer och ansvarig.
- Startsidan ska fungera som en familjeöversikt, inte bara som en meny.
- Kalendern ska ha tydliga datumgrupper, antal aktiviteter per dag och markeringar för dagar med innehåll.
- Hälsa, födelsedagar och inköpslista ska vara användbara egna områden, inte tomma skal.

### Startsida och säsong
- Startsidan har en datumstyrd säsongshero som ritas lokalt och fungerar offline.
- Scener finns för höst, vinter, vår, sommar, advent, Lucia och jul.
- Adventsljusen tänds stegvis under adventsveckorna.
- Lucia visas den 13 december; julscenen från 24 december till 6 januari.
- Användaren har efterfrågat ett mer fotografiskt/vinterbetonat säsongsuttryck. Granska hero-bildens uttryck, proportioner och placering på fysisk iPhone innan den betraktas som slutlig.

### Widgets
- Användaren har godkänt designriktningen för widgets i flera utföranden, inspirerade av en referensbild men anpassade till Familjens färger och formspråk.
- **Status: inte implementerade.** Den aktuella källkodsträdet innehåller ingen Widget Extension eller widget-relaterade filer.
- Nästa widgetarbete ska omfatta lämpliga små/medelstora/stora format, med dagens och närmaste familjehändelser, och kräver separat teknisk implementation och testning.

## 4. Aktuell funktionalitet i local-first-beta

Statusen nedan avser vad som finns i källkoden. Den ska inte förväxlas med full fysisk enhetsverifiering.

| Område | Nuvarande innehåll | Status / begränsning |
|---|---|---|
| Onboarding | Skapa familj och ägarprofil lokalt | Implementerat |
| Familjeprofiler | Vuxna och barn, redigering, borttagning, valbar profilikon | Implementerat; barn behöver inte konto |
| Dashboard | Familjeöversikt, idag/imorgon, kommande tider/händelser, genvägar och profilrad | Implementerat; fortsatt visuell förfining önskas |
| Kalender | Skapa, visa, redigera och radera bokningar, vårdbesök, tandläkartider, födelsedagar och händelser | Implementerat |
| Kalenderdeltagare | En eller flera berörda personer, Hela familjen, separat ansvarig vuxen och personfilter | Implementerat i aktuell gren |
| Återkommande händelser | Årlig återkomst, födelsedagsprojektion, 29 februari hanteras som 28 februari under icke-skottår | Implementerat; veckovis/månadsvis återkomst saknas |
| Plats | Separat valfritt plats-/adressfält för kalenderhändelser | Implementerat |
| Kalenderlayout | Månadsöversikt, svenska ISO-veckonummer, datumgrupper och aktivitetsmarkeringar | Implementerat; scroll/tryck behöver fortsatt enhetskontroll |
| Hälsa | Egen vy med kommande vård- och tandläkarbesök, medicinposter och historik | Implementerat som kalenderöversikt; inte journal, läkemedelslista eller doseringsstöd |
| Födelsedagar | Egen födelsedagsvy med nästa födelsedag och kronologisk lista | Implementerat |
| Presentidéer | Personlig presentlista kopplad till familjemedlem och födelsedag; lägga till, redigera, radera och markera ordnad | Implementerat, lokal lagring |
| Julklappslista | Mottagare, present, anteckning, ansvarig familjemedlem och status | Implementerat, lokal lagring |
| Inköpslista | Lägga till, bocka av och radera varor; dashboardgenväg | Implementerat, lokal lagring |
| Meddelanden | Familjechatt och privata konversationsvyer | Lokal prototyp; skickas inte till andra telefoner |
| Notiscenter i appen | Lokala notisposter och lässtatus | Implementerat, lokal lagring |
| Kalenderpåminnelser | Lokala iOS-notiser per aktivitet; en vecka, en dag, en timme, 15 minuter eller vid start | Implementerat på enheten; inte push eller familjedelning |
| Notisbehörighet | Fråga första gången appen startas; central inställning för att slå på/av lokala påminnelser | Implementerat i senaste commit |
| Standardpåminnelser | Val av förval för nya kalenderaktiviteter | Implementerat |
| OCR | Lokal textavläsning av bokningsskärmbilder med svensk datum-/tidsigenkänning | OCR-motor implementerad; fullständigt gransknings- och importflöde ska fortsätta verifieras |
| Apple Kalender/EventKit | Tidigare importfunktion har tagits bort helt i commit `d0f755a` | Inte del av aktuell beta |
| CloudKit / synk | Ingen molnlagring, familjedelning eller synk | Inte implementerat |
| Remote push | Ingen APNs-leverans när appen är stängd eller i bakgrunden | Inte implementerat |
| iOS-hemskärmswidgets | Godkänd designriktning | Inte implementerat |

## 5. Teknisk arkitektur

- Plattform: iOS 17 eller senare.
- UI: SwiftUI.
- Språk: Swift.
- Projektgenerering: XcodeGen (`project.yml`).
- Bundle identifier: `se.familjen.app`.
- Aktiv datalagring: lokal JSON-snapshot i Application Support.
- `FamilyRepository`: protokoll som isolerar UI från lagringsprovider.
- `LocalFamilyStore`: aktuell lokal repository-implementation.
- `FamilyStore`: observerbar UI-fasad som exponerar snapshots till SwiftUI.
- ViewModels för dashboard, kalender, inköpslista och notiser arbetar mot repository-kontraktet.
- Lokal persistens har validering, korruptionsskydd och synliga skrivfel.
- Kalenderändringar har särskilda återställningsflöden vid misslyckad persistens.
- Lokal OCR sker på enheten; källbilder laddas inte upp i denna beta.
- Notiser använder iOS UserNotifications lokalt.

### Viktig data- och integritetsbegränsning
Varje telefon har en egen, separat datamängd. En ändring som görs på Niklas telefon visas inte automatiskt på Villemos telefon. Inköpslistor, presentlistor, julklappar och meddelanden är också lokala. Gränssnittet ska fortsätta vara tydligt med detta tills en verklig delningslösning är byggd och testad.

## 6. Repository och versionsstatus per 2026-11-19

- Repository: https://github.com/72cbbw422f-alt/fam
- Aktiv utvecklingsgren: `local-first-beta`
- Senaste commit: `35eb2f47a5956ef11def4339ea70d3decbc140d5`
- Commitmeddelande: `Centralize notification permission and settings`
- Senaste commit: 2026-11-19 07:01 UTC.
- `main`: `5df9062264d6ac349694012cb57b866b71b63da6`
- Jämförelse: `local-first-beta` är 406 commits före `main` och 0 commits bakom.
- Pull request #1, “Convert Familjen to local-first iOS beta”, är öppen som draft och mergeable.
- PR:n ska inte mergeas och standardgrenen ska inte ändras utan uttryckligt beslut.
- Skillnaden mellan grenarna är avsiktlig: `main` innehåller den äldre Supabase-/inloggningsarkitekturen, medan `local-first-beta` har lokal lagring och har tagit bort Supabase, Sign in with Apple och EventKit från aktuell app.

## 7. Verifiering och byggstatus

### Senaste CI – 19 november 2026
Workflow: https://github.com/72cbbw422f-alt/fam/actions/runs/44476491795

- Run: `44476491795` (run number 470).
- Commit: `35eb2f47a5956ef11def4339ea70d3decbc140d5`.
- Simulatorjobb: lyckades.
- iPhone Release/device-target build: lyckades.
- Enhetstester: **53 tester, 0 fel**.
  - LocalFamilyStoreTests: 42.
  - LocalReminderSchedulerTests: 6.
  - OccurrenceOverrideRestorationTests: 2.
  - OccurrenceOverrideTests: 3.
- Unsigned IPA skapades och laddades upp som artefakt `Familjen-unsigned-IPA`.
- Artifact ID: `14507290543`.
- IPA-arkivets uppladdade ZIP-storlek: cirka 2,2 MB.
- IPA:n är **osignerad**. CI-resultatet bevisar kompilering, automatiserade tester och paketering – inte installation eller full runtime-verifiering på fysisk iPhone.

### Tidigare verifiering på fysisk iPhone
Utvecklingsloggen från 18 november anger att följande kontroller fungerade på fysisk iPhone:
- Lokala kalenderpåminnelser.
- Redigering och borttagning av familjeprofiler.
- Avbockning av inköpsvaror så att de försvinner från den aktiva listan.

Detta är ett avgränsat manuellt test, inte en fullständig regressionstestning av appen.

### Distribution
- Användaren saknar för närvarande Mac och Apple Developer-konto.
- CI bygger därför en unsigned IPA som kan hanteras vidare med användarens FlareStore-signerings-/sidladdningsflöde.
- Unsigned IPA får aldrig beskrivas som signerad eller distributionsklar.
- TestFlight och normal Apple-distribution kräver senare rätt Apple-konto och signeringskonfiguration.

## 8. Kända begränsningar och öppna risker

1. **Ingen familjesynk:** den största produktbegränsningen. Appen är ännu inte ett gemensamt datarum mellan två iPhones.
2. **Ingen CloudKit-delning:** CKShare, behörigheter, konflikthantering och migrering saknas.
3. **Ingen remote push:** lokala påminnelser fungerar på respektive enhet, men ingen APNs-notis skickas till den andra familjemedlemmen.
4. **Ingen widget-extension:** widgetdesignen är godkänd men saknas i källkodsträdet.
5. **Kalenderåterkomst:** årlig återkomst finns; veckovis/månadsvis och redigering av en enskild förekomst kontra hela serien behöver utökas.
6. **Kalenderinteraktion:** tryck på aktivitet ska visa en ren detaljvy; långtryck ska erbjuda Redigera/Radera. Detta finns i test-/önskelistan och måste verifieras mot aktuell kod och fysisk enhet.
7. **OCR-import:** extraherat innehåll måste presenteras som förslag, kunna granskas/redigeras och kräva uttrycklig bekräftelse före kalenderpost skapas.
8. **Hälsa:** nuvarande medicinposter är kalenderposter. Bygg inte doseringsschema eller läkemedelspåminnelser utan separat, tydlig kravspecifikation.
9. **Persistensfel:** lokala skrivfel visas och vissa kalenderoperationer återställs transaktionellt. Kontrollera att alla andra mutationer hanterar skrivfel konsekvent.
10. **Enhetstestning:** fullständig fysisk testmatris för layout, Dynamic Type, VoiceOver, notisbehörighet, kalendergest, persistens och återstart återstår.

## 9. Prioriterad fortsättningsplan

### P0 – Stabil grund och testbar version
- Behåll `local-first-beta` som arbetsgren.
- Kontrollera att senaste IPA:n går att signera/sidladda med FlareStore och installera på fysisk iPhone.
- Kör en strukturerad iPhone-genomgång av onboarding, dashboard, kalender, profiler, hälsa, födelsedagar, presentidéer, julklappslista, inköpslista, inställningar och lokala notiser.
- Verifiera att data överlever tvångsavslut och omstart.
- Bekräfta att första notisfrågan visas en gång och att inställningen kan ändras senare.
- Kontrollera att inga vyer antyder synkronisering eller delning som inte finns.

### P1 – Kalender och startsida
- Slutför kalenderdetaljvy och långtrycksmeny.
- Verifiera månadskalenderns tryck/scroll-gest på iPhone.
- Förfina dashboardens läsbarhet och informationshierarki utan att göra om den visuella identiteten.
- Granska och förbättra vinter-/säsongsheron utifrån användarens önskemål.

### P2 – Widgets
- Implementera en riktig Widget Extension.
- Börja med dagens och nästa familjehändelser.
- Skapa flera storlekar/utföranden i Familjens etablerade formspråk.
- Bestäm hur widgeten får uppdaterade data från den lokala lagringen och testa timeline-refresh.

### P3 – Gemensam familjeupplevelse
- Ta fram separat teknisk och produktmässig plan för CloudKit private/shared databases och CKShare.
- Definiera inbjudan av Villemo, medlemsroller, behörigheter och konflikthantering.
- Designa säker migrering från lokal JSON till CloudKit utan dataförlust.
- Först därefter implementera delade inköpslistor, meddelanden och remote push.
- CloudKit-arbetet startar först efter uttryckligt beslut.

## 10. Arbetsregler för fortsatt utveckling

- Kontrollera aktuell branch, commit och fil-SHA innan ändring.
- Gör inga ändringar direkt på `main` om inte det uttryckligen beslutats.
- Ändra inte arkitektur från local-first utan ett dokumenterat beslut.
- Läs relevant roadmap, utvecklingslogg och testplan innan ny funktion byggs.
- En funktion är inte “klar” bara för att koden finns: ange separat implementation, CI, simulator, unsigned IPA och fysisk enhetstest.
- Räkna endast avslutade CI-körningar med lyckad status som godkänd verifiering.
- Dokumentera varje större ändring med datum, commit, testresultat och kvarstående risk.
- Skapa inte en ny IPA som fungerande leverans innan aktuell build och artefakt är kontrollerade.
- Bevara befintliga fungerande funktioner och användarens designbeslut.
- Om ett äldre beslut har ersatts, dokumentera både det historiska beslutet och den nuvarande riktningen.

## 11. Dokumentindex

- `README.md` – kort produktbeskrivning och aktuell beta-status.
- `Documentation/FAMILJEN_MASTER.md` – denna samlade projektöversikt.
- `Documentation/DEVELOPMENT_LOG.md` – detaljerad ändrings- och felhistorik.
- `Documentation/ROADMAP.md` – prioriteringar och funktionsplan.
- `Documentation/ARCHITECTURE.md` – teknisk arkitektur.
- `Documentation/LOCAL_FEATURE_TEST_PLAN.md` – testmatris för local-first.
- `Documentation/APPLE_PLATFORM_READINESS.md` – förberedelser för Apple-plattformens funktioner.
- `Documentation/FLARESTORE_SIGNING_PLAN.md` – signerings- och sidladdningsflöde.

---
**Status:** Sammanställd mot GitHub-källkod, branchhistorik, CI-run 470 och tillgänglig tidigare projektkontext den 19 november 2026. Gamla chattar kan innehålla ytterligare användarfeedback som ännu inte har verifierats mot denna masteröversikt.
