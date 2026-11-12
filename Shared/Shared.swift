import Foundation
import SwiftUI

// MARK: - Storage
enum Shared {
    // Должен совпадать с App Group в provisioning profile
    static let group = "group.flamio.ios.ipa"
    static let key = "appdata.v1"
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
    static var groupOK: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil
    }
}

extension KeyedDecodingContainer {
    /// Мягкое чтение: если ключа нет, берём значение по умолчанию (старые данные не пропадают)
    func v<T: Decodable>(_ k: Key, _ d: T) -> T { (try? decodeIfPresent(T.self, forKey: k)) ?? d }
}

// MARK: - Язык, даты, деньги
func localeID(_ lang: String) -> String {
    switch lang {
    case "uk": return "uk_UA"
    case "en": return "en_US"
    default: return "ru_RU"
    }
}

func appCal(_ lang: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.locale = Locale(identifier: localeID(lang))
    c.firstWeekday = lang == "en" ? 1 : 2
    return c
}

func capFirst(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

/// «Июнь (06)»
func monthTitle(_ d: Date, _ lang: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: localeID(lang))
    f.dateFormat = "LLLL"
    let name = capFirst(f.string(from: d))
    f.dateFormat = "MM"
    return "\(name) (\(f.string(from: d)))"
}

func weekdayName(_ d: Date, _ lang: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: localeID(lang))
    f.dateFormat = "EEEE"
    return capFirst(f.string(from: d))
}

func money(_ v: Double, _ code: String, _ lang: String) -> String {
    v.formatted(.currency(code: code).precision(.fractionLength(0...2)).locale(Locale(identifier: localeID(lang))))
}

func hoursStr(_ h: Double) -> String {
    let m = Int((h * 60).rounded())
    return String(format: "%d:%02d", m / 60, m % 60)
}

func hms(_ s: TimeInterval) -> String {
    let t = Int(max(0, s))
    return String(format: "%d:%02d:%02d", t / 3600, t % 3600 / 60, t % 60)
}

func temp(_ c: Double, _ fahrenheit: Bool) -> String {
    let v = fahrenheit ? c * 9 / 5 + 32 : c
    return "\(Int(v.rounded()))°"
}

enum Currencies {
    static let all = ["UAH", "USD", "EUR", "PLN", "GBP", "RUB", "CZK", "CHF", "TRY", "KZT", "CAD"]
    static func label(_ c: String) -> String {
        "\(c) · \(Locale(identifier: "ru_RU").localizedString(forCurrencyCode: c) ?? c)"
    }
}

struct AccentOpt: Identifiable {
    let id: String
    let color: Color
}

enum Accent {
    static let all = [
        AccentOpt(id: "orange", color: .orange), AccentOpt(id: "purple", color: .purple),
        AccentOpt(id: "blue", color: .blue), AccentOpt(id: "green", color: .green),
        AccentOpt(id: "pink", color: .pink), AccentOpt(id: "red", color: .red),
        AccentOpt(id: "teal", color: .teal)
    ]
    static func color(_ id: String) -> Color { all.first { $0.id == id }?.color ?? .orange }
}

// MARK: - Settings
struct Settings: Codable {
    var language = "ru"          // ru | uk | en
    var currency = "UAH"
    var theme = "system"         // system | light | dark
    var accent = "orange"
    var fahrenheit = false
    var weatherBG = true
    var petStyle = "flamio"      // flamio | emoji
    var petEmoji = "🦊"
    var petName = "Flamio"
    var outfit: [String: String] = [:]
    var slot1 = "pet"            // блоки виджета: off | shifts | pet | spending | weather
    var slot2 = "shifts"
    var slot3 = "weather"
    var widgetAll = false

    enum CodingKeys: String, CodingKey {
        case language, currency, theme, accent, fahrenheit, weatherBG, petStyle, petEmoji, petName
        case outfit, slot1, slot2, slot3, widgetAll
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        language = c.v(.language, language)
        currency = c.v(.currency, currency)
        theme = c.v(.theme, theme)
        accent = c.v(.accent, accent)
        fahrenheit = c.v(.fahrenheit, fahrenheit)
        weatherBG = c.v(.weatherBG, weatherBG)
        petStyle = c.v(.petStyle, petStyle)
        petEmoji = c.v(.petEmoji, petEmoji)
        petName = c.v(.petName, petName)
        outfit = c.v(.outfit, outfit)
        slot1 = c.v(.slot1, slot1)
        slot2 = c.v(.slot2, slot2)
        slot3 = c.v(.slot3, slot3)
        widgetAll = c.v(.widgetAll, widgetAll)
    }
}

