import SwiftUI

// MARK: - Flamio (нарисованный персонаж)
struct FlameShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.62),
                   control1: CGPoint(x: w * 0.62, y: h * 0.22), control2: CGPoint(x: w * 0.95, y: h * 0.35))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h),
                   control1: CGPoint(x: w * 0.9, y: h * 0.88), control2: CGPoint(x: w * 0.7, y: h))
        p.addCurve(to: CGPoint(x: w * 0.08, y: h * 0.62),
                   control1: CGPoint(x: w * 0.3, y: h), control2: CGPoint(x: w * 0.1, y: h * 0.88))
        p.addCurve(to: CGPoint(x: w * 0.5, y: 0),
                   control1: CGPoint(x: w * 0.05, y: h * 0.4), control2: CGPoint(x: w * 0.38, y: h * 0.3))
        p.closeSubpath()
        return p
    }
}

struct SmileShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: r.width, y: 0), control: CGPoint(x: r.width / 2, y: r.height * 2))
        return p
    }
}

struct FlamioView: View {
    let size: CGFloat

    var eye: some View {
        ZStack {
            Circle().fill(Color(red: 0.15, green: 0.05, blue: 0.1)).frame(width: size * 0.1, height: size * 0.1)
            Circle().fill(Color.white).frame(width: size * 0.035, height: size * 0.035)
                .offset(x: size * 0.015, y: -size * 0.02)
        }
    }

    var body: some View {
        ZStack {
            FlameShape()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.32, blue: 0.1), Color(red: 1, green: 0.7, blue: 0.15)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.8, height: size * 0.92)
            FlameShape()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.92, blue: 0.5), Color(red: 1, green: 0.8, blue: 0.3)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.5, height: size * 0.55)
                .offset(y: size * 0.16)
            HStack(spacing: size * 0.16) { eye; eye }.offset(y: size * 0.1)
            HStack(spacing: size * 0.3) {
                Circle().fill(Color.orange.opacity(0.5)).frame(width: size * 0.09, height: size * 0.09)
                Circle().fill(Color.orange.opacity(0.5)).frame(width: size * 0.09, height: size * 0.09)
            }
            .offset(y: size * 0.19)
            SmileShape()
                .stroke(Color(red: 0.35, green: 0.1, blue: 0.05), lineWidth: size * 0.02)
                .frame(width: size * 0.14, height: size * 0.05)
                .offset(y: size * 0.2)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Гардероб
enum Wardrobe {
    struct Slot: Identifiable {
        let id: String
        let name: String
        let items: [String]
    }
    static let slots = [
        Slot(id: "hat", name: "Шапки", items: ["🎩", "🧢", "👑", "🎓", "👒", "⛑️", "🎀", "🪖"]),
        Slot(id: "face", name: "Очки", items: ["🕶️", "👓", "🥽", "😷"]),
        Slot(id: "neck", name: "Шея", items: ["🧣", "🎀", "📿", "🔔"]),
        Slot(id: "body", name: "Одежда", items: ["🧥", "🦺", "👕", "🥼", "👘"]),
        Slot(id: "bling", name: "Украшения", items: ["💎", "⭐", "🏅", "💍", "🌸", "🦋"])
    ]
}

struct PetAvatar: View {
    let s: Settings
    var size: CGFloat = 180

    @ViewBuilder func acc(_ slot: String, x: CGFloat, y: CGFloat, f: CGFloat) -> some View {
        if let e = s.outfit[slot], !e.isEmpty {
            Text(e).font(.system(size: size * f)).offset(x: size * x, y: size * y)
        }
    }

    var body: some View {
        ZStack {
            if s.petStyle == "emoji" {
                Text(s.petEmoji).font(.system(size: size * 0.7))
            } else {
                ZStack {
                    FlamioView(size: size).opacity(0.24).scaleEffect(1.12)
                    Text("🦊").font(.system(size: size * 0.76))
                        .shadow(color: FlamioPalette.orange.opacity(0.65), radius: 12, y: 4)
                }
            }
            acc("body", x: 0, y: 0.34, f: 0.36)
            acc("neck", x: 0, y: 0.22, f: 0.28)
            acc("face", x: 0, y: 0.06, f: 0.34)
            acc("hat", x: 0, y: -0.36, f: 0.34)
            acc("bling", x: 0.3, y: 0.3, f: 0.2)
        }
        .frame(width: size, height: size)
    }
}

