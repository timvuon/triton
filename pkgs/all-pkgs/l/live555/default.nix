{ stdenv
, fetchurl
, lib
}:

let
  version = "2018.02.28";
in
stdenv.mkDerivation rec {
  name = "live555-${version}";

  src = fetchurl {
    # upstream doesn't provide a stable URL, use videolan mirror
    url = "mirror://videolan/testing/contrib/live555/live.${version}.tar.gz";
    sha256 = "2db4f05616bdd21a609baf82c836486c44820c16a006315e02abe2b0b53a247e";
  };

  postPatch = /* Remove hard-coded paths */ ''
    sed -i genMakefiles \
      -e 's,/bin/rm,rm,g'
  '' + /* Add fPIC support */ ''
    sed -i config.linux \
      -e 's/$(INCLUDES) -I. -O2 -DSOCKLEN_T/$(INCLUDES) -I. -O2 -I. -fPIC -DRTSPCLIENT_SYNCHRONOUS_INTERFACE=1 -DSOCKLEN_T/g' \
  '';

  configureFlags = [
    "linux"
  ];

  preBuild = ''
    makeFlagsArray+=("PREFIX=$out")
  '';

  configureScript = "./genMakefiles";

  # Not a standard configure script
  addPrefix = false;

  meta = with lib; {
    description = "Libraries for RTP/RTCP/RTSP/SIP multimedia streaming";
    homepage = http://www.live555.com/liveMedia/;
    license = licenses.lgpl21Plus;
    maintainers = with maintainers; [
      codyopel
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
