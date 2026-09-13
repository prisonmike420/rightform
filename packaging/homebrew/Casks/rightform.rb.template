cask "rightform" do
  version "0.17.5"
  sha256 "e8246921556c6dbc2cd7e461a0a0f730d0b6a37e53e7146aac14797645a1f083"

  url "https://github.com/prisonmike420/rightform/releases/download/v#{version}/Rightform-#{version}.zip"
  name "Rightform"
  desc "Native macOS file preparation app with optional processing plugins"
  homepage "https://github.com/prisonmike420/rightform"

  depends_on macos: :ventura

  app "Rightform/Rightform.app"
  binary "Rightform/rightform"

  caveats <<~EOS
    Rightform is currently unsigned. If macOS blocks its first launch,
    open System Settings > Privacy & Security and choose Open Anyway.
  EOS
end
