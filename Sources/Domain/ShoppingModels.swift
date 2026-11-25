import Foundation

struct ShoppingList: Identifiable, Codable {
    let id: UUID
    let title: String
}

enum ShoppingCategory: String, Codable, CaseIterable, Identifiable {
    case fruitVegetables, dairy, meatFish, pantry, frozen, household, other

    var id: String { rawValue }
    var title: String {
        switch self {
        case .fruitVegetables: return "Frukt & grönt"
        case .dairy: return "Mejeri"
        case .meatFish: return "Kött & fisk"
        case .pantry: return "Skafferi"
        case .frozen: return "Frys"
        case .household: return "Hushåll"
        case .other: return "Övrigt"
        }
    }
    var symbol: String {
        switch self {
        case .fruitVegetables: return "carrot"
        case .dairy: return "drop"
        case .meatFish: return "fish"
        case .pantry: return "basket"
        case .frozen: return "snowflake"
        case .household: return "sparkles"
        case .other: return "square.grid.2x2"
        }
    }
}

struct ShoppingItem: Identifiable, Codable, Equatable {
    let id: UUID
    let listID: UUID
    var title: String
    var isChecked: Bool
    let createdAt: Date
    var category: ShoppingCategory? = nil
    enum CodingKeys: String, CodingKey { case id, title, category; case listID = "list_id"; case isChecked = "is_checked"; case createdAt = "created_at" }
}


struct GiftIdea: Identifiable, Codable, Equatable {
    let id: UUID
    let memberID: UUID
    let birthdayItemID: UUID
    var title: String
    var note: String?
    var isOrdered: Bool
    let createdAt: Date

    init(id: UUID = UUID(), memberID: UUID, birthdayItemID: UUID,
         title: String, note: String? = nil, isOrdered: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.memberID = memberID
        self.birthdayItemID = birthdayItemID
        self.title = title
        self.note = note
        self.isOrdered = isOrdered
        self.createdAt = createdAt
    }
}


enum ChristmasGiftStatus: String, Codable, CaseIterable, Identifiable {
    case idea, planned, purchased
    var id: String { rawValue }
    var title: String {
        switch self {
        case .idea: return "Idé"
        case .planned: return "Planerad"
        case .purchased: return "Inköpt"
        }
    }
}

struct ChristmasGift: Identifiable, Codable, Equatable {
    let id: UUID
    var recipient: String
    var title: String
    var note: String?
    var responsibleMemberID: UUID?
    var status: ChristmasGiftStatus
    let createdAt: Date

    init(id: UUID = UUID(), recipient: String, title: String, note: String? = nil,
         responsibleMemberID: UUID? = nil, status: ChristmasGiftStatus = .idea, createdAt: Date = .now) {
        self.id = id
        self.recipient = recipient
        self.title = title
        self.note = note
        self.responsibleMemberID = responsibleMemberID
        self.status = status
        self.createdAt = createdAt
    }
}


struct ShoppingItemSuggestion: Identifiable, Equatable {
    let title: String
    let category: ShoppingCategory

    var id: String { title.lowercased() }

