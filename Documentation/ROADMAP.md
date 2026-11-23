

## 2026-11-23 – Produktbeslut: Apple-first, ingen extern backend

- Supabase och andra externa serverlösningar väljs bort för Familjen.
- Nuvarande beta fortsätter vara local-first tills Apple Developer-konto och CloudKit-konfiguration finns.
- Målet är CloudKit private/shared databases och CKShare för delad familjedata.
- Meddelanden på respektive telefon är fortsatt enhetslokala. Ingen gemensam chatt eller bildsynk utlovas före verifierad CloudKit-delning.
- Före Developer-kontot prioriteras lokal funktionalitet, meddelande-UX, datamodell/repository-förberedelser, migreringstester och dokumentation.
- Efter Developer-kontot: CloudKit-konfiguration, familjedelning, säker migrering, delad kalender/inköpslista, meddelanden, bildbilagor och därefter pushnotiser.
- Detaljerad plan finns i `Documentation/MESSAGING_ROADMAP.md`.
- Ingen Supabase-SDK, server, databas eller serverhemlighet ska läggas till.
