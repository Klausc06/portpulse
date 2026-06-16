cask "portpulse" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/portpulse/portpulse/releases/download/v#{version}/PortPulse.zip"
  name "PortPulse"
  desc "macOS menu bar diagnostics for USB-C cables and ports"
  homepage "https://github.com/portpulse/portpulse"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "PortPulse.app"

  zap trash: [
    "~/Library/Preferences/com.portpulse.app.plist",
    "~/Library/Application Support/PortPulse",
  ]
end
