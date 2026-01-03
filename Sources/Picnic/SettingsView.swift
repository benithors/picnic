import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("Picnic.SaveDirectory") private var saveDirectory: String = ""
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.headline)
            
            Toggle("Start Picnic at login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    launchAtLogin = newValue
                    if newValue {
                        try? SMAppService.mainApp.register()
                    } else {
                        try? SMAppService.mainApp.unregister()
                    }
                }
            ))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Save Screenshots To:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                    
                    Text(displayPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(displayPath)
                    
                    Spacer()
                    
                    Button("Choose...") {
                        selectFolder()
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }
            
            ShortcutRecorder()
            
            Spacer()
        }
        .padding(20)
        .frame(width: 450, height: 220)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var displayPath: String {
        if !saveDirectory.isEmpty {
            return saveDirectory.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        }
        // Default logic matching OutputManager
        let base = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first ??
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures")
        return base.appendingPathComponent("Picnic").path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            saveDirectory = url.path
        }
    }
}
