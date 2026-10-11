# The engines Stou builds itself, used by scripts/build-engine.sh. Each one
# pins an upstream release and the SHA-256 of its source archive; change both
# together when updating.
#
# engine_define <name> sets:
#   VERSION  SOURCE_URL  SOURCE_SHA256  LICENSE (SPDX)  LICENSE_FILE (in the source)  TOOLS (binaries it installs)
#   VERSION_ARG (what makes a tool print its version, to check it runs; default --version)
# engine_build <source-dir> <bin-dir> builds TOOLS into bin-dir.

engine_define() {
  case "$1" in
    pdfcpu)
      VERSION=0.16.1
      SOURCE_URL=https://github.com/pdfcpu/pdfcpu/archive/refs/tags/v0.16.1.tar.gz
      SOURCE_SHA256=bee48520012b0997b2de61114d3af6ea4d8a1d5fc8d98443de5ff231664155aa
      LICENSE=Apache-2.0
      LICENSE_FILE=LICENSE.txt
      TOOLS=pdfcpu
      VERSION_ARG=version
      ;;
    oxipng)
      VERSION=10.2.1
      SOURCE_URL=https://github.com/shssoichiro/oxipng/archive/refs/tags/v10.2.1.tar.gz
      SOURCE_SHA256=460ccfcdcc9c3877b9f7fae1dfd4f2a3f93d3b2a2af3e3b62ca32b163f923cca
      LICENSE=MIT
      LICENSE_FILE=LICENSE
      TOOLS=oxipng
      ;;
    *)
      echo "Unknown engine: $1" >&2
      return 1
      ;;
  esac
}

engine_build() {
  local src="$1" bin="$2"
  case "$engine" in
    pdfcpu)
      (cd "$src" && CGO_ENABLED=0 GOARCH=arm64 go build -trimpath -ldflags "-s -w" -o "$bin/pdfcpu" ./cmd/pdfcpu)
      ;;
    oxipng)
      (cd "$src" && cargo build --release --locked --target aarch64-apple-darwin)
      cp "$src/target/aarch64-apple-darwin/release/oxipng" "$bin/oxipng"
      ;;
  esac
}
