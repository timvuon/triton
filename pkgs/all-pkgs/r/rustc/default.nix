{ stdenv
, cmake
, fetchTritonPatch
, fetchurl
, file
, python2
, rustc_bootstrap
, which

, jemalloc
, libffi
, llvm
, ncurses
, zlib

, channel ? "stable"
}:

let
  sources = import ./sources.nix {
    inherit fetchurl;
  };

  inherit (sources."${channel}")
    src
    srcVerification
    version;
in
stdenv.mkDerivation {
  name = "rustc-${version}";

  inherit src;

  nativeBuildInputs = [
    cmake
    file
    python2
    which
  ];

  buildInputs = [
    ncurses
    zlib
  ];

  patches = [
    (fetchTritonPatch {
      rev = "e79f57c34a7ab32d39c29c066c59be0f20ea249a";
      file = "r/rust/0001-debuginfo-Remove-nix-build-dir-impurities.patch";
      sha256 = "b59d53bb95bd4a31b4c8b33d14f20d930320f7b7470daff589ec150bd1cc7578";
    })
  ];

  postPatch = ''
    # Fix not filtering out -L lines from llvm-config
    sed -i '\#if len(lib) == 1#a\        continue\n    if lib[0:2] == "-L":' src/etc/mklldeps.py
  '';

  # We don't directly run the cmake configure
  # The build system uses it for building compiler-rt
  cmakeConfigure = false;

  configureFlags = [
    "--disable-docs"
    "--release-channel=${channel}"
    "--enable-local-rust"
    "--local-rust-root=${rustc_bootstrap}"
    "--llvm-root=${llvm}"
    "--jemalloc-root=${jemalloc}/lib"
  ];

  buildFlags = [
    "VERBOSE=1"
  ];

  preFixup = ''
    rm "$out"/lib/rustlib/install.log
  '';

  # Fix an issues with gcc6
  NIX_CFLAGS_COMPILE = "-Wno-error";

  NIX_LDFLAGS = "-L${libffi}/lib -lffi";

  passthru = {
    inherit srcVerification;
  };

  meta = with stdenv.lib; {
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
