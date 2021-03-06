{ stdenv, fetchurl, unzip }:

stdenv.mkDerivation rec {
  version = "1.2.1";

  name = "meslo-lg";

  meslo-lg = fetchurl {
    url="https://github.com/andreberg/Meslo-Font/blob/master/dist/v${version}/Meslo%20LG%20v${version}.zip?raw=true";
    name="${name}";
    sha256="1l08mxlzaz3i5bamnfr49s2k4k23vdm64b8nz2ha33ysimkbgg6h";
  };

  meslo-lg-dz = fetchurl {
    url="https://github.com/andreberg/Meslo-Font/blob/master/dist/v${version}/Meslo%20LG%20DZ%20v${version}.zip?raw=true";
    name="${name}-dz";
    sha256="0lnbkrvcpgz9chnvix79j6fiz36wj6n46brb7b1746182rl1l875";
  };

  buildInputs = [ unzip ];

  srcRoot = ".";

  phases = [ "unpackPhase" "installPhase" ];
  unpackPhase = ''
    unzip -j ${meslo-lg}
    unzip -j ${meslo-lg-dz}
  '';

  installPhase = ''
    mkdir -p $out/share/fonts/truetype
    cp *.ttf $out/share/fonts/truetype
  '';

  meta = {
    description = "A customized version of Apple’s Menlo-Regular font";
    homepage = https://github.com/andreberg/Meslo-Font/;
    license = stdenv.lib.licenses.asl20;
    maintainers = with stdenv.lib.maintainers; [ balajisivaraman ];
    platforms = with stdenv.lib.platforms; all;
  };
}
