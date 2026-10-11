cask "stou" do
  version "0.19.5"
  sha256 "6cbd55185aa625a543bd82b61757cb1d30910278114872ccd9ca0220fc8a72d9"

  url "https://github.com/prisonmike420/stou/releases/download/v#{version}/Stou-#{version}.zip"
  name "Stou"
  desc "Native macOS file preparation app with optional processing plugins"
  homepage "https://github.com/prisonmike420/stou"

  depends_on macos: :tahoe

  app "Stou/Stou.app"
  binary "Stou/stou"

  caveats <<~EOS
    Stou is currently unsigned. If macOS blocks its first launch,
    open System Settings > Privacy & Security and choose Open Anyway.
  EOS
end
