{ stdenv, fetchTritonPatch, fetchurl, noSysDirs
, langC ? true, langCC ? true, langFortran ? false
, langJava ? false
, langAda ? false
, langVhdl ? false
, langGo ? false
, profiledCompiler ? false
, staticCompiler ? false
, enableShared ? true
, texinfo ? null
, perl ? null # optional, for texi2pod (then pod2man); required for Java
, gmp, mpfr, libmpc, gettext, which
, libelf                      # optional, for link-time optimizations (LTO)
, isl ? null # optional, for the Graphite optimization framework.
, zlib ? null, boehmgc ? null
, zip ? null, unzip ? null, pkgconfig ? null
, gtk ? null, libart_lgpl ? null, xorg ? null
, x11Support ? langJava
, gnatboot ? null
, enableMultilib ? false
, enablePlugin ? true             # whether to support user-supplied plug-ins
, name ? "gcc"
, cross ? null
, binutilsCross ? null
, libcCross ? null
, crossStageStatic ? true
, gnat ? null
, libpthread ? null, libpthreadCross ? null  # required for GNU/Hurd
, stripped ? true
, gnused ? null
, binutils ? null
, shouldBootstrap ? true
, libPathExcludes ? []
}:

assert langJava     -> zip != null && unzip != null
                       && zlib != null && boehmgc != null
                       && perl != null;  # for `--enable-java-home'
assert langAda      -> gnatboot != null;
assert langVhdl     -> gnat != null;

# LTO needs libelf and zlib.
assert libelf != null -> zlib != null;

# The go frontend is written in c++
assert langGo -> langCC;

with stdenv.lib;
with builtins;

