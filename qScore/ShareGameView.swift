import SwiftUI

// MARK: - Options

/// The look of the shared results card. Colors are fixed (not light/dark
/// adaptive) so the image looks the same on whatever screen it lands on.
enum ShareCardStyle: String, CaseIterable, Identifiable {
    case sage
    case paper
    case night

    var id: Self { self }

    var title: String {
        switch self {
        case .sage: "Sage"
        case .paper: "Paper"
        case .night: "Night"
        }
    }

    var background: [Color] {
        switch self {
        case .sage: [Color(red: 0.33, green: 0.49, blue: 0.39), Color(red: 0.19, green: 0.31, blue: 0.25)]
        case .paper: [Color(red: 0.99, green: 0.97, blue: 0.92), Color(red: 0.93, green: 0.90, blue: 0.82)]
        case .night: [Color(red: 0.13, green: 0.16, blue: 0.14), Color(red: 0.05, green: 0.07, blue: 0.06)]
        }
    }

    var ink: Color {
        switch self {
        case .sage, .night: .white
        case .paper: Color(red: 0.13, green: 0.16, blue: 0.14)
        }
    }

    var secondary: Color { ink.opacity(self == .paper ? 0.55 : 0.68) }

    var gold: Color {
        switch self {
        case .sage: Color(red: 0.96, green: 0.80, blue: 0.42)
        case .paper: Color(red: 0.80, green: 0.55, blue: 0.16)
        case .night: Color(red: 0.90, green: 0.72, blue: 0.35)
        }
    }

    /// Accent for headings and the round-by-round grid.
    var accent: Color {
        switch self {
        case .sage: Color(red: 0.80, green: 0.91, blue: 0.83)
        case .paper: Color(red: 0.30, green: 0.45, blue: 0.36)
        case .night: Color(red: 0.52, green: 0.73, blue: 0.58)
        }
    }

    var panel: Color {
        switch self {
        case .sage: .white.opacity(0.10)
        case .paper: Color(red: 0.30, green: 0.45, blue: 0.36).opacity(0.08)
        case .night: .white.opacity(0.06)
        }
    }

    var hairline: Color { ink.opacity(0.12) }

