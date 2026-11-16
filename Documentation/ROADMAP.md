# Familjen roadmap

## Local-first beta
- [x] Native SwiftUI app and Scandinavian Premium visual direction
- [x] Local family setup without sign-in or invitation codes
- [x] On-device persistence for family, profiles, calendar and shopping list
- [x] Add, edit and remove child profiles without separate accounts
- [x] Add, edit and delete appointments, birthdays, events and health visits
- [x] Yearly birthdays, including 29 February birthdays observed on 28 February in non-leap years
- [x] On-device OCR for screenshots; images are not uploaded
- [x] Per-activity reminder choices (one week, one day, one hour, 15 minutes, at start)
- [x] Apple Calendar read-only import for upcoming events
- [x] Local family group chat and private conversation UI (device-local prototype only)
- [x] Add a provider-neutral `FamilyRepository` contract and local repository factory
- [x] Inject the repository contract into dashboard, calendar, shopping and notification view models
- [x] Add an observable UI facade so SwiftUI screens no longer depend directly on the local storage implementation
- [x] Route family profiles, messages, settings, app root, onboarding and dashboard through the facade
- [x] Expose repository change notifications so view state refreshes after mutations
- [x] Explicitly include the unit-test bundle in the XcodeGen test scheme
- [x] Make local storage file location injectable for isolated persistence tests
- [x] Preserve unreadable local snapshots as recovery files instead of silently overwriting them
- [x] Add unit tests for family/profile/shopping persistence, calendar CRUD, message read state, input validation, repeat-onboarding protection, observable facade behavior, birthday projection edge cases and local-time-zone handling, reminder persistence, legacy snapshot compatibility and corrupt-snapshot recovery
- [x] Add unit tests for reminder deduplication, future filtering, legacy fallback and the 60-reminder cap
- [x] Verify local-first regression suite in CI (run 43980622324 passed 28/28 tests and both simulator/iPhone unsigned builds on SHA 15ee4303; later FAM-019/FAM-020 changes await CI)
- [ ] Verify persistence, CRUD and reminders on physical iPhones
- [x] Verify the repository abstraction, calendar regression tests and reminder tests in CI (27/27 passed in run 43950845036; later FAM-018 change awaits a fresh run)
- [ ] Verify unsigned iOS Simulator build in CI after local-first refactor
- [ ] Prepare signed device build when signing credentials are available

## Known beta limitation
Each iPhone stores its own independent family data. There is no shared calendar, shared shopping list, account login or cloud backup in this phase.

## Later: Apple ecosystem
- [ ] CloudKit private/shared databases and CKShare for family sharing
- [ ] CloudKit-backed family group and private messaging, read state and cross-device sync
- [ ] Safe migration from each phone's local data to CloudKit
- [ ] Conflict handling and family membership permissions
- [x] Apple Calendar read-only integration via EventKit (calendar selection still pending)
- [ ] Push notifications if needed after CloudKit and Apple Developer setup

## Planerad funktion: familjemedlemmar i kalendern
- [x] Införa bakåtkompatibel grundmodell för flera berörda personer, explicit Hela familjen och separat ansvarig person (CI-verifiering inväntas).

- [ ] Hantera familjeprofiler i Inställningar: vuxna och barn utan krav på egna konton.
- [x] Vid skapande och redigering av kalenderhändelse kunna välja en eller flera berörda personer (CI-verifiering inväntas).
- [x] Ha ett tydligt val för **Hela familjen**, skilt från en händelse som ännu inte har tilldelats någon (CI-verifiering inväntas).
- [x] Filtrera kalendern på alla, en person eller flera personer; familjehändelser visas även i personfilter (CI-verifiering inväntas).
- [x] Visa personkopplingar, familjeomfattning och ansvarig diskret i kalenderlistan och dashboardens kommande tider (CI-verifiering inväntas).
- [x] Göra datamodellsändringen bakåtkompatibel så befintliga händelser och lokala snapshots bevaras (CI-verifiering inväntas).
- [x] Lägga till tester för äldre data, flera deltagare, familjeomfattande händelser, borttagning och kalenderfilter (CI-verifiering inväntas).

