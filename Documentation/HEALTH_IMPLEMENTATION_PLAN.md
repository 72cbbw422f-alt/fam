# Hälsa – teknisk implementationsplan

## Utgångsläge (2026-11-21)
- Repository: `72cbbw422f-alt/fam`
- Bas: `local-first-beta` / PR #1
- Bas-commit: `9cbbbe33d8a96694b14df25d0585c91de451c05d`
- Arbetsgren: `feature/health-foundation`
- Arkitektur: SwiftUI, `FamilyRepository`-abstraktion, `FamilyStore`-UI-fasad och `LocalFamilyStore` med atomisk JSON-snapshot.
- Befintligt: Hälsa-flik med en enkel vy över kalenderposter av typerna vårdbesök, tandläkare och medicin; kalenderposter har deltagare, plats, anteckningar och lokala påminnelse-offsets.
- Befintligt påminnelsesystem: `LocalReminderScheduler`, UserNotifications, högst 60 framtida kalenderpåminnelser. Notiser identifieras med prefixet `familjen-item-`.
- Begränsning: local-first-betan har separat data per iPhone, ingen familjesynk eller autentiserad användaridentitet.

## Mål
Utöka Hälsa till fem områden: Översikt, Vårdbesök, Recept och läkemedel, Uppföljningar samt Hälsoinformation. All registrering i första versionen är manuell och lagras lokalt i samma repository-snapshot.

## Föreslagen domänmodell
- `HealthRecord`: vårdbesök, uppföljning, provsvar, remiss, vårdkontakt och anteckning. Har obligatorisk familjemedlem, datum/status, vårdgivare/plats, anteckning och synlighetsnivå.
- `HealthPrescription`: läkemedel, berörd medlem, receptgiltighet, uttag kvar och separat förnyelsedatum/status.
- `MedicationPickup`: separat uthämtningshändelse med eget förfallodatum/status. Receptförnyelse och uthämtning får aldrig representeras av samma status.
- `HealthProfileInformation`: allergier, intoleranser, viktig vårdinformation och viktiga vårdkontakter per medlem.
- `HealthReminder`: egen påminnelse med måltyp/mål-ID, medlem, datum/tid, aktiv status och synlighetsnivå.

## Integritet
- Alla känsliga objekt kopplas till en enskild familjemedlem.
- Synlighet modelleras explicit som `personal` eller `sharedSummary`; gemensamma listor får endast exponera sammanfattningsfält för `sharedSummary`.
- Det finns ännu ingen autentiserad identitet eller fleranvändarsynk i local-first-betan. Synlighetsfältet är därför datamodellens grund för framtida behörighetskontroll, inte ett påstående om verifierad åtkomstkontroll mellan olika personer på samma upplåsta enhet.
- Notistext ska vara neutral och inte innehålla läkemedelsnamn, provresultat eller andra privata detaljer på låsskärmen.

## Integration
- Hälsobesök kopplas till befintlig kalender via `calendarItemID` i stället för att duplicera kalenderposter.
- Hälsopåminnelser får ett eget identifierarprefix och schemaläggs av samma lokala notistjänst; kalenderpåminnelser ska inte rensas när hälsopåminnelser uppdateras.
- Notiscentret visar kommande vårdbesök och aktiva hälsopåminnelser som markerats `sharedSummary`. Påminnelsetexten är neutral; privata poster filtreras bort.
- Översikt och startsida ska visa endast delade sammanfattningar om inte aktuell profilkontext uttryckligen ger tillgång till privata detaljer.
- Ingen 1177-, apoteks- eller automatisk läkemedelssynk i denna fas.

## Genomförandeordning
1. Domänmodeller, bakåtkompatibel snapshot och repository-kontrakt.
2. Enhetstester för validering, persistens, migration från äldre snapshot och statusseparation.
3. CRUD/ViewModel och de fem huvudområdena i Hälsa.
4. Kalenderkoppling för vårdbesök.
5. Hälsopåminnelser med stabila ID:n, deduplicering och selektiv borttagning.
6. Behörighets-/synlighetsfilter och integritetstester.
7. Dashboardintegration, regressionstester och CI-build.

