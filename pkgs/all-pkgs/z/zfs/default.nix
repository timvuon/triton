{ stdenv
, autoconf
, automake
, elfutils
, fetchFromGitHub
, fetchTritonPatch
, fetchurl
, lib
, libtool

, libaio
, libtirpc
, openssl
, python2
, python3
, perl
, systemd_lib
, util-linux_lib
, zlib

, channel
}:

let
  common = (import ./common.nix {
    inherit
      fetchFromGitHub
      fetchTritonPatch
      fetchurl
      stdenv;
  })."${channel}";
in
stdenv.mkDerivation rec {
  name = "zfs-user-${common.version or common.date}";

  inherit (common) src;

  nativeBuildInputs = [
    autoconf
    automake
    libtool
  ];

  buildInputs = [
    libaio
    libtirpc
    openssl
    python2
    python3
    perl
    systemd_lib
    util-linux_lib
    zlib
  ];

  # for zdb to get the rpath to libgcc_s, needed for pthread_cancel to work
  NIX_CFLAGS_LINK = "-lgcc_s";

  inherit (common) patches;

  preConfigure = ''
    test -f configure || ./autogen.sh

    configureFlagsArray+=(
      "--with-mounthelperdir=$out/bin"
      "--with-udevdir=$out/lib/udev"
      "--with-systemdunitdir=$out/etc/systemd/system"
      "--with-systemdpresetdir=$out/etc/systemd/system-preset"
      "--with-systemdmodulesloaddir=$out/etc/module-load.d"
      "--with-systemdgeneratordir=$out/lib/systemd/system-generators"
      "--with-dracutdir=$TMPDIR"
    )
  '';

  configureFlags = [
    "--sysconfdir=/etc"
    "--localstatedir=/var"
    "--enable-systemd"
    "--disable-sysvinit"
    "--with-config=user"
    #"--with-qat"
    "--with-tirpc"
  ];

  preInstall = ''
    installFlagsArray+=(
      "sysconfdir=$out/etc"
    )
  '';

  postInstall = ''
    # Remove test code
    rm -r "$out"/share/zfs

    # Remove initrd stuff
    rm -r "$out"/share/initramfs-tools
  '';

  passthru = {
    inherit channel;
  };

  meta = with lib; {
    description = "ZFS Filesystem Linux Kernel module";
    homepage = http://zfsonlinux.org/;
    license = licenses.cddl;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
