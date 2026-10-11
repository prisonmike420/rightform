cask "rightform" do
  version "0.18.1"
  sha256 "8620b50756f5e3dbd5c606ce04651ed06b2b8ab8e0e9f42b5c8aa58c662031c2"

  url "https://github.com/prisonmike420/rightform/releases/download/v#{version}/Rightform-#{version}.zip"
  name "Rightform"
  desc "Native macOS file preparation app with optional processing plugins"
  homepage "https://github.com/prisonmike420/rightform"

  depends_on macos: :tahoe

  app "Rightform/Rightform.app"
  binary "Rightform/rightform"

  caveats <<~EOS
    Rightform is currently unsigned. If macOS blocks its first launch,
    open System Settings > Privacy & Security and choose Open Anyway.
  EOS
end