// MARK: - Weather
struct City: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var country: String
    var lat: Double
    var lon: Double
}

struct WeatherSnapshot: Codable {
    struct Day: Codable, Identifiable {
        var id = UUID()
        var date: Date
        var min: Double
        var max: Double
        var code: Int
        var rain: Int
    }
    var cityName: String
    var temp: Double
    var feels: Double
    var code: Int
    var isDay: Bool
    var rainChance: Int
    var precip: Double
    var days: [Day]
    var updated: Date

    var umbrella: Bool { rainChance >= 40 || precip > 0 }

    func clothes(_ lang: String) -> (String, String) {
        let level = feels < 5 ? 0 : (feels < 16 ? 1 : 2)
        let e = ["🧥", "🧣", "👕"][level]
        switch lang {
        case "uk": return (e, ["Вдягайся тепло", "Вдягайся помірно", "Вдягайся легко"][level])
        case "en": return (e, ["Dress warm", "Dress medium", "Dress light"][level])
        default: return (e, ["Одевайся тепло", "Одевайся средне", "Одевайся легко"][level])
        }
    }
    func umbrellaText(_ lang: String) -> String {
        switch lang {
        case "uk": return umbrella ? "Візьми парасольку" : "Парасолька не потрібна"
        case "en": return umbrella ? "Take an umbrella" : "No umbrella needed"
        default: return umbrella ? "Возьми зонт" : "Зонт не нужен"
        }
    }
}

func weatherSymbol(_ c: Int) -> String {
    switch c {
    case 0: return "sun.max"
    case 1, 2: return "cloud.sun"
    case 3: return "cloud"
    case 45, 48: return "cloud.fog"
    case 51...57: return "cloud.drizzle"
    case 61...67, 80...82: return "cloud.rain"
    case 71...77, 85, 86: return "cloud.snow"
    case 95...99: return "cloud.bolt.rain"
    default: return "cloud"
    }
}

func weatherText(_ c: Int, _ lang: String) -> String {
    let k: Int
    switch c {
    case 0: k = 0
    case 1, 2: k = 1
    case 3: k = 2
    case 45, 48: k = 3
    case 51...57: k = 4
    case 61...67, 80...82: k = 5
    case 71...77, 85, 86: k = 6
    case 95...99: k = 7
    default: k = 2
    }
    let ru = ["Ясно", "Малооблачно", "Облачно", "Туман", "Морось", "Дождь", "Снег", "Гроза"]
    let uk = ["Ясно", "Мінлива хмарність", "Хмарно", "Туман", "Мжичка", "Дощ", "Сніг", "Гроза"]
    let en = ["Clear", "Partly cloudy", "Cloudy", "Fog", "Drizzle", "Rain", "Snow", "Thunderstorm"]
    return (lang == "uk" ? uk : (lang == "en" ? en : ru))[k]
}

enum WeatherService {
    private struct Geo: Decodable {
        struct R: Decodable { let name: String; let country: String?; let latitude: Double; let longitude: Double }
        let results: [R]?
    }
    private struct Fc: Decodable {
        struct Cur: Decodable {
            let temperature_2m: Double
            let apparent_temperature: Double
            let weather_code: Int
            let precipitation: Double
            let is_day: Int
        }
        struct Daily: Decodable {
            let time: [String]
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
            let weather_code: [Int]
            let precipitation_probability_max: [Int?]
        }
        let current: Cur
        let daily: Daily
    }

    static func search(_ q: String) async -> [City] {
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        c.queryItems = [.init(name: "name", value: q), .init(name: "count", value: "6"), .init(name: "language", value: "ru")]
        guard let u = c.url else { return [] }
        do {
            let (d, _) = try await URLSession.shared.data(from: u)
            let r = try JSONDecoder().decode(Geo.self, from: d)
            return (r.results ?? []).map { City(name: $0.name, country: $0.country ?? "", lat: $0.latitude, lon: $0.longitude) }
        } catch { return [] }
    }

