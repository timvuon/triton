{ stdenv
, fetchurl

, gmp

, channel
}:

let
  sources = {
    "0.18" = {
      version = "0.18";
      multihash = "QmPTtYQfodApCrwdwgKg2B9yY8n21MAT1MwUuwPDQqTDNK";
      sha256 = "0f35051cc030b87c673ac1f187de40e386a1482a0cfdf2c552dd6031b307ddc4";
    };
    "0.14" = {
      version = "0.14.1";
      sha256 = "1m922l5bz69lvkcxrib7lvjqwfqsr8rpbzgmb2aq07bp76460jha";
    };
  };

  inherit (sources."${channel}")
    multihash
    sha256
    version;
in
stdenv.mkDerivation rec {
  name = "isl-${version}";

  src = fetchurl {
    url = "http://isl.gforge.inria.fr/${name}.tar.xz";
    inherit multihash sha256;
  };

  buildInputs = [
    gmp
  ];

  meta = with stdenv.lib; {
    homepage = http://www.kotnet.org/~skimo/isl/;
    description = "A library for manipulating sets and relations of integer points bounded by linear constraints";
    license = licenses.mit;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      i686-linux
      ++ x86_64-linux;
  };
}
