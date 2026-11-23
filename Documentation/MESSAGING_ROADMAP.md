# Familjen – meddelanden och privat familjechatt

Status: beslutad produktinriktning, implementation ej påbörjad.
Arbetsgren: feature/family-messenger.
Utgångspunkt: feature/ux-navigation-shopping @ 17aae832f4982f49c39c80e37cb907fd1e9a83f6.

## Mål

Familjen ska kunna fungera som Niklas och Villemos primära privata kommunikationskanal. Meddelanden och bilder ska vara gemensamma mellan deras iPhones, inte enhetslokala testdata.

## Nuläge – verifierat i källkoden

- FamilyMessagesView nås från Mer > Meddelanden.
- Domänmodellen FamilyMessage innehåller conversationID, kind, senderID, text, sentAt och readAt.
- FamilyRepository/FamilyStore exponerar sendMessage och markConversationRead.
- LocalFamilyStore sparar meddelanden i den lokala JSON-snapshoten.
- Varje iPhone har en separat datamängd. Meddelanden, läskvitton och familjedata synkroniseras inte mellan enheter.
- Meddelandemodellen saknar bilagor och uppladdningsmetadata.
- README och ARCHITECTURE anger uttryckligen local-first beta utan konto, backend eller synk. Denna feature är därför ett separat, avgränsat steg mot molnbaserad kommunikation.

## Föreslagen teknisk riktning

Använd Supabase som delad backend för den här funktionen, i enlighet med den tidigare diskuterade backend-riktningen. Införandet ska vara isolerat bakom repository-/servicegränser så att SwiftUI-vyerna inte blir beroende av Supabase SDK-detaljer.

- Supabase Auth: separata vuxenkonton, med Sign in with Apple som avsedd inloggning.
- Familjeinbjudan: engångs-/tidsbegränsad kod för att koppla Villemos konto till rätt familj.
- PostgreSQL: familjer, medlemskap, konversationer, meddelanden, läskvitton och bilagornas metadata.
- Row Level Security: en användare får endast läsa/skriva konversationer och filer som hör till familjer där användaren är aktiv medlem.
- Supabase Realtime: nya meddelanden och lässtatus uppdateras medan appen är öppen.
- Privat Supabase Storage-bucket: foton är privata; använd tidsbegränsade signerade URL:er för hämtning. Service-role-nyckel får aldrig finnas i iOS-appen.
- APNs/push: fjärrnotiser för nya meddelanden när appen ligger i bakgrunden eller är stängd. Kräver separat Apple Developer-/APNs-konfiguration. Utan den kan appen erbjuda realtid medan den är öppen men inte lova tillförlitliga pushnotiser.
- Lokal cache: behåll en begränsad lokal cache för snabb visning och tillfällig nätverksfrånvaro. Servern är auktoritativ för delade meddelanden.

## Funktionell omfattning

### Meddelanden
- Familjechatt och privata en-till-en-samtal.
- Avsändare, tidsstämpel och tydliga meddelandebubblor.
- Skicka, ta emot och uppdatera meddelanden i realtid.
- Leverans-/synkstatus och felhantering med möjlighet att försöka igen.
- Olästa markeringar och läskvitton per mottagare.
- Notisinställningar per konversation.
- Robust tomt läge, laddning, offline- och återanslutningsläge.

### Bildbilagor
- Välj flera bilder via PhotosPicker och ta foto med kamera.
- Förhandsvisning innan sändning.
- Komprimering och storleks-/formatkontroll på enheten.
- Uppladdningsindikator, avbryt och försök igen.
- Bildminiatyr i chatten och tryck för fullskärmsvisning.
- Bildmetadata kopplas till meddelandet; filerna ligger i privat lagring.
- Radera meddelande/bilaga med definierad policy för både databaspost och lagrad fil.
- Hantera behörighetsavslag, avbruten uppladdning, nätverksfel och utgångna signerade URL:er.

### Identitet och säkerhet
- Familjemedlemsprofil (t.ex. Niklas/Villemo) hålls separat från inloggningskontot.
- Endast vuxna med aktivt medlemskap får använda privata vuxensamtal.
- Barnprofiler ska inte automatiskt få inloggningskonton.
- RLS-policyer och negativa behörighetstester krävs innan delning aktiveras.
- Transport- och lagringsskydd ska användas. End-to-end-kryptering ingår inte i första leveransen och får inte påstås finnas.

## Leveransordning och kvalitetsgrindar

1. Datamodell, SQL-migrationer, RLS och säkerhets-/åtkomsttester.
2. Konfiguration och autentisering för två separata vuxenkonton.
3. Familjekoppling/inbjudningsflöde och verifierad medlemsbehörighet.
4. Textmeddelanden mellan två riktiga enheter med Realtime och serverbaserade läskvitton.
5. Bildbilagor med privat lagring, komprimering och robust felhantering.
6. Pushnotiser via APNs när Apple Developer-konfiguration finns.
7. Testa omstart, offline/online, dubbeltryck, återförsök, borttagning och åtkomst mellan två olika familjer.
8. Först efter godkända tester: skapa en ny signerad distributionsversion.

## Blockerare och externa beroenden

- Ett Supabase-projekt behöver skapas eller väljas och dess project URL samt anon/publishable key behöver konfigureras som säkra build-inställningar. Service-role key får endast användas server-side och får aldrig checkas in.
- Sign in with Apple kräver korrekt Apple-konfiguration.
- APNs-push kräver Apple Developer-medlemskap, identifierare och nyckel/certifikatkonfiguration.
- Fysisk testning kräver två separata iPhones och två olika användarkonton. En lokal simulator eller en enda enhet bevisar inte synk mellan användare.

## Godkännandekriterier

- Niklas skickar ett textmeddelande på sin iPhone och Villemo ser det på sin iPhone utan manuell uppdatering.
- Villemo kan svara och båda ser korrekt avsändare, tidsordning och lässtatus.
- Båda kan bifoga och öppna bilder; obehöriga familjer kan inte hämta dem.
- Meddelanden och bilagor finns kvar efter appomstart och återanslutning.
- Fel vid uppladdning eller nätverksavbrott leder inte till falsk status som skickat.
- RLS- och åtkomsttester visar att en tredje användare utanför familjen inte kan läsa meddelanden eller bilder.
- Pushnotiser redovisas separat som ej tillgängliga tills APNs är konfigurerat och verifierat.

## Öppna produktbeslut

- Ska meddelanden kunna redigeras och raderas efter sändning, och i så fall inom vilken tidsgräns?
- Ska en konversation stödja andra filtyper än bilder i första versionen? Rekommendation: nej, börja med bilder.
- Ska notisförhandsvisning visa meddelandetext eller endast avsändare? Standard bör vara avsändare + text, med möjlighet att dölja text i inställningar.
