# Meddelandebilagor – lokal grund

Status: lokal lagringsgrund och metadata är implementerade på `feature/family-messenger`. UI-integration och fysisk iPhone-verifiering återstår.

## Omfattning i första steget

- Endast bildinnehåll: JPEG, PNG, HEIC och HEIF.
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

1. Integrera PhotosPicker med bildförhandsvisning och avbryt/skicka.
2. Lägg till bilagemetadata i meddelande-API:t och snapshoten med rollback vid skrivfel.
3. Visa miniatyrer och fullskärmsbild i chatten.
4. Hantera borttagning och orphan-filer säkert.
5. Testa bildflödet på fysisk iPhone.
6. Efter Apple Developer-konfiguration: implementera CloudKit-asset och synkstatus separat.
