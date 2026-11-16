# Familjen – utvecklingslogg

> Levande arbetslogg för beslut, implementation, buggar, testresultat och kvarstående risker. Uppdateras i samma utvecklingsgren som koden. Datum anges enligt svensk tid.

## Projektstatus – 2026-11-16

- Repository: `72cbbw422f-alt/fam`
- Arbetsgren: `local-first-beta`
- Pull request: [#1 – Convert Familjen to local-first iOS beta](https://github.com/72cbbw422f-alt/fam/pull/1)
- PR-status vid senaste kontroll: öppen, draft.
- Senast verifierade commit: `2c533c79804337b06aca1d565f42b2c186e230b4`
- Jämförelse mot `main`: 147 commits före, 0 bakom vid senaste kontroll.
- CI: Run `43922355483` (commit `66fdf9aa959edfed292922cc4cb2fd56010ee5f5`) avslutades med fel i både simulator-testjobbet och unsigned iPhone-bygget. Båda stoppade på samma Swift actor-isoleringsfel i fyra ViewModels. Korrigeringar är nu incheckade; ny CI-körning inväntas.
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

### 2026-11-16 – korrigera MainActor-standardargument i ViewModels

**Fynd**
- CI-run `43922355483` misslyckades i både `Build unsigned IPA (iPhone)` och `Build Familjen (iOS Simulator)`.
- Xcode rapporterade fyra kompilatorfel: `FamilyRepositoryFactory.makeDefault()` är MainActor-isolerad men användes direkt i standardargumentet till fyra synkrona initialiserare. Standardargumentets uttryck utvärderas i en icke-isolerad kontext.
- Berörda filer: `DashboardViewModel.swift`, `NotificationsViewModel.swift`, `FamilyCalendarViewModel.swift` och `ShoppingListViewModel.swift`.

**Åtgärd**
- Ändrade initialiserarna till valfri injicerad repository med standardvärdet `nil`.
- Repository-fabriken anropas nu i initialiserarens kropp, där ViewModel-klassen redan är isolerad till MainActor.
- Behåller testbar dependency injection: tester kan fortfarande skicka in ett explicit repository.
- Commits:
  - `eb3996b90da351dfe6feb6f2b45c7f2fb44cc54b` – dashboard.
  - `b67308809e56bd38ed5c3fed153e1ac990aa1228` – notiser.
  - `47967ca2a1c8ead8b27e8469ab4bef22b38b9b44` – kalender.
  - `8aa354fc8aab8ca09af3ac64cc9988f7c6801ddb` – inköpslista.

**Verifiering**
- CI-loggarna identifierade felet entydigt i samtliga fyra filer.
- Korrigeringen är incheckad, men ännu inte verifierad av en ny CI-körning.
- Ingen IPA har skapats eller delats från den misslyckade körningen; paketeringssteget hoppades över.

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
| FAM-011 | Swift concurrency | MainActor-isolerad repository-fabrik anropades i default arguments för fyra ViewModels, vilket stoppade simulator- och device-kompilering. | Åtgärdad i kod genom att flytta fabriksanropet in i MainActor-isolerade initialiserare. Ny CI-verifiering krävs. |


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


### 2026-11-16 – CI: eliminera dubbla workflow-körningar

**Fynd**
- Varje commit på arbetsgrenen startade två körningar med samma SHA: en från `push` och en från `pull_request`.
- Körningarna låg samtidigt i kö och tidigare uppdateringar avbröts ofta innan jobb hann starta. Det gjorde CI-resultaten svårtolkade och slösade byggkapacitet.

**Åtgärd**
- Behöll `push` för `main` och `local-first-beta` samt manuell `workflow_dispatch`.
- Tog bort den redundanta `pull_request`-triggern. Push-körningen är fortfarande kopplad till samma commit som PR:n.
- Förenklade concurrency-gruppen till workflow-ref så körningar på samma gren hanteras konsekvent.
- Fil: `.github/workflows/ios-build.yml`.
- Commit: `97053bc5bb3dafa99aa8ca024e0344e84dced0b5`.

**Verifiering**
- Workflow-konfigurationen är uppdaterad på arbetsgrenen.
- Ny körning ska kontrolleras separat; inga bygg- eller testresultat är ännu godkända.


### 2026-11-16 – explicit lokal kalender för notistriggers

**Fynd och åtgärd**
- Påminnelsernas absoluta tidpunkt beräknas korrekt som en `Date`, men kalenderkomponenterna som skickas till iOS-notiscentret förlitade sig tidigare på implicit kalender-/tidszonskontext.
- Schemaläggaren använder nu uttryckligen enhetens aktuella kalender och lokala tidszon när år, månad, dag och klockslag skapas för `UNCalendarNotificationTrigger`.
- Fil: `Sources/LocalReminderScheduler.swift`.
- Commit: `a4a91351f1adcd1e956ae566d20d6e6c60032543`.

**Verifiering**
- Källändringen är incheckad.
- Simulator-CI måste verifiera kompilering och tester; fysisk notisleverans och sommartidsgränser återstår att prova på enhet.


### 2026-11-16 – serialisering av påminnelseuppdateringar

**Fynd**
- Kalenderändringar kan trigga flera asynkrona schemaläggningar tätt efter varandra. Utan serialisering kunde en äldre schemaläggning i teorin slutföras efter en nyare och skriva tillbaka ett gammalt triggerdatum för samma notis-ID.

**Åtgärd**
- Schemaläggning och rensning körs nu i en gemensam serialiserad uppgiftskö på main actor.
- En ny operation väntar in föregående operation innan den läser, lägger till eller tar bort notiser.
- Påminnelsetesterna körs på main actor eftersom schemaläggaren nu har uttrycklig actor-isolering.
- Filer: `Sources/LocalReminderScheduler.swift`, `Tests/LocalReminderSchedulerTests.swift`.
- Commit `cae238ab6cc34638b3c8768095663acc6b3e84fd`: serialisering av schemaläggare.
- Commit `35efb44669d3758bbef65c861d420def560de88d`: testisolering.

**Verifiering**
- Ändringarna är incheckade.
- CI-kompilering och testresultat återstår. Fysisk notisleverans måste också verifieras på iPhone.

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
