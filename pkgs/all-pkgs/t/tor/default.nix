{ stdenv
, fetchurl
, perl

, gperftools
, libcap
, libevent
, libscrypt
, libseccomp
, libsodium
, openssl
, systemd_lib
, zlib
}:

stdenv.mkDerivation rec {
  name = "tor-0.3.0.9";

  src = fetchurl {
    url = "https://www.torproject.org/dist/${name}.tar.gz";
    hashOutput = false;
    sha256 = "48d4880bf6ccb19ce9af2abde6946d7cf0635cc807548badbf4a221a79581e42";
  };

  nativeBuildInputs = [
    perl
  ];

  buildInputs = [
    gperftools
    libcap
    libevent
    libscrypt
    libseccomp
    libsodium
    openssl
    systemd_lib
    zlib
  ];

  postPatch = ''
    # Remove donna curve25519
    sed -i 's,"x$tor_cv_can_use_curve25519_donna_c64","xno",g' configure
  '';

  configureFlags = [
    "--sysconfdir=/etc"
    "--localstatedir=/var"
    "--disable-unittests"
    "--enable-systemd"
    "--with-tcmalloc"
  ];

  preInstall = ''
    installFlagsArray+=("sysconfdir=$out/etc")
  '';

  passthru = {
    srcVerification = fetchurl {
      failEarly = true;
      pgpsigUrls = map (n: "${n}.asc") src.urls;
      pgpKeyFingerprints = [
        "B35B F85B F194 89D0 4E28  C33C 2119 4EBB 1657 33EA"
        "2133 BC60 0AB1 33E1 D826  D173 FE43 009C 4607 B1FB"
      ];
      inherit (src) urls outputHash outputHashAlgo;
    };
  };

  meta = with stdenv.lib; {
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
