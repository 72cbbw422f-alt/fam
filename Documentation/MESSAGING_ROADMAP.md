# Familjen – meddelanden och Apple-baserad familjedelning

Status: produktbeslut fastställt; CloudKit-implementation avvaktar Apple Developer-konto.
Arbetsgren: feature/family-messenger.

## Fastställt produktbeslut

Familjen ska vara en Apple-fokuserad app. Ingen Supabase, egen server, extern databas eller annan serverberoende tjänst ska införas som tillfällig lösning.

- Nuvarande beta förblir local-first.
- Meddelanden på respektive telefon är lokala och ska inte beskrivas som synkroniserade.
- Gemensamma meddelanden, bilder och familjedata aktiveras först när Apple-baserad delning är konfigurerad och verifierad.
- CloudKit och CKShare är den avsedda tekniska riktningen.
- Pushnotiser via APNs planeras efter att Apple Developer-konfiguration finns.
- Barn fortsätter att kunna finnas som familjeprofiler utan egna konton.

## Nuläge – verifierat i projektets dokumentation och domänkontrakt

- Meddelandevyn nås via Mer > Meddelanden.
- FamilyMessage innehåller conversationID, kind, senderID, text, sentAt och readAt.
- FamilyRepository/FamilyStore exponerar sändning av textmeddelanden och markering som läst.
- LocalFamilyStore sparar meddelanden i den lokala JSON-snapshoten.
- Varje installation har en egen datamängd. Meddelanden, lässtatus och övrig familjedata synkroniseras inte mellan telefoner.
- Meddelandemodellen har ännu inget färdigt stöd för bildbilagor.
- Nuvarande beta kräver varken konto eller backend.

## Målbild för Apple-integrationen

### Familjedelning och identitet
- Använd CloudKit private database för användarens privata data.
- Använd CloudKit shared database och CKShare för data som familjen delar.
- Definiera en stabil familjeidentitet och mappa befintliga lokala profiler till deltagare i den delade familjen.
- Behåll separata Apple-konton för Niklas och Villemo; familjedelning ska ske via Apples delningsmekanism.
- Barnprofiler ska inte automatiskt kräva egna Apple-konton.
- Behörigheter ska kontrolleras i CloudKit och inte enbart döljas i gränssnittet.

### Meddelanden
- Familjechatt och privata vuxensamtal.
- Avsändare, tidsstämpel, kronologisk ordning och tydlig lässtatus.
- Skicka och ta emot meddelanden mellan två riktiga iPhones.
- Beständig lokal cache med synkstatus och återhämtning efter offlineperiod.
- Definierad hantering av konflikter, dubbla försök och borttagna poster.
- Notisinställningar per konversation.

### Avgränsning
- Bild- och filbilagor ingår inte i Familjens meddelanden.
- Bilder delas via externa appar som Snapchat eller Messenger.

## Arkitekturregler innan implementation

1. Behåll domänmodeller och SwiftUI-vyer oberoende av CloudKit-typer.
2. Använd repository-/servicegränsen som enda väg mellan vyer och datalager.
3. Definiera explicita synkstatusar: lokal, väntar på synk, synkroniserad och fel.
4. Bevara lokala data tills delning och serverbekräftelse har verifierats.
5. Skapa en idempotent export/import-migrering med stabila ID:n.
6. Hantera konfliktlösning och tidszoner uttryckligen.
7. Lägg aldrig in privata nycklar eller hemligheter i appen.
8. Ingen CloudKit-funktion markeras färdig innan den testats med två separata Apple-konton och två fysiska enheter.

## Leveransordning efter att Apple Developer-kontot finns

1. Konfigurera App ID, iCloud capability, CloudKit container och miljöer.
2. Fastställ schema, record types, relationer och delningsmodell.
3. Implementera privat och delad CloudKit-repository bakom befintliga kontrakt.
4. Implementera familjeskapande, inbjudan och accepterande av CKShare.
5. Migrera och verifiera kalender, familjeprofiler och inköpslista.
6. Implementera meddelanden, lässtatus och återanslutning.
8. Lägg till APNs-notiser där plattformen och konfigurationen stöder det.
9. Testa två Apple-konton, två iPhones, offline/online, ominstallation, konfliktfall och återställning.
10. Skapa signerad distributionsversion först efter godkända tester.

## Arbete som kan göras före Developer-kontot

- Förbättra meddelandegränssnittet och den lokala interaktionen utan att påstå att meddelanden delas.
- Dokumentera CloudKit-schema, CKShare-flöden, behörigheter och testmatris.
- Fortsätta förbättra kalender, hälsa, födelsedagar, inköpslista och säsongsupplevelsen lokalt.

## Blockerare och kvalitetsgrindar

- Apple Developer Program och korrekt App ID/iCloud capability-konfiguration krävs för den avsedda delade CloudKit-distributionen.
- CloudKit schema och sharing-flöde måste verifieras i utvecklingsmiljö innan produktionsschema används.
- Två separata Apple-konton och två fysiska iPhones krävs för godkännande av delning och meddelanden.
- FlareStore-installation är inte bevis på att CloudKit-sharing eller APNs fungerar.
- Pushnotiser ska redovisas separat från synkronisering; fungerande CloudKit-synk innebär inte automatiskt fungerande pushnotiser.

## Godkännandekriterier

- Niklas och Villemo kan dela en familj via sina egna Apple-konton.
- Ändringar i delad kalender och inköpslista blir synliga på båda enheterna och överlever omstart.
- Meddelanden levereras korrekt med avsändare, tidsordning och lässtatus.
- Offlineändringar synkroniseras efter återanslutning utan dataförlust eller oavsiktliga dubbletter.
- En användare utanför familjedelningen kan inte läsa familjens data.
- Migrering från lokala snapshots bevarar poster, ID-kopplingar, datum, tidszoner och status.
- Eventuella pushnotiser verifieras separat på fysiska enheter.

## Öppna produktbeslut

- Ska meddelanden kunna redigeras och raderas efter sändning? Rekommendation: radering först, redigering senare.
- Ska notisförhandsvisning visa meddelandetext eller endast avsändare? Rekommendation: valbart i inställningar.
- Ska privata samtal mellan vuxna finnas i första delade versionen eller efter familjechatten? Rekommendation: börja med familjechatten och lägg till privata samtal när delningsmodellen är stabil.
