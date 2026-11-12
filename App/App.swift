import SwiftUI
import WidgetKit

@main
struct LifeAppMain: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store) }
    }
}

@MainActor
final class Store: ObservableObject {
    @Published var data: AppData { didSet { save() } }
    init() { data = AppData.load() }

    private func save() {
        if let d = try? JSONEncoder().encode(data) { Shared.defaults.set(d, forKey: Shared.key) }
        WidgetCenter.shared.reloadAllTimelines()
    }
    func log(_ kind: String, _ item: String) {
        data.petLogs.append(PetLog(date: .now, kind: kind, item: item))
    }
}

struct RootView: View {
    @EnvironmentObject var store: Store

    var scheme: ColorScheme? {
        switch store.data.settings.theme {
        case "light": return .light
        case "dark": return .dark
        default: return .dark
        }
    }

    var body: some View {
        let s = store.data.settings
        TabView {
            WeatherView().tabItem { Label("Погода", systemImage: "cloud.sun") }
            ShiftsView().tabItem { Label("Смены", systemImage: "calendar") }
            PetView().tabItem { Label("Огонёк", systemImage: "flame") }
            SpendingView().tabItem { Label("Траты", systemImage: "creditcard") }
            SettingsView().tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .tint(FlamioPalette.orange)
        .toolbarBackground(FlamioPalette.background.opacity(0.96), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(scheme)
        .environment(\.locale, Locale(identifier: localeID(s.language)))
        .environment(\.calendar, appCal(s.language))
    }
}

// MARK: - Helpers
func optBinding(_ b: Binding<String?>) -> Binding<String> {
    Binding(get: { b.wrappedValue ?? "" }, set: { b.wrappedValue = $0.isEmpty ? nil : $0 })
}

struct EmojiField: View {
    let title: String
    @Binding var text: String
    var presets = ["🔥", "⭐", "💼", "🌙", "☀️", "🏠", "🚗", "💪", "🎯", "🍕", "❤️", "🎁"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                TextField("🙂", text: $text)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .onChange(of: text) { _, v in
                        if v.count > 1 { text = String(v.suffix(1)) }
                    }
            }
            if !presets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(presets, id: \.self) { e in
                            Button { text = e } label: { Text(e).font(.title2) }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

func weatherGradient(_ w: WeatherSnapshot) -> [Color] {
    func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
    if !w.isDay && w.code <= 2 { return [c(0.04, 0.06, 0.18), c(0.18, 0.14, 0.38)] }
    switch w.code {
    case 0, 1:
        return w.feels >= 18 ? [c(0.2, 0.55, 0.95), c(1.0, 0.72, 0.32)] : [c(0.2, 0.5, 0.88), c(0.6, 0.82, 0.96)]
    case 2, 3, 45, 48:
        return w.isDay ? [c(0.45, 0.52, 0.62), c(0.68, 0.73, 0.8)] : [c(0.15, 0.17, 0.25), c(0.3, 0.33, 0.42)]
    case 51...67, 80...82:
        return [c(0.18, 0.25, 0.36), c(0.35, 0.45, 0.58)]
    case 71...77, 85, 86:
        return [c(0.5, 0.64, 0.78), c(0.82, 0.88, 0.94)]
    case 95...99:
        return [c(0.14, 0.1, 0.24), c(0.3, 0.24, 0.45)]
    default:
        return [c(0.4, 0.5, 0.62), c(0.65, 0.72, 0.8)]
    }
}

// MARK: - Weather
struct WeatherView: View {
    @EnvironmentObject var store: Store
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if store.data.cities.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "cloud.sun").font(.system(size: 50)).foregroundStyle(.secondary)
                        Text("Добавь город").foregroundStyle(.secondary)
                        Button("Добавить") { showSettings = true }.buttonStyle(.borderedProminent)
                    }
                } else {
                    TabView(selection: $store.data.selectedCity) {
                        ForEach(Array(store.data.cities.enumerated()), id: \.element.id) { item in
                            CityPage(city: item.element).tag(item.offset)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
            }
            .background(FlamioBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: $showSettings) { WeatherSettings() }
        }
    }
}

struct CityPage: View {
    @EnvironmentObject var store: Store
    let city: City

    var snap: WeatherSnapshot? { store.data.weatherCache[city.id.uuidString] }

