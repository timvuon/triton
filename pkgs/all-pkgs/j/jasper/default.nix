{ stdenv
, cmake
, fetchpatch
, fetchTritonPatch
, fetchFromGitHub
, lib
, ninja

, freeglut
, libjpeg
, mesa
}:

let
  inherit (lib)
    boolOn;

  version = "2.0.6";
in
stdenv.mkDerivation rec {
  name = "jasper-${version}";

  src = fetchFromGitHub {
    version = 2;
    owner = "mdadams";
    repo = "jasper";
    rev = "version-${version}";
    sha256 = "acfae7287d5730ee8a33d522c51e435cfc6640a96e38b4e0c1a0c0bec3aca4b0";
  };

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [
    freeglut
    libjpeg
    mesa
  ];

  cmakeFlags = [
    "-DJAS_ENABLE_SHARED=ON"
    "-DJAS_ENABLE_LIBJPEG=${boolOn (libjpeg != null)}"
    "-DJAS_ENABLE_OPENGL=${boolOn (freeglut != null && mesa != null)}"
    "-DJAS_ENABLE_STRICT=OFF"
    "-DJAS_ENABLE_AUTOMATIC_DEPENDENCIES=OFF"
    "-DJAS_LOCAL=OFF"
  ];

  meta = with lib; {
    description = "JPEG2000 Library";
    homepage = https://www.ece.uvic.ca/~frodo/jasper/;
    license = licenses.free;  # JasPer2.0
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
