import SwiftUI

// MARK: - Дурак (подкидной, 36 карт)
struct DCard: Hashable {
    let rank: Int   // 6...14
    let suit: Int   // 0...3
    static let suits = ["♠", "♥", "♦", "♣"]
    var text: String { ["6", "7", "8", "9", "10", "В", "Д", "К", "Т"][rank - 6] + DCard.suits[suit] }
    var red: Bool { suit == 1 || suit == 2 }
}

struct DPair: Hashable {
    var a: DCard
    var d: DCard?
}

final class DurakGame: ObservableObject {
    @Published var deck: [DCard] = []
    @Published var me: [DCard] = []
    @Published var bot: [DCard] = []
    @Published var table: [DPair] = []
    @Published var trump = 0
    @Published var meAttacks = true
    @Published var msg = ""
    @Published var over = false

    init() { deal() }

    func isTrump(_ c: DCard) -> Bool { c.suit == trump }
    func beats(_ d: DCard, _ a: DCard) -> Bool {
        (d.suit == a.suit && d.rank > a.rank) || (d.suit == trump && a.suit != trump)
    }
    func order(_ a: DCard, _ b: DCard) -> Bool {
        (isTrump(a) ? 1 : 0, a.rank) < (isTrump(b) ? 1 : 0, b.rank)
    }
    var ranksOnTable: Set<Int> {
        var s = Set<Int>()
        for p in table { s.insert(p.a.rank); if let d = p.d { s.insert(d.rank) } }
        return s
    }
    var allDefended: Bool { table.allSatisfy { $0.d != nil } }

    func draw(_ h: inout [DCard]) {
        while h.count < 6, !deck.isEmpty { h.append(deck.removeFirst()) }
    }

    func deal() {
        var all: [DCard] = []
        for s in 0..<4 { for r in 6...14 { all.append(DCard(rank: r, suit: s)) } }
        all.shuffle()
        me = Array(all[0..<6])
        bot = Array(all[6..<12])
        deck = Array(all[12...])
        trump = deck[deck.count - 1].suit
        table = []
        over = false
        let mt = me.filter { $0.suit == trump }.map(\.rank).min() ?? 99
        let bt = bot.filter { $0.suit == trump }.map(\.rank).min() ?? 99
        meAttacks = mt <= bt
        if meAttacks { msg = "Твой ход" } else { botAttack() }
    }

    func checkEnd() {
        guard deck.isEmpty else { return }
        if me.isEmpty && bot.isEmpty { over = true; msg = "Ничья" }
        else if me.isEmpty { over = true; msg = "Ты выиграл! 🎉" }
        else if bot.isEmpty { over = true; msg = "Ты остался в дураках 🃏" }
    }

    func tap(_ c: DCard) {
        guard !over else { return }
        if meAttacks {
            guard allDefended, !bot.isEmpty, table.count < 6,
                  table.isEmpty || ranksOnTable.contains(c.rank) else { msg = "Так нельзя"; return }
            me.removeAll { $0 == c }
            table.append(DPair(a: c, d: nil))
            botDefend()
        } else {
            guard let i = table.lastIndex(where: { $0.d == nil }), beats(c, table[i].a) else {
                msg = "Эта карта не бьёт"; return
            }
            me.removeAll { $0 == c }
            table[i].d = c
            afterMyDefense()
        }
    }

    func botDefend() {
        guard let i = table.lastIndex(where: { $0.d == nil }) else { return }
        let a = table[i].a
        if let c = bot.filter({ beats($0, a) }).sorted(by: order).first {
            bot.removeAll { $0 == c }
            table[i].d = c
            if me.isEmpty || table.count >= 6 { endRound(defended: true) }
            else { msg = "Огонёк отбился. Подкинь или «Бито»" }
        } else {
            for p in table { bot.append(p.a); if let d = p.d { bot.append(d) } }
            table = []
            draw(&me)
            msg = "Огонёк берёт. Твой ход"
            checkEnd()
        }
    }

    func pass() {
        guard meAttacks, !over, !table.isEmpty, allDefended else { return }
        endRound(defended: true)
    }

    func take() {
        guard !meAttacks, !over, table.contains(where: { $0.d == nil }) else { return }
        for p in table { me.append(p.a); if let d = p.d { me.append(d) } }
        table = []
        draw(&bot)
        msg = "Ты взял карты"
        checkEnd()
        if !over { botAttack() }
    }

    func afterMyDefense() {
        if me.isEmpty { endRound(defended: true); return }
        let extra = bot.filter { ranksOnTable.contains($0.rank) && !isTrump($0) }.sorted(by: order).first
        if let c = extra, table.count < 6 {
            bot.removeAll { $0 == c }
            table.append(DPair(a: c, d: nil))
            msg = "Огонёк подкидывает"
        } else {
            endRound(defended: true)
        }
    }

