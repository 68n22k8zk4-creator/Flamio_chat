import SwiftUI

// MARK: - Games
struct GamesList: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Крестики-нолики") { TicTacToeView() }
                NavigationLink("21") { BlackjackView() }
                NavigationLink("Дурак") { DurakView() }
                NavigationLink("Морской бой") { BattleshipView() }
                NavigationLink("Камень-ножницы-бумага") { RPSView() }
            }
            .navigationTitle("Играть")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

func ttWinner(_ b: [Int]) -> Int {
    let l = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]
    for x in l where b[x[0]] != 0 && b[x[0]] == b[x[1]] && b[x[1]] == b[x[2]] { return b[x[0]] }
    return 0
}

func ttMinimax(_ b: [Int], bot: Bool) -> Int {
    let w = ttWinner(b)
    if w == 2 { return 1 }
    if w == 1 { return -1 }
    if !b.contains(0) { return 0 }
    var best = bot ? -2 : 2
    for i in 0..<9 where b[i] == 0 {
        var n = b
        n[i] = bot ? 2 : 1
        let s = ttMinimax(n, bot: !bot)
        best = bot ? max(best, s) : min(best, s)
    }
    return best
}

struct TicTacToeView: View {
    @EnvironmentObject var store: Store
    @State private var b = Array(repeating: 0, count: 9)
    @State private var logged = false

    var result: String? {
        let w = ttWinner(b)
        if w == 1 { return "Ты выиграл! 🎉" }
        if w == 2 { return "Победил огонёк 🦊" }
        if !b.contains(0) { return "Ничья" }
        return nil
    }

    var body: some View {
        VStack(spacing: 24) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { i in
                    Button { tap(i) } label: {
                        Text(b[i] == 1 ? "✕" : (b[i] == 2 ? "◯" : ""))
                            .font(.system(size: 44, weight: .light))
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            Text(result ?? "Твой ход").foregroundStyle(.secondary)
            Button("Заново") { b = Array(repeating: 0, count: 9); logged = false }
            Spacer()
        }
        .navigationTitle("Крестики-нолики")
    }

    func tap(_ i: Int) {
        guard b[i] == 0, result == nil else { return }
        b[i] = 1
        if result == nil { botMove() }
        if result != nil, !logged { logged = true; store.log("play", "ttt") }
    }

    func botMove() {
        let free = (0..<9).filter { b[$0] == 0 }
        guard !free.isEmpty else { return }
        if Int.random(in: 0..<4) == 0 { b[free.randomElement() ?? free[0]] = 2; return }  // иногда ошибается
        var best = -2, mv = free[0]
        for i in free {
            var n = b
            n[i] = 2
            let s = ttMinimax(n, bot: false)
            if s > best { best = s; mv = i }
        }
        b[mv] = 2
    }
}

struct Card: Hashable {
    let rank: Int
    let suit: String
    var value: Int { min(rank, 10) }
    var text: String {
        let r = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
        return r[rank - 1] + suit
    }
}

func bjTotal(_ h: [Card]) -> Int {
    var t = h.reduce(0) { $0 + $1.value }
    if h.contains(where: { $0.rank == 1 }) && t + 10 <= 21 { t += 10 }
    return t
}

struct BlackjackView: View {
    @EnvironmentObject var store: Store
    @State private var me: [Card] = []
    @State private var pet: [Card] = []
    @State private var over = false
    @State private var msg = ""

    var body: some View {
        VStack(spacing: 30) {
            hand(over ? "🦊 Огонёк · \(bjTotal(pet))" : "🦊 Огонёк", pet, hide: !over)
            hand("Ты · \(bjTotal(me))", me, hide: false)
            if over {
                Text(msg).font(.headline)
                Button("Ещё раз") { deal() }.buttonStyle(.borderedProminent)
            } else {
                HStack(spacing: 16) {
                    Button("Ещё") { hit() }
                    Button("Хватит") { stand() }
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("21")
        .onAppear { if me.isEmpty { deal() } }
    }

    func hand(_ title: String, _ cards: [Card], hide: Bool) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            HStack {
                ForEach(Array(cards.enumerated()), id: \.offset) { item in
                    Text(hide && item.offset == 1 ? "?" : item.element.text)
                        .font(.title2).frame(minWidth: 44).padding(10)
                        .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    func draw() -> Card {
        Card(rank: Int.random(in: 1...13), suit: ["♠", "♥", "♦", "♣"].randomElement() ?? "♠")
    }
    func deal() { me = [draw(), draw()]; pet = [draw(), draw()]; over = false; msg = "" }
    func hit() { me.append(draw()); if bjTotal(me) > 21 { end("Перебор. Выиграл огонёк 🦊") } }
    func stand() {
        while bjTotal(pet) < 17 { pet.append(draw()) }
        let m = bjTotal(me), p = bjTotal(pet)
        if p > 21 || m > p { end("Ты выиграл! 🎉") }
        else if m == p { end("Ничья") }
        else { end("Выиграл огонёк 🦊") }
    }
    func end(_ s: String) { msg = s; over = true; store.log("play", "21") }
}