    static let catalog: [ShoppingItemSuggestion] = [
        .init(title: "Äpplen", category: .fruitVegetables),
        .init(title: "Bananer", category: .fruitVegetables),
        .init(title: "Apelsiner", category: .fruitVegetables),
        .init(title: "Avokado", category: .fruitVegetables),
        .init(title: "Gurka", category: .fruitVegetables),
        .init(title: "Tomater", category: .fruitVegetables),
        .init(title: "Potatis", category: .fruitVegetables),
        .init(title: "Morötter", category: .fruitVegetables),
        .init(title: "Paprika", category: .fruitVegetables),
        .init(title: "Sallad", category: .fruitVegetables),
        .init(title: "Mjölk", category: .dairy),
        .init(title: "Mellanmjölk", category: .dairy),
        .init(title: "Lättmjölk", category: .dairy),
        .init(title: "Yoghurt", category: .dairy),
        .init(title: "Fil", category: .dairy),
        .init(title: "Smör", category: .dairy),
        .init(title: "Ost", category: .dairy),
        .init(title: "Grädde", category: .dairy),
        .init(title: "Crème fraiche", category: .dairy),
        .init(title: "Ägg", category: .dairy),
        .init(title: "Köttfärs", category: .meatFish),
        .init(title: "Kyckling", category: .meatFish),
        .init(title: "Bacon", category: .meatFish),
        .init(title: "Lax", category: .meatFish),
        .init(title: "Falukorv", category: .meatFish),
        .init(title: "Korv", category: .meatFish),
        .init(title: "Fiskpinnar", category: .frozen),
        .init(title: "Glass", category: .frozen),
        .init(title: "Frysta grönsaker", category: .frozen),
        .init(title: "Bröd", category: .pantry),
        .init(title: "Knäckebröd", category: .pantry),
        .init(title: "Pasta", category: .pantry),
        .init(title: "Ris", category: .pantry),
        .init(title: "Mjöl", category: .pantry),
        .init(title: "Socker", category: .pantry),
        .init(title: "Kaffe", category: .pantry),
        .init(title: "Te", category: .pantry),
        .init(title: "Krossade tomater", category: .pantry),
        .init(title: "Havregryn", category: .pantry),
        .init(title: "Toalettpapper", category: .household),
        .init(title: "Hushållspapper", category: .household),
        .init(title: "Diskmedel", category: .household),
        .init(title: "Tvättmedel", category: .household),
        .init(title: "Diskmaskinstabletter", category: .household),
        .init(title: "Tandkräm", category: .household),
        .init(title: "Schampo", category: .household),
        .init(title: "Soppåsar", category: .household)
        .init(title: "Päron", category: .fruitVegetables),
        .init(title: "Vindruvor", category: .fruitVegetables),
        .init(title: "Jordgubbar", category: .fruitVegetables),
        .init(title: "Blåbär", category: .fruitVegetables),
        .init(title: "Hallon", category: .fruitVegetables),
        .init(title: "Citron", category: .fruitVegetables),
        .init(title: "Lime", category: .fruitVegetables),
        .init(title: "Grapefrukt", category: .fruitVegetables),
        .init(title: "Mango", category: .fruitVegetables),
        .init(title: "Ananas", category: .fruitVegetables),
        .init(title: "Kiwi", category: .fruitVegetables),
        .init(title: "Melon", category: .fruitVegetables),
        .init(title: "Vattenmelon", category: .fruitVegetables),
        .init(title: "Plommon", category: .fruitVegetables),
        .init(title: "Persikor", category: .fruitVegetables),
        .init(title: "Nektariner", category: .fruitVegetables),
        .init(title: "Körsbär", category: .fruitVegetables),
        .init(title: "Clementiner", category: .fruitVegetables),
        .init(title: "Mandariner", category: .fruitVegetables),
        .init(title: "Broccoli", category: .fruitVegetables),
        .init(title: "Blomkål", category: .fruitVegetables),
        .init(title: "Vitkål", category: .fruitVegetables),
        .init(title: "Rödkål", category: .fruitVegetables),
        .init(title: "Grönkål", category: .fruitVegetables),
        .init(title: "Spenat", category: .fruitVegetables),
        .init(title: "Ruccola", category: .fruitVegetables),
        .init(title: "Zucchini", category: .fruitVegetables),
        .init(title: "Aubergine", category: .fruitVegetables),
        .init(title: "Champinjoner", category: .fruitVegetables),
        .init(title: "Dill", category: .fruitVegetables),
        .init(title: "Persilja", category: .fruitVegetables),
        .init(title: "Basilika", category: .fruitVegetables),
        .init(title: "Purjolök", category: .fruitVegetables),
        .init(title: "Gul lök", category: .fruitVegetables),
        .init(title: "Rödlök", category: .fruitVegetables),
        .init(title: "Vitlök", category: .fruitVegetables),
        .init(title: "Sötpotatis", category: .fruitVegetables),
        .init(title: "Rödbetor", category: .fruitVegetables),
        .init(title: "Selleri", category: .fruitVegetables),
        .init(title: "Palsternacka", category: .fruitVegetables),
        .init(title: "Majskolvar", category: .fruitVegetables),
        .init(title: "Sockerärtor", category: .fruitVegetables),
        .init(title: "Sparris", category: .fruitVegetables),
        .init(title: "Fänkål", category: .fruitVegetables),
        .init(title: "Rädisor", category: .fruitVegetables),
        .init(title: "Körsbärstomater", category: .fruitVegetables),
        .init(title: "Romansallad", category: .fruitVegetables),
        .init(title: "Färsk ingefära", category: .fruitVegetables),
        .init(title: "Standardmjölk", category: .dairy),
        .init(title: "Laktosfri mjölk", category: .dairy),
        .init(title: "Laktosfri lättmjölk", category: .dairy),
        .init(title: "Havredryck", category: .dairy),
        .init(title: "Sojadryck", category: .dairy),
        .init(title: "Mandeldryck", category: .dairy),
        .init(title: "Matlagningsgrädde", category: .dairy),
        .init(title: "Vispgrädde", category: .dairy),
        .init(title: "Laktosfri grädde", category: .dairy),
        .init(title: "Vaniljyoghurt", category: .dairy),
        .init(title: "Grekisk yoghurt", category: .dairy),
        .init(title: "Turkisk yoghurt", category: .dairy),
        .init(title: "Naturell yoghurt", category: .dairy),
        .init(title: "Kvarg", category: .dairy),
        .init(title: "Keso", category: .dairy),
        .init(title: "Gräddfil", category: .dairy),
        .init(title: "Filmjölk", category: .dairy),
        .init(title: "Laktosfri fil", category: .dairy),
        .init(title: "Mozzarella", category: .dairy),
        .init(title: "Fetaost", category: .dairy),
        .init(title: "Parmesan", category: .dairy),
        .init(title: "Halloumi", category: .dairy),
        .init(title: "Philadelphiaost", category: .dairy),
        .init(title: "Färskost", category: .dairy),
        .init(title: "Riven ost", category: .dairy),
        .init(title: "Hårdost", category: .dairy),
        .init(title: "Brieost", category: .dairy),
        .init(title: "Ädelost", category: .dairy),
        .init(title: "Vaniljsås", category: .dairy),
        .init(title: "Pudding", category: .dairy),
        .init(title: "Risgrynsgröt", category: .dairy),
        .init(title: "Margarin", category: .dairy),
        .init(title: "Bregott", category: .dairy),
        .init(title: "Laktosfritt smör", category: .dairy),
        .init(title: "Nötfärs", category: .meatFish),
        .init(title: "Blandfärs", category: .meatFish),
        .init(title: "Fläskfärs", category: .meatFish),
        .init(title: "Lövbiff", category: .meatFish),
        .init(title: "Entrecôte", category: .meatFish),
        .init(title: "Ryggbiff", category: .meatFish),
        .init(title: "Fläskkotletter", category: .meatFish),
        .init(title: "Fläskfilé", category: .meatFish),
        .init(title: "Fläskytterfilé", category: .meatFish),
        .init(title: "Revbensspjäll", category: .meatFish),
        .init(title: "Kassler", category: .meatFish),
        .init(title: "Skinka", category: .meatFish),
        .init(title: "Rökt skinka", category: .meatFish),
        .init(title: "Salami", category: .meatFish),
        .init(title: "Chorizo", category: .meatFish),
        .init(title: "Prinskorv", category: .meatFish),
        .init(title: "Grillkorv", category: .meatFish),
        .init(title: "Varmkorv", category: .meatFish),
        .init(title: "Kalkon", category: .meatFish),
        .init(title: "Kalkonpålägg", category: .meatFish),
        .init(title: "Kycklingfilé", category: .meatFish),
        .init(title: "Kycklinglårfilé", category: .meatFish),
        .init(title: "Kycklingklubbor", category: .meatFish),
        .init(title: "Kycklingvingar", category: .meatFish),
        .init(title: "Grillad kyckling", category: .meatFish),
        .init(title: "Köttbullar", category: .meatFish),
        .init(title: "Pannbiff", category: .meatFish),
        .init(title: "Hamburgare", category: .meatFish),
        .init(title: "Pulled pork", category: .meatFish),
        .init(title: "Räkor", category: .meatFish),
        .init(title: "Torsk", category: .meatFish),
        .init(title: "Sej", category: .meatFish),
        .init(title: "Kolja", category: .meatFish),
        .init(title: "Tonfisk", category: .meatFish),
        .init(title: "Makrill", category: .meatFish),
        .init(title: "Sill", category: .meatFish),
        .init(title: "Blodpudding", category: .meatFish),
        .init(title: "Leverpastej", category: .meatFish),
        .init(title: "Prosciutto", category: .meatFish),
        .init(title: "Rostbiff", category: .meatFish),
        .init(title: "Vetemjöl", category: .pantry),
        .init(title: "Rågmjöl", category: .pantry),
        .init(title: "Grahamsmjöl", category: .pantry),
        .init(title: "Potatismjöl", category: .pantry),
        .init(title: "Maizena", category: .pantry),
        .init(title: "Bakpulver", category: .pantry),
        .init(title: "Bikarbonat", category: .pantry),
        .init(title: "Vaniljsocker", category: .pantry),
        .init(title: "Florsocker", category: .pantry),
        .init(title: "Farinsocker", category: .pantry),
        .init(title: "Sirap", category: .pantry),
        .init(title: "Honung", category: .pantry),
        .init(title: "Pärlsocker", category: .pantry),
        .init(title: "Kakao", category: .pantry),
        .init(title: "Chokladkaka", category: .pantry),
        .init(title: "Blockchoklad", category: .pantry),
        .init(title: "Mörk choklad", category: .pantry),
        .init(title: "Vit choklad", category: .pantry),
        .init(title: "Ströbröd", category: .pantry),
        .init(title: "Panko", category: .pantry),
        .init(title: "Jäst", category: .pantry),
        .init(title: "Torrjäst", category: .pantry),
        .init(title: "Vaniljextrakt", category: .pantry),
        .init(title: "Kanel", category: .pantry),
        .init(title: "Kardemumma", category: .pantry),
        .init(title: "Paprikapulver", category: .pantry),
        .init(title: "Chilipulver", category: .pantry),
        .init(title: "Oregano", category: .pantry),
        .init(title: "Timjan", category: .pantry),
        .init(title: "Svartpeppar", category: .pantry),
        .init(title: "Vitpeppar", category: .pantry),
        .init(title: "Salt", category: .pantry),
        .init(title: "Flingsalt", category: .pantry),
        .init(title: "Grillkrydda", category: .pantry),
        .init(title: "Tacokrydda", category: .pantry),
        .init(title: "Curry", category: .pantry),
        .init(title: "Spiskummin", category: .pantry),
        .init(title: "Buljongtärningar", category: .pantry),
        .init(title: "Köttbuljong", category: .pantry),
        .init(title: "Grönsaksbuljong", category: .pantry),
        .init(title: "Olivolja", category: .pantry),
        .init(title: "Rapsolja", category: .pantry),
        .init(title: "Matolja", category: .pantry),
        .init(title: "Vinäger", category: .pantry),
        .init(title: "Balsamvinäger", category: .pantry),
        .init(title: "Sojasås", category: .pantry),
        .init(title: "Teriyakisås", category: .pantry),
        .init(title: "Sweet chilisås", category: .pantry),
        .init(title: "Tomatpuré", category: .pantry),
        .init(title: "Passerade tomater", category: .pantry),
        .init(title: "Tomatsås", category: .pantry),
        .init(title: "Pesto", category: .pantry),
        .init(title: "Salsa", category: .pantry),
        .init(title: "Kokosmjölk", category: .pantry),
        .init(title: "Kikärtor", category: .pantry),
        .init(title: "Kidneybönor", category: .pantry),
        .init(title: "Svarta bönor", category: .pantry),
        .init(title: "Vita bönor", category: .pantry),
        .init(title: "Linser", category: .pantry),
        .init(title: "Majs på burk", category: .pantry),
        .init(title: "Tonfisk på burk", category: .pantry),
        .init(title: "Ananas på burk", category: .pantry),
        .init(title: "Oliver", category: .pantry),
        .init(title: "Soltorkade tomater", category: .pantry),
        .init(title: "Kapris", category: .pantry),
        .init(title: "Pickles", category: .pantry),
        .init(title: "Inlagd gurka", category: .pantry),
        .init(title: "Sylt", category: .pantry),
        .init(title: "Jordnötssmör", category: .pantry),
        .init(title: "Nutella", category: .pantry),
        .init(title: "Marmelad", category: .pantry),
        .init(title: "Russin", category: .pantry),
        .init(title: "Nötter", category: .pantry),
        .init(title: "Mandlar", category: .pantry),
        .init(title: "Cashewnötter", category: .pantry),
        .init(title: "Jordnötter", category: .pantry),
        .init(title: "Solrosfrön", category: .pantry),
        .init(title: "Pumpakärnor", category: .pantry),
        .init(title: "Chiafrön", category: .pantry),
        .init(title: "Popcorn", category: .pantry),
        .init(title: "Chips", category: .pantry),
        .init(title: "Salta pinnar", category: .pantry),
        .init(title: "Kex", category: .pantry),
        .init(title: "Digestivekex", category: .pantry),
        .init(title: "Riskakor", category: .pantry),
        .init(title: "Tortillabröd", category: .pantry),
        .init(title: "Tacoskal", category: .pantry),
        .init(title: "Hamburgerbröd", category: .pantry),
        .init(title: "Korvbröd", category: .pantry),
        .init(title: "Pitabröd", category: .pantry),
        .init(title: "Majonnäs", category: .pantry),
        .init(title: "Ketchup", category: .pantry),
        .init(title: "Senap", category: .pantry),
        .init(title: "Salladsdressing", category: .pantry),
        .init(title: "Fond", category: .pantry),
        .init(title: "Frysta ärtor", category: .frozen),
        .init(title: "Fryst majs", category: .frozen),
        .init(title: "Fryst broccoli", category: .frozen),
        .init(title: "Fryst blomkål", category: .frozen),
        .init(title: "Fryst spenat", category: .frozen),
        .init(title: "Frysta bär", category: .frozen),
        .init(title: "Frysta jordgubbar", category: .frozen),
        .init(title: "Frysta blåbär", category: .frozen),
        .init(title: "Fryst mango", category: .frozen),
        .init(title: "Pommes frites", category: .frozen),
        .init(title: "Potatisklyftor", category: .frozen),
        .init(title: "Rösti", category: .frozen),
        .init(title: "Kroketter", category: .frozen),
        .init(title: "Fryst pizza", category: .frozen),
        .init(title: "Färdiga köttbullar", category: .frozen),
        .init(title: "Fryst pyttipanna", category: .frozen),
        .init(title: "Fryst lasagne", category: .frozen),
        .init(title: "Panerad torsk", category: .frozen),
        .init(title: "Laxportioner frysta", category: .frozen),
        .init(title: "Fryst wokmix", category: .frozen),
        .init(title: "Fryst grönsaksblandning", category: .frozen),
        .init(title: "Glasspinnar", category: .frozen),
        .init(title: "Glasspaket", category: .frozen),
        .init(title: "Sorbet", category: .frozen),
        .init(title: "Fryst bröd", category: .frozen),
        .init(title: "Frysta bullar", category: .frozen),
        .init(title: "Fryst paj", category: .frozen),
        .init(title: "Fryst färdigmat", category: .frozen),
        .init(title: "Handtvål", category: .household),
        .init(title: "Duschkräm", category: .household),
        .init(title: "Balsam", category: .household),
        .init(title: "Hårinpackning", category: .household),
        .init(title: "Deodorant", category: .household),
        .init(title: "Rakhyvel", category: .household),
        .init(title: "Rakgel", category: .household),
        .init(title: "Bomullspinnar", category: .household),
        .init(title: "Bomullsrondeller", category: .household),
        .init(title: "Tandborste", category: .household),
        .init(title: "Tandtråd", category: .household),
        .init(title: "Munskölj", category: .household),
        .init(title: "Ansiktsrengöring", category: .household),
        .init(title: "Hudkräm", category: .household),
        .init(title: "Solkräm", category: .household),
        .init(title: "Plåster", category: .household),
        .init(title: "Nässpray", category: .household),
        .init(title: "Toalettborste", category: .household),
        .init(title: "Toalettrengöring", category: .household),
        .init(title: "Allrengöring", category: .household),
        .init(title: "Badrumsrengöring", category: .household),
        .init(title: "Fönsterputs", category: .household),
        .init(title: "Köksspray", category: .household),
        .init(title: "Såpa", category: .household),
        .init(title: "Sköljmedel", category: .household),
        .init(title: "Fläckborttagning", category: .household),
        .init(title: "Maskindiskmedel", category: .household),
        .init(title: "Diskborste", category: .household),
        .init(title: "Disktrasor", category: .household),
        .init(title: "Svampar", category: .household),
        .init(title: "Stålull", category: .household),
        .init(title: "Bakplåtspapper", category: .household),
        .init(title: "Ugnsfolie", category: .household),
        .init(title: "Plastfolie", category: .household),
        .init(title: "Fryspåsar", category: .household),
        .init(title: "Matavfallspåsar", category: .household),
        .init(title: "Soppåsar små", category: .household),
        .init(title: "Soppåsar stora", category: .household),
        .init(title: "Pappersservetter", category: .household),
        .init(title: "Tändstickor", category: .household),
        .init(title: "Tändare", category: .household),
        .init(title: "Batterier AA", category: .household),
        .init(title: "Batterier AAA", category: .household),
        .init(title: "Glödlampor", category: .household),
        .init(title: "Dammsugarpåsar", category: .household),
        .init(title: "Hundmat", category: .household),
        .init(title: "Kattmat", category: .household),
        .init(title: "Kattströ", category: .household),
        .init(title: "Hundgodis", category: .household),
        .init(title: "Kattgodis", category: .household),
    ]

    static func matching(_ query: String, excluding existingTitles: [String] = []) -> [ShoppingItemSuggestion] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 2 else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        let existing = Set(existingTitles.map { $0.folding(options: options, locale: Locale(identifier: "sv_SE")) })
        return catalog
            .filter { suggestion in
                let candidate = suggestion.title.folding(options: options, locale: Locale(identifier: "sv_SE"))
                return !existing.contains(candidate) && candidate.localizedStandardContains(cleaned.folding(options: options, locale: Locale(identifier: "sv_SE")))
            }
            .sorted { lhs, rhs in
                let query = cleaned.folding(options: options, locale: Locale(identifier: "sv_SE"))
                let left = lhs.title.folding(options: options, locale: Locale(identifier: "sv_SE"))
                let right = rhs.title.folding(options: options, locale: Locale(identifier: "sv_SE"))
                let leftPrefix = left.hasPrefix(query)
                let rightPrefix = right.hasPrefix(query)
                if leftPrefix != rightPrefix { return leftPrefix }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
            .prefix(6)
            .map { $0 }
    }
}
