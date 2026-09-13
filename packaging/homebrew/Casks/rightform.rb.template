cask "rightform" do
  version "0.17.9"
  sha256 "c649fd3cdc83d2154d45f1a498fa177f1a2e722755560142805a2aeae1fe7939"

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