let version = "7.3.0";

    # Whether building a cross-compiler for GNU/Hurd.
    crossGNU = cross != null && cross.config == "i586-pc-gnu";

    patches = [
      (fetchTritonPatch {
        rev = "8d29376d9dbe106435e0f58523fef8617da47972";
        file = "g/gcc/0001-libcpp-Remove-path-impurities.7.1.0.patch";
        sha256 = "10ed16616d7ed59d4c215367a63b6a1646b8be94be81737bd48403f6ff26d083";
      })
      (fetchTritonPatch {
        rev = "8d29376d9dbe106435e0f58523fef8617da47972";
        file = "g/gcc/0002-libcpp-Enforce-purity-for-time-functions.7.1.0.patch";
        sha256 = "616d16c4586a6ae4823a2e780a0655bf45f07caaacdc5886b73b41a3f5b9ab3d";
      })
      (fetchTritonPatch {
        rev = "8d29376d9dbe106435e0f58523fef8617da47972";
        file = "g/gcc/0003-Don-t-look-in-usr.7.1.0.patch";
        sha256 = "e6ca5a8e0d850c3ab7be2aca4b4dbf0295e1ea5ddeb606f39773bd2144ae3d67";
      })
    ];

    javaEcj = fetchurl {
      # The `$(top_srcdir)/ecj.jar' file is automatically picked up at
      # `configure' time.

      # XXX: Eventually we might want to take it from upstream.
      url = "ftp://sourceware.org/pub/java/ecj-4.3.jar";
      sha256 = "0jz7hvc0s6iydmhgh5h2m15yza7p2rlss2vkif30vm9y77m97qcx";
    };

    # Antlr (optional) allows the Java `gjdoc' tool to be built.  We want a
    # binary distribution here to allow the whole chain to be bootstrapped.
    javaAntlr = fetchurl {
      url = http://www.antlr.org/download/antlr-4.4-complete.jar;
      sha256 = "02lda2imivsvsis8rnzmbrbp8rh1kb8vmq4i67pqhkwz7lf8y6dz";
    };

    xlibs = with xorg; [
      libX11 libXt libSM libICE libXtst libXrender libXrandr libXi
      xproto renderproto xextproto inputproto randrproto
    ];

    javaAwtGtk = langJava && x11Support;

    /* Platform flags */
    platformFlags = let
        gccArch = stdenv.platform.gcc.arch or null;
        gccCpu = stdenv.platform.gcc.cpu or null;
        gccAbi = stdenv.platform.gcc.abi or null;
        gccFpu = stdenv.platform.gcc.fpu or null;
        gccFloat = stdenv.platform.gcc.float or null;
        gccMode = stdenv.platform.gcc.mode or null;
        withArch = if gccArch != null then " --with-arch=${gccArch}" else "";
        withCpu = if gccCpu != null then " --with-cpu=${gccCpu}" else "";
        withAbi = if gccAbi != null then " --with-abi=${gccAbi}" else "";
        withFpu = if gccFpu != null then " --with-fpu=${gccFpu}" else "";
        withFloat = if gccFloat != null then " --with-float=${gccFloat}" else "";
        withMode = if gccMode != null then " --with-mode=${gccMode}" else "";
      in
        withArch +
        withCpu +
        withAbi +
        withFpu +
        withFloat +
        withMode;

    /* Cross-gcc settings */
    crossMingw = cross != null && cross.libc == "msvcrt";
    crossDarwin = cross != null && cross.libc == "libSystem";
    crossConfigureFlags = let
        gccArch = stdenv.cross.gcc.arch or null;
        gccCpu = stdenv.cross.gcc.cpu or null;
        gccAbi = stdenv.cross.gcc.abi or null;
        gccFpu = stdenv.cross.gcc.fpu or null;
        gccFloat = stdenv.cross.gcc.float or null;
        gccMode = stdenv.cross.gcc.mode or null;
        withArch = if gccArch != null then " --with-arch=${gccArch}" else "";
        withCpu = if gccCpu != null then " --with-cpu=${gccCpu}" else "";
        withAbi = if gccAbi != null then " --with-abi=${gccAbi}" else "";
        withFpu = if gccFpu != null then " --with-fpu=${gccFpu}" else "";
        withFloat = if gccFloat != null then " --with-float=${gccFloat}" else "";
        withMode = if gccMode != null then " --with-mode=${gccMode}" else "";
      in
        "--target=${cross.config}" +
        withArch +
        withCpu +
        withAbi +
        withFpu +
        withFloat +
        withMode +
        (if crossMingw && crossStageStatic then
          " --with-headers=${libcCross}/include" +
          " --with-gcc" +
          " --with-gnu-as" +
          " --with-gnu-ld" +
          " --with-gnu-ld" +
          " --disable-shared" +
          " --disable-nls" +
          " --disable-debug" +
          " --enable-sjlj-exceptions" +
          " --enable-threads=win32" +
          " --disable-win32-registry"
          else if crossStageStatic then
          " --disable-libssp --disable-nls" +
          " --without-headers" +
          " --disable-threads " +
          " --disable-libgomp " +
          " --disable-libquadmath" +
          " --disable-shared" +
          " --disable-libatomic " +  # libatomic requires libc
          " --disable-decimal-float" # libdecnumber requires libc
          else
          " --with-headers=${libcCross}/include" +
          " --enable-__cxa_atexit" +
          " --enable-long-long" +
          (if crossMingw then
            " --enable-threads=win32" +
            " --enable-sjlj-exceptions" +
            " --enable-hash-synchronization" +
            " --disable-libssp" +
            " --disable-nls" +
            " --with-dwarf2" +
            # I think noone uses shared gcc libs in mingw, so we better do the same.
            # In any case, mingw32 g++ linking is broken by default with shared libs,
            # unless adding "-lsupc++" to any linking command. I don't know why.
            " --disable-shared" +
            # To keep ABI compatibility with upstream mingw-w64
            " --enable-fully-dynamic-string"
            else (if cross.libc == "uclibc" then
              # In uclibc cases, libgomp needs an additional '-ldl'
              # and as I don't know how to pass it, I disable libgomp.
              " --disable-libgomp" else "") +
            " --enable-threads=posix" +
            " --enable-nls" +
            " --disable-decimal-float") # No final libdecnumber (it may work only in 386)
          );
    stageNameAddon = if crossStageStatic then "-stage-static" else "-stage-final";
    crossNameAddon = if cross != null then "-${cross.config}" + stageNameAddon else "";

  bootstrap = shouldBootstrap && cross == null;

in

# We need all these X libraries when building AWT with GTK+.
assert x11Support -> (filter (x: x == null) ([ gtk libart_lgpl ] ++ xlibs)) == [];

