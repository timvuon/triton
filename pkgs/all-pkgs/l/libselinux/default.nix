{ stdenv
, fetchurl
, lib
, python2
, swig

, libsepol
, pcre
}:

let
  release = "20180524";
  version = "2.8";
in
stdenv.mkDerivation rec {
  name = "libselinux-${version}";

  src = fetchurl {
    url = "https://github.com/SELinuxProject/selinux/releases/download/"
      + "${release}/${name}.tar.gz";
    sha256 = "31db96ec7643ce10912b3c3f98506a08a9116dcfe151855fd349c3fda96187e1";
  };

  nativeBuildInputs = [
    python2
    swig
  ];

  buildInputs = [
    libsepol
    pcre
  ];

  postPatch = ''
    sed \
      -e 's,-Werror ,,g' \
      -i utils/Makefile \
      -i src/Makefile
  '';

  preBuild = ''
    makeFlagsArray+=(
      "PREFIX=$out"
      "SHLIBDIR=$out/lib"
    )
  '';

  buildFlags = [
    "all"
    "pywrap"
  ];

  installTargets = [
    "install"
    "install-pywrap"
  ];

  meta = with lib; {
    description = "SELinux userland library";
    homepage = http://userspace.selinuxproject.org;
    license = licenses.gpl2;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
