import SwiftUI
import ScoringCore

enum AppLanguage: String, CaseIterable, Identifiable {
    case zh = "zh-Hans"
    case en = "en"

    var id: String { rawValue }
    var displayName: String { self == .zh ? "中文" : "English" }
    var flag: String { self == .zh ? "🇨🇳" : "🇺🇸" }
}

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    private init() {
        // `--lang zh|en` launch argument overrides stored preference (used by smoke tests).
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "--lang"), idx + 1 < args.count {
            let value = args[idx + 1]
            if value == "zh" || value == "zh-Hans" {
                language = .zh
                return
            }
            if value == "en" {
                language = .en
                return
            }
        }
        let raw = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.en.rawValue
        language = AppLanguage(rawValue: raw) ?? .en
    }

    func toggle() {
        language = language == .zh ? .en : .zh
    }

    private static let table: [String: [AppLanguage: String]] = [
        "app.title": [.zh: "羽裁助手", .en: "UmpireAid"],
        "nav.start": [.zh: "开始比赛", .en: "Start Match"],
        "nav.history": [.zh: "历史记录", .en: "History"],
        "team.home": [.zh: "主队", .en: "Host Team"],
        "team.away": [.zh: "客队", .en: "Away Team"],
        "court.left": [.zh: "左", .en: "L"],
        "court.right": [.zh: "右", .en: "R"],
        "common.cancel": [.zh: "取消", .en: "Cancel"],

        "setup.title": [.zh: "赛前设置", .en: "Match Setup"],
        "setup.mode": [.zh: "比赛模式", .en: "Game Mode"],
        "setup.mode.label": [.zh: "模式", .en: "Mode"],
        "setup.singles": [.zh: "单打", .en: "Singles"],
        "setup.doubles": [.zh: "双打", .en: "Doubles"],
        "setup.namesSection": [.zh: "队名与双方姓名", .en: "Team Names & Players"],
        "setup.namesFooter": [.zh: "留空则使用默认队名。", .en: "Leave blank to use default team names."],
        "setup.servingSection": [.zh: "发球", .en: "Serve"],
        "setup.initialServer": [.zh: "开局发球方", .en: "First server"],
        "setup.servingFooter": [.zh: "0 分为偶数，开局由发球方右区球员发球。", .en: "Score 0 is even; the serving team's right-court player serves first."],
        "setup.courtSection": [.zh: "初始站位（拖动球员到左右发球区）", .en: "Initial courts (drag players to left / right)"],
        "setup.courtFooter": [.zh: "第 2 局起恢复为这里的初始站位，对局中也可手动拖动调整。", .en: "Courts reset here from game 2; you can still drag during play."],
        "setup.rules": [.zh: "计分规则", .en: "Scoring Rules"],
        "setup.winScore": [.zh: "赢球分数", .en: "Points to win"],
        "setup.bestOf": [.zh: "总局数", .en: "Best of"],
        "setup.game1": [.zh: "1 局", .en: "1 game"],
        "setup.game3": [.zh: "3 局", .en: "3 games"],
        "setup.game5": [.zh: "5 局", .en: "5 games"],
        "setup.winBy2": [.zh: "需 2 分优势才能赢（30 分封顶）", .en: "Win by 2 (cap at 30)"],
        "setup.midThreshold": [.zh: "局中休息阈值", .en: "Interval break at"],
        "setup.breaks": [.zh: "休息时长", .en: "Break durations"],
        "setup.midBreak": [.zh: "局内休息", .en: "Interval break"],
        "setup.gameBreak": [.zh: "局间休息", .en: "Game break"],
        "setup.start": [.zh: "比赛开始", .en: "Start Match"],
        "setup.invalid": [.zh: "请检查：球员姓名不能为空，赢球分数 ≥ 1，休息时长 ≥ 0，总局数为 1/3/5。", .en: "Check: names required, points ≥ 1, breaks ≥ 0, best of 1/3/5."],
        "setup.player": [.zh: "球员姓名", .en: "Player name"],
        "setup.player1": [.zh: "球员一", .en: "Player 1"],
        "setup.player2": [.zh: "球员二", .en: "Player 2"],
        "setup.partner": [.zh: "搭档姓名", .en: "Partner name"],
        "setup.pointsUnit": [.zh: "分", .en: "pts"],
        "setup.secondsUnit": [.zh: "秒", .en: "s"],
        "setup.playerN": [.zh: "球员%d", .en: "Player %d"],

        "match.singles": [.zh: "单打", .en: "Singles"],
        "match.doubles": [.zh: "双打", .en: "Doubles"],
        "match.undo": [.zh: "回滚", .en: "Undo"],
        "match.swap": [.zh: "交换场地", .en: "Swap ends"],
        "match.exit": [.zh: "退出比赛", .en: "Exit"],
        "match.exitConfirm": [.zh: "退出后本场比赛不保存，确定退出？", .en: "This match will NOT be saved if you exit. Continue?"],
        "match.exitYes": [.zh: "退出比赛", .en: "Exit match"],
        "match.exitNo": [.zh: "继续比赛", .en: "Keep playing"],
        "match.hint": [.zh: "点击左右半区为对应一方得分 · 发球人以颜色标出", .en: "Tap left / right half to score · server highlighted"],
        "match.game": [.zh: "局", .en: "G"],
        "match.gameN": [.zh: "第 %d 局", .en: "Game %d"],
        "match.gameScore": [.zh: "局分", .en: "Games"],
        "match.serve": [.zh: "发球", .en: "Serve"],
        "match.receive": [.zh: "接发", .en: "Recv"],
        "match.midBreak": [.zh: "局中休息", .en: "Interval break"],
        "match.gameBreak": [.zh: "局间休息", .en: "Between games"],
        "match.currentScore": [.zh: "当前比分", .en: "Score"],
        "match.nextServer": [.zh: "下一局发球方", .en: "Next server"],
        "match.setInitialServer": [.zh: "设置本局发球方", .en: "Set server"],
        "match.skipBreak": [.zh: "跳过休息", .en: "Skip break"],
        "match.finished": [.zh: "比赛结束", .en: "Match Over"],
        "match.wins": [.zh: "获胜", .en: "wins"],
        "match.done": [.zh: "完成", .en: "Done"],
        "match.totalScore": [.zh: "总比分", .en: "Total"],

        "history.title": [.zh: "历史记录", .en: "History"],
        "history.empty": [.zh: "暂无比赛记录", .en: "No matches yet"],
        "history.emptyHint": [.zh: "完成一场比赛后会自动保存到这里", .en: "Finished matches are saved here automatically"],
        "history.search": [.zh: "按选手姓名搜索", .en: "Search by player name"],
        "history.singles": [.zh: "单打", .en: "Singles"],
        "history.doubles": [.zh: "双打", .en: "Doubles"],
        "history.wins": [.zh: "胜", .en: " wins"],
        "history.durationHM": [.zh: "%d小时%02d分", .en: "%dh %02dm"],
        "history.durationMS": [.zh: "%d分%02d秒", .en: "%dm %02ds"],
        "history.noMatch": [.zh: "没有匹配「%@」的记录", .en: "No results for “%@”"],

        "detail.title": [.zh: "比赛详情", .en: "Match Detail"],
        "detail.summary": [.zh: "概要", .en: "Summary"],
        "detail.time": [.zh: "时间", .en: "Date"],
        "detail.duration": [.zh: "时长", .en: "Duration"],
        "detail.mode": [.zh: "模式", .en: "Mode"],
        "detail.winner": [.zh: "获胜方", .en: "Winner"],
        "detail.rule": [.zh: "规则", .en: "Rules"],
        "detail.ruleFormat": [.zh: "%d 分制 · %d 局 %d 胜", .en: "%d points · best of %d · first to %d"],
        "detail.ruleWinBy2": [.zh: " · 无需 2 分优势", .en: " · no win-by-2"],
        "detail.games": [.zh: "各局比分", .en: "Game scores"],
        "detail.wins": [.zh: "胜", .en: " wins"],
        "detail.rallies": [.zh: "得分详情", .en: "Point-by-point"],
        "detail.expand": [.zh: "详情", .en: "Details"],
        "detail.collapse": [.zh: "收起", .en: "Hide"],
        "detail.noRallies": [.zh: "无得分流水", .en: "No point log"],
        "detail.gameCol": [.zh: "局", .en: "G"],
        "detail.scorerCol": [.zh: "得分方", .en: "By"],
        "detail.scoreCol": [.zh: "比分", .en: "Score"],
        "detail.timeCol": [.zh: "时间", .en: "Time"],
        "detail.export": [.zh: "导出 PDF", .en: "Export PDF"],
        "detail.reportTitle": [.zh: "比赛结果报告", .en: "Match Report"],
        "detail.withRallies": [.zh: "含得分详情", .en: "with point-by-point"],
        "detail.withoutRallies": [.zh: "不含得分详情", .en: "summary only"],
    ]

    func t(_ key: String) -> String {
        Self.table[key]?[language] ?? key
    }

    func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }
}