## Kvalitetsgrindar
- Inga ändringar i `main` eller sammanslagning av PR #1 utan separat godkännande.
- Varje snapshot-fält ska vara optional vid avkodning eller ha bakåtkompatibel standard.
- Skrivningar ska återställas vid persistensfel.
- Tester ska täcka att privata detaljer inte exponeras i delade sammanfattningar, att receptförnyelse och uthämtning är separata, och att uppdatering av hälsopåminnelser inte tar bort kalendernotiser.
- CI-resultat och fysisk iPhone-verifiering redovisas separat. En osignerad IPA betraktas inte som distributionsklar.


## Implementerat efter grundplanen
- Fem områden i Hälsa med redigeringsflöden för vårdbesök/uppföljningar, recept, uthämtning, hälsoinformation och egna påminnelser.
- Kalenderposter kopplas till hälsobesök; kalenderredigering synkroniseras tillbaka till hälsoposten och kalenderborttagning bevarar historiken som avbokad.
- Privata vårdbesök filtreras bort från startsida och huvudkalender.
- Receptförnyelse och läkemedelsuthämtning skapar separata påminnelser med stabila mål-ID:n. Statusändring eller borttagning städar respektive påminnelse.
- Notiscentret visar kommande delade hälsoärenden och aktiva delade hälsopåminnelser utan att visa privata påminnelsetexter.
- CI för arbetsgrenen kör både simulatorns tester/byggnad och en osignerad iPhone-byggnad.

## Verifiering
- 2026-11-21: GitHub Actions run `44943605161` slutförd med success för simulatorns enhetstester och simulatorbyggnad.
- Samma körning: fysisk iPhone-byggnad, paketering och uppladdning av osignerad IPA slutförd med success.
- Detta verifierar CI-byggnaden, inte installation eller notisleverans på fysisk iPhone.
- Individuell autentisering/behörighetskontroll och familjesynk är fortfarande inte implementerade.
- 2026-11-21: Notiscenterintegration med privacy-filter och test är tillagd.
- 2026-11-21: Delade hälsoärenden i notiscentret är tryckbara och öppnar en separat, neutral sammanfattning med rubrik, familjemedlem och datum/tid. Sammanfattningen exponerar inte påminnelsetext eller privata anteckningar.
- Verifierad kodcommit för notiscentrets tryckbara sammanfattning: `7b2306e84db940b0659bf0a393a6dd69aacfad3f` på `feature/health-foundation`.
- GitHub Actions run `44961600818`: simulatorns enhetstester och iOS Simulator-bygge godkända; fysisk iPhone-byggnad, IPA-paketering och artifact-uppladdning godkända.
- Artifact: `Familjen-unsigned-IPA`, ID `14730240562`. IPA har verifierats som ett iPhoneOS-arm64-paket med bundle identifier `se.familjen.app` och minimum iOS 17.0. Installering och signering via FlareStore är inte verifierade.


## Detaljvy och kartplatser (2026-11-22)
- Hälsoposter har nu valfria koordinatfält (`latitude`/`longitude`) utöver platsnamn och adress. Fälten är valfria för att äldre lokala snapshots fortsatt ska kunna avkodas.
- Ärendeeditorn använder MapKit-sökning för att föreslå adresser och intressanta platser. När en träff väljs sparas platsnamn, formaterad adress och koordinater. Manuell adressinmatning är fortsatt möjlig.
- Notiscentrets hälsoärenden öppnar en utökad detaljvy med status, familjemedlem, datum/tid, vårdgivare, mottagning, plats, adress, anteckningar och påminnelser när uppgifterna finns.
- Om koordinater finns visas en kartförhandsvisning och en åtgärd som öppnar Apple Kartor med vägbeskrivning. Ärenden utan koordinater visar fortfarande all registrerad textinformation.
- Nya tester kontrollerar koordinatpersistens samt avkodning när koordinatfälten saknas.
- Kodändringar ligger på `feature/health-foundation`; CI behöver köras innan dessa ändringar betraktas som verifierade. Fysisk iPhone-testning av MapKit-sökning och kartöppning återstår.