    static func fetch(_ city: City) async -> WeatherSnapshot? {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: String(city.lat)),
            .init(name: "longitude", value: String(city.lon)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,precipitation,is_day"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "5")
        ]
        guard let u = c.url else { return nil }
        do {
            let (d, _) = try await URLSession.shared.data(from: u)
            let f = try JSONDecoder().decode(Fc.self, from: d)
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.locale = Locale(identifier: "en_US_POSIX")
            var days: [WeatherSnapshot.Day] = []
            for i in f.daily.time.indices {
                days.append(.init(date: fmt.date(from: f.daily.time[i]) ?? .now,
                                  min: f.daily.temperature_2m_min[i],
                                  max: f.daily.temperature_2m_max[i],
                                  code: f.daily.weather_code[i],
                                  rain: f.daily.precipitation_probability_max[i] ?? 0))
            }
            let rain = (f.daily.precipitation_probability_max.first ?? nil) ?? 0
            return WeatherSnapshot(cityName: city.name, temp: f.current.temperature_2m,
                                   feels: f.current.apparent_temperature, code: f.current.weather_code,
                                   isDay: f.current.is_day == 1, rainChance: rain,
                                   precip: f.current.precipitation, days: days, updated: .now)
        } catch { return nil }
    }
}

// MARK: - Shifts & pay
enum Period: String, CaseIterable, Identifiable {
    case day = "День", week = "Неделя", month = "Месяц"
    var id: String { rawValue }
}

enum PayKind: String, Codable, CaseIterable {
    case hourly = "В час", perShift = "За смену", perDay = "За день"
}

struct PayRule: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: PayKind
    var amount: Double
}

enum BonusKind: String, Codable, CaseIterable {
    case monthHours = "За часы в месяц", task = "За работу", other = "Другое"
}

struct Bonus: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kind: BonusKind
    var hours: Double = 0
    var amount: Double = 0
    var addToRate = false
    var negative = false
    var note = ""
    var signed: Double { negative ? -amount : amount }
}

struct ShiftTemplate: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var auto: Bool
    var startMin: Int = 9 * 60
    var endMin: Int = 18 * 60
    var breakMin: Int = 15
    var lunchMin: Int = 30
    var paidBreaks = false
    var payID: UUID?
    var emoji: String?
    var plannedMin: Int?      // плановая длительность для ручной смены
}

struct Pause: Codable, Hashable {
    var start: Date
    var end: Date?
    var lunch: Bool
}

struct ShiftRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var templateID: UUID?
    var title: String
    var start: Date
    var end: Date?
    var pauses: [Pause] = []
    var deductMin: Int = 0
    var bonusIDs: [UUID] = []
    var breaksPaid = false
    var emoji: String?
    var plannedMin: Int?

    var onPause: Bool { end == nil && pauses.last != nil && pauses.last!.end == nil }

    func worked(now: Date = .now) -> TimeInterval {
        let e = end ?? now
        var t = e.timeIntervalSince(start) - Double(deductMin) * 60
        if !breaksPaid {
            for p in pauses { t -= (p.end ?? e).timeIntervalSince(p.start) }
        }
        return max(0, t)
    }
}

// MARK: - Money entries
struct Cat: Identifiable {
    let id: String
    let emoji: String
    let name: String
}

enum Cats {
    static let expense = [
        Cat(id: "food", emoji: "🛒", name: "Еда"),
        Cat(id: "transport", emoji: "🚌", name: "Транспорт"),
        Cat(id: "home", emoji: "🏠", name: "Дом"),
        Cat(id: "fun", emoji: "🎮", name: "Отдых"),
        Cat(id: "health", emoji: "💊", name: "Здоровье"),
        Cat(id: "shop", emoji: "🛍️", name: "Покупки"),
        Cat(id: "other", emoji: "✨", name: "Другое")
    ]
    static let income = [
        Cat(id: "salary", emoji: "💼", name: "Работа"),
        Cat(id: "side", emoji: "💸", name: "Подработка"),
        Cat(id: "gift", emoji: "🎁", name: "Подарок"),
        Cat(id: "inother", emoji: "➕", name: "Другое")
    ]
    static func find(_ id: String) -> Cat {
        (expense + income).first { $0.id == id } ?? expense[expense.count - 1]
    }
}

