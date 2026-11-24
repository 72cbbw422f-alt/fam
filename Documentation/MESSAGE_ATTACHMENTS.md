# Meddelandebilagor – lokal grund

Status: lokal lagringsgrund, metadata, PhotosPicker och lokal chattvisning är implementerade på `feature/family-messenger`. CI-verifiering och fysisk iPhone-verifiering återstår.

## Omfattning i första steget

- Endast bildinnehåll: JPEG, PNG, HEIC och HEIF.
- PhotosPicker används för bildval och en lokal förhandsvisning visas före sändning.
- Bildmeddelanden utan text stöds.
- Chattbubblan visar en nedskalad miniatyr av den lokalt lagrade bilden. Miniatyrer begränsas till 640 pixlar och cachas i minnet så att SwiftUI inte behöver skapa en fullupplöst bild vid varje omritning.
- Maximal filstorlek: 10 MiB per bild.
- Bilddata sparas separat från JSON-snapshoten i appens privata Application Support-katalog.
- Meddelandemetadata innehåller stabilt UUID, filnamn, innehållstyp, byteantal, skapandetid och relativ sökväg.
- Absoluta sandbox-sökvägar lagras inte i meddelandemodellen.
- Filnamn reduceras till sista sökvägskomponenten och begränsas till 120 tecken.
- Relativa sökvägar begränsas till `MessageAttachments/` och traversal-segment avvisas.

## Arkitektur

`FamilyMessage` har ett valfritt `attachments`-fält. Äldre JSON-meddelanden utan fältet ska fortsätta kunna avkodas. `FamilyMessageAttachmentStore` hanterar lokal skrivning, läsning och borttagning av bildfiler och returnerar metadata som kan kopplas till meddelandet.

Lagringsgränsen är avsiktligt fristående från SwiftUI och CloudKit. Vid framtida synkronisering kan den relativa lokala filen laddas upp som CloudKit-asset medan metadata och stabila ID:n behålls.

## Säkerhets- och kvalitetskrav

- Validera typ, storlek och relativ sökväg före filåtkomst.
- Skriv atomiskt.
- Radera inte lokal fil innan borttagningen av meddelandet har sparats säkert.
- Hantera orphan-filer vid avbruten process och misslyckad snapshot-skrivning.
- Skapa miniatyrer först när bildväljare och visningsflöde integreras.
- Inga PDF- eller dokumentbilagor i första versionen.
- Ingen CloudKit- eller APNs-funktion är implementerad här.

## Återstående arbete

1. Verifiera ny CI för modell, filhantering, UI och regressionstester.
2. Testa PhotosPicker, format, miniatyr och borttagning på fysisk iPhone.
3. Förbättra bildvisning med tryck-för-fullskärm och hantera orphan-filer vid avbruten process.
4. Efter Apple Developer-konfiguration: implementera CloudKit-asset och synkstatus separat.


## Full-screen image viewing

- Tapping an image attachment in a chat bubble opens a dedicated full-screen viewer on a black canvas.
- The image is aspect-fit so the complete image remains visible; a clearly labelled close control dismisses the viewer.
- This viewer uses the already persisted local attachment data. It does not add remote loading, sharing, or CloudKit behavior.
- Physical-device interaction and accessibility behavior still require manual iPhone verification.


## Orphaned-file cleanup

- On startup, cleanup runs only after the local JSON snapshot has decoded successfully. A corrupt or unrecoverable snapshot never triggers attachment deletion.
- The cleanup compares files under UUID-named `MessageAttachments` directories against attachment paths referenced by decoded messages.
- Only unreferenced regular files are removed. Symbolic links and unexpected directory names are ignored; empty attachment directories are removed after their files are processed.
- Cleanup errors are non-fatal and do not change message metadata or the JSON snapshot.


## Thumbnail decoding and cache

- Chat bubbles use ImageIO to create a transformed thumbnail with a maximum pixel dimension of 640 instead of decoding the original full-resolution image for the inline preview.
- Thumbnail decoding runs in a utility-priority detached task rather than synchronously in the SwiftUI view body. The placeholder remains visible until decoding completes; the view checks task cancellation before publishing the result.
- Decoded thumbnails are cached in an in-memory `NSCache`, keyed by the validated relative attachment path. The cache may evict entries under memory pressure.
- Opening the full-screen viewer still reads the original attachment data so the preview remains full quality.
- Physical-device scrolling performance and memory behavior still require manual verification.

## Application Support-fel

- `applicationStore()` använder nu en kastad, typad `applicationSupportUnavailable`-error om Foundation inte returnerar någon Application Support-katalog.
- Den tidigare force unwrap (`first!`) är borttagen. Befintliga läs-/skrivflöden hanterar felet via `try` respektive `try?` och kan visa/behålla sitt befintliga felbeteende i stället för att krascha.
- Enhetstester och CI för denna ändring inväntas.


## Miniatyravkodning – testbar filhantering

- ImageIO-avkodningen ligger i `FamilyMessageThumbnailRenderer`, frikopplad från SwiftUI-vyn.
- Rotkatalogen injiceras så att saknade och korrupta bildfiler kan testas utan att använda appens riktiga Application Support-katalog.
- Cachen använder både rotkatalog och relativ sökväg som nyckel för att undvika kollisioner mellan testmiljöer och appmiljön.
- Miniatyrens maxdimension är fortsatt 640 pixlar och orienteringstransformering är aktiverad.
- Nya tester täcker saknad fil och korrupt bilddata. Positiv avkodning/orientering och faktisk scrollprestanda kräver fortsatt testning.
