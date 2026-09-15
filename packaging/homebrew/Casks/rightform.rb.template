cask "rightform" do
  version "0.17.12"
  sha256 "0a9a025a1d79358231a5c1bb9b242163c56a2a1bea56c2b43dfd146d2597bf11"

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