struct Expense: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var amount: Double
    var cat: String
    var note: String
    var income: Bool?
    var emoji: String?

    var isIncome: Bool { income ?? false }
    var shownEmoji: String {
        if let e = emoji, !e.isEmpty { return e }
        return Cats.find(cat).emoji
    }
}

// MARK: - Pet
struct Food: Identifiable {
    let emoji: String
    let name: String
    let health: Int      // -2 ... 3
    let group: String
    var id: String { emoji }
    init(_ e: String, _ n: String, _ h: Int, _ g: String) { emoji = e; name = n; health = h; group = g }
}

enum Foods {
    static let all = [
        Food("🥦", "Брокколи", 3, "veg"), Food("🥕", "Морковь", 3, "veg"),
        Food("🍎", "Яблоко", 3, "fruit"), Food("🍌", "Банан", 2, "fruit"),
        Food("🐟", "Рыба", 3, "protein"), Food("🍗", "Курица", 2, "protein"),
        Food("🍚", "Рис", 2, "grain"), Food("🥛", "Молоко", 1, "dairy"),
        Food("🍕", "Пицца", -1, "junk"), Food("🍔", "Бургер", -2, "junk"),
        Food("🍟", "Фри", -2, "junk"), Food("🍫", "Шоколад", -2, "junk")
    ]
    static func find(_ id: String) -> Food? { all.first { $0.id == id } }
}

struct PetLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var kind: String   // "feed" | "play"
    var item: String
}

// MARK: - All data
struct AppData: Codable {
    var settings = Settings()
    var cities: [City] = []
    var selectedCity = 0
    var weatherCache: [String: WeatherSnapshot] = [:]
    var templates: [ShiftTemplate] = []
    var pays: [PayRule] = [PayRule(name: "Почасовая", kind: .hourly, amount: 0)]
    var bonuses: [Bonus] = []
    var records: [ShiftRecord] = []
    var expenses: [Expense] = []
    var petLogs: [PetLog] = []

    enum CodingKeys: String, CodingKey {
        case settings, cities, selectedCity, weatherCache, templates, pays, bonuses, records, expenses, petLogs
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        settings = c.v(.settings, settings)
        cities = c.v(.cities, cities)
        selectedCity = c.v(.selectedCity, selectedCity)
        weatherCache = c.v(.weatherCache, weatherCache)
        templates = c.v(.templates, templates)
        pays = c.v(.pays, pays)
        bonuses = c.v(.bonuses, bonuses)
        records = c.v(.records, records)
        expenses = c.v(.expenses, expenses)
        petLogs = c.v(.petLogs, petLogs)
    }

    static func load() -> AppData {
        guard let d = Shared.defaults.data(forKey: Shared.key),
              let v = try? JSONDecoder().decode(AppData.self, from: d) else { return AppData() }
        return v
    }
}

extension AppData {
    private var cal: Calendar { appCal(settings.language) }

    func m(_ v: Double) -> String { money(v, settings.currency, settings.language) }

    var currentWeather: WeatherSnapshot? {
        guard cities.indices.contains(selectedCity) else { return nil }
        return weatherCache[cities[selectedCity].id.uuidString]
    }

    // Смены
    func rule(for r: ShiftRecord) -> PayRule? {
        let tid = templates.first { $0.id == r.templateID }?.payID
        return pays.first { $0.id == tid } ?? pays.first
    }
    func emoji(for r: ShiftRecord) -> String {
        if let e = r.emoji, !e.isEmpty { return e }
        if let t = templates.first(where: { $0.id == r.templateID }), let e = t.emoji, !e.isEmpty { return e }
        return String(r.title.prefix(1))
    }
    func monthRecords(_ d: Date) -> [ShiftRecord] {
        records.filter { cal.isDate($0.start, equalTo: d, toGranularity: .month) }
    }
    func dayRecords(_ d: Date) -> [ShiftRecord] {
        records.filter { cal.isDate($0.start, inSameDayAs: d) }
    }
    func records(in p: Period, around d: Date) -> [ShiftRecord] {
        switch p {
        case .day: return dayRecords(d)
        case .week:
            let i = cal.dateInterval(of: .weekOfYear, for: d) ?? DateInterval(start: d, duration: 0)
            return records.filter { i.contains($0.start) }
        case .month: return monthRecords(d)
        }
    }
    func monthHours(_ d: Date) -> Double {
        monthRecords(d).reduce(0.0) { $0 + $1.worked() / 3600 }
    }
    func payFor(_ p: Period, _ d: Date) -> Double {
        p == .month ? monthPay(d) : pay(records(in: p, around: d))
    }
    func monthPay(_ d: Date) -> Double { pay(monthRecords(d), monthFixedFor: d) }

