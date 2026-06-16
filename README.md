# PortPulse

macOS menu bar diagnostics for USB-C cables and ports.

## Features

- **Cable Detection** — e-marker data, speed, current rating, vendor info
- **Charging Diagnostics** — cable vs charger vs Mac bottleneck detection
- **Data Speed Diagnostics** — identify what's limiting transfer rate
- **Trust Signals** — flag cables with suspicious e-marker data
- **Power Monitor** — real-time wattage, voltage, current tracking with charts
- **Terminal Dashboard** — full-screen ANSI TUI for live monitoring
- **WidgetKit** — small/medium/large desktop widgets
- **App Intents** — Siri and Shortcuts integration (3 intents)
- **Connection History** — persistent log of connect/disconnect events
- **Notifications** — connect, disconnect, charging change, bottleneck alerts
- **CLI Tool** — `--json`, `--watch`, `--raw`, `--dashboard` modes

## Requirements

| | Minimum |
|---|---|
| macOS | 14.0 (macOS 27 preferred) |
| Hardware | Apple Silicon (M1–M5) |
| Intel / Rosetta | Not supported |

## Install

### Homebrew

```bash
brew tap portpulse/portpulse
brew install --cask portpulse
```

### Manual

Download from [Releases](https://github.com/Klausc06/portpulse/releases), unzip, drag to `/Applications`.

### Build from source

```bash
git clone https://github.com/Klausc06/portpulse.git
cd portpulse
./scripts/release.sh
cp -rf dist/PortPulse.app /Applications/
```

## Usage

### Menu Bar App

```bash
open /Applications/PortPulse.app
```

### CLI

```bash
portpulse              # Human-readable summary
portpulse --json       # Structured JSON
portpulse --watch      # Stream connect/disconnect events
portpulse --raw        # IOKit raw properties
portpulse --dashboard  # Full-screen TUI (3 screens: Overview/Negotiation/Power)
portpulse --version
portpulse --help
```

### Siri / Shortcuts

- "What's connected to my USB-C ports"
- "Why is my Mac charging slowly"
- "List my cables"

## Build

### CLI (Swift Package Manager)

```bash
swift build
swift run portpulse
```

### App Bundle

```bash
./scripts/build-app.sh
open dist/PortPulse.app
```

### Xcode

Open `Package.swift` (not `PortPulse.xcodeproj` — the xcodeproj has a known linking bug).

```bash
open -a Xcode Package.swift
```

### Tests

```bash
swift test
```

Requires Xcode (not just Swift toolchain) for XCTest.

## Architecture

```
Sources/
├── PortPulseCore/           Models, diagnostics engine, JSON serialization
│   ├── Models/              CableInfo, ChargerPDO, USBCPort, VendorDatabase
│   ├── Diagnostics/         DiagnosticEngine (charging, speed, trust)
│   └── Serialization/       JSON output models
├── PortPulseHardware/       IOKit hardware interface
│   └── IOKitReader.swift    Read USB-C port state from IOKit registry
├── PortPulseMonitor/        Real-time monitoring
│   ├── PortMonitor.swift    IOKit notifications + polling
│   └── PowerMonitor.swift   Power reading store + poller
├── PortPulseCLI/            Command-line tool + terminal dashboard
│   ├── PortPulseCLI.swift   CLI entry point
│   └── Dashboard.swift      ANSI TUI
├── PortPulseApp/            SwiftUI menu bar app
│   ├── PortPulseApp.swift   MenuBarExtra + delegate wiring
│   ├── Views/               HistoryView, PowerMonitorView
│   └── Settings/            SettingsView (launch at login, notifications)
├── PortPulseWidget/         WidgetKit (small/medium/large)
└── PortPulseIntents/        App Intents (Siri/Shortcuts)
```

### Module Dependencies

```
PortPulseCore          (no deps)
PortPulseHardware      → PortPulseCore
PortPulseMonitor       → PortPulseCore, PortPulseHardware
PortPulseCLI           → all three
PortPulseApp           → all three
PortPulseWidget        → PortPulseCore, PortPulseHardware
PortPulseIntents       → PortPulseCore, PortPulseHardware
```

## How It Works

PortPulse reads four families of IOKit services:

1. **AppleHPMInterfaceType10/11/12** (M3+) or **AppleTCControllerType10/11** (M1/M2) — per-port state, e-marker data
2. **IOPortFeaturePowerSource** — charger PDO list and active profile
3. **IOPortTransportComponentCCUSBPDSOP/SOPp/SOPpp** — PD Discover Identity VDOs
4. **XHCI controller subtree** — connected USB devices

No private APIs, no helper daemons, no network requests.

## Limitations

- E-marker data only available on cables that have one
- Some cables only expose e-marker when a device is connected at the other end
- Desktop Mac front USB-C ports may not expose cable data
- Software cannot verify what's physically inside the cable jacket

## Privacy

All processing happens locally. PortPulse reads USB-C port state from IOKit. Nothing is sent anywhere.

## License

MIT
