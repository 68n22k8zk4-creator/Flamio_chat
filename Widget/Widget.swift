import WidgetKit
import SwiftUI

struct Entry: TimelineEntry {
    let date: Date
    let data: AppData
    let hasData: Bool
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, data: AppData(), hasData: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let has = Shared.defaults.data(forKey: Shared.key) != nil
        completion(Entry(date: .now, data: AppData.load(), hasData: has))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            var d = AppData.load()
            let has = Shared.defaults.data(forKey: Shared.key) != nil
            let s = d.settings
            let needsWeather = s.widgetAll || [s.slot1, s.slot2, s.slot3].contains("weather")
            if needsWeather, d.cities.indices.contains(d.selectedCity) {
                let c = d.cities[d.selectedCity]
                if let w = await WeatherService.fetch(c) { d.weatherCache[c.id.uuidString] = w }
            }
            let now = Date()
            // Обновление раз в 30 минут: минимальная нагрузка на батарею
            let tl = Timeline(entries: [Entry(date: now, data: d, hasData: has)],
                              policy: .after(now.addingTimeInterval(30 * 60)))
            completion(tl)
        }
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    let e: Entry

    var sections: [String] {
        let s = e.data.settings
        if family == .systemLarge && s.widgetAll { return ["shifts", "pet", "spending", "weather"] }
        let all = [s.slot1, s.slot2, s.slot3].filter { $0 != "off" }
        let n = family == .systemSmall ? 1 : (family == .systemMedium ? 2 : 3)
        return Array(all.prefix(n))
    }

    func block(_ s: String) -> some View { BlockView(s: s, d: e.data) }

    var body: some View {
        let secs = sections
        Group {
            if !e.hasData {
                VStack(spacing: 4) {
                    Text("Открой Flamio").font(.headline)
                    Text(Shared.groupOK ? "и виджет обновится" : "нет App Group в профиле")
                        .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            } else if family == .systemLarge && secs.count == 4 {
                VStack(spacing: 14) {
                    HStack { block("shifts"); Divider(); block("pet") }
                    Divider()
                    HStack { block("spending"); Divider(); block("weather") }
                }
            } else if family == .systemMedium {
                HStack {
                    ForEach(Array(secs.enumerated()), id: \.offset) { item in
                        if item.offset > 0 { Divider() }
                        block(item.element)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(secs.enumerated()), id: \.offset) { item in
                        if item.offset > 0 { Divider() }
                        block(item.element)
                    }
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

struct BlockView: View {
    let s: String
    let d: AppData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch s {
            case "shifts": shifts
            case "pet": pet
            case "spending": spending
            case "weather": weather
            default: EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func label(_ icon: String, _ t: String) -> some View {
        Label(t, systemImage: icon).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
    }

    var shifts: some View {
        let act = d.records.first { $0.end == nil }
        let today = d.dayRecords(.now).reduce(0.0) { $0 + $1.worked() / 3600 }
        let big = act.map { hoursStr($0.worked() / 3600) } ?? (today > 0 ? hoursStr(today) : "—")
        return VStack(alignment: .leading, spacing: 2) {
            label("calendar", "Смены")
            Text(big).font(.system(size: 28, weight: .light))
            Text(act != nil ? "идёт смена" : "сегодня").font(.caption2).foregroundStyle(.secondary)
            Text("\(hoursStr(d.monthHours(.now))) ч · \(d.m(d.monthPay(.now)))")
                .font(.caption2).lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    var pet: some View {
        VStack(alignment: .leading, spacing: 2) {
            label("flame", d.settings.petName)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").foregroundStyle(d.streakAlive ? Color.orange : Color.gray)
                Text("\(d.streak)").font(.system(size: 28, weight: .light))
            }
            Text(d.streakAlive ? "дней подряд" : "покорми сегодня!").font(.caption2).foregroundStyle(.secondary)
        }
    }

    var spending: some View {
        let earned = d.monthIncome(.now) + d.monthPay(.now)
        let spent = d.monthSpend(.now)
        let top = d.spendByCat(.now).max { $0.value < $1.value }
        return VStack(alignment: .leading, spacing: 2) {
            label("creditcard", "Финансы")
            Text(d.m(earned - spent)).font(.system(size: 24, weight: .light)).lineLimit(1).minimumScaleFactor(0.5)
            Text("потрачено \(d.m(spent))").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            if let top {
                Text("\(Cats.find(top.key).emoji) \(Cats.find(top.key).name)").font(.caption2).lineLimit(1)
            }
        }
    }

    var weather: some View {
        VStack(alignment: .leading, spacing: 2) {
            label("cloud.sun", d.currentWeather?.cityName ?? "Погода")
            if let w = d.currentWeather {
                HStack(spacing: 6) {
                    Image(systemName: weatherSymbol(w.code)).symbolRenderingMode(.multicolor)
                    Text(temp(w.temp, d.settings.fahrenheit)).font(.system(size: 28, weight: .light))
                }
                Text("\(w.clothes(d.settings.language).1)\(w.umbrella ? " · ☂️" : "")")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            } else {
                Text("Добавь город").font(.caption)
            }
        }
    }
}

@main
struct LifeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LifeWidget", provider: Provider()) { e in
            WidgetView(e: e)
        }
        .configurationDisplayName("Flamio")
        .description("Смены, огонёк, финансы и погода. Блоки выбираются в настройках приложения.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