    private func monthBonus(_ d: Date) -> (rate: Double, fixed: Double) {
        let hrs = monthHours(d)
        let hit = bonuses.filter { $0.kind == .monthHours && hrs >= $0.hours }
        let rate = hit.filter { $0.addToRate }.reduce(0.0) { $0 + $1.signed }
        let fixed = hit.filter { !$0.addToRate }.reduce(0.0) { $0 + $1.signed }
        return (rate, fixed)
    }

    func pay(_ recs: [ShiftRecord], monthFixedFor: Date? = nil) -> Double {
        var total = 0.0
        var seen = Set<Date>()
        var rates: [Date: Double] = [:]
        for r in recs {
            let ms = cal.dateInterval(of: .month, for: r.start)?.start ?? r.start
            if rates[ms] == nil { rates[ms] = monthBonus(r.start).rate }
            let att = bonuses.filter { r.bonusIDs.contains($0.id) }
            let attRate: Double = att.filter { $0.addToRate }.reduce(0.0) { $0 + $1.signed }
            let attFixed: Double = att.filter { !$0.addToRate }.reduce(0.0) { $0 + $1.signed }
            let rateB = attRate + (rates[ms] ?? 0)
            total += attFixed
            guard let rl = rule(for: r) else { continue }
            let h = r.worked() / 3600
            switch rl.kind {
            case .hourly:
                total += h * (rl.amount + rateB)
            case .perShift:
                total += rl.amount + rateB * h
            case .perDay:
                if seen.insert(cal.startOfDay(for: r.start)).inserted { total += rl.amount }
                total += rateB * h
            }
        }
        if let m = monthFixedFor { total += monthBonus(m).fixed }
        return total
    }

    // Финансы
    func entries(in d: Date) -> [Expense] {
        expenses.filter { cal.isDate($0.date, equalTo: d, toGranularity: .month) }
    }
    func monthIncome(_ d: Date) -> Double {
        entries(in: d).filter { $0.isIncome }.reduce(0.0) { $0 + $1.amount }
    }
    func spendByCat(_ d: Date) -> [String: Double] {
        var r = [String: Double]()
        for e in entries(in: d) where !e.isIncome { r[e.cat, default: 0] += e.amount }
        return r
    }
    func monthSpend(_ d: Date) -> Double { spendByCat(d).values.reduce(0, +) }

    // Питомец
    var streakAlive: Bool { petLogs.contains { cal.isDateInToday($0.date) } }
    var streak: Int {
        let days = Set(petLogs.map { cal.startOfDay(for: $0.date) })
        var d = cal.startOfDay(for: .now)
        if !days.contains(d) { d = cal.date(byAdding: .day, value: -1, to: d) ?? d }
        var n = 0
        while days.contains(d) {
            n += 1
            d = cal.date(byAdding: .day, value: -1, to: d) ?? .distantPast
        }
        return n
    }
    func feeds(on day: Date) -> [Food] {
        petLogs.filter { $0.kind == "feed" && cal.isDate($0.date, inSameDayAs: day) }.compactMap { Foods.find($0.item) }
    }
    func plays(on day: Date) -> Int {
        petLogs.filter { $0.kind == "play" && cal.isDate($0.date, inSameDayAs: day) }.count
    }
    func dayHealth(_ day: Date) -> Double? {
        let f = feeds(on: day)
        guard !f.isEmpty else { return nil }
        return Double(f.map(\.health).reduce(0, +)) / Double(f.count)
    }
    func bestFood() -> Food {
        let since = cal.date(byAdding: .day, value: -3, to: .now) ?? .now
        let eaten = petLogs.filter { $0.kind == "feed" && $0.date >= since }.compactMap { Foods.find($0.item) }
        func cnt(_ g: String) -> Int { eaten.filter { $0.group == g }.count }
        let good = Foods.all.filter { $0.health > 0 }
        return good.min { (cnt($0.group), -$0.health) < (cnt($1.group), -$1.health) } ?? good[0]
    }
}
