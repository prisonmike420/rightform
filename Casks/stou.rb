cask "stou" do
  version "0.19.3"
  sha256 "71fe0bbb9afe79745005adba70fd762bff9265301096d68ae3df4f222043d133"

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
