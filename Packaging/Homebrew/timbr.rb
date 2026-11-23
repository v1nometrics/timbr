cask "timbr" do
  version "0.1.0"
  sha256 :no_check # Replace with release DMG SHA-256 on tagged release

  url "https://github.com/v1nometrics/timbr/releases/download/v#{version}/Timbr.dmg"
  name "timbr"
  desc "100% local per-app audio mixer, Float64 parametric EQ, and notch observatory for macOS"
  homepage "https://github.com/v1nometrics/timbr"

  depends_on macos: ">= :sequoia"

  app "Timbr.app"

  zap trash: [
    "~/Library/Application Support/dev.v1torres.timbr",
    "~/Library/Caches/dev.v1torres.timbr",
  ]
end
