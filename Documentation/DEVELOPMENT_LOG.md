# Familjen – utvecklingslogg

> Levande arbetslogg för beslut, implementation, buggar, testresultat och kvarstående risker. Uppdateras i samma utvecklingsgren som koden. Datum anges enligt svensk tid.

## 2026-11-22 – regressionstester för återkommande kalenderhändelser

**Granskning**
- Veckovis och månadsvis återkomst finns redan i datamodellen, redigeraren och projektionen. Kalendern erbjuder också val mellan att ändra ett enskilt tillfälle och hela serien.
- Fortsättningen fokuserade därför på att täcka dessa befintliga flöden med regressionstester, inte att implementera funktionen en gång till.

**Ändrat**
- Lade till test som redigerar klockslag på en veckovis respektive månadsvis serie och verifierar att ursprungligt datumankare och återkomstfrekvens bevaras.
- Lade till test som redigerar en enskild veckoförekomst och verifierar att efterföljande förekomst och grundserien förblir oförändrade.
- Berörd fil: `Tests/LocalFamilyStoreTests.swift`.
- Kodcommit: `3db2592d6dde9427988cc46a3ce9652b071058da`.

**Verifiering**
- Testerna är incheckade men ännu inte körda i CI vid dokumentationstillfället.
- Ingen fysisk iPhone-testning har genomförts för dessa nya testfall.
- Nästa kvalitetsgrind är en avslutad grön CI-körning på dokumentationscommiten, inklusive simulatorns enhetstester och unsigned iPhone-bygge.

## Projektstatus – 2026-11-16

