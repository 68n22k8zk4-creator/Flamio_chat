import SwiftUI

struct SpendingView: View {
    @EnvironmentObject var store: Store
    @State private var month = Date()
    @State private var adding = false

    var body: some View {
        let d = store.data
        let lang = d.settings.language
        let cal = appCal(lang)
        let spent = d.monthSpend(month)
        let manual = d.monthIncome(month)
        let fromShifts = d.monthPay(month)
        let earned = manual + fromShifts
        let by = d.spendByCat(month)
        let items = d.entries(in: month).sorted { $0.date > $1.date }
        NavigationStack {
            ZStack {
                FlamioBackground()
                List {
                Section {
                    VStack(spacing: 14) {
                        HStack {
                            Button { month = cal.date(byAdding: .month, value: -1, to: month) ?? month } label: {
                                Image(systemName: "chevron.left")
                            }
                            Spacer()
                            Text(monthTitle(month, lang)).font(.headline)
                            Spacer()
                            Button { month = cal.date(byAdding: .month, value: 1, to: month) ?? month } label: {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .buttonStyle(.plain)
                        HStack(alignment: .top) {
                            stat(d.m(earned), "заработано", Color.green)
                            stat(d.m(spent), "потрачено", Color.primary)
                            stat(d.m(earned - spent), "баланс", earned - spent >= 0 ? Color.accentColor : Color.red)
                        }
                        if fromShifts > 0 {
                            Text("в заработке: смены \(d.m(fromShifts))" + (manual > 0 ? " + другое \(d.m(manual))" : ""))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .flamioCard(radius: 24)
                    .listRowBackground(Color.clear)
                }
                if !by.isEmpty {
                    Section("Расходы по категориям") {
                        ForEach(by.sorted { $0.value > $1.value }, id: \.key) { item in
                            HStack(spacing: 10) {
                                Text(Cats.find(item.key).emoji).frame(width: 26)
                                GeometryReader { g in
                                    Capsule().fill(Color.accentColor.opacity(0.8))
                                        .frame(width: max(6, g.size.width * item.value / max(spent, 1)))
                                }
                                .frame(height: 6)
                                Text(d.m(item.value)).font(.caption)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                Section("История") {
                    ForEach(items) { e in
                        HStack {
                            Text(e.shownEmoji).font(.title3).frame(width: 30)
                            VStack(alignment: .leading) {
                                Text(e.note.isEmpty ? Cats.find(e.cat).name : e.note)
                                Text(e.date, format: .dateTime.day().month(.wide)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text((e.isIncome ? "+" : "−") + d.m(e.amount))
                                .foregroundStyle(e.isIncome ? Color.green : Color.primary)
                        }
                        .padding(.vertical, 7)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete { idx in
                        let ids = idx.map { items[$0].id }
                        store.data.expenses.removeAll { ids.contains($0.id) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Траты")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { FlamioFeedback.tap(); adding = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $adding) { AddEntry() }
            }
        }
    }

    func stat(_ v: String, _ cap: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 20, weight: .light)).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.5)
            Text(cap).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct AddEntry: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) var dismiss
    @State private var income = false
    @State private var amount: Double?
    @State private var cat = "food"
    @State private var note = ""
    @State private var emoji = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Picker("", selection: $income) {
                    Text("Расход").tag(false)
                    Text("Доход").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: income) { _, v in cat = v ? "salary" : "food" }

                TextField("Сумма", value: $amount, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .light))

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(income ? Cats.income : Cats.expense) { c in
                        Button { cat = c.id } label: {
                            VStack(spacing: 4) {
                                Text(c.emoji).font(.title2)
                                Text(c.name).font(.caption2).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(cat == c.id ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                EmojiField(title: "Свой эмодзи (необязательно)", text: $emoji)
                TextField("Заметка", text: $note)
                DatePicker("Дата", selection: $date, displayedComponents: .date)
            }
            .scrollContentBackground(.hidden)
            .background(FlamioBackground())
            .navigationTitle(income ? "Новый доход" : "Новый расход")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        FlamioFeedback.success()
                        if let a = amount, a > 0 {
                            store.data.expenses.append(Expense(date: date, amount: a, cat: cat, note: note,
                                                               income: income, emoji: emoji.isEmpty ? nil : emoji))
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
