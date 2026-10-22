# UmpireAid（羽裁助手）

iOS 羽毛球裁判辅助 App。SwiftUI，iOS 17+，iPhone。

## 功能

- **计分与站位**：单打/双打计分，发球权与球员站位按规则自动推导（规则见 `Packages/ScoringCore`）；支持手动拖动调整站位
- **局间流程**：局中休息 / 局间休息倒计时，可指定下一局发球方，换边自动处理
- **历史记录**：比赛打完自动保存，支持回看详情、导出 PDF 报告（含逐回合可选）
- **双语**：中文 / English，随时切换并持久化

## 结构

- `Packages/ScoringCore/` — 本地 Swift Package，全部计分/站位规则（纯值类型 `MatchEngine`）+ 单元测试
- `BadmintonUmpire/` — SwiftUI 界面（Setup / Match / History / Detail）
- `BadmintonUmpire.xcodeproj` — Xcode 工程（依赖本地 ScoringCore 包）

## 构建

用 Xcode 16+ 打开 `BadmintonUmpire.xcodeproj`，选择 iPhone 模拟器或真机运行。

核心规则测试（无需模拟器）：

```sh
swift test --package-path Packages/ScoringCore
```

## License

未指定。