    /// Swatch shown in the style picker.
    var swatch: LinearGradient {
        LinearGradient(colors: background, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct ShareCardOptions: Hashable {
    var showWinner = true
    var showPlaces = true
    var showTotals = true
    var showRounds = false
    var showBonuses = true
    var showDetails = true

    var hasContent: Bool { showWinner || showPlaces || showTotals || showRounds }
}

// MARK: - Card

/// The results card that gets rendered to an image and shared.
struct GameShareCard: View {
    let game: Game
    let options: ShareCardOptions
    let style: ShareCardStyle

    static let width: CGFloat = 400

    private var isTie: Bool { game.leaders.count > 1 }
    private var hasBonuses: Bool { game.bonuses?.values.contains(where: { !$0.isEmpty }) == true }

    var body: some View {
        VStack(spacing: 20) {
            header

            if options.showWinner {
                winner
            }

            if options.showPlaces || options.showTotals {
                standings
            }

            if options.showRounds {
                rounds
            }

            footer
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .frame(width: Self.width)
        .background {
            ZStack {
                LinearGradient(colors: style.background, startPoint: .topLeading, endPoint: .bottomTrailing)
                // A soft gold glow behind the winner.
                RadialGradient(
                    colors: [style.gold.opacity(0.22), .clear],
                    center: .init(x: 0.5, y: 0.12),
                    startRadius: 0,
                    endRadius: 240
                )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(style.gold.opacity(0.45), lineWidth: 1)
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .foregroundStyle(style.ink)
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "suit.club.fill")
                    .font(.caption2)
                Text("QUIDDLER")
                    .font(.caption.weight(.heavy))
                    .tracking(3)
                Image(systemName: "suit.club.fill")
                    .font(.caption2)
            }
            .foregroundStyle(style.accent)

            if options.showDetails {
                Text(detailsLine)
                    .font(.footnote)
                    .foregroundStyle(style.secondary)
            }
        }
    }

    private var detailsLine: String {
        let date = (game.completedAt ?? game.createdAt).formatted(date: .abbreviated, time: .omitted)
        let roundCount = game.mode.rounds.count
        return "\(game.mode.title) • \(roundCount) rounds • \(date)"
    }

    private var winner: some View {
        VStack(spacing: 8) {
            Image(systemName: isTie ? "medal.fill" : "trophy.fill")
                .font(.system(size: 46))
                .foregroundStyle(style.gold)
                .shadow(color: style.gold.opacity(0.5), radius: 14)

            Text(winnerTitle)
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            if options.showTotals, let best = game.leaders.first {
                Text("\(game.total(for: best.id)) points")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(style.gold)
            }
        }
    }

    private var winnerTitle: String {
        let leaders = game.leaders
        guard let first = leaders.first else { return "Game Complete" }
        if leaders.count == 1 { return "\(first.name) Wins!" }
        return ListFormatter.localizedString(byJoining: leaders.map(\.name)) + " Tie!"
    }

    /// Ranked when places are shown; otherwise the seating order, so the
    /// list doesn't give away the places by itself.
    private var listedPlayers: [Player] {
        options.showPlaces ? game.rankedPlayers : game.players
    }

    private var standings: some View {
        let players = listedPlayers
        return VStack(spacing: 0) {
            ForEach(players) { player in
                let rank = game.rank(of: player.id)
                let isLeader = rank == 1
                HStack(spacing: 12) {
                    if options.showPlaces {
                        placeMark(rank)
                            .frame(width: 30)
                    }
                    Text(player.name)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    if options.showTotals {
                        Text("\(game.total(for: player.id))")
                            .font(.system(.title3, design: .rounded, weight: .bold).monospacedDigit())
                            .foregroundStyle(isLeader && options.showPlaces ? style.gold : style.ink)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background {
                    if isLeader && options.showPlaces {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(style.gold.opacity(0.16))
                    }
                }
                if player.id != players.last?.id {
                    Rectangle().fill(style.hairline).frame(height: 1).padding(.horizontal, 12)
                }
            }
        }
        .padding(6)
        .background(style.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func placeMark(_ rank: Int) -> some View {
        switch rank {
        case 1:
            Image(systemName: "crown.fill").foregroundStyle(style.gold)
        default:
            Text(ordinal(rank))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(style.secondary)
        }
    }

    private func ordinal(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private var rounds: some View {
        let players = listedPlayers
        return VStack(alignment: .leading, spacing: 10) {
            Text("ROUND BY ROUND")
                .font(.caption2.weight(.heavy))
                .tracking(1.5)
                .foregroundStyle(style.accent)

            Grid(alignment: .center, horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    Text("Cards")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(style.secondary)
                        .gridColumnAlignment(.leading)
                    ForEach(players) { player in
                        Text(player.name)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                    }
                }
                Rectangle().fill(style.hairline).frame(height: 1).gridCellUnsizedAxes(.horizontal)

                ForEach(game.mode.rounds.indices, id: \.self) { round in
                    GridRow {
                        Text("\(game.mode.rounds[round])")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(style.secondary)
                        ForEach(players) { player in
                            roundCell(player: player, round: round)
                        }
                    }
                }

                if options.showTotals {
                    Rectangle().fill(style.hairline).frame(height: 1).gridCellUnsizedAxes(.horizontal)
                    GridRow {
                        Text("Total")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(style.secondary)
                        ForEach(players) { player in
                            Text("\(game.total(for: player.id))")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(options.showPlaces && game.rank(of: player.id) == 1 ? style.gold : style.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                    }
                }
            }

            if options.showBonuses && hasBonuses {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(style.gold)
                    Text("Longest Word or Most Words bonus")
                }
                .font(.caption2)
                .foregroundStyle(style.secondary)
            }
        }
        .padding(14)
        .background(style.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func roundCell(player: Player, round: Int) -> some View {
        let points = game.score(for: player.id, roundIndex: round)
        let best = game.players.compactMap { game.score(for: $0.id, roundIndex: round) }.max()
        let isRoundBest = points != nil && points == best
        let hasBonus = options.showBonuses && game.bonusPoints(for: player.id, roundIndex: round) > 0

        return HStack(spacing: 1) {
            Text(points.map { "\($0)" } ?? "–")
                .font(.caption.weight(isRoundBest ? .bold : .regular).monospacedDigit())
                .foregroundStyle(isRoundBest ? style.gold : style.ink)
            if hasBonus {
                Image(systemName: "star.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(style.gold)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private var footer: some View {
        Text("Scored with qScore")
            .font(.caption2.weight(.medium))
            .foregroundStyle(style.secondary)
    }
}

// MARK: - Share sheet

/// Lets the player pick what goes on the results card, previews it, and
/// hands the rendered image to the system share sheet.
struct ShareGameView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss

    // Remembered between games so people don't have to re-pick every time.
    @AppStorage("share.showWinner") private var showWinner = true
    @AppStorage("share.showPlaces") private var showPlaces = true
    @AppStorage("share.showTotals") private var showTotals = true
    @AppStorage("share.showRounds") private var showRounds = false
    @AppStorage("share.showBonuses") private var showBonuses = true
    @AppStorage("share.showDetails") private var showDetails = true
    @AppStorage("share.style") private var style: ShareCardStyle = .sage

    @State private var rendered: UIImage?

    private var options: ShareCardOptions {
        ShareCardOptions(
            showWinner: showWinner,
            showPlaces: showPlaces,
            showTotals: showTotals,
            showRounds: showRounds,
            showBonuses: showBonuses,
            showDetails: showDetails
        )
    }

    private var hasBonuses: Bool { game.bonuses?.values.contains(where: { !$0.isEmpty }) == true }

    private struct RenderKey: Hashable {
        let options: ShareCardOptions
        let style: ShareCardStyle
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section {
                    stylePicker
                } header: {
                    Text("Style")
                }

                Section {
                    Toggle(isOn: $showWinner) { Label("Winner", systemImage: "trophy") }
                    Toggle(isOn: $showPlaces) { Label("Places", systemImage: "list.number") }
                    Toggle(isOn: $showTotals) { Label("Final Scores", systemImage: "number") }
                    Toggle(isOn: $showRounds) { Label("Round by Round", systemImage: "tablecells") }
                    if hasBonuses && showRounds {
                        Toggle(isOn: $showBonuses) { Label("Bonus Stars", systemImage: "star") }
                    }
                    Toggle(isOn: $showDetails) { Label("Game Details", systemImage: "calendar") }
                } header: {
                    Text("Include")
                } footer: {
                    if !options.hasContent {
                        Text("Turn on at least one of Winner, Places, Final Scores, or Round by Round.")
                    }
                }
                .tint(QTheme.sage)
            }
            .scrollContentBackground(.hidden)
            .background(QBackground())
            .navigationTitle("Share Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                shareButton
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .animation(QMotion.smooth, value: RenderKey(options: options, style: style))
            .task(id: RenderKey(options: options, style: style)) {
                rendered = renderCard()
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let rendered {
            Image(uiImage: rendered)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: GameShareCard.width)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                .padding(.vertical, 8)
                .accessibilityLabel("Preview of the results card")
        } else {
            ProgressView()
                .frame(height: 240)
        }
    }

    private var stylePicker: some View {
        HStack(spacing: 14) {
            ForEach(ShareCardStyle.allCases) { option in
                Button {
                    style = option
                } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(option.swatch)
                            .frame(height: 44)
                            .overlay {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(option.gold)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(style == option ? QTheme.gold : QTheme.ink.opacity(0.12), lineWidth: style == option ? 2.5 : 1)
                            }
                        Text(option.title)
                            .font(.caption.weight(style == option ? .semibold : .regular))
                            .foregroundStyle(style == option ? QTheme.ink : .secondary)
                    }
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(style == option ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: style)
    }

    @ViewBuilder
    private var shareButton: some View {
        if let rendered, options.hasContent {
            let image = Image(uiImage: rendered)
            ShareLink(
                item: image,
                subject: Text("Quiddler results"),
                message: Text(summaryText),
                preview: SharePreview("Quiddler results", image: image)
            ) {
                shareButtonLabel
            }
            .buttonStyle(.pressable)
        } else {
            shareButtonLabel
                .opacity(0.4)
        }
    }

    private var shareButtonLabel: some View {
        Label("Share", systemImage: "square.and.arrow.up")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(QTheme.sage, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: QTheme.sage.opacity(0.3), radius: 10, y: 4)
    }

    private func renderCard() -> UIImage? {
        let card = GameShareCard(game: game, options: options, style: style)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.isOpaque = false
        return renderer.uiImage
    }

    /// Plain-text version that rides along with the image, for apps that
    /// keep the text (Messages, Mail, Notes).
    private var summaryText: String {
        var lines: [String] = []
        let leaders = game.leaders
        if showWinner, let first = leaders.first {
            lines.append(leaders.count == 1
                ? "\(first.name) won our game of Quiddler!"
                : ListFormatter.localizedString(byJoining: leaders.map(\.name)) + " tied in our game of Quiddler!")
        }
        if showPlaces || showTotals {
            let players = showPlaces ? game.rankedPlayers : game.players
            for player in players {
                var line = ""
                if showPlaces { line += "\(game.rank(of: player.id)). " }
                line += player.name
                if showTotals { line += " – \(game.total(for: player.id))" }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }
}

#Preview {
    let store = GameStore.preview
    var game = store.games[0]
    game.completedAt = .now
    return ShareGameView(game: game)
}