struct WardrobeView: View {
    @EnvironmentObject var store: Store
    @State private var slot = "hat"

    var body: some View {
        let cur = Wardrobe.slots.first { $0.id == slot } ?? Wardrobe.slots[0]
        ScrollView {
            VStack(spacing: 18) {
                PetAvatar(s: store.data.settings, size: 200)
                Picker("", selection: $slot) {
                    ForEach(Wardrobe.slots) { Text($0.name).tag($0.id) }
                }
                .pickerStyle(.menu)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    Button { store.data.settings.outfit[slot] = nil } label: {
                        Image(systemName: "xmark").frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    ForEach(cur.items, id: \.self) { e in
                        Button { store.data.settings.outfit[slot] = e } label: {
                            Text(e).font(.system(size: 30)).frame(maxWidth: .infinity, minHeight: 56)
                                .background(store.data.settings.outfit[slot] == e ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Гардероб")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PetAppearance: View {
    @EnvironmentObject var store: Store
    let presets = ["🦊", "🐱", "🐶", "🐼", "🐰", "🦁", "🐸", "🐵", "🐧", "🦄", "🐲", "🐹", "🐻", "🐨", "👾", "🤖", "👻", "🐥"]

    var body: some View {
        Form {
            Section {
                HStack { Spacer(); PetAvatar(s: store.data.settings, size: 150); Spacer() }
            }
            Section("Имя") { TextField("Имя", text: $store.data.settings.petName) }
            Section("Персонаж") {
                Picker("Вид", selection: $store.data.settings.petStyle) {
                    Text("Flamio").tag("flamio")
                    Text("Эмодзи").tag("emoji")
                }
                .pickerStyle(.segmented)
                if store.data.settings.petStyle == "emoji" {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(presets, id: \.self) { e in
                            Button { store.data.settings.petEmoji = e } label: { Text(e).font(.title) }.buttonStyle(.plain)
                        }
                    }
                    EmojiField(title: "Любой эмодзи", text: $store.data.settings.petEmoji, presets: [])
                }
            }
            Section {
                NavigationLink("Гардероб") { WardrobeView() }
                Button("Снять всё") { store.data.settings.outfit = [:] }
            }
        }
        .navigationTitle("Питомец")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Pet screen
struct PetView: View {
    @EnvironmentObject var store: Store
    @State private var petBreath = false
    @State private var feed = false
    @State private var games = false
    @State private var wardrobe = false
    @State private var reaction = ""

    var body: some View {
        let d = store.data
        let best = d.bestFood()
        let yesterday = appCal(d.settings.language).date(byAdding: .day, value: -1, to: .now) ?? .now
        NavigationStack {
            ZStack {
                FlamioBackground()
                ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 4) {
                        PetAvatar(s: d.settings, size: 200)
                            .scaleEffect(petBreath ? 1.035 : 0.97)
                            .shadow(color: FlamioPalette.orange.opacity(0.48), radius: petBreath ? 28 : 14, y: 8)
                            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: petBreath)
                        Text(d.settings.petName).font(.headline)
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").font(.title)
                                .foregroundStyle(d.streakAlive ? Color.orange : Color.gray)
                            Text("\(d.streak)").font(.system(size: 40, weight: .semibold))
                        }
                        Text(d.streakAlive ? "дней подряд" : "покорми или поиграй сегодня")
                            .font(.footnote).foregroundStyle(.secondary)
                        if !reaction.isEmpty { Text(reaction).font(.footnote).padding(.top, 4) }
                    }
                    .padding(.top, 8)
                    .onAppear { petBreath = true }

                    HStack(spacing: 12) {
                        big("Покормить", "fork.knife") { feed = true }
                        big("Играть", "gamecontroller") { games = true }
                        big("Гардероб", "tshirt") { wardrobe = true }
                    }

                    card {
                        HStack {
                            Text(best.emoji).font(.system(size: 36))
                            VStack(alignment: .leading) {
                                Text("Лучшее сейчас").font(.caption).foregroundStyle(.secondary)
                                Text(best.name)
                            }
                            Spacer()
                            Button("Дать") { give(best) }
                                .buttonStyle(.borderedProminent)
                                .tint(FlamioPalette.orange)
                        }
                    }
                    card {
                        HStack {
                            Text("Вчера").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            let f = d.feeds(on: yesterday)
                            Text(f.isEmpty ? "—" : f.map(\.emoji).joined()).font(.title3)
                        }
                    }
                    NavigationLink("Всё о питомце") { PetInfo() }.font(.footnote)
                }
                .padding()
            }
            }
            .navigationTitle("Огонёк")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $feed) { FeedSheet { give($0) } }
            .sheet(isPresented: $games) { GamesList() }
            .sheet(isPresented: $wardrobe) {
                NavigationStack {
                    WardrobeView()
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { wardrobe = false } } }
                }
            }
        }
    }

