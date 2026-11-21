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
- Synlighet modelleras explicit som `private` eller `sharedSummary`; gemensamma listor får endast exponera sammanfattningsfält för `sharedSummary`.
- Det finns ännu ingen autentiserad identitet eller fleranvändarsynk i local-first-betan. Synlighetsfältet är därför datamodellens grund för framtida behörighetskontroll, inte ett påstående om verifierad åtkomstkontroll mellan olika personer på samma upplåsta enhet.
- Notistext ska vara neutral och inte innehålla läkemedelsnamn, provresultat eller andra privata detaljer på låsskärmen.

## Integration
- Hälsobesök kopplas till befintlig kalender via `calendarItemID` i stället för att duplicera kalenderposter.
- Hälsopåminnelser får ett eget identifierarprefix och schemaläggs av samma lokala notistjänst; kalenderpåminnelser ska inte rensas när hälsopåminnelser uppdateras.
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
