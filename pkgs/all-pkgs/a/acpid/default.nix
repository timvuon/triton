{ stdenv
, fetchurl
, lib
}:

stdenv.mkDerivation rec {
  name = "acpid-2.0.29";

  src = fetchurl {
    url = "mirror://sourceforge/acpid2/${name}.tar.xz";
    sha256 = "58503b27975c466e627eb741c5453dd662f97edef1a3d0aac822fd03a84203ff";
  };

  preBuild = ''
    makeFlagsArray+=(
      "BINDIR=$out/bin"
      "SBINDIR=$out/sbin"
      "MAN8DIR=$out/share/man/man8"
    )
  '';

  meta = with lib; {
    description = "A daemon for delivering ACPI events to userspace programs";
    homepage = http://tedfelix.com/linux/acpid-netlink.html;
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [
      wkennington
    ];
    platforms = with platforms;
      x86_64-linux;
  };
}
