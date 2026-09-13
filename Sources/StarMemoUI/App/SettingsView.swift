import StarMemoCore
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var settings: AppSettings
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    private let reduceTransparencyOverride: Bool?
    private var reduceTransparency: Bool { reduceTransparencyOverride ?? systemReduceTransparency }

    public init(settings: AppSettings, reduceTransparencyOverride: Bool? = nil) {
        self.settings = settings
        self.reduceTransparencyOverride = reduceTransparencyOverride
    }

    public var body: some View {
        Form {
            Section("所有便签") {
            Picker("颜色", selection: $settings.defaultAppearance) {
                Text("纸白").tag(NoteAppearance.clear)
                Text("雾蓝").tag(NoteAppearance.mistBlue)
                Text("薰衣草").tag(NoteAppearance.lavender)
                Text("暖黄").tag(NoteAppearance.warmYellow)
                Text("石墨").tag(NoteAppearance.graphite)
            }
            HStack {
                Text("透明度")
                Slider(value: Binding(
                    get: { settings.backgroundTransparency },
                    set: { settings.backgroundTransparency = ($0 * 100).rounded() / 100 }
                ), in: 0...1)
                    .disabled(reduceTransparency)
                    .help("0% 背景不透明，100% 背景全透明；文字和待办框不随背景淡化。")
                Text("\(Int((settings.backgroundTransparency * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(width: 42)
            }
            if reduceTransparency {
                Text("系统已开启减少透明度，背景暂时保持不透明。关闭系统选项后恢复所选透明度。")
                    .font(.caption).foregroundStyle(.secondary)
            }
                HStack {
                    Text("字体大小")
                    Slider(value: $settings.editorFontSize, in: 12...28, step: 1)
                    Text("\(Int(settings.editorFontSize))").monospacedDigit().frame(width: 28)
                }
                Toggle("置顶", isOn: $settings.defaultPinned)
                Text("修改立即应用于所有便签，新建和重新打开的便签也沿用。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 350)
    }
}