stdenv.mkDerivation ({
  name = "${name}${if stripped then "" else "-debug"}-${version}" + crossNameAddon;

  builder = ../builder.sh;

  outputs = [ "out" "info" ];

  src = fetchurl {
    url = "mirror://gnu/gcc/gcc-${version}/gcc-${version}.tar.xz";
    sha256 = "832ca6ae04636adbb430e865a1451adf6979ab44ca1c8374f61fba65645ce15c";
  };

  inherit patches;

  postPatch =
    if ((libcCross != null                  # e.g., building `gcc.crossDrv'
            && libcCross ? crossConfig
            && libcCross.crossConfig == "i586-pc-gnu")
        || (crossGNU && libcCross != null))
    then
      # On GNU/Hurd glibc refers to Hurd & Mach headers and libpthread is not
      # in glibc, so add the right `-I' flags to the default spec string.
      assert libcCross != null -> libpthreadCross != null;
      let
        libc = if libcCross != null then libcCross else stdenv.libc;
        gnu_h = "gcc/config/gnu.h";
        extraCPPDeps =
             libc.propagatedBuildInputs
          ++ stdenv.lib.optional (libpthreadCross != null) libpthreadCross
          ++ stdenv.lib.optional (libpthread != null) libpthread;
        extraCPPSpec =
          concatStrings (intersperse " "
                          (map (x: "-I${x}/include") extraCPPDeps));
        extraLibSpec =
          if libpthreadCross != null
          then "-L${libpthreadCross}/lib ${libpthreadCross.TARGET_LDFLAGS}"
          else "-L${libpthread}/lib";
      in
        '' echo "augmenting \`CPP_SPEC' in \`${gnu_h}' with \`${extraCPPSpec}'..."
           sed -i "${gnu_h}" \
               -es'|CPP_SPEC *"\(.*\)$|CPP_SPEC "${extraCPPSpec} \1|g'

           echo "augmenting \`LIB_SPEC' in \`${gnu_h}' with \`${extraLibSpec}'..."
           sed -i "${gnu_h}" \
               -es'|LIB_SPEC *"\(.*\)$|LIB_SPEC "${extraLibSpec} \1|g'

           echo "setting \`NATIVE_SYSTEM_HEADER_DIR' and \`STANDARD_INCLUDE_DIR' to \`${libc}/include'..."
           sed -i "${gnu_h}" \
               -es'|#define STANDARD_INCLUDE_DIR.*$|#define STANDARD_INCLUDE_DIR "${libc}/include"|g'
        ''
    else if cross != null || stdenv.cc.libc != null then
      # On NixOS, use the right path to the dynamic linker instead of
      # `/lib/ld*.so'.
      let
        libc = if libcCross != null then libcCross else stdenv.cc.libc;
      in
        '' echo "fixing the \`GLIBC_DYNAMIC_LINKER' and \`UCLIBC_DYNAMIC_LINKER' macros..."
           for header in "gcc/config/"*-gnu.h "gcc/config/"*"/"*.h
           do
             grep -q LIBC_DYNAMIC_LINKER "$header" || continue
             echo "  fixing \`$header'..."
             sed -i "$header" \
                 -e 's|define[[:blank:]]*\([UCG]\+\)LIBC_DYNAMIC_LINKER\([0-9]*\)[[:blank:]]"\([^\"]\+\)"$|define \1LIBC_DYNAMIC_LINKER\2 "${libc}\3"|g'
           done
        ''
    else null;

  inherit noSysDirs staticCompiler langJava crossStageStatic
    libcCross crossMingw;

  nativeBuildInputs = [ texinfo which gettext ]
    ++ (optional (perl != null) perl)
    ++ (optional javaAwtGtk pkgconfig);

  buildInputs = [ ]
    ++ (optional (zlib != null) zlib)
    ++ (optionals langJava [ boehmgc zip unzip ])
    ++ (optionals javaAwtGtk ([ gtk libart_lgpl ] ++ xlibs))
    ++ (optionals (cross != null) [binutilsCross])
    ++ (optionals langAda [gnatboot])
    ++ (optionals langVhdl [gnat]);

  ABSOLUTE_LIBTOOL_EXCLUDED = libPathExcludes;

  disableStatic = false;

  configureFlags = "
    --enable-lto
    ${if enableMultilib then "--enable-multilib --disable-libquadmath" else "--disable-multilib"}
    ${if enableShared then "" else "--disable-shared"}
    ${if enablePlugin then "--enable-plugin" else "--disable-plugin"}
    ${optionalString (isl != null) "--with-isl=${isl}"}
    ${if langJava then
      "--with-ecj-jar=${javaEcj} " +

      # Follow Sun's layout for the convenience of IcedTea/OpenJDK.  See
      # <http://mail.openjdk.java.net/pipermail/distro-pkg-dev/2010-April/008888.html>.
      "--enable-java-home --with-java-home=\${prefix}/lib/jvm/jre "
      else ""}
    ${if javaAwtGtk then "--enable-java-awt=gtk" else ""}
    ${if langJava && javaAntlr != null then "--with-antlr-jar=${javaAntlr}" else ""}
    --with-gmp=${gmp}
    --with-mpfr=${mpfr}
    --with-mpc=${libmpc}
    ${if libelf != null then "--with-libelf=${libelf}" else ""}
    --disable-libstdcxx-pch
    --without-included-gettext
    --with-system-zlib
    --enable-static
    --enable-languages=${
      concatStrings (intersperse ","
        (  optional langC        "c"
        ++ optional langCC       "c++"
        ++ optional langFortran  "fortran"
        ++ optional langJava     "java"
        ++ optional langAda      "ada"
        ++ optional langVhdl     "vhdl"
        ++ optional langGo       "go"
        ++ optionals crossDarwin [ "objc" "obj-c++" ]
        )
      )
    }
    ${if (stdenv ? libc && cross == null)
      then " --with-native-system-header-dir=${stdenv.libc}/include"
      else ""}
    ${if langAda then " --enable-libada" else ""}
    ${if stdenv.lib.elem stdenv.targetSystem stdenv.lib.platforms.i686 then "--with-arch=i686" else ""}
    ${if cross != null then crossConfigureFlags else ""}
    ${if !bootstrap then "--disable-bootstrap" else ""}
    ${if cross == null then platformFlags else ""}
  ";

  targetConfig = if cross != null then cross.config else null;

  buildFlags = if bootstrap then
    (if profiledCompiler then "profiledbootstrap" else "bootstrap")
    else "";

  installTargets =
    if stripped
    then "install-strip"
    else "install";

  crossAttrs = let
    xgccArch = stdenv.cross.gcc.arch or null;
    xgccCpu = stdenv.cross.gcc.cpu or null;
    xgccAbi = stdenv.cross.gcc.abi or null;
    xgccFpu = stdenv.cross.gcc.fpu or null;
    xgccFloat = stdenv.cross.gcc.float or null;
    xwithArch = if xgccArch != null then " --with-arch=${xgccArch}" else "";
    xwithCpu = if xgccCpu != null then " --with-cpu=${xgccCpu}" else "";
    xwithAbi = if xgccAbi != null then " --with-abi=${xgccAbi}" else "";
    xwithFpu = if xgccFpu != null then " --with-fpu=${xgccFpu}" else "";
    xwithFloat = if xgccFloat != null then " --with-float=${xgccFloat}" else "";
  in {
    AR = "${stdenv.cross.config}-ar";
    LD = "${stdenv.cross.config}-ld";
    CC = "${stdenv.cross.config}-gcc";
    CXX = "${stdenv.cross.config}-gcc";
    AR_FOR_TARGET = "${stdenv.cross.config}-ar";
    LD_FOR_TARGET = "${stdenv.cross.config}-ld";
    CC_FOR_TARGET = "${stdenv.cross.config}-gcc";
    NM_FOR_TARGET = "${stdenv.cross.config}-nm";
    CXX_FOR_TARGET = "${stdenv.cross.config}-g++";
    # If we are making a cross compiler, cross != null
    NIX_CC_CROSS = if cross == null then "${stdenv.ccCross}" else "";
    dontStrip = true;
    configureFlags = ''
      ${if enableMultilib then "" else "--disable-multilib"}
      ${if enableShared then "" else "--disable-shared"}
      ${if langJava then "--with-ecj-jar=${javaEcj.crossDrv}" else ""}
      ${if javaAwtGtk then "--enable-java-awt=gtk" else ""}
      ${if langJava && javaAntlr != null then "--with-antlr-jar=${javaAntlr.crossDrv}" else ""}
      --with-gmp=${gmp.crossDrv}
      --with-mpfr=${mpfr.crossDrv}
      --disable-libstdcxx-pch
      --without-included-gettext
      --with-system-zlib
      --enable-languages=${
        concatStrings (intersperse ","
          (  optional langC        "c"
          ++ optional langCC       "c++"
          ++ optional langFortran  "fortran"
          ++ optional langJava     "java"
          ++ optional langAda      "ada"
          ++ optional langVhdl     "vhdl"
          ++ optional langGo       "go"
          )
        )
      }
      ${if langAda then " --enable-libada" else ""}
      --target=${stdenv.cross.config}
      ${xwithArch}
      ${xwithCpu}
      ${xwithAbi}
      ${xwithFpu}
      ${xwithFloat}
    '';
    buildFlags = "";
  };


  # Needed for the cross compilation to work
  AR = "ar";
  LD = "ld";
  # http://gcc.gnu.org/install/specific.html#x86-64-x-solaris210
  CC = if stdenv.system == "x86_64-solaris" then "gcc -m64" else "gcc";

  # Setting $CPATH and $LIBRARY_PATH to make sure both `gcc' and `xgcc' find
  # the library headers and binaries, regarless of the language being
  # compiled.

  # Note: When building the Java AWT GTK+ peer, the build system doesn't
  # honor `--with-gmp' et al., e.g., when building
  # `libjava/classpath/native/jni/java-math/gnu_java_math_GMP.c', so we just
  # add them to $CPATH and $LIBRARY_PATH in this case.
  #
  # Likewise, the LTO code doesn't find zlib.

  CPATH = concatStrings
            (intersperse ":" (map (x: x + "/include")
                                  (optionals (zlib != null) [ zlib ]
                                   ++ optionals langJava [ boehmgc ]
                                   ++ optionals javaAwtGtk xlibs
                                   ++ optionals javaAwtGtk [ gmp mpfr ]
                                   ++ optional (libpthread != null) libpthread
                                   ++ optional (libpthreadCross != null) libpthreadCross

                                   # On GNU/Hurd glibc refers to Mach & Hurd
                                   # headers.
                                   ++ optionals (libcCross != null && libcCross ? "propagatedBuildInputs" )
                                        libcCross.propagatedBuildInputs)));

  LIBRARY_PATH = concatStrings
                   (intersperse ":" (map (x: x + "/lib")
                                         (optionals (zlib != null) [ zlib ]
                                          ++ optionals langJava [ boehmgc ]
                                          ++ optionals javaAwtGtk xlibs
                                          ++ optionals javaAwtGtk [ gmp mpfr ]
                                          ++ optional (libpthread != null) libpthread)));

  EXTRA_TARGET_CFLAGS =
    if cross != null && libcCross != null
    then "-idirafter ${libcCross}/include"
    else null;

  EXTRA_TARGET_LDFLAGS =
    if cross != null && libcCross != null
    then "-B${libcCross}/lib -Wl,-L${libcCross}/lib" +
         (optionalString (libpthreadCross != null)
           " -L${libpthreadCross}/lib -Wl,${libpthreadCross.TARGET_LDFLAGS}")
    else null;

  passthru =  {
    inherit
      langC
      langCC
      langAda
      langFortran
      langVhdl
      langGo
      version;
    isGNU = true;

    srcVerification = fetchurl {
      failEarly = true;
      pgpsigUrls = map (n: "${n}.sig") src.urls;
      pgpKeyFingerprint = "33C2 35A3 4C46 AA3F FB29  3709 A328 C3A2 C3C4 5C06";
      inherit (src) urls outputHash outputHashAlgo;
    };
  };

  inherit enableMultilib;

  meta = {
    homepage = http://gcc.gnu.org/;
    license = stdenv.lib.licenses.gpl3Plus;  # runtime support libraries are typically LGPLv3+
    description = "GNU Compiler Collection, version ${version}"
      + (if stripped then "" else " (with debugging info)");

    maintainers = with stdenv.lib.maintainers; [ viric simons ];

    # gnatboot is not available out of linux platforms, so we disable the darwin build
    # for the gnat (ada compiler).
    platforms =
      stdenv.lib.platforms.linux ++
      stdenv.lib.platforms.freebsd;
  };
}

# Strip kills static libs of other archs (hence cross != null)
// optionalAttrs (!stripped || cross != null) { dontStrip = true; NIX_STRIP_DEBUG = 0; }

// optionalAttrs (enableMultilib) { dontMoveLib64 = true; }
)
