# PortPulse

macOS menu bar diagnostics for USB-C cables and ports.

## Features

- **Cable Detection**: Read e-marker data, speed, current rating, vendor info
- **Charging Diagnostics**: See whether cable, charger, or Mac is limiting charge speed
- **Data Speed Diagnostics**: Know what's limiting your data transfer rate
- **Trust Signals**: Flag cables with unusual e-marker data
- **Menu Bar UI**: Clean SwiftUI popover showing all port info
- **CLI Tool**: Command-line interface for scripts and terminal use
- **Real-time Monitoring**: Watch for cable connect/disconnect events
- **Connection History**: Track past cable connections

## Support Matrix

| macOS | Status |
|-------|--------|
| macOS 27 (Tahoe) | Preferred |
| macOS 14–26 | Supported |

| Hardware | Status |
|----------|--------|
| Apple Silicon (M1–M5) | Required |
| Intel / Rosetta | Not supported |

## Install

### Homebrew (recommended)

```bash
# Add the tap (first time only)
brew tap portpulse/portpulse

# Install
brew install --cask portpulse
```

### Manual

Download `PortPulse.zip` from [Releases](https://github.com/portpulse/portpulse/releases), unzip, and drag `PortPulse.app` to `/Applications`.

### Build from source

```bash
git clone https://github.com/portpulse/portpulse.git
cd portpulse
./scripts/release.sh
cp -rf dist/PortPulse.app /Applications/
```

## Usage

### CLI

```bash
swift run portpulse              # Human-readable summary
swift run portpulse --json       # Structured JSON output
swift run portpulse --watch      # Stream updates as cables come and go
swift run portpulse --raw        # Include IOKit properties
swift run portpulse --help       # Show help
```

### Menu Bar App

```bash
open /Applications/PortPulse.app
```

## Build

### CLI

```bash
swift build
swift run portpulse
```

### App

```bash
./scripts/build-app.sh
open dist/PortPulse.app
```

### Xcode

```bash
open PortPulse.xcodeproj
# Select "PortPulse" scheme → Cmd+B
```

## Architecture

```
Sources/
├── PortPulseCore/           # Models, diagnostics, serialization
│   ├── Models/              # CableInfo, ChargerPDO, USBCPort, etc.
│   ├── Diagnostics/         # DiagnosticEngine
│   ├── Evidence/            # EvidenceLevel, DiagnosticFinding (Phase 2)
│   └── Serialization/       # JSON models
├── PortPulseHardware/       # IOKit hardware interface
│   └── IOKitReader.swift    # Read USB-C port state from IOKit
├── PortPulseMonitor/        # Real-time monitoring
│   └── PortMonitor.swift    # Port change detection
├── PortPulseCLI/            # Command-line tool
│   └── main.swift
├── PortPulseApp/            # SwiftUI menu bar app
│   ├── PortPulseApp.swift
│   ├── Views/               # ContentView, HistoryView
│   └── Settings/            # SettingsView
└── PortPulseWidget/         # WidgetKit extension
```

## How It Works

PortPulse reads four families of IOKit services:

1. **AppleHPMInterfaceType10/11/12** (M3+) or **AppleTCControllerType10/11** (M1/M2) — Per-port state, e-marker data
2. **IOPortFeaturePowerSource** — Charger PDO list and active profile
3. **IOPortTransportComponentCCUSBPDSOP/SOPp/SOPpp** — PD Discover Identity VDOs
4. **XHCI controller subtree** — Connected USB devices

No private APIs, no helper daemons, no network requests.

## Limitations

- E-marker data only shows for cables that have one
- Some cables only reveal e-marker when something is plugged in at the other end
- Desktop Mac front USB-C ports don't expose cable data
- Software can't verify what's physically inside the cable jacket

## Privacy

PortPulse reads USB-C port state directly from IOKit on your Mac. All processing happens locally. Nothing is sent anywhere automatically.

## License

MIT
