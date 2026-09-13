class Rightform < Formula
  desc "Native macOS file preparation app with optional processing modules"
  homepage "https://github.com/prisonmike420/rightform"
  url "https://github.com/prisonmike420/rightform/archive/refs/tags/v0.17.0.tar.gz"
  sha256 "2e013632641bb4e84ed8289d9e6ef1bd8f94d9bb09083a0396bc08faefcb5b94"
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
          exec brew upgrade rightform
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
end
