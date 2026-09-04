class Rightform < Formula
  desc "Native macOS batch optimizer for JPEG, PNG and WebP files"
  homepage "https://github.com/prisonmike420/rightform"
  url "https://github.com/prisonmike420/rightform/archive/refs/tags/v0.16.0.tar.gz"
  sha256 "ebc57b992b37c3235979502eaa80e15d678035d32247d9c063a5ff7b7c325bfd"
  license "MIT"

  depends_on "jpeg-archive"
  depends_on "jpeg-turbo"
  depends_on "oxipng"
  depends_on :macos
  depends_on "pngquant"
  depends_on "webp"

  def install
    system "scripts/build-app.sh", buildpath/"Rightform.app"
    libexec.install "Rightform.app"

    (bin/"rightform").write <<~EOS
      #!/bin/zsh
      exec /usr/bin/open "#{libexec}/Rightform.app"
    EOS
    chmod 0755, bin/"rightform"
  end

  test do
    assert_predicate libexec/"Rightform.app/Contents/MacOS/Rightform", :executable?
  end
end
