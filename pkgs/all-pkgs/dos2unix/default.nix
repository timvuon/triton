{ stdenv
, fetchurl
, gettext
}:

stdenv.mkDerivation rec {
  name = "dos2unix-7.3.3";
  
  src = fetchurl {
    url = "http://waterlan.home.xs4all.nl/dos2unix/${name}.tar.gz";
    sha256 = "1yzh5z45c3hr9jdq3r9v83nwvqsgijcjfxp8cwy6d5mf5vm0m4aw";
  };

  nativeBuildInputs = [
    gettext
  ];

  preBuild = ''
    makeFlagsArray+=("prefix=$out")
  '';

  meta = with stdenv.lib; {
    description = "Tools to transform text files from dos to unix formats";
    homepage = http://waterlan.home.xs4all.nl/dos2unix.html;
    license = licenses.bsd2;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      i686-linux
      + x86_64-linux;
  };
}
