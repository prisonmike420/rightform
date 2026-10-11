cask "stou" do
  version "0.19.1"
  sha256 "8916cf37f294291972329b83cdebe9cb9273e1677a957061686e8d00aef79076"

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
