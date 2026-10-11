cask "rightform" do
  version "0.18.0"
  sha256 "9072541784dc8bb0274cece197ab91d25815f44c8f12a55c9c53c1f35332060d"

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