- Repository: `72cbbw422f-alt/fam`
- Arbetsgren: `local-first-beta`
- Pull request: [#1 – Convert Familjen to local-first iOS beta](https://github.com/72cbbw422f-alt/fam/pull/1)
- PR-status vid senaste kontroll: öppen, draft.
- Senast verifierade commit: `309834fdd78bf7feac2cf06fc8ced03111297017`
- Jämförelse mot `main`: 147 commits före, 0 bakom vid senaste kontroll.
- CI: Run `43939559116` på commit `309834fdd78bf7feac2cf06fc8ced03111297017` är verifierad grön. Simulatorjobb och unsigned iPhone-bygge lyckades. Samtliga 18 enhetstester passerade (14 LocalFamilyStoreTests + 4 LocalReminderSchedulerTests). IPA-artefakten `Familjen-unsigned-IPA` skapades och laddades upp; den är osignerad och fysisk iPhone-test är inte genomförd. Två ytterligare regressionstester för redigering av återkommande födelsedagar har lagts till i commit `701de43a89dbafffa2545cb5523a366be2f692ad`; dessa inväntar CI-verifiering.
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

### 2026-11-16 – verifierad CI efter MainActor-korrigering\n\n**Resultat**\n- Workflow run: `43939559116` – [öppna körningen](https://github.com/72cbbw422f-alt/fam/actions/runs/43939559116).\n- Commit: `309834fdd78bf7feac2cf06fc8ced03111297017`.\n- `Build Familjen (iOS Simulator)`: lyckades.\n- `Run unit tests`: lyckades; 18 tester, 0 fel. `LocalFamilyStoreTests`: 14/14. `LocalReminderSchedulerTests`: 4/4.\n- `Build for iOS Simulator`: lyckades.\n- `Build unsigned IPA (iPhone)`: lyckades. Appens bundle identifier verifierades som `se.familjen.app`, plattform `iPhoneOS` och minsta iOS-version 17.0.\n- Artefakt: `Familjen-unsigned-IPA`, artifact ID `14262816270`, SHA-256 `b87ab32cd933d629012621a7e1bdb358e5956b32926edbc0ac03dc1e0e6ecb91`. Artefakten finns till 2026-11-30.\n\n**Bedömning och begränsningar**\n- MainActor-standardargumentfelet är verifierat åtgärdat genom lyckad kompilering i båda byggspåren.\n- Detta verifierar kompilering och befintliga automatiserade tester, inte appens visuella beteende eller fysisk installation/notisleverans.\n- IPA:n är uttryckligen osignerad; den får inte beskrivas som signerad eller distributionsklar.\n- Nästa steg: utöka testtäckningen för kalenderredigering, radering, tidszon/DST och repository-fasadens uppdateringar; därefter fysisk installationstest via tillgänglig sideload-process.\n\n### 2026-11-16 – regressionstester för redigering av återkommande födelsedagar\n\n**Ändring**\n- Lade till test som verifierar att redigering av en projicerad återkommande födelsedag behåller det ursprungliga födelseåret samtidigt som redigerad klocktid sparas.\n- Lade till test som verifierar att en oförändrad 29 februari-födelsedag, projicerad till 28 februari under ett icke-skottår, fortfarande sparas som 29 februari i det ursprungliga födelseåret.\n- Fil: `Tests/LocalFamilyStoreTests.swift`.\n- Commit: `701de43a89dbafffa2545cb5523a366be2f692ad`.\n\n**Verifiering**\n- Testerna är incheckade men väntar på ny simulator-CI. De ska inte räknas som godkända förrän körningen passerat.\n\n**Känd UX-begränsning att bevaka**\n- För en 29 februari-födelsedag går det med nuvarande datumvärde inte att skilja mellan att användaren lämnar den projicerade 28 februari-dagen oförändrad och att användaren avsiktligt ändrar födelsedagen till 28 februari. Nuvarande beteende prioriterar att bevara ursprungligt 29 februari-datum. Om UI ska stödja avsiktlig ändring till 28 februari behövs en tydligare ändringssignal eller separat val.\n\n### Tidigare local-first-arbete – sammanfattning

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
| FAM-011 | Swift concurrency | MainActor-isolerad repository-fabrik anropades i default arguments för fyra ViewModels, vilket stoppade simulator- och device-kompilering. | Åtgärdad och verifierad: båda byggspåren gröna i run `43939559116`. |\n| FAM-012 | Födelsedagsredigering | Regressionstäckningen saknade kontroll av att projicerade födelsedagar behåller födelseåret och att 29 februari bevaras vid oförändrad projicering. | Två regressionstester tillagda i `701de43`; CI-verifiering inväntas. Känd UX-tvetydighet för avsiktlig ändring 29→28 februari dokumenterad ovan. |
| FAM-013 | Familjeprofiler / kalenderhistorik | Att ta bort en familjemedlem raderade tidigare alla kalenderhändelser som var kopplade till profilen. | Åtgärdad i kod: behåll händelserna och rensa endast personkopplingen. Regressionstest tillagt; CI-verifiering inväntas. |
| FAM-014 | Swift-kompilering | En extra escapad backslash i två nya key-path-uttryck stoppade simulatorns kompilering innan testerna startade. | Korrigerat i commits `3212c077` och `7c8c2ee`; ny CI-verifiering inväntas. |


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

### 2026-11-16 – produktbeslut: koppla kalenderhändelser till familjemedlemmar

**Användarbehov**
- Familjens vuxna och barn ska kunna läggas upp som profiler under Inställningar.
- När en kalenderhändelse skapas eller redigeras ska användaren kunna välja vem eller vilka händelsen gäller: exempelvis en vuxen, ett visst barn eller flera familjemedlemmar.
- Det ska finnas ett tydligt alternativ för **Hela familjen**.
- Kalendern ska kunna filtreras på hela familjen, en enskild person eller flera personer.

**Produkt- och UX-beslut**
- Barnprofiler ska inte kräva egna användarkonton.
- Personkoppling ska vara synlig och lätt att förstå i kalendern, exempelvis genom diskreta färgmarkeringar/profilchips.
- En familjeomfattande händelse ska modelleras uttryckligen och inte blandas ihop med en händelse där ingen person har valts.
- Inställningar ska vara den naturliga platsen för att hantera familjens profiler; befintlig profilhantering ska återanvändas i stället för att skapa dubbla system.
- Funktionen ska hålla sig till familjekalenderns syfte. Inga sysslor eller generella att-göra-listor läggs till.

**Teknisk påverkan att utreda före implementation**
- Nuvarande kalenderpost använder en enskild memberID. För flera personer behöver modellen, repository-kontraktet, lagringslagret, ViewModels och kalenderformuläret stödja flera medlems-ID:n.
- Bakåtkompatibel avkodning krävs så befintliga lokala JSON-snapshots och kalenderhändelser inte går förlorade.
- Skilj mellan explicit familjeomfattning och valda personer; exempelvis ett separat scope/flagga eller motsvarande tydlig modell.
- Kalenderfilter ska byggas på den nya tilldelningsmodellen och testas för både enskilda och kombinerade val.

**Prioriterad implementationsordning**
1. Granska befintlig profilhantering och kalenderdatamodell.
2. Utforma bakåtkompatibel datamodell och repository-API för flera personer.
3. Bygg/återanvänd profilhantering i Inställningar.
4. Lägg till personval och valet Hela familjen i skapa/redigera-händelse.
5. Lägg till kalenderfilter och diskreta visuella personmarkeringar.
6. Lägg till regressionstester för legacy-data, flera personer, familjehändelser och filter.
7. Uppdatera roadmap och denna logg med implementation, buggar, commits och verifierad CI.

**Status**
- Beslut och krav är dokumenterade i Documentation/ROADMAP.md.
- Detta är planerat arbete, inte implementerad funktionalitet.
- Ingen befintlig kalenderdata ska migreras eller skrivas om förrän kompatibilitetsstrategin är testad.

### 2026-11-16 – produktgranskning mot Cozi, TimeTree och FamilyWall

**Syfte**
- Jämföra Familjens funktioner och produktinriktning med etablerade familjeappar för att identifiera viktiga luckor innan mer funktionalitet byggs.
- Granskningen fokuserade på Cozi, TimeTree och FamilyWall.

**Fynd i befintlig kod**
- Familjeprofiler för vuxna och barn finns redan i `FamilyMembersView`. Återanvänd befintlig profilhantering; bygg inte ett parallellt inställningssystem.
- `FamilyCalendarView` har aktivitetskategorifilter, lokal påminnelsehantering och visar importerade Apple Kalender-poster separat.
- `AppleCalendarImport` använder EventKit och läser kommande händelser från Apple Kalender. Det är en läsvy/import, inte synkronisering av Familjens egna poster tillbaka till Apple Kalender.
- `FamilyItem` har i nuläget ett enda valfritt `memberID`. Det räcker inte för att ange flera berörda familjemedlemmar eller skilja mellan deltagare och ansvarig.
- Händelsedetaljer består i nuläget av titel, valfri text och datum/tid. Plats/adress och bilagor saknas som separata fält.
- OCR finns redan i projektet. Det mest värdefulla nästa steget är ett granskat arbetsflöde från bild/PDF till föreslagen kalenderpost, inte att skapa en separat OCR-modul.
- Kalendern har stöd för årliga födelsedagar, men inte ett generellt återkommande schema för aktiviteter.
- Local-first-betan har fortfarande separat data på varje telefon. Gemensam synk och säkerhetskopiering är en grundläggande framtida förutsättning för verklig familjeanvändning.

**Prioriterade produktbeslut**
1. P0: slutför verifiering av befintliga regressionstester och fortsätt kvalitetssäkra lokal persistens, kalender och notiser. Senaste kända CI-run `43941033673` avbröts och får inte räknas som godkänd.
2. P1: färdigställ familjekalenderns kärna med flera personer per händelse, explicit val för Hela familjen, personfilter samt åtskillnad mellan berörda personer och ansvarig vuxen. Gör datamodellsändringen bakåtkompatibel från nuvarande `memberID`.
3. P1: förbättra händelsedetaljer med plats/adress och utred bilagor först när lagring och integritet är definierade.
4. P1/P2: utöka återkommande aktiviteter från enbart årliga födelsedagar till veckovis/månadsvis med möjlighet att ändra en förekomst eller hela serien.
5. P2: bygg vidare på befintlig OCR till bild/PDF → förslag → manuell granskning → personval → sparad händelse.
6. P2: widget och snabbregistrering; undersök därefter extern iCal/ICS-import.
7. P3: aktivitetsflöde när synk finns; flera inköpslistor kan utvärderas senare.
8. Gemensam synk/backup kräver separat CloudKit/CKShare-plan med migrering, behörigheter och konfliktlösning. Ingen CloudKit-migrering påbörjas utan uttryckligt beslut.

**Medvetet bortprioriterat**
- Hushållssysslor, poängsystem och generella att-göra-listor.
- GPS-spårning/ankomstaviseringar, budgetering, recept-/måltidsplanering och separat socialt fotoalbum.

**Produktprinciper**
- Varje funktion ska lösa ett verkligt och återkommande familjebehov.
- Importerade dokument ska bara skapa ett granskningsförslag; användaren måste bekräfta innan en händelse sparas.
- Lokal, importerad och gemensamt synkroniserad information ska kunna särskiljas tydligt.
- Roadmapen är uppdaterad med prioriteringarna. Inga av dessa nya funktioner markeras som implementerade.


### 2026-11-16 – bevara kalenderhistorik när familjeprofil tas bort

**Fynd (FAM-013)**
- `LocalFamilyStore.deleteMember` raderade alla kalenderposter vars `memberID` pekade på profilen som togs bort.
- Detta innebar oavsiktlig dataförlust: exempelvis kunde tandläkarbesök och andra historiska händelser försvinna när en barnprofil togs bort.

**Åtgärd**
- Ändrade borttagningen så att profilen tas bort men befintliga kalenderposter behålls. `memberID` rensas på de poster som pekade på profilen.
- Uppdaterade bekräftelsetexten i `FamilyMembersView` så att användaren får korrekt information före borttagningen.
- Lade till regressionstest som verifierar att händelsen, titel, ID och övrig data finns kvar efter borttagningen och efter omladdning från JSON-snapshot.
- Filer: `Sources/Data/LocalFamilyStore.swift`, `Sources/FamilyMembersView.swift`, `Tests/LocalFamilyStoreTests.swift`.
- Commits: `66a32505a3700fe22599b435085745231176aec3`, `8ac2168913a93a7d6354e6443d3a8d4aaac9afc8`, `af37923fb9f804205744cb4c634240f6acc5ea59`.

**Verifiering**
- Regressionstestet är incheckat men ännu inte verifierat i CI.
- Nästa CI-körning ska kontrollera simulatorbuild och hela enhetstestsviten.


### 2026-11-16 – bakåtkompatibel datamodell för flera personer i kalendern

**Mål**
- Förbereda kalendern för flera berörda familjemedlemmar, en separat ansvarig vuxen och ett uttryckligt val för Hela familjen utan att bryta äldre lokala snapshots.

**Ändringar**
- FamilyItem har nu memberIDs för noll eller flera berörda personer.
- isForEveryone skiljer en familjeomfattande händelse från en händelse utan personkoppling.
- responsibleMemberID lagrar separat vem som ansvarar för samordningen.
- Den äldre memberID-egenskapen finns kvar som kompatibilitetsaccessor för befintliga anropsställen.
- Avkodning läser äldre member_id när member_ids saknas. Kodning skriver den nya modellen och behåller även legacy-nyckeln member_id med första valda personen.
- Filer: Sources/Domain/FamilyModels.swift, Tests/LocalFamilyStoreTests.swift.
- Commits: 602be874532bb8131ecad79f0b7b33d4d5e9860e (modell), 25313e264d6b8a9ff7b2dae191f3392e8b991365 (tester).

**Tester tillagda**
- Äldre JSON med enbart member_id avkodas till en deltagare.
- Ny JSON med flera member_ids och separat ansvarig person överlever encode/decode.
- Hela familjen hålls åtskilt från ingen tilldelning.

**Avgränsning**
- Detta är datamodellens första steg. Kalenderformuläret, repository-metoderna och filtreringen använder ännu inte de nya fälten.
- memberID-kompatibiliteten håller befintliga anropsställen fungerande under övergången; den nya UI-implementationen ska använda de explicita fälten.
- CI-verifiering inväntas. Inga tester markeras som godkända innan simulatorjobbet har passerat.


### 2026-11-16 – familjemedlemmar i kalendern: första implementationen

**Mål**
- Göra kalenderhändelser tilldelningsbara till flera familjemedlemmar, med explicit familjeomfattning och separat ansvarig vuxen.

**Implementation**
- Utökade FamilyRepository med saveCalendarItem och behöll äldre saveItem som kompatibilitetsväg.
- LocalFamilyStore sparar flera deltagare, Hela familjen och ansvarig vuxen. Okända medlems-ID:n och dubbletter filtreras bort; ansvarig måste vara en befintlig vuxenprofil.
- Vid borttagning av profil tas endast den personens deltagarkoppling bort. Om personen var ansvarig rensas ansvarigfältet. Kalenderhändelsen och övriga deltagare bevaras.
- FamilyCalendarView har nu flerval av deltagare, ett särskilt Hela familjen-val och separat ansvarig vuxen. Personfilter kan kombineras och familjeomfattande händelser visas även vid personfilter.
- Kalenderlistan och dashboardens kommande tider visar deltagare/familjeomfattning och ansvarig när det finns.
- OCR-förslag på person lägger till personen i urvalet utan att skriva över andra deltagare.
- Filer: Sources/Data/FamilyRepository.swift, Sources/Data/LocalFamilyStore.swift, Sources/Data/FamilyStore.swift, Sources/Data/FamilyCalendarViewModel.swift, Sources/FamilyCalendarView.swift, Sources/DashboardView.swift, Tests/LocalFamilyStoreTests.swift.

**Tester tillagda**
- Persistens av flera deltagare, deduplicering och ansvarig vuxen.
- Hela familjen rensar deltagarurvalet men kan behålla ansvarig vuxen.
- Personfilter matchar valda personer och inkluderar familjeomfattande händelser; tomt filter visar allt.
- Borttagning av en profil rensar endast den personens koppling och ansvar, utan att ta bort kalenderhistorik eller andra deltagare.
- Tidigare tester verifierar även avkodning av äldre member_id-snapshots och round-trip för den nya modellen.

**Commits**
- 936f50f7 – repository-kontrakt.
- 6590f1fe – lokal lagring och borttagningshantering.
- 7f1a6f0f – FamilyStore-fasad.
- 4b9b8618 – ViewModel och filterlogik.
- 808a5cdd – kalenderformulär och personfilter.
- 7c85e21f – deterministisk deduplicering av medlems-ID:n.
- 438fb160 – grundläggande regressionstester.
- bb522145 – deltagare i dashboardens kommande tider.
- bb4aec2b – regressionstest för borttagning av deltagare/ansvarig.

**Verifiering och begränsningar**
- CI för senaste kodcommit bb4aec2b är köad; simulatorjobb och testresultat inväntas.
- Ett tidigare iPhone unsigned-build-jobb lyckades på samma utvecklingsserie, men den slutliga samlade implementationen ska verifieras i CI innan den räknas som bygggodkänd.
- Ingen fysisk iPhone-testning har utförts. IPA är osignerad.
- Personfilter använder OR-semantik: händelsen visas om den gäller minst en vald person. Familjeomfattande händelser visas alltid när ett personfilter är aktivt.
- Detta är första funktionsversionen. Ingen CloudKit-synk eller delning mellan telefoner ingår.


### 2026-11-16 – FAM-014: korrigering av Swift-nyckelvägar efter första CI-körningen

**Fynd**
- Simulator-CI för commit 565440fa misslyckades under kompilering innan testerna kunde köras.
- Loggen pekade ut en felaktigt escapad key path i dashboardens deltagarvisning (`DashboardView.swift`). Samma typ av extra backslash fanns i ett nytt filtertest.

**Åtgärd**
- Korrigerade båda uttrycken till giltig Swift key-path-syntax.
- Filer: Sources/DashboardView.swift och Tests/LocalFamilyStoreTests.swift.
- Commits: 3212c0779f9bf8de3f01d10dce27ae732b080643 och 7c8c2ee14793032d77e5b8f5cdf5ced243513e43.

**Verifiering**
- Källorna har kontrollerats igen för dubbla backslash-tecken före key-path-uttryck.
- Ny CI-körning för commit 7c8c2ee inväntas. Felet räknas inte som åtgärdat/verifierat förrän simulatorbygget och testerna passerar.



### 2026-11-16 – FAM-015: förenkla SwiftUI-kalenderns toolbar efter CI-kompileringsfel

**Fynd**
- CI-run `43944814343` (commit `092908268fd865030124a14082d5d7e6ea238e08`) misslyckades i både simulator- och iPhone-bygget.
- Simulatorloggen pekade på `Sources/FamilyCalendarView.swift:160`: Swift kunde inte typkontrollera det sammansatta SwiftUI-uttrycket inom rimlig tid. Testerna startade därför aldrig; detta var ett kompileringsfel, inte ett konstaterat testfel.

**Åtgärd**
- Flyttade toolbarens `ToolbarItem` till en separat beräknad `some ToolbarContent`-egenskap (`calendarToolbar`) och lät vyn använda den egenskapen. Syftet är att minska typinferensens komplexitet utan att ändra beteendet.
- Fil: `Sources/FamilyCalendarView.swift`.
- Commit: `b1f831efe8af4470d310b1c39217119e3395a36a`.

**Verifiering**
- Ändringen är incheckad. En ny CI-körning krävs för att avgöra om uttrycket nu kompilerar och om enhetstesterna passerar.
- Ingen IPA skapades i run `43944814343`; paketerings- och uppladdningsstegen hoppades över efter byggfelet.
- Ingen fysisk iPhone-testning är utförd.



### 2026-11-16 – FAM-016: förenklad toolbar och korrigerad ansvarig-etikett

**Fynd**
- CI-run `43948780418` misslyckades åter i Swift-kompileringen på `FamilyCalendarView.swift`, nu vid användningen av den separata toolbar-egenskapen. Det visar att första uppdelningen i FAM-015 inte räckte.
- Samma körning gav en varning i `DashboardView.swift`: ansvarigprofilen hämtades men användes inte. Orsaken var en felaktigt escapad stränginterpolation, vilket gjorde att etiketten inte visade namnet.

**Åtgärd**
- Förenklade toolbaren ytterligare: själva plusknappen är nu en separat `some View`-egenskap och placeras direkt i `ToolbarItem`.
- Korrigerade stränginterpolationen för ansvarig vuxen i dashboarden så att profilens namn visas i stället för en bokstavlig interpolationstext.
- Filer: `Sources/FamilyCalendarView.swift`, `Sources/DashboardView.swift`.
- Commits: `d03fa2d2f1de223db08f8145997cc0118733b635`, `52ee91e2e013648908d2ffb0782e4569e39fd5a1`.

**Verifiering**
- Korrigeringarna är incheckade. Ny CI krävs; varken simulator-/enhetstester eller iPhone-bygget är ännu godkända för dessa commits.
- Run `43948780418` skapade ingen IPA eftersom iPhone-bygget avbröts före paketering.



### 2026-11-16 – FAM-017: bryt ut kalenderns filtersektion efter fortsatt SwiftUI type-check-fel

**Fynd**
- CI-run `43949276257` misslyckades under kompilering vid personfilterchipen i `FamilyCalendarView.swift` (rad 82). Toolbarens tidigare fel var inte längre den rapporterade felplatsen; kompilatorn fastnade nu i det stora List/Section-uttrycket för filter.
- Varken enhetstester eller iPhone-paketering kunde slutföras eftersom appmålet inte kompilerade.

**Åtgärd**
- Flyttade kalenderns påminnelse- och filterinnehåll till en separat beräknad `calendarFilterSection`.
- Lade till en liten typad hjälpfunktion för personfilterchip så att den nästlade `ForEach`-closure inte behöver bygga hela uttrycket direkt i List-buildern.
- Fil: `Sources/FamilyCalendarView.swift`.
- Commit: `aa38e9d0a9a2c4d7c44fd16a4fab983d36833b18`.

**Verifiering**
- Ändringen är incheckad. Ny CI krävs innan den kan räknas som kompilerings- eller testgodkänd.
- Run `43949276257` skapade ingen IPA; iPhone-bygget misslyckades före paketering.


### 2026-11-17 – FAM-018: synliggör fel vid lokal datalagring

**Fynd**
- `LocalFamilyStore.saveToDisk()` ignorerade tidigare både JSON-kodningsfel och skrivfel med `try?`.
- Appen kunde därför visa en ändring i minnet utan att användaren fick veta att den inte hade sparats på enheten.
- Skapandet av katalogen för snapshot ignorerade också fel. Vid misslyckad återställning av en korrupt snapshot spärrades skrivningar, men orsaken visades inte i gränssnittet.

**Åtgärd**
- Lägg till `persistenceError` i repository-kontraktet med ett kompatibelt standardvärde för andra implementationer.
- `LocalFamilyStore` fångar nu katalog-, kodnings- och skrivfel och exponerar ett begripligt felmeddelande. Ett lyckat atomiskt skrivande rensar felet.
- Om en korrupt snapshot inte kan flyttas till återställningsfil blockeras skrivningar fortfarande, och ett tydligt fel exponeras.
- `FamilyStore` vidarebefordrar statusen och dashboarden visar en varning om data inte kunde sparas.
- Test tillagt: en fil används avsiktligt som föräldrakatalog så att katalog-/skrivning misslyckas; testet verifierar att felet exponeras och att blockeringsfilen inte skrivs över.
- Filer: `Sources/Data/LocalFamilyStore.swift`, `Sources/Data/FamilyRepository.swift`, `Sources/Data/FamilyStore.swift`, `Sources/DashboardView.swift`, `Tests/LocalFamilyStoreTests.swift`.
- Commits: `8299b4bb`, `5f132df8`, `ea039751`, `90a29dce`, `9be8d112`.

**Verifiering**
- CI-run `43980622324` på SHA `15ee43038b66781429a8e57d251f50c86365485d` passerade både simulator- och unsigned iPhone-build.
- Simulatorlogg: 28/28 tester passerade (24 LocalFamilyStoreTests + 4 LocalReminderSchedulerTests); `TEST SUCCEEDED`.
- Unsigned IPA-artifact `Familjen-unsigned-IPA`, artifact ID `14282708762`, SHA-256 `17e7550317a296949a0c919cfee8f8b7cd0da90d6bcdf4da3f450c04c51f3e`, giltig till 2026-11-30. IPA är osignerad; fysisk installation är inte verifierad.
- FAM-018 är därmed verifierad i CI på ovanstående SHA. Senare kalender-/påminnelseändringar FAM-019 och FAM-020 inväntar egen CI.
- Fysisk iPhone-testning är fortfarande inte utförd.

**Kvarstående risk**
- Vid skrivfel behålls den senaste ändringen i appens minne och användaren varnas; ändringen kan försvinna om appen stängs innan lagringen fungerar igen. Full transaktionell rollback av varje mutation är inte införd i denna ändring.


### 2026-11-17 – FAM-019: rensa inaktuella levererade påminnelser

**Fynd**
- Schemaläggaren tog tidigare bara bort inaktuella väntande notiser. En notis som redan levererats kunde ligga kvar i iOS notiscenter efter att kalenderhändelsen raderats eller ändrats.
- Att stänga av Familjens lokala påminnelser rensade också bara väntande notiser, inte redan levererade notiser.

**Åtgärd**
- Läser nu både väntande och levererade notiser som tillhör Familjens identifierarprefix.
- Vid omschemaläggning tas endast inaktuella Familjen-notiser bort från båda samlingarna; aktuella notiser och andra appars notiser lämnas orörda.
- När användaren stänger av påminnelser rensas både väntande och levererade notiser som ägs av Familjen.
- Ny ren hjälpfunktion väljer inaktuella identifierare deterministiskt och ett regressionstest verifierar att främmande appnotiser och fortfarande önskade notiser bevaras.
- Filer: `Sources/LocalReminderScheduler.swift`, `Tests/LocalReminderSchedulerTests.swift`.
- Commits: `972e1bbc` (schemaläggare), testcommit `bfd54284`.

**Verifiering**
- Källkod och regressionstest är incheckade.
- CI-verifiering inväntas för FAM-019.
- Fysisk leverans/rensning i iOS notiscenter behöver fortfarande provas på en iPhone.

### 2026-11-17 – FAM-020: rensa borttagna profiler ur aktiva kalenderfilter

**Fynd**
- Personfilter lagras som UUID:n i vyernas lokala state. Om en profil togs bort medan kalendern fortfarande var aktiv kunde filtret behålla ett UUID som inte längre motsvarade någon familjemedlem. Det gav ett föråldrat filterläge tills användaren manuellt valde om filter.

**Åtgärd**
- Kalendern observerar nu medlems-ID-listan och tar bort valda ID:n som inte längre finns i medlemslistan.
- Om inga valda personer återstår återgår filtret till Alla personer, vilket är det befintliga och avsedda beteendet.
- Fil: `Sources/FamilyCalendarView.swift`.
- Commit: `ff4bd3c3`.

**Verifiering**
- Källändringen är incheckad; CI-verifiering inväntas.


### 2026-11-17 – FAM-021: återställ kalenderändringar när lokal lagring misslyckas

**Fynd**
- FAM-018 gjorde lagringsfel synliga, men en kalenderändring kunde fortfarande ligga kvar i minnet trots att snapshot-filen inte uppdaterades.
- Det kunde ge en missvisande kalender under pågående session och förlust av ändringen när appen stängdes.

**Åtgärd**
- Kalenderns skapa/uppdatera- och raderingsflöden sparar nu föregående kalenderlista och återställer den om atomisk snapshot-skrivning misslyckas.
- Borttagning av familjeprofil återställer både medlemslistan och kalenderns deltagar-/ansvarskopplingar om skrivningen misslyckas.
- Lagringsfunktionen returnerar nu ett resultat så kalenderflödena kan skilja på lyckad och misslyckad persistens. Det befintliga lagringsfelet behålls och visas via repository.
- Nya regressionstester täcker misslyckad kalenderuppdatering, radering och profilborttagning. Testerna använder en blockerande fil som ersätter snapshot-katalogen för att deterministiskt framkalla skrivfel.
- Filer: Sources/Data/LocalFamilyStore.swift, Tests/LocalFamilyStoreTests.swift.
- Commits: 9d4fe9c6, ebc13c5d.

**Verifiering**
- Källkod och tester är incheckade. Ny CI-verifiering inväntas.
- Den tidigare CI-körningen 43981913051 stod kvar med simulatorns teststeg som pågående trots att iPhone-bygget skapade IPA. Den nya commitserien behöver en färsk, avslutad CI-körning.
- Fysisk iPhone-testning är inte utförd.

**Avgränsning**
- Denna korrigering omfattar kalenderposter och profilborttagning som påverkar kalenderkopplingar. Övriga lokala mutationer har ännu inte fått samma transaktionella rollback.


### 2026-11-17 – FAM-022: strukturerad plats för kalenderhändelser

**Fynd**
- Kalenderhändelser kunde ha anteckningar men saknade ett separat plats-/adressfält. Det gjorde det svårt att snabbt se var ett vårdbesök, en aktivitet eller en bokning äger rum.

**Åtgärd**
- Lade till ett valfritt platsfält i kalenderns datamodell med bakåtkompatibel avkodning av äldre snapshots.
- Plats kan anges och redigeras separat från anteckningar.
- Platsen visas diskret i kalenderlistan och sparas genom repository, FamilyStore och LocalFamilyStore.
- Äldre save-anrop fortsätter att fungera utan platsvärde.
- Regressionstest täcker persistens efter omladdning och äldre poster utan platsfält.
- Filer: Sources/Domain/FamilyModels.swift, Sources/Data/FamilyRepository.swift, Sources/Data/FamilyStore.swift, Sources/Data/LocalFamilyStore.swift, Sources/Data/FamilyCalendarViewModel.swift, Sources/FamilyCalendarView.swift, Tests/LocalFamilyStoreTests.swift.
- Commits: 17bc3b98, 02e6b5e4, c4de61df, 9d148ea3, e1329f50, f14e8f3c, 5d41e93c, 36e8d882, a72b6848, 7581772d, 26d83621.

**Verifiering**
- Källkod och regressionstest är incheckade. CI-verifiering inväntas.
- Äldre snapshots får location = nil och fortsätter därför att kunna läsas.
- Fysisk iPhone-testning är inte utförd.


### 2026-11-17 – FAM-023: årlig återkomst för fler kalenderhändelser än födelsedagar

**Fynd**
- Årlig återkomst var tidigare kopplad till födelsedagskategorin. Återkommande årsdagar, skolavslutningar, traditioner och familjeevenemang kunde därför inte använda samma funktion.

**Åtgärd**
- Flyttade den årliga återkomstinställningen till alla kalenderkategorier.
- Dashboardens och kalenderns projektion visar nästa kommande årsdatum även för andra återkommande händelser.
- Redigering av en projicerad händelse bevarar seriens ursprungliga år och datumankare men sparar den ändrade klocktiden.
- Skottdagslogiken bevaras: 29 februari visas 28 februari under år som inte är skottår.
- Regressionstest täcker projektion och redigering av en årligen återkommande vanlig kalenderhändelse.
- Filer: Sources/Data/LocalFamilyStore.swift, Sources/Data/DashboardViewModel.swift, Sources/Data/FamilyCalendarViewModel.swift, Sources/FamilyCalendarView.swift, Tests/LocalFamilyStoreTests.swift.
- Commits: 9f3e3fe3, 7d7d701c, f47afc59, 299bedcc, 104032a0, 9ea404b4, 81fe4ac8.

**Verifiering**
- Källkod och regressionstest är incheckade. CI-verifiering inväntas.
- Veckovis och månadsvis återkomst ingår inte i denna ändring. De kräver en mer omfattande modell för serier och redigering av en enskild förekomst kontra hela serien.


### 2026-11-17 – FAM-024: visa tydligt när kalendern inte kunde sparas

**Fynd**
- Efter FAM-021 återställdes kalenderns data vid skrivfel, men kalenderns view model kunde ändå rapportera att sparandet lyckats och stänga redigeraren.
- Misslyckad radering kunde också återställas utan att kalenderlistan visade ett fel.

**Åtgärd**
- View model kontrollerar nu repositoryts persistenceError efter spara och returnerar misslyckande till redigeraren i stället för att stänga den.
- Raderingsflödet visar samma lagringsfel i kalenderns felområde.
- Ett lyckat sparande rensar föregående view model-fel.
- Regressionstest verifierar att sparande rapporteras som misslyckat, posten ligger kvar, redigeraren får ett felresultat och radering inte tar bort posten när snapshot-skrivning misslyckas.
- Filer: Sources/Data/FamilyCalendarViewModel.swift, Tests/LocalFamilyStoreTests.swift.
- Commits: 1baf1672, 94d12b7d.

**Verifiering**
- Källkod och regressionstest är incheckade. CI-verifiering inväntas.


## 2026-11-22 – UX-förbättringar: översiktsnavigation och svensk kalender

**Ändringar**
- Skapade separat arbetsgren `feature/ux-navigation-shopping` från den aktuella hälsogrenens commit `4489fcbd0c73892f764ab4de152b1ed3ab664833`. Pågående PR #2 lämnades orörd och ommergad.
- Översiktsfliken får nu ett nytt navigations-ID när den trycks. Dashboardens `NavigationStack` återskapas därmed och återgår till startsidan även om Översikt redan är vald och en undersida ligger ovanpå.
- Kalenderns datumformat använder nu explicit svensk locale (`sv_SE`) i stället för att förlita sig på enhetens aktuella språkval.
- Veckodagsrubrikerna i månadsvyn använder svenska tvåbokstavsförkortningar: Må, Ti, On, To, Fr, Lö, Sö.


- Uppdaterade `.github/workflows/ios-build.yml` så att pushar på `feature/ux-navigation-shopping` också kör simulatorns enhetstester/build och unsigned iPhone-build. Detta gör att den separata UX-grenen får samma CI-kvalitetsgrind.

**Berörda filer**
- `Sources/RootView.swift`
- `Sources/FamilyCalendarView.swift`
- `Documentation/DEVELOPMENT_LOG.md`

**Verifiering**
- Källändringarna är incheckade på `feature/ux-navigation-shopping`.
- Inga lokala Xcode-tester kan köras i den tillgängliga miljön.
- CI har ännu inte verifierat dessa commits. Ingen IPA har skapats från denna arbetsgren.
- Navigationen behöver dessutom verifieras visuellt/interaktivt på iPhone när nästa IPA finns.

**Kvarstår**
- Fortsatt UX-arbete med Bring-inspirerad inköpslista. Datamodell, lokal persistens, äldre snapshots och regressionstester ska granskas innan kategorier och övriga listfunktioner implementeras.


## 2026-11-22 – Bring-inspirerad inköpslista: kategorier och handlat-status

**Ändringar**
- Lade till sju inköpskategorier med svenska namn och symboler: Frukt & grönt, Mejeri, Kött & fisk, Skafferi, Frys, Hushåll och Övrigt.
- Kategorin sparas per vara i den befintliga lokala JSON-snapshoten. Äldre varor utan kategorifält avkodas fortsatt och visas under Övrigt.
- Snabbtillägg behålls med ett separat kategorival. Aktiva varor grupperas per kategori.
- Att bocka av en vara raderar den inte längre. Den flyttas till Handlat och kan återställas med ett tryck. Manuell borttagning via svep finns kvar.
- Repository-kontraktet har en kompatibel standardimplementation för kategoriserat tillägg, så alternativa repository-adaptrar som ännu inte stöder kategorier fortsätter att kompilera.

**Berörda filer**
- Sources/Domain/ShoppingModels.swift
- Sources/Data/FamilyRepository.swift
- Sources/Data/LocalFamilyStore.swift
- Sources/Data/FamilyStore.swift
- Sources/Data/ShoppingListViewModel.swift
- Sources/ShoppingListView.swift
- Tests/LocalFamilyStoreTests.swift

**Tester**
- Tillagt regressionstest för avkodning av äldre inköpsvaror utan kategori.
- Tillagt persistensprov för kategori och avbockad status efter omladdning.
- Testerna är incheckade men ännu inte körda. CI-resultat inväntas.

**Begränsningar**
- Kvantitet och anteckning per vara ingår inte i denna iteration.
- Ingen synk mellan flera enheter; listan använder fortsatt lokal lagring.
- Ingen IPA har verifierats från denna arbetsgren.


## 2026-11-23 – CI-fel: svensk locale i kalenderdetaljer

**Fynd**
- GitHub Actions visade att simulatorns testjobb stoppades under kompilering och att iPhone-bygget föll på tre fel i `FamilyCalendarView.swift`: `swedishLocale` användes i `FamilyCalendarItemDetailView`, men egenskapen var privat i en annan vytyp.
- Enhetstesterna hann därför inte köras; teststeget avbröts på grund av kompileringsfelet. Ikonrenderingen och XcodeGen-projektgenereringen passerade.

**Åtgärd**
- Lade till en egen lokal `swedishLocale`-egenskap i `FamilyCalendarItemDetailView`. Det behåller svensk datum- och tidsformatering utan att ändra den andra vytypens åtkomstnivå.

**Berörd fil**
- `Sources/FamilyCalendarView.swift`

**Commit**
- `5a4a17c6fa7f13570e47a2ddb511757128c8280c` på `feature/ux-navigation-shopping`.

**Verifiering**
- Kodändringen är incheckad. Ny CI-körning inväntas.
- Appikonens asset catalog och renderingssteget finns, men visning av ikonen i en installerad iOS-notis är ännu inte verifierad på fysisk enhet.
- Ingen ny IPA är tillgänglig från denna commit ännu.


## 2026-11-23 – CI: iPhone-paketering passerar, regressionstest korrigerat

**Resultat från körning 45128667578**
- Ikonrendering och XcodeGen-projektgenerering passerade.
- Byggsteget för fysisk iPhone passerade och skapade ett unsigned IPA-artifact (run 45128667578, artifact 14797345612).
- Simulatorns testjobb stoppades före testkörning på ett syntaxfel i slutet av `Tests/LocalFamilyStoreTests.swift`: en bokstavlig `\\n` hade råkat hamna efter klassens avslutande klammer.

**Åtgärd**
- Tog bort den felaktiga escape-sekvensen så testfilen avslutas korrekt.
- Fil: `Tests/LocalFamilyStoreTests.swift`.
- Commit: `533e9d376d5a9c26057dd3773dae770be201c5dd`.

**Verifiering / kvarstår**
- En ny CI-körning startas automatiskt av committen. Simulatorns testresultat måste inväntas.
- IPA-artifactet från föregående körning byggdes från commit `344d0cef1180e19bd9ea16e64047e15986d8495d`, alltså före denna testfix. Det distribueras inte som verifierad version.
- Notisikonens utseende behöver fortfarande kontrolleras på fysisk iPhone efter en fullständigt godkänd bygg- och testkörning.


## 2026-11-23 – CI-stabilisering för parallella pushar

**Fynd**
- CI-körning 45137385951 avbröts under installationen av byggverktyg innan ikonrendering, projektgenerering, test eller byggen hann starta.
- Workflow-konfigurationen hade `cancel-in-progress: true`. En efterföljande dokumentationscommit på samma gren kunde därför avbryta den pågående verifieringen.
- Granskning av testfilen visade att testmetoden och testklassen avslutades med två klamrar på samma rad. Det var giltig Swift-syntax, men avslutningen har nu formaterats tydligare.

**Åtgärder**
- Ändrade CI-concurrency till `cancel-in-progress: false` så att en ny push inte avbryter en pågående bygg- och testkörning. Senare körningar köas i stället.
- Formaterade avslutningen av shoppinglistans regressionstest.

**Berörda filer**
- `.github/workflows/ios-build.yml`
- `Tests/LocalFamilyStoreTests.swift`
- `Documentation/DEVELOPMENT_LOG.md`

**Verifiering**
- Ändringarna är incheckade på `feature/ux-navigation-shopping`.
- Ny CI-verifiering inväntas. Inga nya testresultat eller IPA-artifact har ännu verifierats efter ändringarna.
- PR #4 är fortsatt öppen som draft och har inte slagits ihop.

**Kvarstår**
- Bekräfta gröna simulatorstester och unsigned iPhone-build.
- Kontrollera att appikonen finns i den paketerade appen.
- Installera och testa navigering, kalender och inköpslista på fysisk iPhone.


## 2026-11-23 – Fullständig CI-verifiering och IPA-inspektion

**CI-resultat**
- GitHub Actions-körning: [45138536295](https://github.com/72cbbw422f-alt/fam/actions/runs/45138536295).
- Simulatorjobbet passerade: ikonrendering, XcodeGen, Swift package resolution, samtliga 79 enhetstester och simulatorbygget.
- Testresultat: 79 tester, 0 fel.
- iPhone-jobbet passerade: Release-build för `iphoneos`, paketering och uppladdning av unsigned IPA.
- En varning kvarstår i `Tests/LocalFamilyStoreTests.swift:518` om tvetydig `Optional<FamilyRecurrenceFrequency>.none`. Den blockerar inte bygget eller testerna och bör städas separat.

**IPA-inspektion**
- Artifact: `Familjen-unsigned-IPA`, ID `14801676082`.
- Byggd från commit `90cf866028dd93a9dae714f8c0c1d9f4169b2a85`.
- Arkivet innehåller `Payload/Familjen.app`, körbar binär, `Assets.car`, appikonfiler och `Info.plist`.
- Bundle ID: `se.familjen.app`.
- Minimum iOS: `17.0`.
- Plattform: `iPhoneOS`.
- Info.plist deklarerar `AppIcon` som primär appikon. Att ikonen finns i appbundle är verifierat; visuellt utseende i iOS-notiser är inte verifierat på fysisk iPhone.
- IPA är osignerad. Den behöver signeras/installationshanteras av FlareStore eller motsvarande innan enheten kan installera den.

**Berörda filer**
- `Documentation/DEVELOPMENT_LOG.md`

**Kvarstår**
- Installera via FlareStore och kontrollera appstart, navigation, kalender och inköpslista på fysisk iPhone.
- Kontrollera notisikonens utseende på enheten.
- Åtgärda den icke-blockerande Swift-varningen i ett separat litet underhållsarbete.
- PR #4 hålls fortsatt öppen som draft; ingen merge har gjorts.


## 2026-11-23 – Städa Swift-varning efter grön CI

**Fynd**
- Senaste CI-körningen `45159145961` passerade med 79 tester utan fel samt simulator- och iPhone Release-bygge.
- Kompilatorn rapporterade en icke-blockerande varning i `Tests/LocalFamilyStoreTests.swift:518`: `.none` tolkades som `Optional.none` i stället för enumvärdet.

**Åtgärd**
- Kvalificerade värdet med den explicita typen `FamilyRecurrenceFrequency.none` för att undanröja tvetydigheten.

**Berörda filer**
- `Tests/LocalFamilyStoreTests.swift`
- `Documentation/DEVELOPMENT_LOG.md`

**Verifiering**
- Ändringen är incheckad och ny CI-körning startar automatiskt.
- Föregående kodcommit har 79/79 godkända tester och en godkänd unsigned iPhone-build. Denna lilla varningsfix måste också passera CI innan den betraktas som verifierad.

**Kvarstår**
- Installera senaste IPA via FlareStore och testa funktionerna på fysisk iPhone.
- Kontrollera notisikon visuellt på enheten.
- PR #4 lämnas öppen som draft.


## 2026-11-23 – Fullständig CI-verifiering efter varningsfix

**CI-resultat**
- GitHub Actions-körning: [45163360241](https://github.com/72cbbw422f-alt/fam/actions/runs/45163360241).
- Verifierad kodcommit: `821161440687b98eb388e8cedc3d89eda259b8e2` på `feature/ux-navigation-shopping`.
- Simulatorjobbet passerade ikonrendering, XcodeGen, Swift package resolution, enhetstester och simulatorbygge.
- Testresultat: 79 tester, 0 fel. Xcode-loggen avslutades med `TEST SUCCEEDED`.
- iPhone-jobbet passerade Release-build, paketering och uppladdning av osignerad IPA.
- Den tidigare tvetydiga `.none`-varningen i `Tests/LocalFamilyStoreTests.swift` återfinns inte i den nya testloggen efter att värdet kvalificerats som `FamilyRecurrenceFrequency.none`.
- Xcode rapporterar fortfarande en icke-blockerande App Intents-metadata-varning eftersom appen inte har någon `AppIntents.framework`-dependency.

**IPA**
- Artifact: `Familjen-unsigned-IPA`, ID `14814400977`.
- Byggd från verifierad kodcommit `821161440687b98eb388e8cedc3d89eda259b8e2`.
- Storlek: 2 646 272 byte.
- Artifact-länk: [GitHub Actions 45163360241](https://github.com/72cbbw422f-alt/fam/actions/runs/45163360241).
- Artefakten är osignerad och behöver installeras/signeras via FlareStore eller motsvarande. Fysisk iPhone-installation är inte verifierad.

**Berörda filer i denna dokumentationsuppdatering**
- `Documentation/DEVELOPMENT_LOG.md`

**Kvarstår**
- Fysisk iPhone-testning av appstart, översiktsnavigation, svensk kalender och inköpslistans kategorier/Handlat-flöde.
- Verifiera appikonens och notisikonens visuella utseende på enheten.
- PR #4 hålls öppen som draft; ingen merge har gjorts.


## 2026-11-23 – Inköpslista: helradstryck och svenska tidsformat

**Ändringar**
- Hela inköpsvarans rad är nu en tryckyta. Tryck var som helst på raden markerar varan som handlad; ett nytt tryck i Handlat återställer den. Svep för manuell borttagning finns kvar.
- Startsidan använder nu explicit `sv_SE` för klockslag, datum, veckodagar och relativa tidsangivelser. Detta åtgärdar engelska värden som "Tuesday" och "13 seconds ago" när telefonens språkregion inte är svenska.
- Varuförslag har lagts till för en första svensk katalog med vanliga livsmedel och hushållsvaror. Matchning ignorerar skiftläge/diakritiska skillnader, prioriterar prefix och filtrerar bort redan aktiva varor. Val av förslag lägger till varan i föreslagen kategori.
- Regressionstester tillagda för sökträffar, kategori och filtrering av redan tillagda varor.

**Berörda filer**
- `Sources/Domain/ShoppingModels.swift`
- `Sources/Data/ShoppingListViewModel.swift`
- `Sources/ShoppingListView.swift`
- `Sources/DashboardView.swift`
- `Tests/LocalFamilyStoreTests.swift`

**Verifiering**
- Kod incheckad på `feature/ux-navigation-shopping`.
- CI-körning `45167892315` för commit `1bc3edecc2943aa28cac29457678cb524bc8eb6d` startade men är ännu inte avslutad vid dokumentationstillfället. Den täcker varuförslag och svensk datumformatering.
- Helradstryck lades till i efterföljande commit och behöver ingå i nästa gröna CI-körning.
- Fysisk iPhone-testning krävs fortfarande för att kontrollera känslan i interaktionen och datumvisningen.

**Vintrig toppbild**
- En ny vinterbild har genererats som designunderlag. Den har ännu inte lagts in i appens asset catalog eller kopplats till `SeasonalFamilyHero`. Ingen bildväxling i appen ska betraktas som färdig innan asseten är incheckad och CI-byggd.


**Säsongsbanner – vinter**
- Ändrade säsongslogiken så att november också använder vinterscenen, med fortsatt prioritet för advent, Lucia och jul.
- Uppdaterade vinterscenen med snötäckta granar, måne och snöflingor i den befintliga vektorbaserade SwiftUI-illustrationen.
- Den genererade fotorealistiska vinterbilden användes som visuellt inspirationsunderlag men är inte incheckad som bildasset. Bannerbytet är därför en uppdaterad inbyggd illustration, inte ett foto.
- Fil: `Sources/SeasonalFamilyHero.swift`.
- Ändringen inväntar CI-verifiering.


## 2026-11-23 – Säsongsbanner: datumuppdatering och regressionstester

**Ändringar**
- Flyttade datumlogiken till den testbara SeasonalSceneResolver, med explicita gränser för årstider, advent, Lucia och jul.
- Startsidan uppdaterar nu sitt datum när kalenderdagen ändras, vid betydande tidsändring och när appen återgår till aktivt läge.
- Adventsberäkningen är separerad och hanterar datum före första advent som noll tända ljus.
- Säkerställde att advent kan börja redan i november; Lucia har fortsatt företräde den 13 december och julscenen gäller 24 december–6 januari.
- Lade till regressionstester för säsongs-/högtidsgränser och de fyra adventssöndagarna.

**Berörda filer**
- Sources/SeasonalFamilyHero.swift
- Tests/LocalFamilyStoreTests.swift
- Documentation/DEVELOPMENT_LOG.md

**Verifiering**
- Källkod och tester är incheckade på feature/ux-navigation-shopping.
- CI-verifiering inväntas. Inga nya testresultat eller IPA är ännu godkända från dessa ändringar.
- Fotorealistiska säsongsbilder är fortfarande inte integrerade; befintliga SwiftUI-illustrationer används tills riktiga bildassets har lagts in.

**Nästa steg**
- Granska CI-loggarna och korrigera eventuella kompilerings-/testfel.
- Därefter ta fram separata säsongs- och högtidsbilder som riktiga assets, med offline-fallback.
- PR #4 förblir öppen som draft; ingen merge.

- Efter kodgranskning lades UIKit-import till för den explicita UIApplication-tidsändringsnotisen och SeasonalScene deklarerades uttryckligen Equatable för stabila tester.

- Utökade datumtester med flera kalenderår där första advent infaller 1 december (2024) respektive 30 november (2025), och bytte scenassertions till direkt Equatable-jämförelse.


## 2026-11-24 – regressionstester för inköpslistans autocomplete

**Granskning**
- Bring-liknande förslag finns redan i `ShoppingItemSuggestion`: minst två tecken, svensk case-/diakritikokänslig matchning, prefixprioritering, exkludering av redan listade varor och högst sex förslag.
- Hela inköpsraden är redan en knapp som växlar mellan aktiv och handlad; handlade varor visas separat under **Handlat**.
- Dashboardens `SeasonalFamilyHero` är en lokalt renderad säsongsillustration som växlar automatiskt; november använder vinter/advent-logik enligt datum.

**Ändrat**
- Lade till `Tests/ShoppingItemSuggestionTests.swift` med regressionstäckning för minsta söklängd, svensk accent-/skiftlägesmatchning, prefixsortering, dubblettexkludering, resultatgräns och kategorimappning.
- Förfinade testerna för att använda verkliga svenska katalogposter, bland annat `Crème fraiche`.
- Commits: `674c5c5b1d477d29275c05044cc6ef717020d662` (första testfilen), `8db0b213addc057cf5fae2d0d29cb91ba8a7f824` (slutlig testversion).

**Verifiering**
- Testerna är incheckade på `feature/ux-navigation-shopping`.
- Ingen workflow-run har ännu rapporterats för commit `8db0b213addc057cf5fae2d0d29cb91ba8a7f824`; testresultat och byggstatus är därför ej verifierade.
- Nästa steg är att invänta/utlösa CI och granska resultatet innan funktionen markeras verifierad.
- Fysisk iPhone-testning av autocomplete, radtryck och säsongsillustration återstår.


## 2026-11-24 – korrigera CI-kompileringsfel i dashboardens datumformat

**CI-fynd**
- Workflow run `45441598539` på commit `3f611236699e4ae6983f54a5a03306bbd15533d4` misslyckades i unsigned iPhone-bygget. Simulatorjobbet avbröts innan det kunde ge testresultat.
- Kompilatorfelet var i `Sources/DashboardView.swift`: `Date.FormatStyle.Symbol.Month` saknar medlemmen `.long` i uttrycket `month(.long)`.
- Det här var ett befintligt kompileringsfel i den aktiva utvecklingsgrenen, inte ett fel i autocomplete-testernas logik.

**Åtgärd**
- Bytte till det giltiga formatalternativet `.month(.wide)`, vilket behåller avsikten att visa månadens fullständiga namn.
- Fil: `Sources/DashboardView.swift`.
- Commit: `130841df113291459fc8b8390a6a7df01eb531c5`.

**Verifiering**
- Korrigeringen är incheckad. Ny CI-körning för denna commit inväntas; bygget och de sex nya autocomplete-testerna är ännu inte verifierade.


## 2026-11-25 – inköpslista: hopfällbar handlat-sektion och större varukatalog

**Produktbeslut**
- Handlade varor visas i en hopfällbar sektion med antal; sektionen är stängd som standard.
- Varor kan återställas genom att trycka på dem när sektionen öppnas.
- Inköpslistans meny erbjuder både `Rensa handlade` och `Rensa hela listan`; båda kräver bekräftelse.
- Rensning av hela listan tar bort både aktiva och handlade varor. Ingen automatisk tidsbaserad rensning införs.

**Varukatalog**
- Utökade den lokala svenska katalogen från 47 till 342 förslag, fördelade på frukt & grönt, mejeri, kött & fisk, skafferi, frys och hushåll.
- Katalogen kontrollerades för unika sök-ID:n; inga dubbletter hittades.
- Behöll befintlig svensk tecken-/diakritikokänslig sökning, dubblettfiltrering och högst sex relevanta förslag åt gången.

**Teknik och test**
- Lade till repository-operationer för att rensa handlade respektive samtliga inköpsvaror.
- Lokal lagring återställer föregående lista i minnet om skrivningen misslyckas.
- Lade till regressionstester för rensning, persistens, rollback vid skrivfel och katalogens storlek/unikhet.
- Berörda filer: `Sources/Domain/ShoppingModels.swift`, `Sources/Data/FamilyRepository.swift`, `Sources/Data/LocalFamilyStore.swift`, `Sources/Data/ShoppingListViewModel.swift`, `Sources/ShoppingListView.swift`, `Tests/LocalFamilyStoreTests.swift`.

**GitHub**
- Gren: `feature/ux-navigation-shopping`.
- Bas-commit vid arbetets start: `479ddbb5171d1bea14c3a58fe02b44bc08fe4aa9`.
- Senaste kodcommit för denna ändring: `95f9784b55749919a7f052a2c13869ab81825c17`.
- Ingen merge till huvudgren genomförd.

**Verifiering**
- CI-tester och simulator-/iPhone-bygge ska köras på slutlig branch-head innan funktionerna betraktas som verifierade.
- Fysisk iPhone-kontroll återstår.


## 2026-11-25 – inköpslista: godis, snacks, dryck, glass och fika

**Varukatalog**
- Utökade den svenska katalogen från 342 till 723 unika förslag.
- Nya kategorier: Godis, Chips & snacks, Dryck, Glass samt Fika & sötsaker.
- Lade till svenska vardagsprodukter och välkända produkt-/märkesvarianter, inklusive choklad, lösgodis, chips, dipp, läsk, mineralvatten, juice, saft, energidryck, glasspinnar, glasspaket, bullar, kakor och tårtor.
- Kategorierna är separata i både förslagsrader och kategoriindelningen i inköpslistan.
- Befintliga kategorier och gamla varor utan sparad kategori behålls kompatibla.

**Kvalitet**
- Kontrollerade att katalogen inte innehåller dubbla normaliserade titlar: inga dubbletter hittades.
- Lade till regressionstester för att verifiera att nya kategorier och representativa varor finns i katalogen.
- Behöll befintlig sökordning, svensk diakritikhantering, filtrering av redan tillagda varor och sex synliga förslag.

**Filer**
- `Sources/Domain/ShoppingModels.swift`
- `Tests/LocalFamilyStoreTests.swift`
- `Documentation/DEVELOPMENT_LOG.md`

**GitHub**
- Gren: `feature/ux-navigation-shopping`.
- Senaste kod-/testcommit: `b82d85a73debb7a9d10628c8713aa7b71ccfc705`.
- Ingen merge till huvudgren genomförd.

**Verifiering**
- CI ska verifiera kompilering och regressionstester innan katalogutökningen betraktas som färdig.
- Ingen IPA byggd för denna ändring ännu.

 
## 2026-11-25 – inköpslista: aliasbaserad sökning

**Ändringar**
- Lade till valfria sökalias per katalogvara. Alias påverkar sökträffar men skapar inte separata produkter eller dubbletter i listan.
- Normaliserar sökord genom svensk case-/diakritikhantering och skiljeteckensnormalisering, så exempelvis ”Coca Cola”, ”Coca-Cola” och ”coke” kan hitta samma kanoniska produkt.
- Prioriterar titelprefix, därefter aliasprefix och sedan delträffar. Behåller gränsen på sex förslag.
- Lade till alias för Coca-Cola-varianter som första konkreta aliasgrupp.

**Berörda filer**
- Sources/Domain/ShoppingModels.swift
- Tests/ShoppingItemSuggestionTests.swift
- Documentation/DEVELOPMENT_LOG.md

**Tester**
- Regressionstester tillagda för alias, skiljetecken, skiftläge, prioritering och filtrering när kanonisk vara redan finns.
- Testerna är ännu inte körda; CI-verifiering inväntas.

**GitHub**
- Arbetsgren: feature/shopping-search-aliases.
- Baserad på feature/ux-navigation-shopping vid commit 47c228a49fe82448ffb1f8ef1b2f860b748a7469.
- Ingen merge genomförd.


## 2026-11-25 – CI-trigger för aliasgrenen

**Fynd**
- Granskning av `.github/workflows/ios-build.yml` visade att workflow endast lyssnade på push till `main`, `local-first-beta`, `feature/health-foundation` och `feature/ux-navigation-shopping`.
- `feature/shopping-search-aliases` saknades i listan. Därför startades ingen GitHub Actions-körning för aliascommitten; tom CI-status var ett konfigurations-/triggerproblem, inte ett godkänt testresultat.

**Åtgärd**
- Lade till `feature/shopping-search-aliases` i workflowets push-brancher.
- Fil: `.github/workflows/ios-build.yml`.
- Commit: `9903ca7008290a657860b119ec04b9f5bcc3376c`.

**Verifiering**
- Workflow-filen är uppdaterad och incheckad på aliasgrenen.
- Vid första kontrollen efter committen hade GitHub ännu inte exponerat någon workflow-run eller statuskontroll för SHA:n. Test och bygg är därför fortfarande ej verifierade.
- Nästa kontroll: bekräfta att simulatorjobb, enhetstester och unsigned iPhone-build faktiskt startar och slutförs för aktuell branch-head.
- Ingen merge och ingen IPA-distribution har genomförts.


## 2026-11-25 – inköpslista: favoritvaror

**Ändringar**
- Införde en lokal, beständig lista över favoritvaror i inköpskatalogen.
- Favoriter kan markeras direkt i sökförslagen med stjärnikon.
- En separat sektion **Favoriter** visar sparade katalogvaror och låter användaren lägga till dem i inköpslistan med ett tryck.
- Favoriter kan tas bort från sektionen och sorteras alfabetiskt.
- Favoritlistan sparas i samma lokala snapshot som övriga familjedata. Det nya snapshotfältet är valfritt vid avkodning för bakåtkompatibilitet med äldre installationer.
- Dubbletter förhindras med skiftlägesokänslig jämförelse. Skrivfel vid persistens återställer föregående favoritlista.

**Berörda filer**
- `Sources/Data/FamilyRepository.swift`
- `Sources/Data/LocalFamilyStore.swift`
- `Sources/Data/ShoppingListViewModel.swift`
- `Sources/ShoppingListView.swift`
- `Tests/LocalFamilyStoreTests.swift`
- `.github/workflows/ios-build.yml`

**Tester**
- Tillagt persistens-/reload-test som även kontrollerar dubblettskydd och borttagning.
- Testet är incheckat men ännu inte kört. CI-resultat inväntas.
- Fysisk iPhone-testning av stjärnknappar och favoritsektionen återstår.

**GitHub**
- Gren: `feature/shopping-favorites`, baserad på `feature/shopping-search-aliases`.
- CI-triggern utökad till den nya grenen.
- Ingen merge genomförd.


### 2026-11-25 – korrigera ett för strikt söktest

**Fynd**
- CI på commit `e6a42f2d745311d6f9d19c964d62da55c078e398` visade 1 fel av 97 tester: `ShoppingItemSuggestionTests.testExistingItemsAreExcludedWithoutCaseOrDiacriticSensitivity`.
- Felet låg i testets förväntan att både `Mellanmjölk` och `Lättmjölk` alltid skulle synas i samma breda sökning. Sökfunktionen har avsiktligt en sexresultatsgräns och prioriterar prefixträffar; därför var förväntan inte stabil när katalogen växte.

**Åtgärd**
- Behöll kontrollen att befintlig vara `MJÖLK` exkluderas utan skiftlägeskänslighet.
- Verifierar nu suffixvarorna med separata, fokuserade sökningar (`mellan` respektive `lätt`) i stället för att anta att båda ryms i samma begränsade resultatlista.
- Fil: `Tests/ShoppingItemSuggestionTests.swift`.
- Commit: `eefe4903d2a50610ceea194431496b19076777d1`.

**Verifiering**
- Ny CI-körning krävs på den här committen. Ingen test- eller simulatorbyggstatus markeras som godkänd ännu.
- Unsigned iPhone-bygget och IPA-paketeringen lyckades i föregående körning, men det ersätter inte simulatorns testsvit.

## 2026-11-25 – kvalitetssäkring av favoritvaror

**Granskning och ändring**
- Granskning av favoritlagringen visade att repository-metoden kunde anropas innan en familj hade skapats. UI-flödet exponerar normalt inte detta, men lagringslagret ska själv upprätthålla invarianten.
- Begränsade därför favoritändringar till ett initierat familjeutrymme. Ogiltiga anrop före familjeuppläggning lämnar favoritlistan orörd.
- Lade till regressionstest som provar anrop före familjeskapande och verifierar att favorit kan sparas efteråt.

**Berörda filer**
- `Sources/Data/LocalFamilyStore.swift`
- `Tests/LocalFamilyStoreTests.swift`
- `.github/workflows/ios-build.yml`

**Verifiering**
- Nytt regressionstest är incheckat; CI för denna arbetsgren inväntas.
- Senaste verifierade bas är PR #7, commit `14a4475c6f5fec20b46ee5db97496ee2de8252b0`, där simulatorns testjobb och osignerade iPhone-bygget passerade.
- Fysisk iPhone-testning återstår.

**GitHub**
- Arbetsgren: `feature/shopping-recurring-items`, skapad från `feature/shopping-favorites`.
- PR #7 lämnas öppen som Draft. Ingen merge genomförd.


## 2026-11-25 – avstämning av kalenderns översikt och aktivitetsdetaljer

**Granskning**
- Roadmapens kvarstående punkter för månadsöversikt, aktivitetsdetaljer och kontextmeny jämfördes med den aktuella implementationen.
- Funktionerna finns redan i `FamilyCalendarView.swift`: månadsrutnät med svenska veckonummer och aktivitetsmarkeringar, separat detaljvy vid tryck samt kontextmeny med Redigera/Radera och svep för radering.
- Detaljvyn visar datum, tid, berörda personer, ansvarig, plats, anteckningar, påminnelser och återkomst. Kartlänk visas när koordinater finns.

**Dokumentation**
- Markerade dessa tre roadmap-punkter som implementerade och förtydligade att fysisk iPhone-verifiering återstår.
- Berörd fil: `Documentation/ROADMAP.md`.
- Ingen produktkod ändrades i denna avstämning. Workflowen `.github/workflows/ios-build.yml` uppdaterades så att den nya grenen omfattas av push-CI.

**Verifiering och begränsningar**
- Kodgranskning av `Sources/FamilyCalendarView.swift` genomförd.
- CI körs på grenen efter att push-triggern lagts till; verifiering av den slutliga commiten inväntas.
- Interaktionerna är inte fysiskt verifierade på iPhone i denna arbetsinsats; särskilt långtryck/context menu, listscroll och månadsväljaren behöver kontrolleras på enheten.
- Arbetsgren: `feature/calendar-event-details`.

## 2026-11-26 – synkronisera lokala påminnelser efter kalenderundantag

**Fynd**
- Vanlig kalenderredigering och borttagning via `FamilyStore` schemalägger om lokala påminnelser.
- Redigering av ett enskilt återkommande tillfälle (`saveOccurrenceOverride`) och avbokning av en förekomst (`skipOccurrence`) går direkt via repository i `FamilyCalendarViewModel` och utlöste inte motsvarande omschemaläggning.
- Det kunde lämna kvar en påminnelse för gammalt datum eller sakna en påminnelse för det flyttade tillfället tills nästa fullständiga schemaläggning.

**Ändrat**
- Lade till en gemensam metod som omschemalägger enhetens kalender- och hälsopåminnelser när lokala påminnelser är aktiverade.
- Anropar metoden efter lyckad sparning av ett enskilt tillfälles override, efter att en förekomst hoppats över och efter kalenderpost tagits bort.
- Använder repositoryts uppdaterade poster, undantag och overrides som underlag. Funktionen lämnar schemaläggningen orörd om användaren har stängt av lokala påminnelser.
- Berörd kodfil: `Sources/Data/FamilyCalendarViewModel.swift`.
- Befintliga scheduler-tester täcker redan flyttad förekomst, överhoppad förekomst och nästa giltiga återkomst. De körs på nytt i CI för denna gren.

**GitHub och verifiering**
- Gren: `feature/calendar-reminder-sync`, baserad på `feature/calendar-event-details`.
- Kodcommit: `01faf2a546f464e30de0a78d2f490801ddd1f45c`.
- CI och fysisk iPhone-verifiering inväntar resultat. Ingen merge har gjorts.


## 2026-11-26 – deduplicering och städning av lokala påminnelser

**Granskning**
- Den första CI-körningen för kalenderändringarna är grön: 98 tester passerade utan fel, simulatorbygget lyckades och osignerad iPhone-IPA paketerades.
- Granskningen av påminnelseschemaläggaren visade att upprepade påminnelseintervall redan dedupliceras vid kandidatgenerering, men detta saknade ett direkt regressionstest.
- Städningen av gamla notiser filtrerade bort främmande appar och behöll önskade Familjen-ID:n. Samma identifierare kunde dock förekomma mer än en gång i indata och därmed skickas upprepade gånger till borttagningsanropet.

**Ändrat**
- Gjorde listan över inaktuella Familjen-notis-ID:n unik och deterministiskt sorterad.
- Lade till tester för dubbla påminnelseintervall, skydd av notiser som tillhör andra appar, bibehållna önskade hälsopåminnelser samt unik städlista.
- Berörda filer:
  - `Sources/LocalReminderScheduler.swift`
  - `Tests/LocalReminderSchedulerTests.swift`

**Verifiering**
- De nya testerna är incheckade men ännu inte körda. En ny GitHub Actions-körning inväntas.
- Senaste gröna bas före dessa tester: 98 tester, 0 fel; iPhone unsigned-build och IPA-paketering lyckades.
- Fysisk iPhone-verifiering av att flyttade, avbokade och borttagna händelser ger rätt notiser återstår.

**GitHub**
- Gren: `feature/calendar-reminder-sync`.
- Ingen merge genomförd.


## 2026-11-26 – regressionstester för avbokning av en kalenderförekomst

**Granskning**
- Genomgång av repositoryns återkomsthantering bekräftade att avbokning av en enskild förekomst ska vara idempotent och transaktionell.
- Implementationen hade redan skydd mot dubbla undantag och återställning vid skrivfel, men dessa två egenskaper saknade direkta tester i den dedikerade återkomsttestsviten.

**Ändrat**
- Lade till test som avbokar samma veckoförekomst två gånger och verifierar att endast ett undantag sparas och överlever omladdning.
- Lade till test som simulerar skrivfel vid avbokning och verifierar att undantaget återställs, att felet exponeras och att blockeringsfilen inte skrivs över.
- Berörd fil: `Tests/OccurrenceOverrideRestorationTests.swift`.

**Verifiering**
- Testerna är incheckade men inte körda ännu. CI-resultat inväntas.
- Tidigare verifierade bas för kalenderpåminnelsegrenen: 98 tester passerade; simulator- och osignerat iPhone-bygge lyckades före de senaste testtilläggen.
- Fysisk iPhone-verifiering av verklig notisleverans återstår.

**GitHub**
- Gren: `feature/calendar-reminder-sync`.
- Ingen merge genomförd.


**CI-trigger för senaste regressionstesterna**
- Uppdaterade workflow-kommentaren på samma arbetsgren för att skapa en ny push-händelse och begära CI på senaste testcommitten.
- Workflow-commit: `d26168f360153193829f37d1d02e8d207ebea67e`.
- Workflowen omfattar fortsatt `feature/calendar-reminder-sync`.
- GitHub Actions-resultat för den nya head-commiten är ännu inte synligt via tillgängliga statuskontroller; därför redovisas de nya testerna fortfarande som ej verifierade.


## 2026-11-26 – gemensamt kapacitetstak för kalender- och hälsopåminnelser

**Granskning**
- Hittade en prioriteringsbugg i `LocalReminderScheduler`: kalenderkandidater begränsades till 60 innan hälsopåminnelser lades till.
- Om familjekalendern hade minst 60 kommande påminnelser kunde därför hälsopåminnelser helt trängas undan, trots att båda typerna senare sorteras och delar samma systemgräns.

**Ändrat**
- Tog bort det för tidiga taket i kalenderkandidatgenereringen.
- Det gemensamma taket på 60 tillämpas nu efter att kalender- och hälsopåminnelser slagits samman och sorterats efter när de ska skickas.
- Lade till regressionstest som verifierar att kandidatgenereringen inte kapar kalenderlistan innan sammanslagningen.
- Berörda filer: `Sources/LocalReminderScheduler.swift`, `Tests/LocalReminderSchedulerTests.swift`.

**Verifiering**
- Nytt test är incheckat men inte kört; CI inväntas.
- Den faktiska schemaläggningen behåller fortsatt ett totalt tak på 60 väntande Familjen-påminnelser.
- Fysisk iPhone-verifiering återstår.


## 2026-11-26 – verifiera faktiskt urval under gemensamt påminnelsetak

**Fynd och åtgärd**
- Det tidigare regressionstestet visade att kalenderkandidatgenereringen inte längre kapar listan före sammanslagningen, men bevisade inte direkt att hälsopåminnelser får rätt plats i det slutliga urvalet.
- Bröt därför ut den faktiska sorterings- och kapacitetslogiken till LocalReminderScheduler.selectCandidates.
- Produktionsschemaläggningen använder nu samma rena funktion som testerna, vilket undviker att test och produktionskod provar två olika urvalsalgoritmer.
- Lade till test med 75 senare kalenderpåminnelser och en tidigare hälsopåminnelse. Testet förväntar 60 valda kandidater, inklusive hälsopåminnelsen och 59 kalenderpåminnelser.
- Lade även till test för gränsfallet kapacitet 0.

**Berörda filer**
- Sources/LocalReminderScheduler.swift
- Tests/LocalReminderSchedulerTests.swift
- Documentation/DEVELOPMENT_LOG.md

**Commits**
- Produktionskod: 821c55798bfe10ce3f7108d7516e966fab371118.
- Regressionstester: 606510c9a869210ce6f62a5e04b3a7c9a3e68cb1.

**Verifiering**
- Källkod och tester är incheckade på feature/calendar-reminder-sync.
- Testerna är ännu inte körda i GitHub Actions; inget grönt CI-resultat hävdas för dessa commits.
- Fysisk iPhone-testning och faktisk notisleverans återstår.
- PR #11 förblir draft och har inte mergats.


## 2026-11-28 – Reminder scheduler review follow-up
- Corrected the shared-capacity regression test's calendar identifier interpolation so generated identifiers include each candidate index.
- Prevented occurrence skip/delete flows from scheduling reminders after a failed repository persistence operation. The repository's rollback state is retained and no unnecessary notification reconciliation is started.
- Verification: source review and GitHub content updates only. No local Xcode/Swift test run was available; latest CI status remains to be checked.
- Files: `Tests/LocalReminderSchedulerTests.swift`, `Sources/Data/FamilyCalendarViewModel.swift`, `Documentation/DEVELOPMENT_LOG.md`.


## 2026-11-28 – deterministisk urval och granskning av notifieringsfel
- Granskade schemaläggarens serialisering: varje `schedule`-/`clearAll`-operation väntar på föregående operation innan den läser/ändrar notifieringscentret. Behöll denna ordning.
- Bekräftade att schemaläggaren försöker lägga till/uppdatera önskade notiser innan inaktuella Familjen-notiser tas bort. Om minst ett tillägg misslyckas avbryts städningen, så gamla fungerande notiser inte rensas bort i ett partiellt misslyckat varv.
- Tog bort en oanvänd identifierarhjälpare.
- Lade till regressionstester för deterministisk identifierarsortering vid lika utskickstid och för att de närmaste kandidaterna väljs även när indata kommer i omvänd ordning.
- Berörda filer: `Sources/LocalReminderScheduler.swift`, `Tests/LocalReminderSchedulerTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: ändrade filer återhämtade från GitHub och granskade. Ingen lokal Swift/Xcode-körning; GitHub Actions visar ännu inga statusar eller workflow-runs för aktuell head.



## 2026-11-28 – omschemaläggning även efter vanlig kalenderredigering
- Kodgranskningen visade att `FamilyCalendarViewModel.save(...)` skrev kalenderposten direkt via repositoryt och returnerade efter lyckad lagring utan att anropa den lokala påminnelseschemaläggaren.
- Följden var att ändrade datum, tider eller påminnelseintervall via det vanliga kalenderformuläret kunde lämna kvar gamla lokala notiser. Flödena för förekomstundantag och borttagning hade redan uttrycklig omschemaläggning.
- Lade därför till samma `rescheduleLocalRemindersIfEnabled()` efter lyckad och beständig vanlig kalenderlagring. Misslyckad lagring returnerar fortsatt innan omschemaläggning, och avstängda lokala påminnelser lämnas orörda.
- Berörd fil: `Sources/Data/FamilyCalendarViewModel.swift`.
- Commit: `4a8601d7ffad09a85b111ccdc3cb15dd874034fb`.
- Verifiering: kodväg granskad och ändringen incheckad på `feature/calendar-reminder-sync`. Ingen Swift/Xcode-körning; CI saknar ännu körning/status för tidigare head och måste kontrolleras mot den nya committen. Fysisk iPhone-verifiering återstår.


## 2026-11-28 – kalenderkoppling följer status för hälsoärenden
- Granskningen visade att hälsoärenden av typen vårdbesök/uppföljning behöll en kalenderpost även när status ändrades till genomfört eller avbokat. Det kunde lämna en missvisande kalenderpost och lokala påminnelser kopplade till ett avslutat ärende.
- Ändrade synkroniseringen så att endast aktiva ärenden (planerat eller inväntar svar) har en länkad kalenderpost. Genomfört/avbokat ärende behålls i hälsohistoriken men dess kalenderpost tas bort och kalenderkopplingen nollställs.
- Lade till regressionstest som verifierar att planerat besök skapar kalenderpost och att statusövergång till genomfört respektive avbokat tar bort kalenderposten utan att radera hälsoärendet.
- Berörda filer: `Sources/Data/LocalFamilyStore.swift`, `Tests/HealthReminderSchedulerTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: ändringar incheckade på `feature/calendar-reminder-sync`; ingen lokal Swift/Xcode-körning. CI-status för aktuell gren/head behöver inväntas. Ingen merge.


## 2026-11-28 – avslutade hälsoärenden städar även fristående påminnelser
- Fortsatt granskning av hälsoflödet visade att record-kopplade HealthReminder kunde leva kvar efter att ett ärende markerats genomfört eller avbokat, trots att kalenderposten togs bort.
- Vid status genomfört/avbokat tas nu även påminnelser med targetType `record` och targetID för ärendet bort. Historikposten bevaras.
- Rollback vid misslyckad lagring återställer även påminnelselistan.
- Regressionstest tillagt för att kontrollera att record-påminnelsen försvinner både ur minnet och efter omladdning från disk.
- Inställningstexten korrigerad: iOS frågar om notisbehörighet när användaren aktiverar lokala påminnelser första gången, inte vid första appstart.
- Berörda filer: `Sources/Data/LocalFamilyStore.swift`, `Tests/HealthReminderSchedulerTests.swift`, `Sources/FamilySettingsView.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: ändringarna incheckade på `feature/calendar-reminder-sync`. Ingen Swift/Xcode-körning; CI-status saknas för senaste head. Ingen merge och ingen IPA.



## 2026-11-28 – kontroll av notisbehörighet när appen återgår till förgrunden
- Granskningen visade att inställningsvyn schemalade om påminnelser när den öppnades, men inte kontrollerade om användaren hunnit återkalla notisbehörigheten i iOS-inställningarna. Den lokala inställningsflaggan kunde därför fortsätta visa påminnelser som aktiverade trots att iOS inte längre tillät notiser.
- Inställningsvyn kontrollerar nu den faktiska notisbehörigheten vid öppning och när appen återgår till aktivt läge. Vid tillåten, provisorisk eller tillfällig behörighet synkroniseras schemat om mot aktuell familjedata. Vid nekad eller ännu ej bestämd behörighet stängs den lokala påminnelseflaggan av och Familjens gamla väntande/levererade notiser rensas.
- Okänd framtida behörighetsstatus lämnar användarens flagga orörd och visar ett kontrollmeddelande.
- Berörd fil: `Sources/FamilySettingsView.swift`.
- Commit: `528ee16ff54393ca8298f6e8861912894a11eb74`.
- Verifiering: kodändringen är incheckad på `feature/calendar-reminder-sync`. Ingen lokal Xcode/Swift-körning; CI för denna commit inväntas. Ingen fysisk iPhone-testning eller IPA.



## 2026-11-28 – granskning av tidszoner, sommartid och levererade notiser
- Granskade hur kalender- och hälsopåminnelser räknar fram utskickstid och hur den skickas till UserNotifications.
- Kandidater använder ett absolut `Date`-värde. Påminnelseintervall dras av i sekunder från händelsens absoluta starttid; veckovis/månadsvis/årlig återkomst projiceras däremot med en gregoriansk `Calendar` i aktuell tidszon för att behålla lokal kalenderdag och klocktid.
- Schemaläggaren bygger kompletta datumkomponenter (år, månad, dag, timme, minut, sekund) från det beräknade utskickstillfället och sätter uttryckligen både kalender och tidszon. Granskningen hittade därför ingen belagd DST-/tidszonsbugg som motiverar att byta till en annan triggerstrategi.
- Befintliga levererade Familjen-notiser tas med i städningen. När utskickstiden passerat skapas inte längre kandidaten (den måste ligga efter `now`), och dess levererade notis tas därmed bort som inaktuell vid nästa lyckade schemaläggning. Önskade notiser rensas inte om ett tillägg misslyckas.
- Inga kodändringar gjordes i denna granskning. DST-beteende över verkliga tidsomställningar och resor behöver fortfarande verifieras på enhet/simulator; denna kodläsning är inte ett runtime-test.
- Berörda filer granskade: `Sources/LocalReminderScheduler.swift`, `Sources/Data/DashboardViewModel.swift`, `Tests/LocalReminderSchedulerTests.swift`.
- Verifiering: endast källkodsgranskning. Ingen Swift/Xcode-körning; CI saknar fortfarande körning/status för aktuell head.



## 2026-11-28 – notisbehörighet begärs först efter aktivt val
- Fortsatt granskning av appens startflöde visade att `RootView` fortfarande begärde notisbehörighet automatiskt vid första appstart och slog på lokala påminnelser direkt om iOS gav tillstånd. Det stämde inte med inställningstexten eller det avsedda opt-in-flödet där användaren själv aktiverar påminnelser.
- Tog bort den automatiska behörighetsbegäran från appstart. Behörighetsfrågan visas nu först när användaren slår på lokala påminnelser i Inställningar.
- Appstarten behåller däremot en tyst avstämning för användare som redan aktiverat påminnelser: vid tillåten/provisorisk/tillfällig behörighet synkroniseras schemat, och vid nekad/ej bestämd behörighet stängs flaggan av och gamla Familjen-notiser rensas.
- Berörd fil: `Sources/RootView.swift`.
- Commit: `26ac91f40fb0de8132096a177ccf0d622734e299`.
- Verifiering: kodväg granskad och filen incheckad. Ingen lokal Xcode/Swift-körning; CI för aktuell head inväntas. Fysisk iPhone-verifiering av att behörighetsdialogen endast visas efter aktivt val återstår.

## 2026-11-28 – rullande kö för återkommande kalenderpåminnelser
- Granskningen visade att schemaläggaren endast projicerade nästa förekomst per återkommande kalenderpost. Om appen inte öppnades igen efter att den påminnelsen skickats kunde kommande veckor sakna förhandsplanerade notiser.
- Schemaläggaren bygger nu en rullande kö med upp till 12 kommande förekomster per återkommande serie. Varje iteration använder samma kalenderprojektion som appens översikt, vilket bevarar hanteringen av överhoppade datum och flyttade undantag utan att ändra vad kalendern visar.
- Icke återkommande poster behåller tidigare beteende. Det gemensamma taket på 60 kalender- och hälsopåminnelser tillämpas fortsatt efter sammanslagning och sortering.
- Lade till regressionstest som verifierar 12 unika veckoförekomster i kronologisk ordning.
- Berörda filer: `Sources/LocalReminderScheduler.swift`, `Tests/LocalReminderSchedulerTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: kod och test är incheckade på `feature/calendar-reminder-sync`. Ingen lokal Swift/Xcode-körning; CI-resultat för aktuell head inväntas. Test på fysisk iPhone och faktisk notisleverans återstår. Ingen IPA byggd och ingen merge genomförd.

## 2026-11-28 – stoppa notisomschemaläggning efter misslyckad lagring
- Granskning av hälsorepositoryts transaktioner visade att FamilyStore alltid startade notisomschemaläggning efter ett mutationsanrop, även när LocalFamilyStore hade återställt data efter ett skrivfel.
- Lade ett gemensamt skydd i FamilyStore så att notisomschemaläggning endast startar när repositoryts senaste persistensstatus är felfri. Skyddet gäller de kalender- och hälsomutationer som använder den gemensamma schemaläggningsmetoden.
- Lade till ett fokuserat regressionstest för både lyckad och misslyckad persistensstatus.
- Berörda filer: `Sources/Data/FamilyStore.swift`, `Tests/HealthReminderSchedulerTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: kod och test incheckade på `feature/calendar-reminder-sync`. Ingen lokal Swift/Xcode-körning; CI för senaste head inväntas. Ingen IPA eller fysisk enhetstestning.

## 2026-11-28 – städa record-påminnelser när kalenderkopplad vårdtid avbokas
- Hittade en livscykellucka: när en kalenderpost som representerar ett vårdbesök togs bort eller ändrades till en vanlig händelse markerades vårdposten som avbokad, men separata `HealthReminder` kopplade till vårdposten kunde ligga kvar.
- Både borttagning och ändring av kalenderpost tar nu bort record-påminnelser för den avbokade vårdposten. Historikposten bevaras med status avbokad.
- Lagringsrollback återställer även påminnelselistan om skrivningen misslyckas.
- Lade till regressionstester för borttagning och typändring, inklusive kontroll efter omladdning för borttagningsfallet.
- Berörda filer: `Sources/Data/LocalFamilyStore.swift`, `Tests/HealthReminderSchedulerTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: källkod och tester incheckade; testinterpolation kontrollerad i GitHub-filen. Ingen lokal Swift/Xcode-körning och inget CI-resultat för aktuell head ännu. Ingen IPA byggd.

## 2026-11-28 – normalisera dubbletter av länkade hälsopåminnelser
- Granskningen av receptförnyelse visade att upsert-funktionen bara uppdaterade eller tog bort den första påminnelsen för ett visst mål. Om äldre data eller import innehöll flera påminnelser med samma target kunde dubbletter därför överleva, även när receptet markerades som förnyat.
- Upsert normaliserar nu varje länkad target till högst en aktiv påminnelse. När målet inte längre ska påminnas tas samtliga matchande påminnelser bort.
- Lade till regressionstest som skapar en dubblett, verifierar att uppdatering lämnar en enda schemalagd påminnelse och att statusen förnyat tar bort den helt.
- Berörda filer: `Sources/Data/LocalFamilyStore.swift`, `Tests/HealthReminderSchedulerTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: kod och test incheckade och återhämtade från GitHub; interpolation kontrollerad. Ingen lokal Swift/Xcode-körning och inget CI-resultat för aktuell head ännu.

## 2026-11-28 – verifiering av recept- och läkemedelshämtningars livscykel
- Granskade statusövergångar för receptförnyelse och läkemedelshämtning. Befintlig lagringslogik tar bort receptpåminnelser när status inte längre är aktiv och tar bort hämtningspåminnelser när uthämtningen markeras hämtad eller avbokad.
- Bekräftade att borttagning av en läkemedelshämtning tar bort dess länkade påminnelser, medan borttagning av ett recept bevarar hämtningshistoriken genom att koppla loss den från receptet.
- Lade till regressionstester för hämtad/avbokad läkemedelshämtning, borttagning av hämtning samt receptborttagning med bevarad uthämtningshistorik. Det tidigare testet för receptförnyelse verifierar också att länkade dubbletter normaliseras.
- Inga produktionsändringar behövdes i dessa statusflöden efter granskningen; den enda produktionsändringen i denna del är normalisering av dubbletter per länkad target.
- Berörda filer: `Sources/Data/LocalFamilyStore.swift`, `Tests/HealthReminderSchedulerTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: testkällan återhämtad från GitHub och Swift-interpolation kontrollerad. Ingen lokal Swift/Xcode-körning och inget CI-resultat för aktuell head ännu.

## 2026-11-28 – blockera nya påminnelser för avslutade hälsomål
- Granskningen av den publika lagringsvägen för HealthReminder hittade en lucka: valideringen kontrollerade att länkad post och familjemedlem fanns, men inte att målet fortfarande var aktivt. Det gick därför att lägga till en ny record-påminnelse för ett genomfört vårdbesök, en förnyelsepåminnelse för ett redan förnyat recept eller en hämtningspåminnelse för läkemedel som redan hämtats/avbokats.
- Skärpte valideringen: record-påminnelser kräver status planerat/inväntar svar, receptpåminnelser kräver förnyelse due/requested och hämtningspåminnelser kräver status planned. Egna/custom-påminnelser påverkas inte.
- Lade till regressionstest som försöker skapa alla tre inaktiva länktyperna och verifierar att ingen sparas, inte heller efter omladdning.
- Berörda filer: Sources/Data/LocalFamilyStore.swift, Tests/HealthReminderSchedulerTests.swift, Documentation/DEVELOPMENT_LOG.md.
- Verifiering: kod och test återhämtade från GitHub; testets Swift-interpolation kontrollerad. Ingen lokal Swift/Xcode-körning och inget CI-resultat för aktuell head.

## 2026-11-28 – konsekvent borttagning av familjemedlem och hälsodata
- Dataintegritetsgranskningen hittade att borttagning av en familjemedlem endast tog bort medlemsprofilen och rensade kalenderns personkopplingar. Hälsoposter, recept, läkemedelshämtningar, hälsoprofilinformation och påminnelser kunde därför ligga kvar med ett memberID som inte längre fanns.
- Borttagning av en icke-ägande medlem tar nu bort den medlemmens personliga hälsodata och tillhörande påminnelser i samma persistenta transaktion. Kalenderhistorik som inte är ett länkat vårdbesök bevaras, men personkoppling och ansvarig tas bort. Kalenderposten som endast skapats av ett länkat vårdbesök tas bort tillsammans med hälsoposten.
- Rollback vid misslyckad lagring återställer alla berörda samlingar. FamilyStore schemalägger om lokala notiser efter medlemsborttagning så att gamla notiser försvinner.
- Bekräftelsedialogen beskriver nu uttryckligen att personens hälsouppgifter, vårdbesök, recept och läkemedelshämtningar också tas bort.
- Lade till regressionstest som verifierar borttagning av personliga hälsodata och notiser, bevarad övrig kalenderhistorik samt resultat efter omladdning.
- Berörda filer: Sources/Data/LocalFamilyStore.swift, Sources/Data/FamilyStore.swift, Sources/FamilyMembersView.swift, Tests/LocalFamilyStoreTests.swift, Documentation/DEVELOPMENT_LOG.md.
- Verifiering: kod/test/dokumentation återhämtade och kontrollerade via GitHub. Ingen lokal Swift/Xcode-körning; CI för aktuell head inväntas.

## 2026-11-28 – korrigera Swift-keypath i återkomsttest
- Källkodsgranskning av den senaste PR-headen hittade ett extra escapetecken i keypath-uttrycket i testet för 12 kommande veckoförekomster. Det skulle ge ett Swift-kompileringsfel innan testet kunde köras.
- Korrigerade uttrycket till `candidates.map(\\.id)` i `Tests/LocalReminderSchedulerTests.swift`.
- Commit: `9dafbd77e10abc396e4541ec2f2a748310e85393`.
- Verifiering: uppdaterad fil återhämtas och kontrolleras från GitHub. Ingen lokal Swift/Xcode-körning; CI för den nya head-commiten måste inväntas. Ingen IPA och ingen merge.

## 2026-11-28 – städa presentkopplingar vid borttagning av familjemedlem
- Granskningen av profilborttagning hittade två kvarvarande referensproblem: presentidéer kunde ligga kvar med ett borttaget memberID, och julklappar kunde behålla en ansvarig person som inte längre fanns.
- Vid borttagning tas nu presentidéer för profilen bort. Julklapparnas historik och mottagare bevaras, men ansvarig koppling nollställs när den pekar på den borttagna profilen.
- Båda samlingarna ingår nu i samma rollback-snapshot som övrig medlemsdata. Ett misslyckat skrivförsök återställer presentidéer och julklappsansvar tillsammans med profilen.
- Lade till regressionstest för lyckad borttagning/omladdning samt separat test för rollback vid persistensfel.
- Berörda filer: `Sources/Data/LocalFamilyStore.swift`, `Tests/LocalFamilyStoreTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: källkod och test har uppdaterats via GitHub och ska återhämtas för kontroll. Ingen lokal Swift/Xcode-körning; CI för senaste head inväntas. Ingen IPA och ingen merge.

## 2026-11-28 – hålla presentidéer synkroniserade med födelsedagar
- Fortsatt granskning av kalenderhistorik visade att presentidéer kunde ligga kvar när deras födelsedagspost raderades eller ändrades till en vanlig kalenderaktivitet.
- Rensar nu presentidéer kopplade till födelsedagsposten när posten tas bort eller konverteras till annan aktivitetstyp. Redigering av datum/titel medan posten fortfarande är en födelsedag behåller idéerna.
- Presentidéerna ingår i rollback-snapshot för både kalenderredigering och borttagning.
- Lade till regressionstest för borttagning av födelsedag och konvertering till vanlig aktivitet.
- Berörda filer: `Sources/Data/LocalFamilyStore.swift`, `Tests/LocalFamilyStoreTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: ändringar återhämtas och granskas via GitHub. Ingen lokal Swift/Xcode-körning; CI för aktuell head inväntas. Ingen IPA och ingen merge.

## 2026-11-28 – transaktionssäker presenthantering och födelsedagskopplingar
- Fortsatt granskning hittade att `deleteItem` tog bort presentidéer i minnet men inte återställde dem om snapshot-skrivningen misslyckades. Rollback återställer nu även presentidéerna.
- Tog bort en redundant rollback-tilldelning i `saveCalendarItem`.
- `addGiftIdea` och `addChristmasGift` återställer nu sina samlingar om lagringen misslyckas, i linje med befintliga update/delete-operationer.
- Presentidéer måste nu tillhöra en medlem som faktiskt är kopplad till födelsedagsposten. När födelsedagens medlemskoppling ändras rensas idéer för tidigare/ej längre kopplade medlemmar.
- Lade till regressionstester för misslyckad födelsedagsradering, misslyckad skapning av presentidé/julklapp samt ändrad medlemskoppling.
- Berörda filer: `Sources/Data/LocalFamilyStore.swift`, `Tests/LocalFamilyStoreTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: källkod, testfall och dokumentation har återhämtats från GitHub och kontrollerats på filnivå. Ingen lokal Xcode/Swift-körning; aktuell CI är inte verifierad. Ingen IPA och ingen merge.

## 2026-11-28 – transaktionssäker profilskapning och tydlig lagringsfeedback
- Granskning av familjeprofilernas CRUD-flöde visade att `addChild` och `addMember` lade till profiler i minnet även om snapshot-skrivningen misslyckades. Båda operationerna återställer nu medlemslistan vid skrivfel.
- Familjeinställningarnas vy visar nu lagringsfelet vid misslyckad profilskapning eller borttagning i stället för att visa ett falskt framgångsmeddelande. Inmatningen behålls när skapningen misslyckas.
- Lade till regressionstest som verifierar rollback för både barn- och vuxenprofil när lagringen blockeras.
- Berörda filer: `Sources/Data/LocalFamilyStore.swift`, `Sources/FamilyMembersView.swift`, `Tests/LocalFamilyStoreTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: uppdaterade filer återhämtas och granskas via GitHub. Ingen lokal Xcode/Swift-körning; CI för senaste head inväntas. Ingen IPA och ingen merge.

## 2026-11-28 – atomisk uppdatering av familjeprofil
- Profilredigeraren sparade tidigare namn och ikon i två separata skrivningar. Vid ett tillfälligt lagringsfel kunde endast en av ändringarna bli beständig. Införde updateMemberProfile som validerar och sparar båda fälten i en enda transaktion med rollback.
- Profilredigeraren använder nu den atomiska metoden.
- Lade till regressionstest för lyckad uppdatering och rollback av både namn och ikon vid skrivfel.
- Berörda filer: Sources/Data/LocalFamilyStore.swift, Sources/FamilyMembersView.swift, Tests/LocalFamilyStoreTests.swift, Documentation/DEVELOPMENT_LOG.md.
- Verifiering: filer hämtas och granskas via GitHub. Ingen lokal Xcode/Swift-körning; aktuell CI är inte verifierad. Ingen IPA och ingen merge.

## 2026-11-28 – koppla atomisk profilredigering genom repository-lagret
- Granskning av lagergränsen visade att den nya atomiska updateMemberProfile-metoden först fanns i LocalFamilyStore men saknades i FamilyRepository-kontraktet och FamilyStore-fasaden. Det hade orsakat ett kompileringsfel i profilvyn.
- Lade till metoden i FamilyRepository och exponerade den via FamilyStore, som därefter uppdaterar publicerat UI-tillstånd genom refresh.
- Berörda filer: Sources/Data/FamilyRepository.swift, Sources/Data/FamilyStore.swift, Sources/Data/LocalFamilyStore.swift, Sources/FamilyMembersView.swift, Tests/LocalFamilyStoreTests.swift, Documentation/DEVELOPMENT_LOG.md.
- Verifiering: kontrakt, fasad och anrop har hämtats tillbaka från GitHub och jämförts. Ingen lokal Xcode/Swift-körning; CI för senaste head inväntas. Ingen IPA och ingen merge.

## 2026-11-28 – integritetsskydd för privata hälsoärenden i lokala notiser
- Fortsatt granskning hittade att privata hälsoärenden filtrerades bort från kalender- och dashboardvyerna men fortfarande kunde skickas till den lokala notisschemaläggaren via den gemensamma kalenderlistan.
- Lade till en gemensam filtreringsfunktion i LocalReminderScheduler som exkluderar kalenderposter länkade till hälsoärenden med visibility .personal.
- Gjorde privateHealthCalendarIDs till ett obligatoriskt argument för schemaläggning så att varje anrop måste ta ställning till privata kalenderkopplingar.
- Uppdaterade samtliga nuvarande produktionsanrop i FamilyStore, FamilyCalendarViewModel, FamilySettingsView och RootView. HealthReminders fortsätter schemaläggas enligt sina egna inställningar.
- Lade till regressionstest som bekräftar att en privat vårdpost inte genererar en lokal kalendernotis medan en vanlig familjeaktivitet fortfarande gör det.
- Berörda filer: Sources/LocalReminderScheduler.swift, Sources/Data/FamilyStore.swift, Sources/Data/FamilyCalendarViewModel.swift, Sources/FamilySettingsView.swift, Sources/RootView.swift, Tests/LocalReminderSchedulerTests.swift, Documentation/DEVELOPMENT_LOG.md.
- Verifiering: samtliga kända produktionsanrop och de uppdaterade filerna har hämtats tillbaka från GitHub och kontrollerats på källkodsnivå. Ingen lokal Xcode/Swift-körning; CI för senaste head är inte verifierad. Ingen IPA och ingen merge.


## 2026-11-28 – regressionstäckning för månadsdatum och skottår
- Fortsatt granskning av återkommande kalenderpåminnelser med fokus på månadsserier som startar den 29:e–31:a och årliga serier som startar den 29 februari.
- Lade till test som följer en månadsserie från 31 januari genom samtliga 12 månader. Det verifierar att korta månader klampar datumet (exempelvis 28 februari) men att serien återgår till ursprungsdagen när månaden tillåter det (31 mars).
- Lade till test av en årlig 29-februari-serie genom den rullande 12-förekomstkön: 28 februari under icke-skottår och 29 februari under skottår.
- Produktionslogiken ändrades inte eftersom källkodsgranskningen inte visade något belagt fel i dessa två datumregler.
- Berörd fil: `Tests/LocalReminderSchedulerTests.swift`.
- Verifiering: testfall och keypaths kontrollerade genom återhämtning från GitHub. Ingen lokal Swift/Xcode-körning; CI-status för den senaste head-commiten är ännu inte verifierad. Ingen IPA och ingen merge.


## 2026-11-28 – bevara identiteten för flyttade återkommande tillfällen
- Granskningen av återkommande undantag hittade ett konkret fel: ett flyttat tillfälle visades som en vanlig engångshändelse eftersom den projicerade posten tappade seriens återkomstfrekvens. Därmed kunde dialogen för borttagning erbjuda borttagning av hela serien i stället för bara tillfället.
- Samma identitetsförlust gjorde att ett flyttat tillfälle kunde hoppas över med sitt nya datum, trots att undantaget måste knytas till ursprungsdatumet i serien. Det kunde lämna den flyttade posten kvar eller påverka fel förekomst.
- Lade till det valfria, bakåtkompatibla fältet `recurrenceOccurrenceDate` på `FamilyItem`. Projektionen sätter nu både återkomstfrekvens och ursprungligt förekomstdatum på normala och flyttade förekomster.
- Kalenderredigeraren skickar ursprungsdatumet när ett redan flyttat tillfälle redigeras igen. Borttagning av en flyttad förekomst tar bort dess override och sparar i stället ett skip-undantag mot ursprungsdatumet. Båda listorna återställs tillsammans om lagringen misslyckas.
- Lade till regressionstester för identiteten i projektionen, borttagning av ett flyttat tillfälle, beständighet efter omladdning och rollback vid skrivfel.
- Berörda filer: `Sources/Domain/FamilyModels.swift`, `Sources/Data/DashboardViewModel.swift`, `Sources/Data/LocalFamilyStore.swift`, `Sources/FamilyCalendarView.swift`, `Tests/LocalFamilyStoreTests.swift`.
- Verifiering: uppdaterade filer och anrop återhämtade från GitHub och granskade på källkodsnivå. Ingen lokal Swift/Xcode-körning; CI för aktuell head är inte verifierad. Ingen IPA och ingen merge.

## 2026-11-28 – regressionstäckning för flera flyttade tillfällen i notiskön
- Utökade granskningen av återkommande undantag med en serie som har två separata flyttade tillfällen och en vanlig förekomst mellan dem.
- Lade till test som kontrollerar att notiskön behåller kronologisk ordning, använder respektive flyttat datum och bevarar ursprungsdatumet för båda undantagen. Testet kontrollerar även att den vanliga förekomsten mellan undantagen inte försvinner.
- Ingen produktionskod ändrades eftersom den granskade sekvenseringen hanterar dessa skilda datum korrekt.
- Berörd fil: `Tests/LocalReminderSchedulerTests.swift`.
- Verifiering: testet är incheckat på `feature/calendar-reminder-sync`. Ingen lokal Xcode/Swift-körning; CI för aktuell head är inte verifierad. Ingen IPA och ingen merge.

## 2026-11-28 – bevara veckoseriernas klockslag efter sommartidsomställning
- Reproducerade ett fel i veckovis återkomst med tidszonen Europe/Stockholm: när ett ankarklockslag 02:30 hamnade i vårens DST-gap normaliserades den förekomsten till 03:30. Nästa förekomster beräknades tidigare från föregående förekomst och kunde därför fortsätta på 03:30 permanent.
- Ändrade veckoberäkningen så att nästa förekomst alltid räknas från seriens ursprungliga startdatum och veckoförskjutning. En förekomst som inte existerar lokalt på omställningsdagen kan fortfarande normaliseras av Foundation, men den efterföljande veckan återgår till seriens ursprungliga väggklockslag.
- Lade till ett valfritt tidszonsargument i projektionsfunktionen för deterministiska tester och ett regressionstest för 21–28 mars–4 april 2027 i Europe/Stockholm.
- Berörda filer: `Sources/Data/DashboardViewModel.swift`, `Tests/LocalReminderSchedulerTests.swift`.
- Verifiering: felet reproducerat med Swift 6.2.1/Foundation på Linux före ändringen. Kod, test och dokumentation incheckade på `feature/calendar-reminder-sync`; fulla iOS/Xcode-tester kan inte köras i denna miljö. CI för aktuell head måste kontrolleras. Ingen IPA och ingen merge.

## 2026-11-28 – omplanera notiser efter tidszonsändring och återgång till appen
- Granskade `LocalReminderScheduler`: notiser byggs som engångs-`UNCalendarNotificationTrigger` med uttryckliga lokala kalenderkomponenter och aktuell tidszon. En tidszonsändring kräver därför att väntande påminnelser räknas om från familjens sparade kalenderdata.
- Flyttade inte schemaläggningen till en ny parallell tjänst. Utökade i stället `FamilyTabShell` så att tidigare aktiverade notiser synkroniseras vid appstart, när appen åter blir aktiv och vid `NSSystemTimeZoneDidChange`. Befintlig scheduler serialiserar operationer och behåller sin rollback-/felhantering.
- Inställningssidans befintliga aktiverings- och behörighetsflöde är oförändrat. Ingen ny behörighetsdialog introduceras.
- Berörd fil: `Sources/RootView.swift`.
- Verifiering: källan uppdaterad på `feature/calendar-reminder-sync`. Ingen Xcode-miljö finns tillgänglig här; SwiftUI-livscykel, Foundation-notifikationen och faktisk omplanering måste verifieras i iOS-simulator/enhet. Ingen IPA och ingen merge.


## 2026-11-28 – granskning av levererade och inaktuella lokala notiser
- Granskade hela schemaläggningsflödet för väntande och levererade notiser, inklusive stabila identifierare, gemensam kapacitetsgräns, uppdatering av befintliga requests och borttagning av föråldrade Familjen-ID:n.
- Bekräftade att både väntande och levererade notiser ingår i samma städning. Notiser som inte längre motsvarar en önskad kalender- eller hälsopåminnelse tas bort, medan andra appars notiser lämnas orörda.
- Bekräftade att städningen sker först efter att samtliga önskade notiser har lagts till utan fel. Om någon add misslyckas behålls gamla requests, vilket prioriterar att inte förlora fungerande påminnelser vid ett tillfälligt fel.
- Granskningen identifierade inget verifierat produktionsfel som motiverar ändring av denna logik. Ingen produktionskod ändrades.
- Berörd fil: `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: scheduler- och testkällor återhämtade från aktuell GitHub-branch och granskade. GitHub combined status och tillgänglig PR-workflow-listning saknar checks för head `0b433aedf3ff6c8248d0bf4943fb257e1f7e65d7`. Ingen lokal Xcode/SwiftUI-körning, ingen IPA och ingen merge.


## 2026-11-28 – åtgärda obligatoriskt argument i kalenderns notisuppdatering
- GitHub Actions för head `7e8fa1cfb42ad306488641a0b8d4ff6040f3207c` misslyckades i både simulator- och iPhone-bygget: `FamilyCalendarView.swift` anropade `LocalReminderScheduler.schedule` utan det numera obligatoriska argumentet `privateHealthCalendarIDs`.
- Flyttade kalenderns vyanrop till den befintliga samordnade metoden i `FamilyCalendarViewModel`. Den använder repositoryts fullständiga kalender- och hälsopåminnelsedata och skickar med privata kalender-ID:n, så att hälsopåminnelser inte tappas bort och privata vårdbesök fortsatt filtreras.
- Gjorde view model-metoden tillgänglig för kalender-vyn i stället för att duplicera scheduler-anrop och riskera att nya obligatoriska argument missas igen.
- Berörda filer: `Sources/Data/FamilyCalendarViewModel.swift`, `Sources/FamilyCalendarView.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: GitHub Actions-run 932 reproducerade felet på exakt head; båda jobbloggarna pekade på samma saknade argument på rad 704. Korrigeringen är incheckad men ännu inte verifierad av en ny CI-körning. Ingen IPA och ingen merge.


## 2026-11-28 – komplettera och verifiera anropskedjan för kalendernotiser
- Slutförde korrigeringen efter CI-fyndet: kalender-vyn använder nu FamilyCalendarViewModels gemensamma `rescheduleLocalRemindersIfEnabled()` i stället för att anropa schedulern direkt.
- Den gemensamma vägen inkluderar kalenderposter, health reminders och privata hälso-ID:n. Det förhindrar att kalenderredigering oavsiktligt ersätter hela kön med enbart kalendernotiser eller kringgår integritetsfiltret.
- Ändrade metodens åtkomst från private till intern så att vyn kan återanvända den.
- Berörda filer: `Sources/FamilyCalendarView.swift`, `Sources/Data/FamilyCalendarViewModel.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Verifiering: båda uppdaterade källfilerna återhämtade från aktuell branch och kontrollerade; det gamla direkta anropet är ersatt. En ny CI-körning behövs för att verifiera kompilering och tester. Ingen IPA och ingen merge.


## 2026-11-28 – korrigera förväntningar i kalenderpåminnelsernas regressionstester
- Exakt-head CI-run #935 körde 136 XCTest och identifierade sju assertion-fel i tre testfall. Övriga tester i körningen passerade.
- Analysen visade att produktionslogiken gav rätt resultat: två flyttade serieundantag ska båda ersätta sina ursprungliga datum och sorteras efter de nya påminnelsetiderna; obsolete-ID:n returneras deterministiskt sorterade; en årlig 29-februari-serie ska återgå till 29 februari under skottåren 2028, 2032 och 2036.
- Rättade därför endast testförväntningarna i `Tests/LocalReminderSchedulerTests.swift`. Ingen produktionskod ändrades.
- CI-run #935:s separata iPhone-jobb byggde och paketerade en unsigned IPA och laddade upp artefakten. Simulatorjobbet stoppades av de felaktiga testförväntningarna före simulatorbygget.
- Berörda filer: `Tests/LocalReminderSchedulerTests.swift`, `Documentation/DEVELOPMENT_LOG.md`.
- Testresultat före rättelse: 136 tester, 7 assertion-fel i 3 testfall. Efter rättelsen krävs ny CI-körning; inget nytt testresultat eller IPA från den nya headen är ännu verifierat.
- Commit med testkorrigering: `cefb21ec4a5d061558ee18a33f75c72ccfe4af13`. Ingen merge; PR #11 är fortsatt Draft.
