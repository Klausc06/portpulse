import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("hideEmptyPorts") private var hideEmptyPorts = true
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("notifyChargingChange") private var notifyChargingChange = true
    @AppStorage("notifyBottleneck") private var notifyBottleneck = true
    @AppStorage("showTechnicalDetails") private var showTechnicalDetails = false
    @AppStorage("fontSize") private var fontSize: Double = 13
    
    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
                Toggle("Hide empty ports", isOn: $hideEmptyPorts)
                Toggle("Show technical details", isOn: $showTechnicalDetails)
            }
            
            Section("Notifications") {
                Toggle("Enable notifications", isOn: $showNotifications)
                
                if showNotifications {
                    Toggle("Cable connect/disconnect", isOn: .constant(true))
                        .disabled(true)
                    Toggle("Charging state changes", isOn: $notifyChargingChange)
                    Toggle("Performance warnings", isOn: $notifyBottleneck)
                }
            }
            
            Section("Display") {
                HStack {
                    Text("Font size")
                    Slider(value: $fontSize, in: 10...18, step: 1)
                    Text("\(Int(fontSize))pt")
                        .monospacedDigit()
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("0.1.0")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("License")
                    Spacer()
                    Text("MIT")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 420)
        .padding()
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Login item error: \(error)")
            }
        }
    }
}
