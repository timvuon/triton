{ stdenv
, cmake
, fetchgit
, ninja
, perl
, pythonPackages
, python2Packages
, python3Packages
, yasm

, accelio
, boost_1-61
, curl
, expat
, fcgi
, fuse
, jemalloc
, keyutils
, leveldb
, libaio
, libatomic_ops
, lz4
, nspr
, nss
, openldap
, snappy
, systemd_lib
, util-linux_lib
, xfsprogs_lib
, zlib

, channel ? "10"
}:

let
  inherit ((import ./sources.nix)."${channel}")
    fetchVersion
    rev
    sha256
    version;
in
stdenv.mkDerivation {
  name = "ceph-${version}";

  src = fetchgit {
    url = "https://github.com/ceph/ceph.git";
    inherit rev sha256;
    version = fetchVersion;
  };


  nativeBuildInputs = [
    cmake
    #ninja
    perl
    pythonPackages.sphinx
    python2Packages.python
    python3Packages.cython
    python3Packages.python
    yasm
  ];

  buildInputs = [
    accelio
    boost_1-61
    curl
    expat
    fcgi
    fuse
    jemalloc
    keyutils
    leveldb
    libaio
    libatomic_ops
    lz4
    nspr
    nss
    openldap
    snappy
    systemd_lib
    util-linux_lib
    xfsprogs_lib
    zlib
  ];

  postPatch = ''
    # We manually set the version of ceph directly so we don't have to depend on git
    sed -i 's,GITDIR-NOTFOUND,"${version}",g' cmake/modules/GetGitRevisionDescription.cmake
  '';

  cmakeFlags = [
    "-DWITH_XIO=ON"
    "-DHAVE_BABELTRACE=OFF"
    "-DHAVE_LIBZFS=ON"
    "-DWITH_SYSTEMD=ON"

    "-DBUILD_SHARED_LIBS=ON"
    "-DXFS_INCLUDE_DIR=${xfsprogs_lib}/include"
    "-DKEYUTILS_INCLUDE_DIR=${keyutils}/include"
  ];

  makeFlags = [
    "VERBOSE=1"
  ];
  
  meta = with stdenv.lib; {
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
