cask "stou" do
  version "0.19.11"
  sha256 "04efdeb31456782ec3aa9cdbfa5c9490f5514f5f099a0c570c12381eb9058d75"

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