    func endRound(defended: Bool) {
        table = []
        if meAttacks { draw(&me); draw(&bot) } else { draw(&bot); draw(&me) }
        if defended { meAttacks.toggle() }
        checkEnd()
        if over { return }
        if meAttacks { msg = "Бито. Твой ход" } else { botAttack() }
    }

    func botAttack() {
        guard !over, let c = bot.sorted(by: order).first else { checkEnd(); return }
        bot.removeAll { $0 == c }
        table = [DPair(a: c, d: nil)]
        msg = "Огонёк ходит. Отбейся или «Беру»"
    }
}

struct DurakView: View {
    @EnvironmentObject var store: Store
    @StateObject private var g = DurakGame()

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("🦊 \(g.bot.count)")
                Spacer()
                Text("колода \(g.deck.count)").font(.caption).foregroundStyle(.secondary)
                Text("козырь \(DCard.suits[g.trump])").font(.headline)
                    .foregroundStyle(g.trump == 1 || g.trump == 2 ? Color.red : Color.primary)
            }
            Text(g.msg).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(g.table.enumerated()), id: \.offset) { item in
                        VStack(spacing: -22) {
                            card(item.element.a)
                            if let d = item.element.d { card(d).offset(x: 10) }
                            else { Color.clear.frame(width: 46, height: 64) }
                        }
                        .padding(.trailing, 10)
                    }
                }
                .frame(minHeight: 120)
            }

            Spacer()

            if g.over {
                Button("Новая игра") { g.deal() }.buttonStyle(.borderedProminent)
            } else if g.meAttacks, !g.table.isEmpty, g.allDefended {
                Button("Бито") { g.pass() }.buttonStyle(.borderedProminent)
            } else if !g.meAttacks, g.table.contains(where: { $0.d == nil }) {
                Button("Беру") { g.take() }.buttonStyle(.borderedProminent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(g.me.sorted { g.order($0, $1) }, id: \.self) { c in
                        Button { g.tap(c) } label: { card(c) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .navigationTitle("Дурак")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: g.over) { _, o in if o { store.log("play", "durak") } }
    }

    func card(_ c: DCard) -> some View {
        Text(c.text)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(c.red ? Color.red : Color.primary)
            .frame(width: 46, height: 64)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(c.suit == g.trump ? Color.orange : Color.gray.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Морской бой 8×8
final class BattleGame: ObservableObject {
    let n = 8
    let lens = [4, 3, 3, 2, 2]
    @Published var myFleet: [[Int]] = []
    @Published var botFleet: [[Int]] = []
    @Published var myShots = Set<Int>()    // выстрелы огонька по тебе
    @Published var botShots = Set<Int>()   // твои выстрелы по огоньку
    @Published var msg = ""
    @Published var over = false

    init() { reset() }

    func reset() {
        myFleet = Self.place(n, lens)
        botFleet = Self.place(n, lens)
        myShots = []
        botShots = []
        over = false
        msg = "Стреляй по полю огонька"
    }

    static func blocked(_ occ: Set<Int>, _ i: Int, _ n: Int) -> Bool {
        let r = i / n, c = i % n
        for dr in -1...1 {
            for dc in -1...1 {
                let rr = r + dr, cc = c + dc
                if rr >= 0, rr < n, cc >= 0, cc < n, occ.contains(rr * n + cc) { return true }
            }
        }
        return false
    }

    static func place(_ n: Int, _ lens: [Int]) -> [[Int]] {
        while true {
            var fleet: [[Int]] = []
            var occ = Set<Int>()
            var ok = true
            for len in lens {
                var placed = false
                for _ in 0..<200 {
                    let h = Bool.random()
                    let r = Int.random(in: 0..<(h ? n : n - len + 1))
                    let c = Int.random(in: 0..<(h ? n - len + 1 : n))
                    let cells = (0..<len).map { h ? r * n + c + $0 : (r + $0) * n + c }
                    if cells.allSatisfy({ !blocked(occ, $0, n) }) {
                        fleet.append(cells)
                        occ.formUnion(cells)
                        placed = true
                        break
                    }
                }
                if !placed { ok = false; break }
            }
            if ok { return fleet }
        }
    }

    func fire(_ i: Int) {
        guard !over, !botShots.contains(i) else { return }
        botShots.insert(i)
        if botFleet.flatMap({ $0 }).contains(i) {
            if botFleet.allSatisfy({ Set($0).isSubset(of: botShots) }) {
                over = true
                msg = "Ты победил! 🎉"
                return
            }
            let sunk = botFleet.first { $0.contains(i) }.map { Set($0).isSubset(of: botShots) } ?? false
            msg = sunk ? "Потопил! Ходи ещё" : "Попал! Ходи ещё"
            return
        }
        botTurn()
    }

    func botTurn() {
        var log = "Мимо. Огонёк промахнулся"
        while true {
            let c = botPick()
            myShots.insert(c)
            if myFleet.flatMap({ $0 }).contains(c) {
                if myFleet.allSatisfy({ Set($0).isSubset(of: myShots) }) {
                    over = true
                    msg = "Огонёк победил 🦊"
                    return
                }
                log = "Мимо. Огонёк попал, потом промахнулся"
                continue
            }
            break
        }
        msg = log + ". Твой ход"
    }

    func botPick() -> Int {
        let live = myFleet.filter { !Set($0).isSubset(of: myShots) }.flatMap { $0 }.filter { myShots.contains($0) }
        var cand = Set<Int>()
        for h in live {
            let r = h / n, c = h % n
            for (dr, dc) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let rr = r + dr, cc = c + dc
                if rr >= 0, rr < n, cc >= 0, cc < n, !myShots.contains(rr * n + cc) { cand.insert(rr * n + cc) }
            }
        }
        if let c = cand.randomElement() { return c }
        let free = (0..<n * n).filter { !myShots.contains($0) }
        let par = free.filter { ($0 / n + $0 % n) % 2 == 0 }
        return (par.isEmpty ? free : par).randomElement() ?? 0
    }
}

struct BattleshipView: View {
    @EnvironmentObject var store: Store
    @StateObject private var g = BattleGame()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(g.msg).font(.footnote).foregroundStyle(.secondary)
                grid(enemy: true).padding(.horizontal)
                Text("Твоё поле").font(.caption).foregroundStyle(.secondary)
                grid(enemy: false).frame(width: 190)
                if g.over || g.botShots.isEmpty {
                    Button(g.over ? "Ещё раз" : "Перемешать корабли") { g.reset() }.buttonStyle(.bordered)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Морской бой")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: g.over) { _, o in if o { store.log("play", "battleship") } }
    }

    func grid(enemy: Bool) -> some View {
        let fleet = enemy ? g.botFleet : g.myFleet
        let shots = enemy ? g.botShots : g.myShots
        let ships = Set(fleet.flatMap { $0 })
        let sunk = Set(fleet.filter { Set($0).isSubset(of: shots) }.flatMap { $0 })
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: g.n), spacing: 2) {
            ForEach(0..<g.n * g.n, id: \.self) { i in
                let shot = shots.contains(i)
                let ship = ships.contains(i)
                let color: Color = {
                    if shot && ship { return sunk.contains(i) ? Color.red.opacity(0.7) : Color.orange.opacity(0.8) }
                    if !enemy && ship { return Color.gray.opacity(0.55) }
                    return Color.gray.opacity(0.12)
                }()
                ZStack {
                    RoundedRectangle(cornerRadius: 3).fill(color)
                    if shot { Text(ship ? "✕" : "•").font(.caption2).foregroundStyle(ship ? Color.white : Color.secondary) }
                }
                .aspectRatio(1, contentMode: .fit)
                .onTapGesture { if enemy { g.fire(i) } }
            }
        }
    }
}

// MARK: - Камень-ножницы-бумага
struct RPSView: View {
    @EnvironmentObject var store: Store
    @State private var wins = 0
    @State private var losses = 0
    @State private var mine = ""
    @State private var theirs = ""
    @State private var res = "Выбирай"
    let opts = ["✊", "✌️", "✋"]

    var body: some View {
        VStack(spacing: 28) {
            Text("\(wins) : \(losses)").font(.system(size: 40, weight: .light))
            HStack(spacing: 30) {
                Text(mine.isEmpty ? " " : mine).font(.system(size: 56))
                Text("vs").foregroundStyle(.secondary)
                Text(theirs.isEmpty ? " " : theirs).font(.system(size: 56))
            }
            Text(res).foregroundStyle(.secondary)
            HStack(spacing: 20) {
                ForEach(0..<3, id: \.self) { i in
                    Button { play(i) } label: {
                        Text(opts[i]).font(.system(size: 40)).frame(width: 80, height: 80)
                            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(.top, 30)
        .navigationTitle("Камень-ножницы-бумага")
        .navigationBarTitleDisplayMode(.inline)
    }

    func play(_ i: Int) {
        let b = Int.random(in: 0..<3)
        mine = opts[i]
        theirs = opts[b]
        if i == b { res = "Ничья" }
        else if (i + 1) % 3 == b { res = "Ты выиграл"; wins += 1 }
        else { res = "Огонёк выиграл"; losses += 1 }
        store.log("play", "rps")
    }
}
