# Familjen – utvecklingslogg

> Levande arbetslogg för beslut, implementation, buggar, testresultat och kvarstående risker. Uppdateras i samma utvecklingsgren som koden. Datum anges enligt svensk tid.

## Projektstatus – 2026-11-16

- Repository: `72cbbw422f-alt/fam`
- Arbetsgren: `local-first-beta`
- Pull request: [#1 – Convert Familjen to local-first iOS beta](https://github.com/72cbbw422f-alt/fam/pull/1)
- PR-status vid senaste kontroll: öppen, draft.
- Senast verifierade commit: `2c533c79804337b06aca1d565f42b2c186e230b4`
- Jämförelse mot `main`: 147 commits före, 0 bakom vid senaste kontroll.
- CI: GitHub Actions-run `43920508546` var köad vid senaste kontroll. Simulatorjobbet och unsigned IPA-jobbet var båda `queued`. Inget godkänt bygge eller testresultat är verifierat.
- Fysisk iPhone-test: inte genomförd/verifierad.
- Tvåtelefonssynk: inte implementerad i local-first-betan. Varje enhet har separat lokal data.

## Produktmål och tekniska ramar

Familjen är en native SwiftUI-app med Scandinavian Premium / Modern iOS-uttryck i champagne, sand och marinblått. Kärnfunktionerna är familjekalender, bokningar, vårdbesök, födelsedagar, kommande händelser, delad inköpslista och familjemeddelanden.

- Inga hushållssysslor eller generella att-göra-listor.
- Barn kan ha profiler utan egna konton.
- Nuvarande beta använder lokal lagring på respektive enhet.
- Ingen fungerande gemensam familjesynk, CloudKit-delning eller kontobaserad inloggning i denna beta.
- Utvecklingsmiljö: användaren saknar Mac och Apple Developer-konto. CI och unsigned IPA är därför viktiga steg, men unsigned IPA är inte samma sak som signerad och verifierad app på fysisk iPhone.

## Arkitektur och genomförda delar

### Local-first-lagring
- `LocalFamilyStore` implementerar `FamilyRepository` och sparar familj, medlemmar, kalenderposter, inköpslista, notiser och meddelanden som JSON lokalt.
- Lagringsfilens URL kan injiceras för isolerade tester.
- Ogiltiga familje-/ägarnamn och barnprofiler valideras.
- Familj kan inte skapas om igen på ett sätt som ersätter befintliga data.
- Inköpsposter kan inte skapas utan en familj.
- Ägarprofilen kan inte byta namn eller raderas via medlemsoperationerna.
- Om JSON-snapshot är korrupt försöker appen bevara originalet som en `.corrupt-<UUID>`-fil. Om bevarandet misslyckas blockeras framtida skrivningar för att undvika att skriva över den enda återstående kopian.

### Repository-gräns och UI
- `FamilyRepository` definierar kontraktet mellan funktioner och lagringsprovider.
- `FamilyRepositoryFactory` väljer för närvarande `LocalFamilyStore`.
- `FamilyStore` fungerar som observerbar UI-fasad och exponerar snapshots till SwiftUI.
- Dashboard-, kalender-, inköpsliste- och notis-ViewModels använder repository-kontraktet.
- Familjeprofiler, meddelanden, inställningar, onboarding, app-root och dashboard har migrerats till fasaden.
- Detta gör framtida providerbyte lättare, men innebär inte att CloudKit redan finns.

### Kalender och påminnelser
- Kalenderposter kan skapas, redigeras och tas bort.
- Årliga födelsedagar projiceras till nästa förekomst.
- 29 februari visas den 28 februari under icke-skottår.
- Påminnelseval finns per aktivitet: en vecka, en dag, en timme, 15 minuter och vid start.
- Lokala iOS-notiser schemaläggs på enheten.
- Schemaläggaren väljer högst 60 framtida påminnelser, sorterade efter närmast tid.
- Apple Kalender kan läsas in via EventKit; importerade poster visas separat och ändras inte av Familjens redigeringar.
- OCR sker lokalt på enheten.

## Utvecklingshistorik

### 2026-11-16 – robusthet, bakåtkompatibilitet och tidszon

**Genomfört**
- Lade till regressionstest för äldre JSON-snapshot där fältet `messages` saknas. Förväntat beteende är att meddelandehistoriken blir tom och att filen fortfarande finns kvar.
- Ändrade födelsedagsprojektionen till att uttryckligen använda en gregoriansk kalender med enhetens lokala tidszon.
- Uppdaterade roadmap så att dessa kontroller finns dokumenterade.
- Commit `69597183aa9f20bc20d95157848c317b86cad804`: test för legacy-snapshot.
- Commit `2ff1cae97c76753bda8ddee3951e92d0048a3ca3`: lokal tidszon i födelsedagsprojektion.
- Commit `2c533c79804337b06aca1d565f42b2c186e230b4`: dokumentation/roadmap.

**Granskning och fynd**
- `Snapshot.messages` är optional och laddas med tom array om fältet saknas. Det ger bakåtkompatibilitet för äldre snapshot som saknar meddelanden.
- Födelsedagsprojektionen använder nu lokal tidszon. Kalendergränser och sommartidsövergångar bör fortfarande testas mer systematiskt.
- Påminnelseschemaläggaren rensar befintliga Familjen-notiser och lägger sedan in de 60 närmaste framtida kandidaterna.
- Påminnelse-ID byggs av aktivitetens UUID och offset. Två identiska offsets på samma aktivitet kan därför ge samma identifierare; indata bör normaliseras eller dedupliceras.
- Schemaläggningen tar bort befintliga notiser före nya notiser läggs till. Om ett eller flera nya tillägg misslyckas kan enheten tillfälligt få färre notiser än tidigare. Detta är ett förbättringsområde.
- Standardvärdet för poster där `reminderOffsets` är nil är 24 timmar och 1 timme. Detta behöver vara ett medvetet kompatibilitetsbeslut och testas mot äldre poster.
- Påminnelser är lokala till enheten och är inte pushnotiser eller familjesynk.

**CI-status**
- Run `43920508546` var `queued` vid senaste avläsning.
- Jobb: `Build Familjen (iOS Simulator)` och `Build unsigned IPA (iPhone)`, båda köade.
- Inga tester eller byggen markeras som godkända i denna logg förrän körningen har avslutats med verifierad status och relevanta loggar har granskats.

### Tidigare local-first-arbete – sammanfattning

- Native SwiftUI local-first-beta sattes upp med lokala familjeprofiler, kalender, inköpslista, meddelanden och notiser.
- Repository-abstraktion och UI-fasad infördes för att minska kopplingen till lokal lagring.
- CI-workflow byggdes ut med simulatorjobb och unsigned iPhone IPA-jobb.
- Testfall har lagts till för CRUD, persistens, validering, ägarskydd, upprepade onboardingförsök, födelsedagsprojektion, påminnelsepersistens, korrupt snapshot och observerbar fasad.
- CI har tidigare haft avbrutna körningar på grund av concurrency/cancel-in-progress. Det är en historisk orsak till att enskilda avbrutna körningar inte ska räknas som testfel eller godkända tester.
- Ett tidigare verktygsproblem gjorde att workflow-run-resultat för push-triggers inte alltid syntes via den använda commit-run-listningen. Därför kontrolleras run-ID och jobb separat när de finns tillgängliga.

## Kända buggar, risker och öppna frågor

| ID | Område | Fynd / risk | Status / nästa åtgärd |
|---|---|---|---|
| FAM-001 | CI | Tidigare körningar har avbrutits av concurrency-inställningen. | Öppen: verifiera aktuell körning och justera endast om problemet återkommer. |
| FAM-002 | CI-rapportering | Connectorns commit-run-listning har inte alltid visat push-triggade körningar. | Känd begränsning i rapportvägen: använd run-ID/jobs när det finns. |
| FAM-003 | Påminnelser | Dubblett-offsets kunde skapa samma notis-ID. | Åtgärdad i kod: offsets dedupliceras per aktivitet; enhetstester tillagda. CI-verifiering återstår. |
| FAM-004 | Påminnelser | Tidigare togs gamla notiser bort före nya tillägg. | Förbättrad i kod: nya/uppdaterade notiser läggs till först; därefter tas bara inaktuella ID:n bort. CI-verifiering återstår. |
| FAM-005 | Påminnelser | Högst 60 framtida notiser schemaläggs. | Begränsningen kvarstår; kandidatfunktionen sorterar och testar urvalet av de 60 närmaste. UI-kommunikation kan förbättras senare. |
| FAM-006 | Påminnelser | Nil-offsets ger standardpåminnelser 24 h och 1 h. | Test tillagt för fallbacken; CI-verifiering återstår. |
| FAM-007 | Tidszon | Födelsedagsprojektion har lokal tidszon, men gränsfall vid sommartid är inte fullständigt testade. | Öppen: lägg till tester för datum/tid nära DST-skiften och midnatt. |
| FAM-008 | Familjedata | Varje telefon har separat lokal databas. | Känd produktbegränsning: CloudKit/CKShare krävs för gemensam data. |
| FAM-009 | Enhetskvalitet | Ingen verifierad fysisk iPhone-test ännu. | Öppen: testa installation, persistens, notisbehörighet och notisleverans på enheten. |
| FAM-010 | Signering | Unsigned IPA är inte direkt likvärdig med signerad distributionsklar app. | Känd begränsning: signera och testa via tillgänglig sideload-process; Apple Developer senare. |


### 2026-11-16 – korrigering av legacy-snapshot-test

**Fynd**
- Vid kodgranskning upptäcktes att testet för äldre snapshot hade två omvända snedstreck före UUID-uttrycket i den temporära katalognamnet. Swift interpolerade därför inte UUID:t. Flera testkörningar kunde använda samma katalog och påverka varandra.

**Åtgärd**
- Korrigerade strängen till riktig Swift-interpolering så varje test får en unik temporär katalog.
- Fil: `Tests/LocalFamilyStoreTests.swift`
- Commit: `6d826dc3e2c864e32eb5bf7fb3e83cbaa21077fa`

**Verifiering**
- Källtexten är korrigerad och uppdaterad på `local-first-beta`.
- CI behöver köras på den nya committen innan testet kan markeras som godkänt.


### 2026-11-16 – robustare lokal påminnelseschemaläggning

**Ändringar**
- Bröt ut kandidatgenereringen till en ren, deterministisk funktion som kan enhetstestas utan iOS-notiscenter.
- Dubblett-offsets dedupliceras per aktivitet.
- Negativa offsets och påminnelser som redan har passerat filtreras bort.
- Kandidater sorteras med stabil ordning och begränsas till de 60 närmaste.
- Nil-offsets behåller den befintliga kompatibilitetsfallbacken på 24 timmar och 1 timme.
- Schemaläggaren lägger nu till/uppdaterar önskade notiser innan inaktuella tas bort. Om ett tillägg misslyckas tas en befintlig notis med samma ID inte bort.
- Filer: `Sources/LocalReminderScheduler.swift`, `Tests/LocalReminderSchedulerTests.swift`.
- Commit `a0562f087eaeaeb035a88975128f5fda598fd91f`: schemaläggare.
- Commit `f9f799d20a0892a20c812ec2bfe64e6f289bcdf3`: fyra enhetstester.

**Tester tillagda**
- Dubblett-offsets ger en kandidat per offset.
- Tidigare tidpunkter och negativa offsets filtreras bort.
- Nil-offsets använder fallbackvärdena.
- Endast de 60 närmaste kandidaterna väljs.

**Verifiering**
- Källkod och tester är incheckade.
- Testerna är ännu inte verifierade i CI; bygg- och testresultat rapporteras separat när workflow-körningen avslutats.

## Test- och leveransregler

- Ett test räknas som godkänt först när CI-resultat/logg visar att det passerat.
- Simulatorbuild, unsigned device IPA, signerad IPA och fysisk enhetstest är fyra olika verifieringsnivåer och ska rapporteras separat.
- Skapa inte eller dela en ny IPA som fungerande innan aktuell build har verifierats och artefakten har kontrollerats.
- Ändra inte default branch, mergea inte PR och påbörja inte CloudKit-migrering utan uttryckligt beslut.
- För varje kodändring: kontrollera aktuell filversion/SHA före uppdatering, dokumentera ändringen och notera commit.
- Buggar ska få ID, reproduktionssteg när de är kända, förväntat/observerat beteende, status och verifieringsresultat.
- Om ett fynd visar sig vara felaktigt ska det markeras som avfärdat med förklaring, inte raderas ur historiken.

## Arbetslogg – mall för kommande pass

### YYYY-MM-DD – kort rubrik
**Mål**
- 

**Ändringar**
- Filer:
- Commit:

**Buggar/fynd**
- ID:
- Reproduktionssteg:
- Förväntat:
- Observerat:

**Tester**
- Kommando/workflow:
- Resultat:
- Logg/artefakt:

**Kvarstår**
- 

**Beslut**
- 