**Designprincip:** Barn ska kunna finnas som profiler utan egna konton. Funktionen ska stödja praktisk familjeplanering, inte bli ett generellt uppgiftssystem.

**Status:** Första implementationen är incheckad 2026-11-16. En key-path-kompileringsmiss korrigerades (FAM-014). Nästa CI-körning visade ett SwiftUI type-check-fel i toolbar-uttrycket; detta har brutits ut i FAM-015 följdes av en ytterligare förenkling och interpolationsfix (FAM-016 följdes av att filtersektionen bröts ut i FAM-017. Ny CI-verifiering inväntas. Fysisk iPhone-testning återstår.

## Produktgranskning: jämförelse med familjeappar (2026-11-16)

Genomgången jämförde Familjens inriktning med Cozi, TimeTree och FamilyWall. Slutsatsen är att Familjen ska prioritera en stark familjekalender och en genomtänkt iOS-upplevelse, inte försöka kopiera alla konkurrenters moduler.

### Befintligt som ska byggas vidare på
- Familjeprofiler för vuxna och barn finns redan i `FamilyMembersView`; återanvänd den befintliga hanteringen i Inställningar i stället för att skapa ett parallellt profilsystem.
- Kalendern har redan aktivitetskategorier, lokal påminnelsehantering och läsning av Apple Kalender via EventKit.
- Lokal OCR finns redan i projektet. Nästa steg bör vara ett granskat importflöde, inte en separat OCR-funktion.
- Repository-abstraktion finns, men local-first-betan har ännu inte gemensam data mellan telefoner.

### Prioritering

#### P0 – kvalitet och grund
- [ ] Slutför verifiering av de senast tillagda födelsedagsregressionstesterna i CI; senaste kända run `43941033673` avbröts och räknas inte som godkänd.
- [x] Förhindra dataförlust när en familjeprofil tas bort: behåll kalenderhändelser och rensa endast personkopplingen (test verifierat i run 43950845036).
- [ ] Fortsätt regressionstesta lokal persistens, kalenderredigering och notiser innan större funktionsbyggen. FAM-018 gör skrivfel synliga; dess nya test inväntar CI.

#### P1 – kärnupplevelsen i familjekalendern
- [x] Familjemedlemmar i kalendern: koppla en händelse till en eller flera profiler (implementation incheckad; simulator-CI verifierad i run 43950845036 (27/27 tester)).
- [x] Separat och tydligt val för **Hela familjen** (implementation incheckad; CI-verifiering inväntas).
- [x] Filter för alla, en person och flera valda personer (implementation incheckad; CI-verifiering inväntas).
- [x] Skilj på deltagare/berörda personer och ansvarig vuxen för händelsen (implementation incheckad; CI-verifiering inväntas).
- [x] Bakåtkompatibel datamodell från nuvarande `memberID` till stöd för flera personer; bevara befintliga snapshots och poster (implementation incheckad; CI-verifiering inväntas).
- [x] Lägg till separat plats-/adressfält för kalenderhändelser, med bakåtkompatibel lokal lagring och visning i kalenderlistan (FAM-022; CI inväntas).
- [x] Stöd årlig återkomst även för vanliga kalenderhändelser, inte bara födelsedagar (FAM-023; CI inväntas).\n- [ ] Utöka återkomst med veckovis/månadsvis och stöd för att ändra en förekomst eller hela serien; kräver en separat serie-/förekomstmodell.

#### P2 – minska manuellt arbete och förbättra iOS-åtkomst
- [ ] Bygg vidare på befintlig OCR till ett importflöde: bild/PDF → extraherat förslag på titel, datum, tid och plats → användaren granskar → väljer familjemedlem → sparar.
- [ ] Lägg till kalenderwidget med dagens och närmaste familjehändelser.
- [ ] Lägg till snabbregistrering av händelser med rimliga standardvärden och så få tryck som möjligt.
- [ ] Undersök prenumeration/import av externa kalendrar (t.ex. iCal/ICS) med tydlig källa och utan att blanda ihop importerade poster med Familjens egna.

#### P3 – samordning och utökning
- [ ] Aktivitetsflöde som visar vem som lagt till eller ändrat en händelse, när gemensam synk finns.
- [ ] Utvärdera flera inköpslistor först efter att kalender och synk är stabila.
- [ ] Gemensam synk och säkerhetskopiering mellan familjens telefoner krävs för att appen ska fungera som ett gemensamt familjeverktyg. Planera CloudKit/CKShare separat med migrering, behörigheter och konfliktlösning; påbörja inte migreringen utan uttryckligt beslut.

### Medvetet utanför nuvarande produktfokus
- Hushållssysslor, poängsystem och generella att-göra-listor.
- GPS-spårning och ankomstaviseringar.
- Budgetering, recept-/måltidsplanering och ett separat socialt fotoalbum.

### Produktprinciper
- Funktioner ska lösa ett återkommande familjebehov; undvik funktionsmängd för sin egen skull.
- Import från bilder eller dokument ska alltid presenteras som ett förslag som användaren godkänner, aldrig skapa kalenderposter utan bekräftelse.
- Visa tydligt om data är lokal, importerad eller gemensamt synkroniserad.
- Barn ska kunna vara profiler utan egna konton.
- Håll gränssnittet kompakt, lättläst och i linje med Scandinavian Premium / Modern iOS.

**Status:** Produktgranskning dokumenterad. Detta är en prioriterad plan, inte ett påstående om att dessa funktioner redan är implementerade.


## Kvalitetsförbättring: synlig status för lokal lagring (2026-11-17)
- [x] Fånga fel när snapshot-katalogen inte kan skapas eller JSON inte kan skrivas.
- [x] Exponera lagringsfel genom repository och FamilyStore.
- [x] Visa en varning på dashboarden när en ändring inte kunde sparas.
- [x] Lägg till regressionstest som säkerställer att ett skrivfel exponeras och att befintlig blockeringsfil inte skrivs över.
- [ ] Verifiera FAM-018 i CI på aktuell commit.
- **Viktig begränsning:** vid skrivfel behålls ändringen i minnet och användaren varnas; full rollback av den aktuella mutationen ingår inte ännu.


## Kvalitetsrunda: transaktionella kalenderändringar (2026-11-17)
- [x] Återställ kalenderlistan om skapande eller uppdatering inte kan skrivas till lokal snapshot (FAM-021; CI inväntas).
- [x] Återställ kalenderposten om radering inte kan sparas (FAM-021; CI inväntas).
- [x] Återställ familjeprofil och berörda kalenderkopplingar om profilborttagning inte kan sparas (FAM-021; CI inväntas).
- [x] Lägg till regressionstester för de tre skrivfelen (CI inväntas).

## Kalender: återkoppling vid lagringsfel (2026-11-17)
- [x] Låt inte kalenderredigeraren stängas om lokal persistens misslyckas (FAM-024; CI inväntas).
- [x] Visa fel när kalenderpost inte kan raderas och återställs efter skrivfel.
- [x] Lägg till regressionstest för view model och användarflöde.

## Kalender: årlig återkomst (2026-11-17)
- [x] Tillåt årlig återkomst för samtliga kalenderkategorier, med bevarat ursprungligt datumankare (FAM-023; CI inväntas).
- [x] Testa projektion och redigering av en återkommande händelse som inte är en födelsedag.
- [ ] Veckovis/månadsvis återkomst och val mellan att redigera en förekomst eller hela serien återstår.

## Kalender: platsuppgifter (2026-11-17)
- [x] Lägg till separat valfritt plats-/adressfält, skilt från anteckningar (FAM-022; CI inväntas).
- [x] Visa plats i kalenderlistan och behåll kompatibilitet med äldre lokala snapshots.
- [x] Testa platsens persistens och avkodning av äldre poster utan platsfält.

## Kvalitetsrunda: kalenderfilter och påminnelser (2026-11-17)
- [x] Rensa inaktuella levererade Familjen-påminnelser när en händelse ändras/raderas och när påminnelser stängs av (FAM-019; CI inväntas).
- [x] Säkerställ att andra appars notiser inte påverkas av Familjens rensning (regressionstest tillagt; CI inväntas).
- [x] Rensa borttagna familjemedlemmar ur aktiva personfilter så kalendern inte fastnar i ett föråldrat filterläge (FAM-020; CI inväntas).
