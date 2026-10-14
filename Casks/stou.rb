cask "stou" do
  version "0.20.0"
  sha256 "8ac2f02651720614c9af94d11f4404629a416ed6e6018bfafdd28feeecbf1f7c"

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
