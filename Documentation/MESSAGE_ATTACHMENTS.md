# Meddelandebilagor – lokal grund

Status: lokal lagringsgrund, metadata, PhotosPicker och lokal chattvisning är implementerade på `feature/family-messenger`. CI-verifiering och fysisk iPhone-verifiering återstår.

## Omfattning i första steget

- Endast bildinnehåll: JPEG, PNG, HEIC och HEIF.
- PhotosPicker används för bildval och en lokal förhandsvisning visas före sändning.
- Bildmeddelanden utan text stöds.
- Chattbubblan visar den lokalt lagrade bilden.
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