    var body: some View {
        let s = store.data.settings
        let useBG = s.weatherBG && snap != nil
        let fg: Color = useBG ? .white : .primary
        ZStack {
            if useBG, let w = snap {
                LinearGradient(colors: weatherGradient(w), startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            }
            ScrollView {
                if let w = snap {
                    content(w, s, fg)
                } else {
                    ProgressView().padding(.top, 140)
                }
            }
            .refreshable { await refresh() }
        }
        .task(id: city.id) { await refresh() }
    }

    func refresh() async {
        if let w = await WeatherService.fetch(city) { store.data.weatherCache[city.id.uuidString] = w }
    }

    func content(_ w: WeatherSnapshot, _ s: Settings, _ fg: Color) -> some View {
        VStack(spacing: 14) {
            Text(city.name).font(.title2).fontWeight(.medium)
            Image(systemName: weatherSymbol(w.code)).font(.system(size: 60)).symbolRenderingMode(.multicolor)
            Text(temp(w.temp, s.fahrenheit)).font(.system(size: 76, weight: .thin))
            Text(weatherText(w.code, s.language)).font(.title3)
            Text("↓ \(temp(w.days.first?.min ?? w.temp, s.fahrenheit))   ↑ \(temp(w.days.first?.max ?? w.temp, s.fahrenheit))")
                .font(.footnote).opacity(0.75)
            HStack(spacing: 10) {
                chip(w.clothes(s.language).0, w.clothes(s.language).1)
                chip(w.umbrella ? "☂️" : "🕶️", w.umbrellaText(s.language))
            }
            VStack(spacing: 0) {
                ForEach(w.days) { d in
                    HStack {
                        Text(weekdayName(d.date, s.language)).frame(width: 140, alignment: .leading)
                        Image(systemName: weatherSymbol(d.code)).symbolRenderingMode(.multicolor)
                        Spacer()
                        Text(temp(d.min, s.fahrenheit)).opacity(0.65)
                        Text(temp(d.max, s.fahrenheit))
                    }
                    .padding(.vertical, 10)
                    Divider().overlay(fg.opacity(0.3))
                }
            }
            .padding(.top, 8)
        }
        .foregroundStyle(fg)
        .padding()
    }

    func chip(_ e: String, _ t: String) -> some View {
        HStack(spacing: 6) { Text(e); Text(t).font(.footnote) }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.gray.opacity(0.25), in: Capsule())
    }
}

struct WeatherSettings: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var q = ""
    @State private var results: [City] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Мои города") {
                    ForEach(store.data.cities) { c in
                        HStack {
                            Text(c.name)
                            Spacer()
                            Text(c.country).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete {
                        store.data.cities.remove(atOffsets: $0)
                        store.data.selectedCity = max(0, min(store.data.selectedCity, store.data.cities.count - 1))
                    }
                    .onMove { store.data.cities.move(fromOffsets: $0, toOffset: $1) }
                }
                if !results.isEmpty {
                    Section("Найдено (нажми, чтобы добавить)") {
                        ForEach(results) { c in
                            Button("\(c.name), \(c.country)") {
                                store.data.cities.append(c)
                                store.data.selectedCity = store.data.cities.count - 1
                                results = []
                                q = ""
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
                Section("Вид") {
                    Toggle("Фон по погоде", isOn: $store.data.settings.weatherBG)
                    Toggle("Градусы Фаренгейта", isOn: $store.data.settings.fahrenheit)
                }
            }
            .searchable(text: $q, prompt: "Добавить город")
            .onSubmit(of: .search) { Task { results = await WeatherService.search(q) } }
            .navigationTitle("Настройки погоды")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
        }
    }
}

// MARK: - Settings tab
struct SettingsView: View {
    @EnvironmentObject var store: Store

    func slotPicker(_ title: String, _ b: Binding<String>) -> some View {
        Picker(title, selection: b) {
            Text("—").tag("off")
            Text("Смены").tag("shifts")
            Text("Огонёк").tag("pet")
            Text("Траты").tag("spending")
            Text("Погода").tag("weather")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Тема") {
                    Picker("Режим", selection: $store.data.settings.theme) {
                        Text("Системная").tag("system")
                        Text("Светлая").tag("light")
                        Text("Тёмная").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 14) {
                        ForEach(Accent.all) { a in
                            Circle().fill(a.color).frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Color.primary, lineWidth: store.data.settings.accent == a.id ? 2.5 : 0).padding(-4))
                                .onTapGesture { store.data.settings.accent = a.id }
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section("Язык и валюта") {
                    Picker("Язык", selection: $store.data.settings.language) {
                        Text("Русский").tag("ru")
                        Text("Українська").tag("uk")
                        Text("English").tag("en")
                    }
                    Picker("Валюта", selection: $store.data.settings.currency) {
                        ForEach(Currencies.all, id: \.self) { Text(Currencies.label($0)).tag($0) }
                    }
                    Text("Язык меняет названия дней недели, месяцев и погоды").font(.caption).foregroundStyle(.secondary)
                }
                Section("Огонёк") {
                    NavigationLink("Питомец и гардероб") { PetAppearance() }
                }
                Section("Виджет") {
                    slotPicker("Блок 1 (маленький)", $store.data.settings.slot1)
                    slotPicker("Блок 2 (средний)", $store.data.settings.slot2)
                    slotPicker("Блок 3 (большой)", $store.data.settings.slot3)
                    Toggle("Большой — показать всё", isOn: $store.data.settings.widgetAll)
                    HStack {
                        Text("Связь с виджетом")
                        Spacer()
                        Text(Shared.groupOK ? "✓ работает" : "✗ нет App Group")
                            .foregroundStyle(Shared.groupOK ? Color.green : Color.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(FlamioBackground())
            .navigationTitle("Настройки")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