/// Localized court label: 左/右 in zh, L/R in en.
@MainActor
func courtDisplay(_ side: CourtSide) -> String {
    LanguageManager.shared.t(side == .left ? "court.left" : "court.right")
}

/// Localized team display name: custom name wins; default labels translate.
@MainActor
func teamDisplay(_ setup: MatchSetup, _ side: TeamSide) -> String {
    let name = setup.teamName(side)
    if name == side.label {
        return LanguageManager.shared.t(side == .a ? "team.home" : "team.away")
    }
    return name
}

// MARK: - PDF report

enum MatchReportPDF {
    /// Render a SwiftUI view into a paginated US-Letter PDF; returns the file URL.
    @MainActor
    static func make<V: View>(from view: V, fileName: String) -> URL? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        guard let cgImage = renderer.cgImage else { return nil }

        let pageW: CGFloat = 612
        let pageH: CGFloat = 792
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        let scale = pageW / imgW
        let fullH = imgH * scale

        let format = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        let data = format.pdfData { ctx in
            var y: CGFloat = 0
            while y < fullH - 0.5 {
                ctx.beginPage()
                let drawH = min(pageH, fullH - y)
                let srcY = y / scale
                let srcH = drawH / scale
                let srcRect = CGRect(x: 0, y: srcY, width: imgW, height: srcH)
                if let crop = cgImage.cropping(to: srcRect) {
                    UIImage(cgImage: crop).draw(in: CGRect(x: 0, y: 0, width: pageW, height: drawH))
                }
                y += drawH
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName).pdf")
        try? data.write(to: url)
        return url
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
