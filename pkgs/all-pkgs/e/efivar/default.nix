{ stdenv
, fetchurl

, popt
}:

let
  version = "36";
in
stdenv.mkDerivation rec {
  name = "efivar-${version}";

  src = fetchurl {
    url = "https://github.com/rhinstaller/efivar/releases/download/${version}/"
      + "${name}.tar.bz2";
    sha256 = "94bfccc20889440978a85f08d5af4619040ee199001b62588d47d676f58c0d33";
  };

  buildInputs = [
    popt
  ];

  # FIXME: ld.so is not properly linked in with ld --no-allow-shlib-undefined
  #   https://sourceware.org/bugzilla/show_bug.cgi?id=19249
  postPatch = ''
    sed -i 's/--no-allow-shlib-undefined//' gcc.specs
  '';

  makeFlags = [
    # Avoid building static binary/libs
    "BINTARGETS=efivar"
    "STATICLIBTARGETS="
  ];

  preInstall = ''
    installFlagsArray+=(
      "bindir=$out/bin"
      "includedir=$out/include"
      "libdir=$out/lib"
      "mandir=$out/share/man"
    )
  '';

  meta = with stdenv.lib; {
    description = "Tools and library to manipulate EFI variables";
    homepage = https://github.com/rhinstaller/efivar;
    license = licenses.lgpl21;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
