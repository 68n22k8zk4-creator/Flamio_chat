import SwiftUI

struct IDBox: Identifiable { let id: UUID }

struct ShiftsView: View {
    @EnvironmentObject var store: Store
    @State private var selected = Date()
    @State private var period: Period = .month
    @State private var settings = false
    @State private var edit: IDBox?

    private var lang: String { store.data.settings.language }
    private var cal: Calendar { appCal(store.data.settings.language) }

    var body: some View {
        NavigationStack {
            ZStack {
                FlamioBackground()
                ScrollView {
                VStack(spacing: 20) {
                    header
                    statsCard
                    todayCard
                    calendarGrid
                    dayPanel
                }
                .padding()
            }
            }
            .navigationTitle("Смены")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { FlamioFeedback.tap(); settings = true } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: $settings) { ShiftSettings() }
            .sheet(item: $edit) { RecordEditor(id: $0.id) }
        }
    }

    func moveMonth(_ v: Int) {
        selected = cal.date(byAdding: .month, value: v, to: selected) ?? selected
    }

    // MARK: Header + stats
    var header: some View {
        HStack {
            Button { FlamioFeedback.tap(); moveMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            VStack(spacing: 0) {
                Text(monthTitle(selected, lang)).font(.headline)
                Text(selected, format: .dateTime.year()).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button { FlamioFeedback.tap(); moveMonth(1) } label: { Image(systemName: "chevron.right") }
        }
    }

    @ViewBuilder var periodLabel: some View {
        switch period {
        case .day:
            Text(selected, format: .dateTime.weekday(.wide).day().month(.wide))
        case .week:
            let i = cal.dateInterval(of: .weekOfYear, for: selected) ?? DateInterval(start: selected, duration: 0)
            Text(i.start, format: .dateTime.day().month(.abbreviated))
                + Text(" – ")
                + Text(i.end.addingTimeInterval(-1), format: .dateTime.day().month(.abbreviated))
        case .month:
            EmptyView()
        }
    }

    var statsCard: some View {
        let d = store.data
        let recs = d.records(in: period, around: selected)
        let h = recs.reduce(0.0) { $0 + $1.worked() / 3600 }
        let p = d.payFor(period, selected)
        return VStack(spacing: 12) {
            Picker("", selection: $period) {
                ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack(spacing: 40) {
                stat(hoursStr(h), "часов")
                stat(d.m(p), "заработок")
            }
            periodLabel.font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .flamioCard(radius: 24)
    }

    func stat(_ v: String, _ cap: String) -> some View {
        VStack {
            Text(v).font(.system(size: 30, weight: .light)).lineLimit(1).minimumScaleFactor(0.6)
            Text(cap).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Today / manual shift with two timers
    @ViewBuilder var todayCard: some View {
        let ai = store.data.records.firstIndex { $0.end == nil }
        VStack(spacing: 12) {
            if let i = ai { activeView(i) } else { startView }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .flamioCard(radius: 24)
    }

    var bigButton: some View {
        Label("Начать смену", systemImage: "play.fill")
            .font(.headline).padding(.horizontal, 24).padding(.vertical, 12)
            .background(FlamioPalette.gradient, in: Capsule()).foregroundStyle(.white)
            .shadow(color: FlamioPalette.orange.opacity(0.35), radius: 14, y: 5)
    }

    var startView: some View {
        let manual = store.data.templates.filter { !$0.auto }
        return VStack(spacing: 8) {
            Text("Сегодня").font(.caption).foregroundStyle(.secondary)
            if manual.count > 1 {
                Menu {
                    ForEach(manual) { t in Button("\(t.emoji ?? "") \(t.name)") { start(t) } }
                } label: { bigButton }
            } else {
                Button { FlamioFeedback.success(); start(manual.first) } label: { bigButton }
            }
        }
    }

    func timerBox(_ t: String, _ cap: String, _ icon: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(t).font(.system(size: 30, weight: .light)).monospacedDigit().foregroundStyle(c)
            Label(cap, systemImage: icon).font(.caption2).foregroundStyle(.secondary)
        }
    }

    func activeView(_ i: Int) -> some View {
        let r = store.data.records[i]
        return VStack(spacing: 10) {
            Text("\(store.data.emoji(for: r)) \(r.title)").font(.subheadline).foregroundStyle(.secondary)
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let w = r.worked(now: ctx.date)
                HStack(alignment: .top, spacing: 26) {
                    timerBox(hms(w), "на работе", "arrow.up", Color.primary)
                    if let p = r.plannedMin {
                        let left = Double(p) * 60 - w
                        timerBox((left < 0 ? "+" : "") + hms(abs(left)),
                                 left < 0 ? "переработка" : "до конца",
                                 "arrow.down",
                                 left < 0 ? Color.red : Color.accentColor)
                    }
                }
            }
            Text(r.onPause ? ((r.pauses.last?.lunch ?? false) ? "Обед" : "Перерыв") : "Идёт смена")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if r.onPause {
                    pill("Продолжить", "play.fill") { resume(i) }
                } else {
                    pill("Перерыв", "pause.fill") { pause(i, false) }
                    pill("Обед", "fork.knife") { pause(i, true) }
                }
                pill("Завершить", "stop.fill") { finish(i) }
            }
            Button("Изменить") { edit = IDBox(id: r.id) }.font(.caption).foregroundStyle(.secondary)
        }
    }

    func pill(_ t: String, _ icon: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Label(t, systemImage: icon).font(.footnote).lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    func start(_ t: ShiftTemplate?) {
        var r = ShiftRecord(templateID: t?.id, title: t?.name ?? "Смена", start: .now,
                            breaksPaid: t?.paidBreaks ?? false)
        r.emoji = t?.emoji
        r.plannedMin = t?.plannedMin ?? 480
        store.data.records.append(r)
    }
    func pause(_ i: Int, _ lunch: Bool) {
        store.data.records[i].pauses.append(Pause(start: .now, end: nil, lunch: lunch))
    }
    func resume(_ i: Int) {
        if let j = store.data.records[i].pauses.indices.last { store.data.records[i].pauses[j].end = .now }
    }
    func finish(_ i: Int) {
        if store.data.records[i].onPause { resume(i) }
        store.data.records[i].end = .now
    }

    // MARK: Calendar
    var calendarGrid: some View {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: selected)) ?? selected
        let n = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let syms = cal.veryShortWeekdaySymbols
        let heads = (0..<7).map { syms[($0 + cal.firstWeekday - 1) % 7] }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            ForEach(Array(heads.enumerated()), id: \.offset) { item in
                Text(item.element.uppercased()).font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 46) }
            ForEach(1...n, id: \.self) { d in cell(d, first) }
        }
    }

    func cell(_ d: Int, _ first: Date) -> some View {
        let day = cal.date(byAdding: .day, value: d - 1, to: first) ?? first
        let recs = store.data.dayRecords(day)
        let today = cal.isDateInToday(day)
        let sel = cal.isDate(day, inSameDayAs: selected)
        return Button { FlamioFeedback.tap(); withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) { selected = day } } label: {
            VStack(spacing: 2) {
                Text("\(d)").font(.callout).fontWeight(today ? .bold : .regular)
                    .foregroundStyle(today ? Color.accentColor : Color.primary)
                Text(recs.first.map { store.data.emoji(for: $0) } ?? " ").font(.caption)
            }
            .frame(height: 46).frame(maxWidth: .infinity)
            .background(sel ? FlamioPalette.orange.opacity(0.24) : (recs.isEmpty ? Color.clear : FlamioPalette.purple.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: Selected day
    var dayPanel: some View {
        let recs = store.data.dayRecords(selected)
        return VStack(alignment: .leading, spacing: 8) {
            Text(selected, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(recs) { r in
                Button { edit = IDBox(id: r.id) } label: {
                    HStack {
                        Text(store.data.emoji(for: r))
                        Text(r.title)
                        Spacer()
                        Text(hoursStr(r.worked() / 3600)).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .flamioCard(radius: 14)
                }
                .buttonStyle(.plain)
            }
            if store.data.templates.isEmpty {
                Text("Создай шаблон смены в настройках ⚙︎").font(.footnote).foregroundStyle(.secondary)
            }
            Menu {
                ForEach(store.data.templates) { t in Button("\(t.emoji ?? "") \(t.name)") { add(t) } }
                Button("Пустая смена") { add(nil) }
            } label: { Label("Добавить смену", systemImage: "plus") }
                .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func add(_ t: ShiftTemplate?) {
        func at(_ m: Int) -> Date { cal.date(byAdding: .minute, value: m, to: cal.startOfDay(for: selected)) ?? selected }
        let isAuto = t?.auto ?? false
        let s0 = isAuto ? (t?.startMin ?? 540) : 540
        let e0 = isAuto ? (t?.endMin ?? 1080) : 540 + (t?.plannedMin ?? 480)
        var r = ShiftRecord(templateID: t?.id, title: t?.name ?? "Смена", start: at(s0),
                            end: at(e0 <= s0 ? e0 + 1440 : e0), breaksPaid: t?.paidBreaks ?? false)
        r.emoji = t?.emoji
        if let t, t.auto {
            if !t.paidBreaks { r.deductMin = t.breakMin + t.lunchMin }
            r.plannedMin = max(0, (e0 <= s0 ? e0 + 1440 : e0) - s0 - r.deductMin)
        } else {
            r.plannedMin = t?.plannedMin
        }
        store.data.records.append(r)
        edit = IDBox(id: r.id)
    }
}

// MARK: - Record editor
struct RecordEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    let id: UUID

    var body: some View {
        NavigationStack {
            if let i = store.data.records.firstIndex(where: { $0.id == id }) {
                form($store.data.records[i])
            }
        }
    }

    func form(_ r: Binding<ShiftRecord>) -> some View {
        Form {
            TextField("Название", text: r.title)
            EmojiField(title: "Эмодзи в календаре", text: optBinding(r.emoji))
            DatePicker("Начало", selection: r.start)
            Toggle("Смена завершена", isOn: Binding(
                get: { r.wrappedValue.end != nil },
                set: { r.wrappedValue.end = $0 ? (r.wrappedValue.end ?? .now) : nil }))
            if r.wrappedValue.end != nil {
                DatePicker("Конец", selection: Binding(
                    get: { r.wrappedValue.end ?? .now },
                    set: { r.wrappedValue.end = $0 }))
            }
            Stepper("План: \(hoursStr(Double(r.wrappedValue.plannedMin ?? 0) / 60)) ч",
                    value: Binding(get: { r.wrappedValue.plannedMin ?? 0 },
                                   set: { r.wrappedValue.plannedMin = $0 }),
                    in: 0...1440, step: 15)
            Section("Перерывы и обед") {
                Toggle("Оплачиваются", isOn: r.breaksPaid)
                ForEach(Array(r.wrappedValue.pauses.indices), id: \.self) { j in
                    VStack(alignment: .leading) {
                        Text(r.wrappedValue.pauses[j].lunch ? "Обед" : "Перерыв").font(.caption).foregroundStyle(.secondary)
                        DatePicker("С", selection: r.pauses[j].start)
                        DatePicker("До", selection: Binding(
                            get: { r.wrappedValue.pauses[j].end ?? .now },
                            set: { r.wrappedValue.pauses[j].end = $0 }))
                    }
                }
                .onDelete { r.wrappedValue.pauses.remove(atOffsets: $0) }
                Stepper("Вычесть ещё: \(r.wrappedValue.deductMin) мин", value: r.deductMin, in: 0...600, step: 5)
                Button("Добавить перерыв") {
                    let s = r.wrappedValue.start
                    r.wrappedValue.pauses.append(Pause(start: s, end: s.addingTimeInterval(900), lunch: false))
                }
                Button("Добавить обед") {
                    let s = r.wrappedValue.start
                    r.wrappedValue.pauses.append(Pause(start: s, end: s.addingTimeInterval(1800), lunch: true))
                }
            }
            let extra = store.data.bonuses.filter { $0.kind != .monthHours }
            if !extra.isEmpty {
                Section("Бонусы / штрафы") {
                    ForEach(extra) { b in
                        Toggle("\(b.name) \(b.negative ? "−" : "+")\(store.data.m(b.amount))", isOn: Binding(
                            get: { r.wrappedValue.bonusIDs.contains(b.id) },
                            set: { on in
                                if on { r.wrappedValue.bonusIDs.append(b.id) }
                                else { r.wrappedValue.bonusIDs.removeAll { $0 == b.id } }
                            }))
                    }
                }
            }
            Section {
                Text("Отработано: \(hoursStr(r.wrappedValue.worked() / 3600))")
                Button("Удалить смену", role: .destructive) {
                    store.data.records.removeAll { $0.id == id }
                    dismiss()
                }
            }
        }
        .navigationTitle("Смена")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
    }
}

// MARK: - Settings: templates, pay, bonuses, currency
struct ShiftSettings: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Валюта") {
                    Picker("Валюта", selection: $store.data.settings.currency) {
                        ForEach(Currencies.all, id: \.self) { Text(Currencies.label($0)).tag($0) }
                    }
                }
                Section("Шаблоны смен") {
                    ForEach($store.data.templates) { $t in
                        NavigationLink { TemplateForm(t: $t) } label: {
                            HStack {
                                Text("\(t.emoji ?? "") \(t.name)")
                                Spacer()
                                Text(t.auto ? "авто" : "ручная").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { store.data.templates.remove(atOffsets: $0) }
                    Button("Новая смена") { store.data.templates.append(ShiftTemplate(name: "Смена", auto: false)) }
                }
                Section("Оплата") {
                    ForEach($store.data.pays) { $p in
                        NavigationLink { PayForm(p: $p) } label: {
                            HStack {
                                Text(p.name)
                                Spacer()
                                Text("\(store.data.m(p.amount)) · \(p.kind.rawValue.lowercased())")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { store.data.pays.remove(atOffsets: $0) }
                    Button("Новый тип оплаты") { store.data.pays.append(PayRule(name: "Ставка", kind: .hourly, amount: 0)) }
                }
                Section("Бонусы и штрафы") {
                    ForEach($store.data.bonuses) { $b in
                        NavigationLink { BonusForm(b: $b) } label: {
                            HStack {
                                Text(b.name)
                                Spacer()
                                Text("\(b.negative ? "−" : "+")\(store.data.m(b.amount))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { store.data.bonuses.remove(atOffsets: $0) }
                    Button("Новый бонус / штраф") { store.data.bonuses.append(Bonus(name: "Бонус", kind: .other)) }
                }
            }
            .navigationTitle("Настройки смен")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }
}

func timeBinding(_ m: Binding<Int>) -> Binding<Date> {
    Binding(
        get: { Calendar.current.date(bySettingHour: m.wrappedValue / 60, minute: m.wrappedValue % 60, second: 0, of: .now) ?? .now },
        set: {
            let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
            m.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        })
}

struct TemplateForm: View {
    @EnvironmentObject var store: Store
    @Binding var t: ShiftTemplate

    var body: some View {
        Form {
            TextField("Название", text: $t.name)
            EmojiField(title: "Эмодзи в календаре", text: optBinding($t.emoji))
            Toggle("Авто (время задано заранее)", isOn: $t.auto)
            if t.auto {
                DatePicker("Начало", selection: timeBinding($t.startMin), displayedComponents: .hourAndMinute)
                DatePicker("Конец", selection: timeBinding($t.endMin), displayedComponents: .hourAndMinute)
                Stepper("Перерыв: \(t.breakMin) мин", value: $t.breakMin, in: 0...120, step: 5)
                Stepper("Обед: \(t.lunchMin) мин", value: $t.lunchMin, in: 0...180, step: 5)
            } else {
                Stepper("План смены: \(hoursStr(Double(t.plannedMin ?? 480) / 60)) ч",
                        value: Binding(get: { t.plannedMin ?? 480 }, set: { t.plannedMin = $0 }),
                        in: 60...960, step: 15)
            }
            Toggle("Перерывы оплачиваются", isOn: $t.paidBreaks)
            Picker("Оплата", selection: $t.payID) {
                Text("По умолчанию").tag(UUID?.none)
                ForEach(store.data.pays) { p in Text(p.name).tag(UUID?.some(p.id)) }
            }
        }
        .navigationTitle(t.name)
    }
}

struct PayForm: View {
    @Binding var p: PayRule
    var body: some View {
        Form {
            TextField("Название", text: $p.name)
            Picker("Тип", selection: $p.kind) {
                ForEach(PayKind.allCases, id: \.self) { Text($0.rawValue) }
            }
            HStack {
                Text("Сумма")
                TextField("0", value: $p.amount, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            }
        }
        .navigationTitle(p.name)
    }
}

struct BonusForm: View {
    @Binding var b: Bonus
    var body: some View {
        Form {
            TextField("Название", text: $b.name)
            Picker("За что", selection: $b.kind) {
                ForEach(BonusKind.allCases, id: \.self) { Text($0.rawValue) }
            }
            if b.kind == .monthHours {
                HStack {
                    Text("От часов в месяц")
                    TextField("0", value: $b.hours, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
            }
            HStack {
                Text("Сумма")
                TextField("0", value: $b.amount, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
            }
            Toggle("Прибавка к ставке в час", isOn: $b.addToRate)
            Toggle("Минус (штраф)", isOn: $b.negative)
            if b.kind == .other { TextField("Описание", text: $b.note) }
        }
        .navigationTitle(b.name)
    }
}
