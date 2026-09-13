class Rightform < Formula
  desc "Native macOS file preparation app with optional processing plugins"
  homepage "https://github.com/prisonmike420/rightform"
  url "https://github.com/prisonmike420/rightform/archive/refs/tags/v0.17.3.tar.gz"
  sha256 "79dec968f6631b1fcba8b398cb65d3588534b865f3e880b942e8a27277cd0941"
  license "MIT"

  depends_on :macos

  def install
    system "scripts/build-app.sh", buildpath/"Rightform.app"
    libexec.install "Rightform.app"

    (bin/"rightform").write <<~EOS
      #!/bin/zsh
      case "${1:-info}" in
        info)
          print "Rightform #{version}"
          print "Installed through Homebrew."
          print "Use: rightform update | rightform app"
          ;;
        update)
          brew upgrade rightform && \
            print "Rightform updated successfully." && \
            exec /usr/bin/open "$(brew --prefix rightform)/libexec/Rightform.app"
          ;;
        app)
          exec /usr/bin/open "#{libexec}/Rightform.app"
          ;;
        *)
          print -u2 "Usage: rightform [info|update|app]"
          exit 64
          ;;
      esac
    EOS
    chmod 0755, bin/"rightform"
  end

  test do
    assert_predicate libexec/"Rightform.app/Contents/MacOS/Rightform", :executable?
  end

  def caveats
    <<~EOS
      Rightform installed successfully.
      Open the app with:
        rightform app

      Check Homebrew status or update with:
        rightform info
        rightform update
    EOS
  end
end