    func give(_ f: Food) {
        FlamioFeedback.feed()
        store.log("feed", f.emoji)
        reaction = f.health > 0 ? "Вкусно! 😋" : (f.health < 0 ? "Это не самая здоровая еда" : "Ням")
    }

    func big(_ t: String, _ icon: String, _ a: @escaping () -> Void) -> some View {
        Button { FlamioFeedback.tap(); withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) { a() } } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(t).font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(FlamioPalette.gradient.opacity(0.20), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(FlamioPalette.purple.opacity(0.38), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().padding().flamioCard(radius: 20)
    }
}

struct FeedSheet: View {
    @Environment(\.dismiss) var dismiss
    let pick: (Food) -> Void

    var body: some View {
        NavigationStack {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 14) {
                ForEach(Foods.all) { f in
                    Button { pick(f); dismiss() } label: {
                        VStack(spacing: 4) {
                            Text(f.emoji).font(.system(size: 40))
                            Text(f.name).font(.caption)
                            Circle().fill(f.health > 0 ? Color.green : (f.health < 0 ? Color.red : Color.orange))
                                .frame(width: 6, height: 6)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("Чем накормить?")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

struct PetInfo: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let d = store.data
        let cal = appCal(d.settings.language)
        let days = (0..<7).map { cal.date(byAdding: .day, value: -$0, to: .now) ?? .now }
        let lastFed = d.petLogs.last { $0.kind == "feed" }?.date
        List {
            Section("Сегодня") {
                HStack {
                    Text("Последнее кормление")
                    Spacer()
                    if let lastFed { Text(lastFed, style: .relative).foregroundStyle(.secondary) } else { Text("—") }
                }
                HStack { Text("Кормлений"); Spacer(); Text("\(d.feeds(on: .now).count)").foregroundStyle(.secondary) }
                HStack { Text("Игр"); Spacer(); Text("\(d.plays(on: .now))").foregroundStyle(.secondary) }
            }
            Section("Питание за неделю") {
                ForEach(days, id: \.self) { day in
                    HStack {
                        Text(day, format: .dateTime.weekday(.abbreviated)).frame(width: 40, alignment: .leading)
                        Text(d.feeds(on: day).map(\.emoji).joined())
                        Spacer()
                        if let h = d.dayHealth(day) {
                            Circle().fill(h > 0.5 ? Color.green : (h > -0.5 ? Color.orange : Color.red))
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
            Section("Лучшая еда") {
                Text(Foods.all.sorted { $0.health > $1.health }.prefix(5).map(\.emoji).joined(separator: "  ")).font(.title2)
                Text("Больше овощей, фруктов и белка. Фастфуд и сладкое — редко.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Всего") {
                HStack { Text("Кормлений"); Spacer(); Text("\(d.petLogs.filter { $0.kind == "feed" }.count)").foregroundStyle(.secondary) }
                HStack { Text("Игр"); Spacer(); Text("\(d.petLogs.filter { $0.kind == "play" }.count)").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Инфо")
        .navigationBarTitleDisplayMode(.inline)
    }
}
