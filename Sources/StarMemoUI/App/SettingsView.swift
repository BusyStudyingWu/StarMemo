import StarMemoCore
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var settings: AppSettings

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public var body: some View {
        Form {
            Picker("默认颜色", selection: $settings.defaultAppearance) {
                Text("透明").tag(NoteAppearance.clear)
                Text("雾蓝").tag(NoteAppearance.mistBlue)
                Text("薰衣草").tag(NoteAppearance.lavender)
                Text("暖黄").tag(NoteAppearance.warmYellow)
                Text("石墨").tag(NoteAppearance.graphite)
            }
            HStack {
                Text("字体大小")
                Slider(value: $settings.editorFontSize, in: 12...28, step: 1)
                Text("\(Int(settings.editorFontSize))")
                    .monospacedDigit()
                    .frame(width: 28)
            }
            HStack {
                Text("默认背景浓度")
                Slider(value: $settings.windowOpacity, in: 0.65...1, step: 0.05)
                    .help("降低浓度可增强玻璃通透感；文字保持不透明，并保留保证可读性的底色。仅影响新建便笺。")
                Text("\(Int(settings.windowOpacity * 100))%")
                    .monospacedDigit()
                    .frame(width: 42)
            }
            Toggle("新便笺默认置顶", isOn: $settings.defaultPinned)
        }
        .padding(20)
        .frame(width: 420)
    }
}
