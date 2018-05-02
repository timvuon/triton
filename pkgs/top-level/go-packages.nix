/* This file defines the composition for Go packages. */

{ stdenv
, buildGoPackage
, fetchFromGitHub
, fetchTritonPatch
, fetchzip
, go
, lib
, overrides
, pkgs
}:

let
  self = _self // overrides; _self = with self; {

  inherit go buildGoPackage;

  fetchGxPackage = { src, sha256 }: stdenv.mkDerivation {
    name = "gx-src-${src.name}";

    impureEnvVars = [ "IPFS_API" ];

    buildCommand = ''
      if ! [ -f /etc/ssl/certs/ca-certificates.crt ]; then
        echo "Missing /etc/ssl/certs/ca-certificates.crt" >&2
        echo "Please update to a version of nix which supports ssl." >&2
        exit 1
      fi

      start="$(date -u '+%s')"

      unpackDir="$TMPDIR/src"
      mkdir "$unpackDir"
      cd "$unpackDir"
      unpackFile "${src}"
      cd *

      echo "Environment:" >&2
      echo "  IPFS_API: $IPFS_API" >&2

      SOURCE_DATE_EPOCH=$(find . -type f -print0 | xargs -0 -r stat -c '%Y' | sort -n | tail -n 1)
      if [ "$start" -lt "$SOURCE_DATE_EPOCH" ]; then
        str="The newest file is too close to the current date:\n"
        str+="  File: $(date -u -d "@$SOURCE_DATE_EPOCH")\n"
        str+="  Current: $(date -u)\n"
        echo -e "$str" >&2
        exit 1
      fi
      echo -n "Clamping to date: " >&2
      date -d "@$SOURCE_DATE_EPOCH" --utc >&2

      gx --verbose install --global

      echo "Building GX Archive" >&2
      cd "$unpackDir"
      deterministic-zip '.' >"$out"
    '';

    buildInputs = [
      src.deterministic-zip
      gx.bin
    ];

    outputHashAlgo = "sha256";
    outputHashMode = "flat";
    outputHash = sha256;
    preferLocalBuild = true;

    passthru = {
      inherit src;
    };
  };

  nameFunc =
    { rev
    , goPackagePath
    , name ? null
    , date ? null
    }:
    let
      name' =
        if name == null then
          baseNameOf goPackagePath
        else
          name;
      version =
        if date != null then
          date
        else if builtins.stringLength rev != 40 then
          rev
        else
          stdenv.lib.strings.substring 0 7 rev;
    in
      "${name'}-${version}";

  buildFromGitHub =
    lib.makeOverridable ({ rev
    , date ? null
    , owner
    , repo
    , sha256
    , version
    , gxSha256 ? null
    , goPackagePath ? "github.com/${owner}/${repo}"
    , name ? null
    , ...
    } @ args:
    buildGoPackage (args // (let
      name' = nameFunc {
        inherit
          rev
          goPackagePath
          name
          date;
      };
    in {
      inherit rev goPackagePath;
      name = name';
      src = let
        src' = fetchFromGitHub {
          name = name';
          inherit rev owner repo sha256 version;
        };
      in if gxSha256 == null then
        src'
      else
        fetchGxPackage { src = src'; sha256 = gxSha256; };
    })));

  ## OFFICIAL GO PACKAGES

  appengine = buildFromGitHub {
    version = 6;
    rev = "962cbd1200af94a5a35ba8d512e9f91271b4d01a";
    owner = "golang";
    repo = "appengine";
    sha256 = "16y9yss77k4lq7qx8ih1zbi5vw5a5ybw8m6zcpvan1jhcxr515n9";
    goPackagePath = "google.golang.org/appengine";
    excludedPackages = "aetest";
    propagatedBuildInputs = [
      protobuf
      net
      text
    ];
    postPatch = ''
      find . -name \*_classic.go -delete
      rm internal/main.go
    '';
    date = "2018-04-27";
  };

  build = buildFromGitHub {
    version = 6;
    rev = "ff392962e377acc3b547d3811a07aed43028b061";
    date = "2018-05-02";
    owner = "golang";
    repo = "build";
    sha256 = "0713mbscdmkc2q05lbw7yl0ik6mbfx3drg22mgnbxld57ywy1k00";
    goPackagePath = "golang.org/x/build";
    subPackages = [
      "autocertcache"
    ];
    propagatedBuildInputs = [
      crypto
      google-cloud-go
    ];
  };

  crypto = buildFromGitHub {
    version = 6;
    rev = "8b1d31080a7692e075c4681cb2458454a1fe0706";
    date = "2018-05-02";
    owner = "golang";
    repo = "crypto";
    sha256 = "0zclsnjyc3w8qnfp7x00gc8czsi0lv9jf302gm3f8npvblcf595f";
    goPackagePath = "golang.org/x/crypto";
    buildInputs = [
      net_crypto_lib
    ];
    propagatedBuildInputs = [
      sys
    ];
  };

  debug = buildFromGitHub {
    version = 6;
    rev = "9a68d5cd74a8febd7cb729de93ee3af9828d3c5f";
    date = "2018-05-01";
    owner = "golang";
    repo = "debug";
    sha256 = "0vlcc8szg6zasn4zfg9hk84f657j5xsdn0m19s38qddap3knzywf";
    goPackagePath = "golang.org/x/debug";
    excludedPackages = "\\(testdata\\)";
  };

  geo = buildFromGitHub {
    version = 6;
    rev = "e41ca803f92c4c1770133cfa5b4fc8249a7dbe82";
    owner = "golang";
    repo = "geo";
    sha256 = "1ai46qpx9s79w9ccipiszjyzx1zl9vnzivcwycdgnc53hgvyy9b1";
    date = "2018-05-01";
  };

  glog = buildFromGitHub {
    version = 6;
    rev = "23def4e6c14b4da8ac2ed8007337bc5eb5007998";
    date = "2016-01-26";
    owner = "golang";
    repo = "glog";
    sha256 = "1ck5grhwbi76lv8v72vgwza0y7cgyb757x69q8i6zfm3kqx96iis";
  };

  image = buildFromGitHub {
    version = 6;
    rev = "f315e440302883054d0c2bd85486878cb4f8572c";
    date = "2018-04-03";
    owner = "golang";
    repo = "image";
    sha256 = "1nidhax0qljhqwdzxbzr5l9w74pflv65nnq9gy5wqylly229r5qh";
    goPackagePath = "golang.org/x/image";
    propagatedBuildInputs = [
      text
    ];
  };

  net = buildFromGitHub {
    version = 6;
    rev = "640f4622ab692b87c2f3a94265e6f579fe38263d";
    date = "2018-05-02";
    owner = "golang";
    repo = "net";
    sha256 = "1asr5f5ccsdm1l4kf4g1ksda2fbgd86xv9p8rmc2gkzwdsrv9g6g";
    goPackagePath = "golang.org/x/net";
    goPackageAliases = [
      "github.com/hashicorp/go.net"
    ];
    excludedPackages = "h2demo";
    propagatedBuildInputs = [
      text
      crypto
    ];
  };

  net_crypto_lib = buildFromGitHub {
    inherit (net) rev date owner repo sha256 version goPackagePath;
    subPackages = [
      "context"
    ];
  };

  oauth2 = buildFromGitHub {
    version = 6;
    rev = "6881fee410a5daf86371371f9ad451b95e168b71";
    date = "2018-04-16";
    owner = "golang";
    repo = "oauth2";
    sha256 = "1dsy9mh9am85hrdqi386jfqpqvpiaf14j19x0nb3xvn6rc6j4fi7";
    goPackagePath = "golang.org/x/oauth2";
    propagatedBuildInputs = [
      appengine
      google-cloud-go-compute-metadata
      net
    ];
  };

  protobuf = buildFromGitHub {
    version = 6;
    rev = "v1.1.0";
    owner = "golang";
    repo = "protobuf";
    sha256 = "0xl1k76bhsmy2l67na052amd8mf8i8yb4ygs6d5mgacsj5ijdly0";
    goPackagePath = "github.com/golang/protobuf";
    excludedPackages = "\\(test\\|conformance\\)";
  };

  snappy = buildFromGitHub {
    version = 6;
    rev = "553a641470496b2327abcac10b36396bd98e45c9";
    date = "2017-02-15";
    owner  = "golang";
    repo   = "snappy";
    sha256 = "1b9ccg1kyy9jzfx1g1kmjvrqjg67rl2kwm0nzqy5rgxli2k3dkli";
  };

  sync = buildFromGitHub {
    version = 5;
    rev = "1d60e4601c6fd243af51cc01ddf169918a5407ca";
    date = "2018-03-14";
    owner  = "golang";
    repo   = "sync";
    sha256 = "1msv6dknh2r4z6lak7fp877748374wvcjw41x1ndxzjqvdqh1bgx";
    goPackagePath = "golang.org/x/sync";
    propagatedBuildInputs = [
      net
    ];
  };

  sys = buildFromGitHub {
    version = 6;
    rev = "78d5f264b493f125018180c204871ecf58a2dce1";
    date = "2018-05-01";
    owner  = "golang";
    repo   = "sys";
    sha256 = "1gw6wncn4hxaw6manp6rrbbfqzkzl162vxzsj9dkm661k1i3kpha";
    goPackagePath = "golang.org/x/sys";
  };

  text = buildFromGitHub {
    version = 5;
    rev = "v0.3.0";
    owner = "golang";
    repo = "text";
    sha256 = "0jh3hnpnnp61h2p2sk1kq804m6iaxqsnrnllvxws4ni8k0rqp8cy";
    goPackagePath = "golang.org/x/text";
    excludedPackages = "\\(cmd\\|test\\)";
    buildInputs = [
      tools_for_text
    ];
  };

  time = buildFromGitHub {
    version = 6;
    rev = "fbb02b2291d28baffd63558aa44b4b56f178d650";
    date = "2018-04-12";
    owner  = "golang";
    repo   = "time";
    sha256 = "1hqz404sg8589x0k49671znn5i2z5f7g9m5i6djjvg27n4k5xdxf";
    goPackagePath = "golang.org/x/time";
    propagatedBuildInputs = [
      net
    ];
  };

  tools = buildFromGitHub {
    version = 6;
    rev = "8026fb003c560896db954319ee6d037f22a8d9c7";
    date = "2018-05-02";
    owner = "golang";
    repo = "tools";
    sha256 = "1j3kzgz2fa41flbgmvg2fpm5r7z77m0zrg0jrn00n5v4j3z7rbss";
    goPackagePath = "golang.org/x/tools";

    preConfigure = ''
      # Make the builtin tools available here
      mkdir -p $bin/bin
      eval $(go env | grep GOTOOLDIR)
      find $GOTOOLDIR -type f | while read x; do
        ln -sv "$x" "$bin/bin"
      done
      export GOTOOLDIR=$bin/bin
    '';

    excludedPackages = "\\("
      + stdenv.lib.concatStringsSep "\\|" ([ "testdata" ] ++ stdenv.lib.optionals (stdenv.lib.versionAtLeast go.meta.branch "1.5") [ "vet" "cover" ])
      + "\\)";

    buildInputs = [
      appengine
      build
      crypto
      google-cloud-go
      net
    ];

    # Do not copy this without a good reason for enabling
    # In this case tools is heavily coupled with go itself and embeds paths.
    allowGoReference = true;

    postPatch = ''
      grep -r '+build appengine' -l | xargs rm
    '';

    # Set GOTOOLDIR for derivations adding this to buildInputs
    postInstall = ''
      mkdir -p $bin/nix-support
      echo "export GOTOOLDIR=$bin/bin" >> $bin/nix-support/setup-hook
    '';
  };

  tools_for_text = tools.override {
    buildInputs = [ ];
    subPackages = [
      "go/ast/astutil"
      "go/buildutil"
      "go/loader"
    ];
  };

  ## THIRD PARTY

  ace = buildFromGitHub {
    version = 6;
    owner = "yosssi";
    repo = "ace";
    rev = "v0.0.5";
    sha256 = "067d3cr6vk0y1nvaqcwflpsm0a6xv71a705zbjadysfqrrmgzj99";
    buildInputs = [
      gohtml
    ];
  };

  acme = buildFromGitHub {
    version = 5;
    owner = "hlandau";
    repo = "acme";
    rev = "v0.0.67";
    sha256 = "1l2a1y3mqv1mfri568j967n6jnmzbdb6cxm7l06m3lwidlzpjqvg";
    buildInputs = [
      pkgs.libcap
    ];
    propagatedBuildInputs = [
      jmhodges_clock
      crypto
      dexlogconfig
      easyconfig_v1
      hlandau_goutils
      kingpin_v2
      go-jose_v1
      go-systemd
      go-wordwrap
      graceful_v1
      satori_go-uuid
      link
      net
      pb_v1
      service_v2
      svcutils_v1
      xlog
      yaml_v2
    ];
  };

  aeshash = buildFromGitHub {
    version = 6;
    rev = "8ba92803f64b76c91b111633cc0edce13347f0d1";
    owner  = "tildeleb";
    repo   = "aeshash";
    sha256 = "d3428c8f14db3b9589b3c97b0a0c3b30cb7a19356d11ab26a2b08b6ecb5c365c";
    goPackagePath = "leb.io/aeshash";
    date = "2016-11-30";
    subPackages = [
      "."
    ];
    meta.autoUpdate = false;
    propagatedBuildInputs = [
      hashland_for_aeshash
    ];
  };

  afero = buildFromGitHub {
    version = 6;
    owner = "spf13";
    repo = "afero";
    rev = "v1.1.0";
    sha256 = "1vrqjw92044nf3zlzipsqys18jcmmwxr263w311dhs0nqv33ndp6";
    propagatedBuildInputs = [
      sftp
      text
    ];
  };

  akamaiopen-edgegrid-golang = buildFromGitHub {
    version = 6;
    owner = "akamai";
    repo = "AkamaiOPEN-edgegrid-golang";
    rev = "v0.6.2";
    sha256 = "0sbij3pfkig4yggl1l34b8dz17s6a5iyq3alcqiwris3d154zws6";
    propagatedBuildInputs = [
      go-homedir
      gojsonschema
      ini
      logrus
      google_uuid
    ];
  };

  alertmanager = buildFromGitHub {
    version = 6;
    owner = "prometheus";
    repo = "alertmanager";
    rev = "v0.14.0";
    sha256 = "0fsgsv15xz4i27ppwcjrra8sby6a8myl5nhkh9x8y4gkakmk8pv6";
    propagatedBuildInputs = [
      backoff
      errors
      golang_protobuf_extensions
      satori_go-uuid
      kingpin
      kit
      mesh
      net
      oklog
      prometheus_pkg
      prometheus_common
      prometheus_client_golang
      gogo_protobuf
      cespare_xxhash
      yaml_v2
    ];
    postPatch = ''
      grep -q '= uuid.NewV4().String()' silence/silence.go
      sed -i 's,uuid.NewV4(),uuid.Must(uuid.NewV4()),' silence/silence.go
    '';
  };

  aliyungo = buildFromGitHub {
    version = 6;
    owner = "denverdino";
    repo = "aliyungo";
    rev = "7ca81f64f06b4d65801663f2e1c51e5c18be077d";
    date = "2018-04-26";
    sha256 = "1x1y28crlm3r2kc0bwgmhnhf3dkymi9ydijdk0jynw4s6v5lk3wq";
    propagatedBuildInputs = [
      protobuf
    ];
  };

  aliyun-oss-go-sdk = buildFromGitHub {
    version = 6;
    rev = "1.8.0";
    owner  = "aliyun";
    repo   = "aliyun-oss-go-sdk";
    sha256 = "06bk77jxdr2k5f0ix45ag5chvp3pqga6adb75ca6zlppds6r5g5v";
  };

  amber = buildFromGitHub {
    version = 6;
    owner = "eknkc";
    repo = "amber";
    rev = "cdade1c073850f4ffc70a829e31235ea6892853b";
    date = "2017-10-10";
    sha256 = "006nbvabx3wp7lwpc021crazzxysp8p3zcwd7263fsq3dx225fb7";
  };

  amqp = buildFromGitHub {
    version = 5;
    owner = "streadway";
    repo = "amqp";
    rev = "8e4aba63da9fc5571e01c6a45dc809a58cbc5a68";
    date = "2018-03-15";
    sha256 = "0h3dv3wybnllnjm1am4ac7y6kga33sy878cd11xrpmm5l6nmkzsd";
  };

  ansicolor = buildFromGitHub {
    version = 5;
    owner = "shiena";
    repo = "ansicolor";
    rev = "a422bbe96644373c5753384a59d678f7d261ff10";
    date = "2015-11-19";
    sha256 = "1683x3yhny5xbqf9kp3i9rpkj1gkc6a6w5r4p5kbbxpzidwmgb35";
  };

  ansiterm = buildFromGitHub {
    version = 5;
    owner = "juju";
    repo = "ansiterm";
    rev = "720a0952cc2ac777afc295d9861263e2a4cf96a1";
    date = "2018-01-09";
    sha256 = "1kp0qg4rivjqgf4p2ymrbrg980k1xsgigp3f4qx5h0iwkjsmlcm4";
    propagatedBuildInputs = [
      go-colorable
      go-isatty
      vtclean
    ];
  };

  asn1-ber = buildFromGitHub {
    version = 6;
    rev = "v1.2";
    owner  = "go-asn1-ber";
    repo   = "asn1-ber";
    sha256 = "16152l7va4212bzsvgl1had7d1a0bs51mvqpj5c9aakxxzgz2lqb";
    goPackageAliases = [
      "gopkg.in/asn1-ber.v1"
    ];
  };

  atime = buildFromGitHub {
    version = 6;
    owner = "djherbis";
    repo = "atime";
    rev = "89517e96e10b93292169a79fd4523807bdc5d5fa";
    sha256 = "0m2s1qqcd1j32i4mxfcxm8r087v5rpf2qp5y49wng8i1qk9jmgzc";
    date = "2017-02-15";
  };

  atomic = buildFromGitHub {
    version = 6;
    owner = "uber-go";
    repo = "atomic";
    rev = "v1.3.1";
    sha256 = "1924076ki9qqgbssk6d6mv6mar97gl1xb5jsjwh3fnbd0m5bvihc";
    goPackagePath = "go.uber.org/atomic";
    goPackageAliases = [
      "github.com/uber-go/atomic"
    ];
  };

  atomicfile = buildFromGitHub {
    version = 6;
    owner = "facebookgo";
    repo = "atomicfile";
    rev = "2de1f203e7d5e386a6833233882782932729f27e";
    sha256 = "0p2ga2ny0safzmdfx9r5m1hqjd8a5bmild797axczv19dlx2ywvx";
    date = "2015-10-19";
  };

  auroradnsclient = buildFromGitHub {
    version = 5;
    rev = "v1.0.3";
    owner  = "edeckers";
    repo   = "auroradnsclient";
    sha256 = "1zyx9imgqz8y7fdjrnzf0qmggavk3cgmz9vn49gi9nkc57xsqfd8";
    propagatedBuildInputs = [
      logrus
    ];
  };

  aws-sdk-go = buildFromGitHub {
    version = 6;
    rev = "v1.13.40";
    owner  = "aws";
    repo   = "aws-sdk-go";
    sha256 = "0yw2yam0pxi487b7xhjb5l0pgr4bh3nrw66m0by7769xq05dygdf";
    excludedPackages = "\\(awstesting\\|example\\)";
    buildInputs = [
      tools
    ];
    propagatedBuildInputs = [
      ini
      go-jmespath
      net
    ];
    preBuild = ''
      pushd go/src/$goPackagePath
      make generate
      popd
    '';
  };

  azure-sdk-for-go = buildFromGitHub {
    version = 6;
    rev = "v16.1.0";
    owner  = "Azure";
    repo   = "azure-sdk-for-go";
    sha256 = "0z5a4ysp1arablazxhfzv91mb8vk2bci83kaijd91finrapx7r9a";
    subPackages = [
      "services/compute/mgmt/2017-12-01/compute"
      "storage"
      "version"
    ];
    propagatedBuildInputs = [
      go-autorest
      satori_go-uuid
      guid
    ];
  };

  backoff = buildFromGitHub {
    version = 6;
    owner = "cenkalti";
    repo = "backoff";
    rev = "v2.0.0";
    sha256 = "0pm2q8j2lj5a21b0aqw4n0j7avvzijvf2jpgdxiji1d8yh8znsc5";
    propagatedBuildInputs = [
      net
    ];
  };

  barcode = buildFromGitHub {
    version = 5;
    owner = "boombuler";
    repo = "barcode";
    rev = "3c06908149f740ca6bd65f66e501651d8f729e70";
    sha256 = "0mjyx8s76n4xzmmqfp2hr7sa1hlafvcigxfhil31ck8b9di0g5za";
    date = "2018-03-15";
  };

  base32 = buildFromGitHub {
    version = 6;
    owner = "whyrusleeping";
    repo = "base32";
    rev = "c30ac30633ccdabefe87eb12465113f06f1bab75";
    sha256 = "1g2ah84rf7nv08j89crbpmxn74gc4x0x0n2zr0v9l7iwx5iqblv6";
    date = "2017-08-28";
  };

  base58 = buildFromGitHub {
    version = 5;
    rev = "c1bdf7c52f59d6685ca597b9955a443ff95eeee6";
    owner  = "mr-tron";
    repo   = "base58";
    sha256 = "0c7w1kif0vw68617ac7hsaxlq5v2s71byhd0wxjmvirkyi447jjx";
    date = "2017-12-18";
  };

  binary = buildFromGitHub {
    version = 6;
    owner = "alecthomas";
    repo = "binary";
    rev = "6e8df1b1fb9d591dfc8249e230e0a762524873f3";
    date = "2017-11-01";
    sha256 = "0fms5gs17j1ab1p2kfzf5ihkk2j8lhngg5609km0sydaci7sj5y9";
  };

  binding = buildFromGitHub {
    version = 6;
    date = "2017-06-11";
    rev = "ac54ee249c27dca7e76fad851a4a04b73bd1b183";
    owner = "go-macaron";
    repo = "binding";
    sha256 = "1iarx97i3axs42k6i1x9vijgwc014ra3jjz0nmgaf8xdaxjhvnzv";
    buildInputs = [
      com
      macaron_v1
    ];
  };

  blackfriday = buildFromGitHub {
    version = 6;
    owner = "russross";
    repo = "blackfriday";
    rev = "v1.5.1";
    sha256 = "959a36690c3687eed66672cd7befecd88dd3a3fa7e84ce2b6387288894ebcdfa";
    propagatedBuildInputs = [
      sanitized-anchor-name
    ];
    meta.autoUpdate = false;
  };

  blake2b-simd = buildFromGitHub {
    version = 6;
    owner = "minio";
    repo = "blake2b-simd";
    date = "2016-07-23";
    rev = "3f5f724cb5b182a5c278d6d3d55b40e7f8c2efb4";
    sha256 = "0f6gsg38lljxsbcpnlrmacg0s4rasjd9j4fj8chhvkc1jj5g2n4r";
  };

  blazer = buildFromGitHub {
    version = 6;
    rev = "2081f5bf046503f576d8712253724fbf2950fffe";
    owner  = "minio";
    repo   = "blazer";
    sha256 = "13vp5mzk7kvw61lm1zkwkdrc9pvbvzrmjhmricb18ww16c6yhzki";
    meta.useUnstable = true;
    date = "2017-11-26";
  };

  bbolt = buildFromGitHub {
    version = 6;
    rev = "af9db2027c98c61ecd8e17caa5bd265792b9b9a2";
    owner  = "coreos";
    repo   = "bbolt";
    sha256 = "0zwkc4sjxvi19qhfyq4lbmq8lxqjbqwhlylfgh52b6r32mlavpwg";
    date = "2018-03-18";
    buildInputs = [
      sys
    ];
  };

  bolt = buildFromGitHub {
    version = 5;
    rev = "fd01fc79c553a8e99d512a07e8e0c63d4a3ccfc5";
    owner  = "boltdb";
    repo   = "bolt";
    sha256 = "05ma1sn604hs6smr8alzx6nfzfi289ixxzknj0p73miwdfpz9299";
    buildInputs = [
      sys
    ];
    date = "2018-03-02";
  };

  btcd = buildFromGitHub {
    version = 6;
    owner = "btcsuite";
    repo = "btcd";
    date = "2018-04-18";
    rev = "675abc5df3c5531bc741b56a765e35623459da6d";
    sha256 = "165vsqwynd51fql72m8bd6gdiq224d2w163zvii8imyfingsq8ll";
    subPackages = [
      "btcec"
    ];
  };

  btree = buildFromGitHub {
    version = 5;
    rev = "e89373fe6b4a7413d7acd6da1725b83ef713e6e4";
    owner  = "google";
    repo   = "btree";
    sha256 = "0z6w5z9pi4psvrpami5k65pqg7hnv3gykzyw82pr3gfa2vwabj3m";
    date = "2018-01-24";
  };

  builder = buildFromGitHub {
    version = 6;
    rev = "v0.1.0";
    owner  = "go-xorm";
    repo   = "builder";
    sha256 = "0wkmqkd43d522150jil7k58f60s6dh0iqqhgmqg5jpbsxwvpx2jp";
  };

  buildinfo = buildFromGitHub {
    version = 6;
    rev = "337a29b5499734e584d4630ce535af64c5fe7813";
    owner  = "hlandau";
    repo   = "buildinfo";
    sha256 = "10nixanz1iclg1psfxl6nfj4j3i5mlzal29lh68ala04ps8s9r4z";
    date = "2016-11-12";
    propagatedBuildInputs = [
      easyconfig_v1
    ];
  };

  bufio_v1 = buildFromGitHub {
    version = 6;
    date = "2014-06-18";
    rev = "567b2bfa514e796916c4747494d6ff5132a1dfce";
    owner  = "go-bufio";
    repo   = "bufio";
    sha256 = "1xyh0241qc1zwrqc431ngj1azxrqi6gx9zw6rd4dksvsmbz8b4iq";
    goPackagePath = "gopkg.in/bufio.v1";
  };

  bytefmt = buildFromGitHub {
    version = 5;
    date = "2018-01-08";
    rev = "b31f603f5e1e047fdb38584e1a922dcc5c4de5c8";
    owner  = "cloudfoundry";
    repo   = "bytefmt";
    sha256 = "0lfh31x7h83xhrr1l2rcs6r021d1cizsrzy6cpi5m7yhsgk8c2vj";
    goPackagePath = "code.cloudfoundry.org/bytefmt";
    goPackageAliases = [
      "github.com/cloudfoundry/bytefmt"
    ];
  };

  cachecontrol = buildFromGitHub {
    version = 5;
    owner = "pquerna";
    repo = "cachecontrol";
    rev = "525d0eb5f91d30e3b1548de401b7ef9ea6898520";
    date = "2018-03-06";
    sha256 = "1ncpir8cj55s5qs2ss9y4w9ch4q9blnvsy1i4sc73g6kmsd0bxma";
  };

  cascadia = buildFromGitHub {
    version = 5;
    rev = "v1.0.0";
    owner  = "andybalholm";
    repo   = "cascadia";
    sha256 = "16xpfqiazm9xjmnrhp63dwjhkb3rpcwhzmcjvjlkrdqwc5pflqk3";
    propagatedBuildInputs = [
      net
    ];
  };

  cast = buildFromGitHub {
    version = 5;
    owner = "spf13";
    repo = "cast";
    rev = "v1.2.0";
    sha256 = "0kzhnlc6iz2kdnhzg0kna1smvnwxg0ygn3zi9mhrm4df9rr19320";
    buildInputs = [
      jwalterweatherman
    ];
  };

  cbauth = buildFromGitHub {
    version = 3;
    date = "2016-06-09";
    rev = "ae8f8315ad044b86ced2e0be9e3598e9dd94f38a";
    owner = "couchbase";
    repo = "cbauth";
    sha256 = "185c10ab80cn4jxdp915h428lm0r9zf1cqrfsjs71im3w3ankvsn";
  };

  cbor = buildFromGitHub {
    version = 6;
    owner = "whyrusleeping";
    repo = "cbor";
    rev = "63513f603b11583741970c5045ea567130ddb492";
    sha256 = "095n3ylchw5nlbg7ca2jjb8ykc91hffxxdzzcql9y96kf4qd1wnb";
    date = "2017-10-05";
  };

  certificate-transparency-go = buildFromGitHub {
    version = 6;
    owner = "google";
    repo = "certificate-transparency-go";
    rev = "d3b12b119dbd68296b95ccbb148ef0ca59eff3de";
    date = "2018-05-02";
    sha256 = "13yrp5nw2jm71rxqg3spsqpb0vpcia3b8ywhy8d77rphz8d2vgx2";
    subPackages = [
      "."
      "asn1"
      "client"
      "client/configpb"
      "jsonclient"
      "tls"
      "x509"
      "x509/pkix"
    ];
    propagatedBuildInputs = [
      crypto
      net
      protobuf
      gogo_protobuf
    ];
  };

  cfssl = buildFromGitHub {
    version = 6;
    rev = "1.3.2";
    owner  = "cloudflare";
    repo   = "cfssl";
    sha256 = "10bs7zd9nfmpjssa2smwfy17dis4dcdb27mbc55fprqyfzx7fysn";
    subPackages = [
      "auth"
      "api"
      "certdb"
      "config"
      "csr"
      "crypto/pkcs7"
      "errors"
      "helpers"
      "helpers/derhelpers"
      "info"
      "initca"
      "log"
      "ocsp/config"
      "signer"
      "signer/local"
    ];
    propagatedBuildInputs = [
      crypto
      certificate-transparency-go
      net
    ];
  };

  cfssl_errors = cfssl.override {
    subPackages = [
      "errors"
    ];
    buildInputs = [
    ];
    propagatedBuildInputs = [
    ];
  };

  cgofuse = buildFromGitHub {
    version = 6;
    rev = "v1.1.0";
    owner  = "billziss-gh";
    repo   = "cgofuse";
    sha256 = "0ddb6bkls9f7z1lv0jp883940zp82xbcsw2b9w8jj3hhibfgl89g";
    buildInputs = [
      pkgs.fuse_2
    ];
  };

  chacha20 = buildFromGitHub {
    version = 6;
    rev = "8457f65383c5be6183d33e992fbf1786d6ab3e76";
    owner  = "aead";
    repo   = "chacha20";
    sha256 = "0z9n5qw13akzg9x27v8zf0vvr5zp08kjwyq0c9jfi251v3lnw1r1";
    date = "2018-04-26";
  };

  chalk = buildFromGitHub {
    version = 6;
    rev = "22c06c80ed312dcb6e1cf394f9634aa2c4676e22";
    owner  = "ttacon";
    repo   = "chalk";
    sha256 = "0s5ffh4cilfg77bfxabr5b07sllic4xhbnz5ck68phys5jq9xhfs";
    date = "2016-06-26";
  };

  chroma = buildFromGitHub {
    version = 6;
    rev = "222a1f0fc811afd47471d4a4e32f3aa09b6f9cdf";
    owner  = "alecthomas";
    repo   = "chroma";
    sha256 = "0p6hwlbwqpbw8lgcfv0z10l2apk6qdqn8150d0w378zg5v0dic7c";
    excludedPackages = "cmd";
    propagatedBuildInputs = [
      fnmatch
      regexp2
    ];
    meta.useUnstable = true;
    date = "2018-04-20";
  };

  circbuf = buildFromGitHub {
    version = 6;
    date = "2015-08-27";
    rev = "bbbad097214e2918d8543d5201d12bfd7bca254d";
    owner  = "armon";
    repo   = "circbuf";
    sha256 = "1g4rrgv936x8mfdqsdg3gzz79h763pyj03p76pranq9cpvzg3ws2";
  };

  circonus-gometrics = buildFromGitHub {
    version = 5;
    rev = "v2.1.1";
    owner  = "circonus-labs";
    repo   = "circonus-gometrics";
    sha256 = "0sfp3x7h7pzf21cwcvh00f2fbrynxmdbgwp0g9xwc8720c2j0f95";
    propagatedBuildInputs = [
      circonusllhist
      errors
      go-retryablehttp
      httpunix
    ];
  };

  circonusllhist = buildFromGitHub {
    version = 6;
    date = "2018-04-30";
    rev = "5eb751da55c6d3091faf3861ec5062ae91fee9d0";
    owner  = "circonus-labs";
    repo   = "circonusllhist";
    sha256 = "1bylnq7llki3ah9ybxq6ghfi00pmp47waj4di26r2kp7a9nhaaxy";
  };

  cli_minio = buildFromGitHub {
    version = 6;
    owner = "minio";
    repo = "cli";
    rev = "v1.3.0";
    sha256 = "100ga7sjdxfnskd04yqdmvda9ydfalx7fj2s130y72n0zqpxvn0k";
    buildInputs = [
      toml
      urfave_cli
      yaml_v2
    ];
  };

  AudriusButkevicius_cli = buildFromGitHub {
    version = 6;
    rev = "7f561c78b5a4aad858d9fd550c92b5da6d55efbb";
    owner = "AudriusButkevicius";
    repo = "cli";
    sha256 = "17i9igwf84j1ippgws0fvgaswj06fp1y8ls6q6dgqfkm3p68gyi1";
    date = "2014-07-27";
  };

  docker_cli = buildFromGitHub {
    version = 6;
    date = "2018-05-02";
    rev = "222b0245f71fae6579b8c013f5eb156d9e5c3fff";
    owner = "docker";
    repo = "cli";
    sha256 = "025a93phrwd4581635nigbmx6dpml0s99zlzf5c3b44wgamk4y8k";
    goPackageAlises = [
      "github.com/docker/docker/cli/cli"
    ];
    subPackages = [
      "cli/config/configfile"
      "cli/config/credentials"
      "opts"
    ];
    propagatedBuildInputs = [
      docker-credential-helpers
      errors
      go-connections
      go-units
      logrus
      moby_lib
    ];
  };

  mitchellh_cli = buildFromGitHub {
    version = 6;
    date = "2018-04-14";
    rev = "c48282d14eba4b0817ddef3f832ff8d13851aefd";
    owner = "mitchellh";
    repo = "cli";
    sha256 = "1zb58bvlqnvnnfag443zm0y7jyvc0zg93dvh3m0z3f1nxsl6w3z4";
    propagatedBuildInputs = [
      color
      complete
      go-isatty
      go-radix
      speakeasy
    ];
  };

  urfave_cli = buildFromGitHub {
    version = 6;
    rev = "v1.20.0";
    owner = "urfave";
    repo = "cli";
    sha256 = "1ca93c2vs3d8d3zbc0dadaab5cailmi1ln6vlng7qlxv2m69f794";
    goPackagePath = "gopkg.in/urfave/cli.v1";
    goPackageAliases = [
      "github.com/codegangsta/cli"
      "github.com/urfave/cli"
    ];
    buildInputs = [
      toml
      yaml_v2
    ];
  };

  clock = buildFromGitHub {
    version = 6;
    owner = "benbjohnson";
    repo = "clock";
    rev = "7dc76406b6d3c05b5f71a86293cbcf3c4ea03b19";
    date = "2016-12-15";
    sha256 = "01b6g283q95vrhkq45mfysaz2ysm1bh6m9avjfq1jzva104z53gq";
    goPackageAliases = [
      "github.com/facebookgo/clock"
    ];
  };

  jmhodges_clock = buildFromGitHub {
    version = 5;
    owner = "jmhodges";
    repo = "clock";
    rev = "v1.1";
    sha256 = "0qda1xvz0kq5q6jzfvf23j9anzjgs4dylp71bnnlcbq64s9ywwp6";
  };

  clockwork = buildFromGitHub {
    version = 6;
    rev = "v0.1.0";
    owner = "jonboulle";
    repo = "clockwork";
    sha256 = "1hwdrck8k4nxdc0zpbd4hbxsyh8xhip9k7d71cv4ziwlh71sci5g";
  };

  cloud-golang-sdk = buildFromGitHub {
    version = 5;
    rev = "7c97cc6fde16c41f82cace5cbba3e5f098065b9c";
    owner = "centrify";
    repo = "cloud-golang-sdk";
    sha256 = "0pmxkf9f9iqcqlm95g1qxj78cxjhp6vl26f89gikc8wz6l0ls0rx";
    date = "2018-01-19";
    excludedPackages = "sample";
  };

  cmux = buildFromGitHub {
    version = 5;
    rev = "v0.1.4";
    owner = "soheilhy";
    repo = "cmux";
    sha256 = "02hbqja3sv9ah6hnb2zzj2v5ajpc2zdgvc4rs3j4mfq1y6hdi4in";
    goPackageAliases = [
      "github.com/cockroachdb/cmux"
    ];
    propagatedBuildInputs = [
      net
    ];
  };

  cni = buildFromGitHub {
    version = 6;
    rev = "cb4cd0e12ce960e860bebf9ac4a13b68908039e9";
    owner = "containernetworking";
    repo = "cni";
    sha256 = "5d53ebb9171ff31ad21106ea17cd84d421f5833e2cc9866b48c39c8af50fa4e6";
    subPackages = [
      "pkg/types"
    ];
    meta.autoUpdate = false;
  };

  cobra = buildFromGitHub {
    version = 6;
    owner = "spf13";
    repo = "cobra";
    rev = "ef82de70bb3f60c65fb8eebacbb2d122ef517385";
    sha256 = "1n33w1gl1zxv0sslcdna1qqvlbnr6x1q9l9zfknvf00vpjqsrzqw";
    propagatedBuildInputs = [
      go-homedir
      go-md2man
      mousetrap
      pflag
      viper
      yaml_v2
    ];
    meta.useUnstable = true;
    date = "2018-04-27";
  };

  cockroach = buildFromGitHub {
    version = 6;
    rev = "v2.0.1";
    owner  = "cockroachdb";
    repo   = "cockroach";
    sha256 = "0gqcwwx67minlbhm0cpr8yrqv378p8axdd6cw05vk3pi5mmph5d4";
    subPackages = [
      "pkg/build"
      "pkg/settings"
      "pkg/util"
      "pkg/util/caller"
      "pkg/util/color"
      "pkg/util/envutil"
      "pkg/util/fileutil"
      "pkg/util/httputil"
      "pkg/util/humanizeutil"
      "pkg/util/log"
      "pkg/util/log/logflags"
      "pkg/util/protoutil"
      "pkg/util/randutil"
      "pkg/util/syncutil"
      "pkg/util/timeutil"
      "pkg/util/tracing"
      "pkg/util/uint128"
      "pkg/util/uuid"
    ];
    propagatedBuildInputs = [
      errors
      goid
      go-deadlock
      go-humanize
      satori_go-uuid
      go-version
      grpc-gateway
      gogo_protobuf
      lightstep-tracer-go
      net
      opentracing-go
      pflag
      raven-go
      sync
      sys
      tools
      zipkin-go-opentracing
    ];
    postPatch = ''
      sed -i 's,uuid.NewV4(),uuid.Must(uuid.NewV4()),' pkg/util/uuid/uuid.go
    '';
  };

  cockroach-go = buildFromGitHub {
    version = 5;
    rev = "59c0560478b705bf9bd12f9252224a0fad7c87df";
    owner  = "cockroachdb";
    repo   = "cockroach-go";
    sha256 = "1jfjmgaslclzkswn9phdxp30kmyhzkxyd1d9dcpwcri9r1bkygkg";
    date = "2018-02-12";
    propagatedBuildInputs = [
      pq
    ];
  };

  color = buildFromGitHub {
    version = 5;
    rev = "v1.6.0";
    owner  = "fatih";
    repo   = "color";
    sha256 = "15hz4n6x4avca02gr0kr19qkicdvlmw1dxzswgv763nh4pfb1chh";
    propagatedBuildInputs = [
      go-colorable
      go-isatty
    ];
  };

  colorstring = buildFromGitHub {
    version = 6;
    rev = "8631ce90f28644f54aeedcb3e389a85174e067d1";
    owner  = "mitchellh";
    repo   = "colorstring";
    sha256 = "1xdggialfb55ph18vkp8c7031py2pns62xk00am449mr4gsyn5ck";
    date = "2015-09-17";
  };

  columnize = buildFromGitHub {
    version = 6;
    rev = "abc90934186a77966e2beeac62ed966aac0561d5";
    owner  = "ryanuber";
    repo   = "columnize";
    sha256 = "00nrx8yh3ydynjlqf4daj49niwyrrmdav0g2a7cdzbxpsz6j7x22";
    date = "2017-07-03";
  };

  com = buildFromGitHub {
    version = 6;
    rev = "7677a1d7c1137cd3dd5ba7a076d0c898a1ef4520";
    owner  = "Unknwon";
    repo   = "com";
    sha256 = "0dif4i331vn0dbdg77br4crwzxdh4c8gsia8khjl7hqa1lwkb6dn";
    date = "2017-08-19";
  };

  complete = buildFromGitHub {
    version = 5;
    rev = "v1.1.1";
    owner  = "posener";
    repo   = "complete";
    sha256 = "0bb2bkclyszbpyf59rcyzl1h3nr8kra956145jz8qyibk7vpz9xx";
    propagatedBuildInputs = [
      go-multierror
    ];
  };

  compress = buildFromGitHub {
    version = 6;
    rev = "5fb1f31b0a61e9858f12f39266e059848a5f1cea";
    owner  = "klauspost";
    repo   = "compress";
    sha256 = "06y8pmqs7282g802r6p5h5zzbari4pwsrp0vbs13s2w9c9r20ixi";
    propagatedBuildInputs = [
      cpuid
    ];
    date = "2018-04-02";
  };

  concurrent = buildFromGitHub {
    version = 5;
    rev = "1.0.3";
    owner  = "modern-go";
    repo   = "concurrent";
    sha256 = "0s0jzhcwbnqinx9pxbfk0fsc6brb7j716pvssr60gv70k7052lcn";
  };

  configurable_v1 = buildFromGitHub {
    version = 6;
    rev = "v1.0.1";
    owner = "hlandau";
    repo = "configurable";
    sha256 = "0ycp11wnihrwnqywgnj4mn4mkqlsk1j4c7zyypl9s4k525apz581";
    goPackagePath = "gopkg.in/hlandau/configurable.v1";
  };

  configure = buildFromGitHub {
    version = 6;
    rev = "4e0f2df8846ee9557b5c88307a769ff2f85e89cd";
    owner = "gravitational";
    repo = "configure";
    sha256 = "1gnkzr1jhcqad6ba9q7krk9is14xnfga74pvvmxsa89i65p9sy3h";
    date = "2016-10-02";
    propagatedBuildInputs = [
      gojsonschema
      kingpin_v2
      trace
      yaml_v2
    ];
    excludedPackages = "test";
  };

  console = buildFromGitHub rec {
    version = 6;
    rev = "cb7008ab3d8359b78c5f464cb7cf160107ad5925";
    owner = "containerd";
    repo = "console";
    sha256 = "0cc56pf92rdcbb7dw6qm64m50hhvqf6v5cbhrp26n9lpajcpp72s";
    date = "2018-03-07";
    propagatedBuildInputs = [
      errors
      sys
    ];
  };

  consul = buildFromGitHub rec {
    version = 6;
    rev = "v1.0.7";
    owner = "hashicorp";
    repo = "consul";
    sha256 = "06ws9rlviax6n5x892lsrc88xydxgwnp0cjgf91rm9sxpgfpyyjn";
    excludedPackages = "test";

    buildInputs = [
      armon_go-metrics
      circbuf
      columnize
      copystructure
      dns
      errors
      go-bindata-assetfs
      go-checkpoint
      go-connections
      go-discover
      go-dockerclient
      go-memdb
      go-multierror
      go-radix
      go-rootcerts
      hashicorp_go-sockaddr
      go-syslog
      go-testing-interface
      go-version
      golang-lru
      golang-text
      google-api-go-client
      gopsutil
      hashicorp_go-uuid
      grpc
      gziphandler
      hcl
      hil
      logutils
      mapstructure
      memberlist
      mitchellh_cli
      net
      net-rpc-msgpackrpc
      oauth2
      raft-boltdb
      raft
      time
      ugorji_go
      hashicorp_yamux
    ];

    propagatedBuildInputs = [
      go-cleanhttp
      serf
    ];

    postPatch = let
      v = stdenv.lib.substring 1 (stdenv.lib.stringLength rev - 1) rev;
    in ''
      sed \
        -e 's,\(Version[ \t]*= "\)unknown,\1${v},g' \
        -e 's,\(VersionPrerelease[ \t]*= "\)unknown,\1,g' \
        -i version/version.go
    '';
  };

  consul_api = buildFromGitHub {
    inherit (consul) rev owner repo sha256 version;
    propagatedBuildInputs = [
      go-cleanhttp
      go-rootcerts
      go-testing-interface
      go-version
      golang-text
      mapstructure
      raft
      serf
      hashicorp_yamux
    ];
    subPackages = [
      "agent/consul/autopilot"
      "api"
      "command/flags"
      "lib"
      "lib/freeport"
      "tlsutil"
    ];
  };

  consulfs = buildFromGitHub {
    version = 6;
    rev = "v0.2";
    owner = "bwester";
    repo = "consulfs";
    sha256 = "0y8msx0yxphfl7rrllisni2s6fa565xrhr4kr69y7ms4anxbzi97";
    buildInputs = [
      consul_api
      fuse
      logrus
      net
    ];
  };

  consul-replicate = buildFromGitHub {
    version = 6;
    rev = "675a2c291d06aa1d152f11a2ac64b7001b588816";
    owner = "hashicorp";
    repo = "consul-replicate";
    sha256 = "16201jwbx89brk36rbbijr429jwqckc1id031s01k6irygwf7fps";
    propagatedBuildInputs = [
      consul_api
      consul-template
      errors
      go-multierror
      hcl
      mapstructure
    ];
    meta.useUnstable = true;
    date = "2017-08-10";
  };

  consul-template = buildFromGitHub {
    version = 6;
    rev = "v0.19.4";
    owner = "hashicorp";
    repo = "consul-template";
    sha256 = "0ncwcfpygnhqx39ddmihzjbvsqxpvvhf03p2z46m6h672h87rl38";

    propagatedBuildInputs = [
      consul_api
      errors
      go-homedir
      go-multierror
      go-rootcerts
      go-shellwords
      go-syslog
      hcl
      logutils
      mapstructure
      toml
      yaml_v2
      vault_api
    ];
  };

  context = buildFromGitHub {
    version = 6;
    rev = "v1.1";
    owner = "gorilla";
    repo = "context";
    sha256 = "0h0c5cr991ilxbww717x18fy6j0d3ksjf1r9izkk3cc6ff9kvdw8";
  };

  continuity = buildFromGitHub {
    version = 6;
    rev = "c6cef34830231743494fe2969284df7b82cc0ad0";
    owner = "containerd";
    repo = "continuity";
    sha256 = "022v57a2d0q5bvya42s9wl7qqnhfr3w1l3xhpa7q5f7s5dx0lb7m";
    date = "2018-04-16";
    subPackages = [
      "pathdriver"
    ];
  };

  copier = buildFromGitHub {
    version = 6;
    date = "2018-03-08";
    rev = "7e38e58719c33e0d44d585c4ab477a30f8cb82dd";
    owner = "jinzhu";
    repo = "copier";
    sha256 = "1sx33vrks8ml9fnf4zdb5kyf7pmvn7mqgndf04b6lllrcdvhbq40";
  };

  copystructure = buildFromGitHub {
    version = 6;
    date = "2017-05-25";
    rev = "d23ffcb85de31694d6ccaa23ccb4a03e55c1303f";
    owner = "mitchellh";
    repo = "copystructure";
    sha256 = "168y1w04qhygly1axy2s1p6kzjkcfn01h91ix9xnf1f4sc2n3k9a";
    propagatedBuildInputs = [
      reflectwalk
    ];
  };

  core = buildFromGitHub {
    version = 6;
    rev = "v0.5.8";
    owner = "go-xorm";
    repo = "core";
    sha256 = "0q0sklz74cbpqv966gw7mc7ssl1il6gqxmr897vxdxq4al1dxry6";
  };

  cors = buildFromGitHub {
    version = 5;
    owner = "rs";
    repo = "cors";
    rev = "v1.3.0";
    sha256 = "1vrzp3hij6h39lfnzhl8zdklwnzbppchwkf81h3y9ifyx8blly01";
    propagatedBuildInputs = [
      net
    ];
  };

  cpuid = buildFromGitHub {
    version = 6;
    rev = "e7e905edc00ea8827e58662220139109efea09db";
    owner  = "klauspost";
    repo   = "cpuid";
    sha256 = "1pdf0s88c45w5wvk8mcsdgbi06j9dbdrqd7w8wdbgw9xl5arkkz8";
    excludedPackages = "testdata";
    date = "2018-04-05";
  };

  critbitgo = buildFromGitHub {
    version = 6;
    rev = "v1.2.0";
    owner  = "k-sone";
    repo   = "critbitgo";
    sha256 = "002j0njkvfdpdwjf0l7r2bx429ps8p80yfvr0kvwdksbdvssjhyh";
  };

  cronexpr = buildFromGitHub {
    version = 6;
    rev = "88b0669f7d75f171bd612b874e52b95c190218df";
    owner  = "gorhill";
    repo   = "cronexpr";
    sha256 = "00my3b7sjs85v918xf2ckqax48gxzvidqp6im0h5acrw9kpc0vhv";
    date = "2018-04-27";
  };

  cuckoo = buildFromGitHub {
    version = 6;
    rev = "23d6a3a21bf6bee833d131ddeeab610c71915c30";
    owner  = "tildeleb";
    repo   = "cuckoo";
    sha256 = "be2e1fa31e9c75204866ae2785b650f3b8df3f1c25b25225618ac1d4d6fdecea";
    date = "2017-09-28";
    goPackagePath = "leb.io/cuckoo";
    goPackageAliases = [
      "github.com/tildeleb/cuckoo"
    ];
    meta.autoUpdate = false;
    excludedPackages = "\\(example\\|dstest\\|primes/primes\\)";
    propagatedBuildInputs = [
      aeshash
      binary
    ];
  };

  crypt = buildFromGitHub {
    version = 6;
    owner = "xordataexchange";
    repo = "crypt";
    rev = "b2862e3d0a775f18c7cfe02273500ae307b61218";
    date = "2017-06-26";
    sha256 = "1p4yf48c7pfjqc9nzb50c6yj55sdh0259ggncprlsfj9kqbfm8xi";
    propagatedBuildInputs = [
      consul_api
      crypto
      etcd_client
    ];
    postPatch = ''
      sed -i backend/consul/consul.go \
        -e 's,"github.com/armon/consul-api",consulapi "github.com/hashicorp/consul/api",'
    '';
  };

  datadog-go = buildFromGitHub {
    version = 6;
    rev = "2.1.0";
    owner = "DataDog";
    repo = "datadog-go";
    sha256 = "17s2rnblcqwg5gy2l242cf7cglhqja3k7vwc6mmzj50hlpwzqv2x";
  };

  dbus = buildFromGitHub {
    version = 6;
    rev = "2033fb2fe4dc4cc75083e8c26ce59aac0646030f";
    owner = "godbus";
    repo = "dbus";
    sha256 = "1w5x8bd0x82k1ir8dljlk4gbqycadw13dz37klaz259ai0ghxhi1";
    date = "2018-05-01";
  };

  debounce = buildFromGitHub {
    version = 6;
    rev = "v1.1.0";
    owner  = "bep";
    repo   = "debounce";
    sha256 = "0hrkin8h3lnpg0lk5lm0jm9xxwccav9w0z0wc7zkawzqpvxbzx5r";
  };

  demangle = buildFromGitHub {
    version = 6;
    date = "2016-09-27";
    rev = "4883227f66371e02c4948937d3e2be1664d9be38";
    owner = "ianlancetaylor";
    repo = "demangle";
    sha256 = "09rsl8cgn9jgdi2s2vhji92mzy6qirbvg2j74nhq3x0y5pk0s08c";
  };

  dexlogconfig = buildFromGitHub {
    version = 6;
    date = "2016-11-12";
    rev = "244f29bd260884993b176cd14ef2f7631f6f3c18";
    owner = "hlandau";
    repo = "dexlogconfig";
    sha256 = "1j3zvhc4cyl9n8sd1apdgc0rw689xx26n8h4q89ymnyrqfg9g5py";
    propagatedBuildInputs = [
      buildinfo
      easyconfig_v1
      go-systemd
      svcutils_v1
      xlog
    ];
  };

  diskv = buildFromGitHub {
    version = 5;
    rev = "0646ccaebea1ed1539efcab30cae44019090093f";
    owner  = "peterbourgon";
    repo   = "diskv";
    sha256 = "1fvw9rk4x3lvavv6agj1ycsvnqa819fi31xjglwmddxil7avdcjb";
    propagatedBuildInputs = [
      btree
    ];
    date = "2018-03-12";
  };

  distribution = buildFromGitHub {
    version = 6;
    rev = "83389a148052d74ac602f5f1d62f86ff2f3c4aa5";
    owner = "docker";
    repo = "distribution";
    sha256 = "0nx795g4rskwzgy47g1xzqzbkp71hrh4c2ff1wzaxwz1szhcnndi";
    meta.useUnstable = true;
    date = "2018-03-27";
  };

  distribution_for_moby = buildFromGitHub {
    inherit (distribution) date rev owner repo sha256 version meta;
    subPackages = [
      "."
      "digestset"
      "context"
      "manifest"
      "manifest/manifestlist"
      "metrics"
      "reference"
      "registry/api/errcode"
      "registry/api/v2"
      "registry/client"
      "registry/client/auth"
      "registry/client/auth/challenge"
      "registry/client/transport"
      "registry/storage/cache"
      "registry/storage/cache/memory"
      "uuid"
    ];
    propagatedBuildInputs = [
      go-digest
      docker_go-metrics
      logrus
      mux
      net
    ];
  };

  dlog = buildFromGitHub {
    version = 5;
    rev = "0.3";
    owner  = "jedisct1";
    repo   = "dlog";
    sha256 = "0llzxkwbfmffj5cjdf5avzjypygy0fq6wm2ls2603phjfx5adh6n";
    propagatedBuildInputs = [
      go-syslog
      sys
    ];
  };

  dns = buildFromGitHub {
    version = 6;
    rev = "v1.0.5";
    owner  = "miekg";
    repo   = "dns";
    sha256 = "0480h89rp2byp03jccr0xymhz6fy2vnafgxbvn7xmvd1lyq3il6m";
    propagatedBuildInputs = [
      crypto
      net
    ];
  };

  dnscrypt-proxy = buildFromGitHub {
    version = 6;
    rev = "2.0.11";
    owner  = "jedisct1";
    repo   = "dnscrypt-proxy";
    sha256 = "1npnq41kcpilkg6knmw969zkrnw93djs9gknhsyvfpmxic270fas";
    propagatedBuildInputs = [
      cachecontrol
      critbitgo
      crypto
      dlog
      dns
      ewma
      godaemon
      go-clocksmith
      go-dnsstamps
      go-immutable-radix
      go-minisign
      go-systemd
      golang-lru
      lumberjack_v2
      net
      pidfile
      safefile
      service
      toml
      xsecretbox
    ];
  };

  dnsimple-go = buildFromGitHub {
    version = 5;
    rev = "v0.16.0";
    owner  = "dnsimple";
    repo   = "dnsimple-go";
    sha256 = "0vfqw98zxg8s99pci8y0n3ln71kk61l5ggzf2nnxa4dlbs017vjc";
    propagatedBuildInputs = [
      go-querystring
    ];
  };

  dnspod-go = buildFromGitHub {
    version = 6;
    rev = "83a3ba562b048c9fc88229408e593494b7774684";
    owner = "decker502";
    repo = "dnspod-go";
    sha256 = "0hhbvf0r7ir17fa3rxd76jhm2waz3baqmb51ywvq48z3bypx11n0";
    date = "2018-04-16";
    propagatedBuildInputs = [
      json-iterator_go
    ];
  };

  docker-credential-helpers = buildFromGitHub {
    version = 6;
    rev = "v0.6.0";
    owner = "docker";
    repo = "docker-credential-helpers";
    sha256 = "01gzy7drx9l2015n6igypm0y7g8aacxmc9mq2l1kbzh61pn6qrag";
    postPatch = ''
      find . -name \*_windows.go -delete
    '';
    buildInputs = [
      pkgs.libsecret
    ];
  };

  docopt-go = buildFromGitHub {
    version = 5;
    rev = "ee0de3bc6815ee19d4a46c7eb90f829db0e014b1";
    owner  = "docopt";
    repo   = "docopt-go";
    sha256 = "1y66riv7rw266vq043lp79l77jarfyi4dy9p43maxgsk9bwyh71i";
    date = "2018-01-11";
  };

  dqlite = buildFromGitHub {
    version = 6;
    rev = "eb56912a8a508af151048e464dcd5c30780680b4";
    owner  = "CanonicalLtd";
    repo   = "dqlite";
    sha256 = "1nwa2lgplwz5x1isjg8p82nq4x16ajrik9mhkyj2gnykajcm28ia";
    date = "2018-04-30";
    excludedPackages = "testdata";
    propagatedBuildInputs = [
      cobra
      errors
      fsm
      CanonicalLtd_go-sqlite3
      protobuf
      raft
      raft-boltdb
    ];
  };

  dsync = buildFromGitHub {
    version = 5;
    owner = "minio";
    repo = "dsync";
    date = "2018-01-24";
    rev = "439a0961af700f80db84cc180fe324a89070fa65";
    sha256 = "02nq7jk3hcxxs60r09kfmzc1xfk2qsn4ahp79fcvlvzq6xi46rvz";
  };

  du = buildFromGitHub {
    version = 6;
    rev = "v1.0.1";
    owner  = "calmh";
    repo   = "du";
    sha256 = "00l7y5f2si43pz9iqnfccfbx6z6wni00aqc6jgkj1kwpjq5q9ya4";
  };

  duo_api_golang = buildFromGitHub {
    version = 5;
    date = "2018-03-15";
    rev = "d0530c80e49a86b1c3f5525daa5a324bfb795ef3";
    owner = "duosecurity";
    repo = "duo_api_golang";
    sha256 = "15a8hhxl33qdx9qnclinlwglr8vip37hvxxa5yg3m6kldyisq3vk";
  };

  easyconfig_v1 = buildFromGitHub {
    version = 6;
    owner = "hlandau";
    repo = "easyconfig";
    rev = "v1.0.16";
    sha256 = "0ncv0i7s65sqlm0jwi9dz19y2yn7zlfxbpg1s3xxvslmg53hlvfk";
    goPackagePath = "gopkg.in/hlandau/easyconfig.v1";
    excludedPackages = "example";
    propagatedBuildInputs = [
      configurable_v1
      kingpin_v2
      pflag
      toml
      svcutils_v1
    ];
    postPatch = ''
      sed -i '/type Value interface {/a\'$'\t'"Type() string" adaptflag/adaptflag.go
      echo "func (v *value) Type() string {" >>adaptflag/adaptflag.go
      echo $'\t'"return \"string\"" >>adaptflag/adaptflag.go
      echo "}" >>adaptflag/adaptflag.go
    '';
  };

  easyjson = buildFromGitHub {
    version = 6;
    owner = "mailru";
    repo = "easyjson";
    rev = "8b799c424f57fa123fc63a99d6383bc6e4c02578";
    date = "2018-03-23";
    sha256 = "1al6gscpjfvynxachblja850lb2lml4fq4wc0b8x6gdixd48k5lp";
    excludedPackages = "benchmark";
  };

  ed25519 = buildFromGitHub {
    version = 6;
    owner = "agl";
    repo = "ed25519";
    rev = "5312a61534124124185d41f09206b9fef1d88403";
    sha256 = "1zcf7dw0nb8z36763grc383x7a1bq613i1r7a94pjvdsp317ihsg";
    date = "2017-01-16";
  };

  egoscale = buildFromGitHub {
    version = 5;
    rev = "v0.9.12";
    owner  = "exoscale";
    repo   = "egoscale";
    sha256 = "1c6nbgl5r7wcb7y3sij70avrrchnlr4z1srqwckmjflyhi5rfdkv";
    propagatedBuildInputs = [
      copier
    ];
  };

  elastic_v5 = buildFromGitHub {
    version = 6;
    owner = "olivere";
    repo = "elastic";
    rev = "v5.0.68";
    sha256 = "1iyxlznir2qhn77k05ggdhaij70k3zcdjbk6cld08mg1h94qarfa";
    goPackagePath = "gopkg.in/olivere/elastic.v5";
    propagatedBuildInputs = [
      easyjson
      errors
      sync
      google_uuid
    ];
  };

  elvish = buildFromGitHub {
    version = 6;
    owner = "elves";
    repo = "elvish";
    rev = "bac2d37023099ecb1636801be30e108aa290df2f";
    sha256 = "1va48wj7yhsp2mcp83sg9br592s7ic9fpz182q847v5hwwdphna2";
    propagatedBuildInputs = [
      bolt
      go-isatty
      persistent
      sys
    ];
    meta.useUnstable = true;
    date = "2018-03-30";
  };

  eme = buildFromGitHub {
    version = 6;
    owner = "rfjakob";
    repo = "eme";
    rev = "2222dbd4ba467ab3fc7e8af41562fcfe69c0d770";
    date = "2017-10-28";
    sha256 = "1saazrhj3jg4bkkyiy9l3z5r7b3gxmvdwxz0nhxc86czk93bdv8v";
    meta.useUnstable = true;
  };

  emoji = buildFromGitHub {
    version = 6;
    owner = "kyokomi";
    repo = "emoji";
    rev = "2e9a9507333f3ee28f3fab88c2c3aba34455d734";
    sha256 = "1hf6bhxwfb2vzhqz75rwdhbfg1qbymqinj5l5py88rd278a8x4yj";
    date = "2017-11-21";
  };

  encoding = buildFromGitHub {
    version = 6;
    owner = "jwilder";
    repo = "encoding";
    date = "2017-08-11";
    rev = "b4e1701a28efcc637d9afcca7d38e495fe909a09";
    sha256 = "0qzzrxiwynsqwrp2y6xpz5i2yk6wncfcjjzbvqrhnm08hvra74dc";
  };

  environschema_v1 = buildFromGitHub {
    version = 6;
    owner = "juju";
    repo = "environschema";
    rev = "7359fc7857abe2b11b5b3e23811a9c64cb6b01e0";
    sha256 = "1yb94v3l6ciwl3551w6fshmbla575qmmyz1hw788ll2cmcjyz7qn";
    goPackagePath = "gopkg.in/juju/environschema.v1";
    date = "2015-11-04";
    propagatedBuildInputs = [
      crypto
      errgo_v1
      juju_errors
      schema
      utils
      yaml_v2
    ];
  };

  envy = buildFromGitHub {
    version = 6;
    owner = "gobuffalo";
    repo = "envy";
    rev = "v1.6.2";
    sha256 = "1ihjdwjm323byzi8a7a29k4502pbdin0qxgn9z6hpi5hp85jxpwb";
    propagatedBuildInputs = [
      godotenv
      go-homedir
    ];
  };

  errgo_v1 = buildFromGitHub {
    version = 6;
    owner = "go-errgo";
    repo = "errgo";
    rev = "c17903c6b19d5dedb9cfba9fa314c7fae63e554f";
    sha256 = "18sbwmnxkx36kcw6yl29z0s4fvrn1gkcacwpzislbbf9x81rxqlv";
    date = "2018-05-02";
    goPackagePath = "gopkg.in/errgo.v1";
  };

  juju_errors = buildFromGitHub {
    version = 6;
    owner = "juju";
    repo = "errors";
    rev = "c7d06af17c68cd34c835053720b21f6549d9b0ee";
    sha256 = "072ayhg9j3ff1xl2a6kjk87wsyijkhh26mxrcjvj0cf8n4av2z5a";
    date = "2017-07-03";
  };

  errors = buildFromGitHub {
    version = 5;
    owner = "pkg";
    repo = "errors";
    rev = "816c9085562cd7ee03e7f8188a1cfd942858cded";
    sha256 = "1szqq12n3wc0r2yayvkdfa429zv05csvzlkfjjwnf1p4h1v084y2";
    date = "2018-03-11";
  };

  errwrap = buildFromGitHub {
    version = 6;
    date = "2014-10-28";
    rev = "7554cd9344cec97297fa6649b055a8c98c2a1e55";
    owner  = "hashicorp";
    repo   = "errwrap";
    sha256 = "0b7wrwcy9w7im5dyzpwbl1bv3prk1lr5g54ws8lygvwrmzfi479h";
  };

  escaper = buildFromGitHub {
    version = 6;
    owner = "lucasem";
    repo = "escaper";
    rev = "17fe61c658dcbdcbf246c783f4f7dc97efde3a8b";
    sha256 = "1k0cbipikxxqc4im8dhkiq30ziakbld6h88vzr099c4x00qvpanf";
    goPackageAliases = [
      "github.com/10gen/escaper"
    ];
    date = "2016-08-02";
  };

  etcd = buildFromGitHub {
    version = 6;
    owner = "coreos";
    repo = "etcd";
    rev = "cc44c08d9475c75c52326f916558de457c155e4c";
    sha256 = "0q81rlpi1mn9sd2wmsylfl111a8m43bi8dgl9rgw1dysgpsphqps";
    propagatedBuildInputs = [
      bbolt
      btree
      urfave_cli
      clockwork
      cobra
      cmux
      crypto
      go-grpc-prometheus
      go-humanize
      go-semver
      go-systemd
      groupcache
      grpc
      grpc-gateway
      grpc-websocket-proxy
      jwt-go
      net
      pb_v1
      pflag
      pkg
      probing
      prometheus_client_golang
      protobuf
      gogo_protobuf
      pty
      speakeasy
      tablewriter
      time
      ugorji_go
      yaml
      zap

      pkgs.libpcap
    ];

    excludedPackages = "\\(test\\|benchmark\\|example\\|bridge\\)";
    meta.useUnstable = true;
    date = "2018-05-02";
  };

  etcd_client = etcd.override {
    subPackages = [
      "auth/authpb"
      "client"
      "clientv3"
      "clientv3/balancer"
      "clientv3/concurrency"
      "etcdserver/api/v3rpc/rpctypes"
      "etcdserver/etcdserverpb"
      "mvcc/mvccpb"
      "pkg/logutil"
      "pkg/pathutil"
      "pkg/srv"
      "pkg/tlsutil"
      "pkg/transport"
      "pkg/types"
      "raft"
      "raft/raftpb"
      "version"
    ];
    buildInputs = [
      go-systemd
    ];
    propagatedBuildInputs = [
      go-humanize
      go-semver
      grpc
      net
      pkg
      protobuf
      gogo_protobuf
      ugorji_go
      zap
    ];
  };

  etcd_for_swarmkit = etcd.override {
    subPackages = [
      "raft/raftpb"
    ];
    buildInputs = [
    ];
    propagatedBuildInputs = [
      protobuf
      gogo_protobuf
    ];
  };

  etree = buildFromGitHub {
    version = 6;
    owner = "beevik";
    repo = "etree";
    rev = "2f16c1d84957920dc0e6cd51f9e6c384ada7d911";
    sha256 = "12xhc3n4ig2xvfmh8c775p6681wg4jhbm92h21vrl9nhs4lkhb1x";
    date = "2018-04-26";
  };

  eventfd = buildFromGitHub {
    version = 6;
    owner = "gxed";
    repo = "eventfd";
    rev = "80a92cca79a8041496ccc9dd773fcb52a57ec6f9";
    date = "2016-09-16";
    sha256 = "1z5dqpawjj2r0hhlh57l49w1hw6dz148hgnklxcc9274ghzgyiny";
    propagatedBuildInputs = [
      goendian
    ];
  };

  ewma = buildFromGitHub {
    version = 6;
    owner = "VividCortex";
    repo = "ewma";
    rev = "43880d236f695d39c62cf7aa4ebd4508c258e6c0";
    date = "2017-08-04";
    sha256 = "0mdiahsdh61nbvdbzbf1p1rp13k08mcsw5xk75h8bn3smk3j8nrk";
    meta.useUnstable = true;
  };

  fastuuid = buildFromGitHub {
    version = 6;
    date = "2015-01-06";
    rev = "6724a57986aff9bff1a1770e9347036def7c89f6";
    owner  = "rogpeppe";
    repo   = "fastuuid";
    sha256 = "190ixhjlwhgdc2s52hlmq95yj3lr8gx5rg1q9jkzs7717bsf2c15";
  };

  filepath-securejoin = buildFromGitHub {
    version = 6;
    rev = "v0.2.1";
    owner  = "cyphar";
    repo   = "filepath-securejoin";
    sha256 = "0sz7cppgh5zyqdmkdih3i69yaixi3kks37yzw15g4algk0dyx0yk";
    propagatedBuildInputs = [
      errors
    ];
  };

  fileutils = buildFromGitHub {
    version = 6;
    date = "2017-11-03";
    rev = "7d4729fb36185a7c1719923406c9d40e54fb93c7";
    owner  = "mrunalp";
    repo   = "fileutils";
    sha256 = "0b2ba3bvx1pwbywq395nkgsvvc1rihiakk8nk6i6drsi6885wcdz";
  };

  flagfile = buildFromGitHub {
    version = 6;
    date = "2018-04-26";
    rev = "0d750334dbb886bfd9480d158715367bfef2441c";
    owner  = "spacemonkeygo";
    repo   = "flagfile";
    sha256 = "0fm67m72mlfxhmpzcs4vyrl5kfzc40f8d2jqbqsqca46iwvljivf";
  };

  fnmatch = buildFromGitHub {
    version = 6;
    date = "2016-04-03";
    rev = "cbb64ac3d964b81592e64f957ad53df015803288";
    owner  = "danwakefield";
    repo   = "fnmatch";
    sha256 = "126zbs23kbv3zn5g60a2w6cdxjrhqplpn6h8rwvvhm8lss30bql6";
  };

  form = buildFromGitHub {
    version = 6;
    rev = "c4048f792f70d207e6d8b9c1bf52319247f202b8";
    date = "2015-11-09";
    owner = "gravitational";
    repo = "form";
    sha256 = "0800jqfkmy4h2pavi8lhjqca84kam9b1azgwvb6z4kpirbnchpy3";
  };

  fs = buildFromGitHub {
    version = 6;
    date = "2013-11-11";
    rev = "2788f0dbd16903de03cb8186e5c7d97b69ad387b";
    owner  = "kr";
    repo   = "fs";
    sha256 = "1pllnjm1q96fl3pp62c38jl97pvcrzmb8k641aqndik3794n9x71";
  };

  fsm = buildFromGitHub {
    version = 6;
    date = "2016-01-10";
    rev = "3dc1bc0980272fd56d81167a48a641dab8356e29";
    owner  = "ryanfaerman";
    repo   = "fsm";
    sha256 = "1i30f7k4ilwy51nfnl5x5k4ib4sg3i2acy0ys1l5mkzf3m8pc4lz";
  };

  fsnotify = buildFromGitHub {
    version = 5;
    owner = "fsnotify";
    repo = "fsnotify";
    rev = "v1.4.7";
    sha256 = "0r0lw5wfs2jfksk13zqbz2f9i5l25x7kpcyjx2iwd4sc9h0fwgm8";
    propagatedBuildInputs = [
      sys
    ];
  };

  fsnotify_v1 = buildFromGitHub {
    version = 5;
    owner = "fsnotify";
    repo = "fsnotify";
    rev = "v1.4.7";
    sha256 = "19j58cdxnydx8nad708syyasriwz4l97rjf1qs4b1jv0g8az9paj";
    goPackagePath = "gopkg.in/fsnotify.v1";
    propagatedBuildInputs = [
      sys
    ];
  };

  fs-repo-migrations = buildFromGitHub {
    version = 6;
    owner = "ipfs";
    repo = "fs-repo-migrations";
    rev = "v1.3.0";
    sha256 = "147byjj3148z71l4yry6rkhlavd4apv0135c78hnm914sq47l155";
    propagatedBuildInputs = [
      goprocess
      go-homedir
      go-os-rename
    ];
    postPatch = ''
      # Unvendor
      find . -name \*.go -exec sed -i 's,".*Godeps/_workspace/src/,",g' {} \;

      # Remove old, unused migrations
      sed -i 's,&mg[01234].Migration{},nil,g' main.go
      sed -i '/mg[01234]/d' main.go
    '';
    subPackages = [
      "."
      "go-migrate"
      "ipfs-1-to-2/lock"
      "ipfs-1-to-2/repolock"
      "ipfs-4-to-5/go-datastore"
      "ipfs-4-to-5/go-datastore/query"
      "ipfs-4-to-5/go-ds-flatfs"
      "ipfs-5-to-6/migration"
      "mfsr"
      "stump"
    ];
  };

  fsync = buildFromGitHub {
    version = 6;
    owner = "spf13";
    repo = "fsync";
    rev = "12a01e648f05a938100a26858d2d59a120307a18";
    date = "2017-03-20";
    sha256 = "1vn313i08byzsmzvq98xqb074iiz1fx7hi912gzbzwrzxk81bish";
    buildInputs = [
      afero
    ];
  };

  ftp = buildFromGitHub {
    version = 6;
    owner = "jlaffaye";
    repo = "ftp";
    rev = "2403248fa8cc9f7909862627aa7337f13f8e0bf1";
    sha256 = "12zxp0a86hpnrfn28gw04rcs0h3pv08xihzbmlyc5lzmffqp31rp";
    date = "2018-04-04";
  };

  fuse = buildFromGitHub {
    version = 6;
    owner = "bazil";
    repo = "fuse";
    rev = "65cc252bf6691cb3c7014bcb2c8dc29de91e3a7e";
    date = "2018-04-21";
    sha256 = "0kf3v0fh736l5rw8yysssrw2z8glb7wdgfwqxr3pwng783xys36s";
    goPackagePath = "bazil.org/fuse";
    propagatedBuildInputs = [
      net
      sys
    ];
  };

  fwd = buildFromGitHub {
    version = 6;
    rev = "v1.0.0";
    owner  = "philhofer";
    repo   = "fwd";
    sha256 = "0z0z6f7lwbi1a6lw7xj3mmyxy0dmdgxlcids9wl1dgadmggvwb8f";
  };

  gabs = buildFromGitHub {
    version = 6;
    owner = "Jeffail";
    repo = "gabs";
    rev = "7a0fed31069aba77993a518cc2f37b28ee7aa883";
    sha256 = "1igrp5czkf6hv7vxsnspywjay0bmlsil784d3sc6pwp2s0wdchjp";
    date = "2018-04-20";
  };

  gateway = buildFromGitHub {
    version = 6;
    date = "2018-04-07";
    rev = "cbcf4e3f3baee7952fc386c8b2534af4d267c875";
    owner  = "jackpal";
    repo   = "gateway";
    sha256 = "18vggnjfhbw7axjp0ikwj5vps532bkrwn0qxsdgpn6i5db0r0swc";
  };

  gax-go = buildFromGitHub {
    version = 6;
    rev = "de2cc08e690b99dd3f7d19937d80d3d54e04682f";
    owner  = "googleapis";
    repo   = "gax-go";
    sha256 = "0ygshjd9l3rvk2wwgnpaiwkf8x02si0sgfdxkjrzdqkb0lig3lal";
    propagatedBuildInputs = [
      grpc_for_gax-go
      net
    ];
    date = "2018-03-29";
  };

  genproto = buildFromGitHub {
    version = 6;
    date = "2018-04-27";
    rev = "86e600f69ee4704c6efbf6a2a40a5c10700e76c2";
    owner  = "google";
    repo   = "go-genproto";
    goPackagePath = "google.golang.org/genproto";
    sha256 = "0bv7pgx4yiz8b8jrr1b7r7b1x2gh9i5cq56ss1hzgqmrcs1f2qvy";
    propagatedBuildInputs = [
      grpc
      net
      protobuf
    ];
  };

  genproto_for_grpc = genproto.override {
    subPackages = [
      "googleapis/rpc/status"
    ];
    propagatedBuildInputs = [
      protobuf
    ];
  };

  geoip2-golang = buildFromGitHub {
    version = 5;
    rev = "v1.2.1";
    owner = "oschwald";
    repo = "geoip2-golang";
    sha256 = "0g2g7mhwp5abjrp2x3jn736230jkvfz154922kpzjwyc2i34ynly";
    propagatedBuildInputs = [
      maxminddb-golang
    ];
  };

  getopt = buildFromGitHub {
    version = 5;
    rev = "7148bc3a4c3008adfcab60cbebfd0576018f330b";
    owner = "pborman";
    repo = "getopt";
    sha256 = "0bdxna6rgvzxaxfmsfgrjh83mmpc7i9b5k48x2kb54nr44w4bd4q";
    date = "2017-01-12";
  };

  gettext = buildFromGitHub {
    version = 6;
    rev = "v0.9";
    owner = "gosexy";
    repo = "gettext";
    sha256 = "1zrxfzwlv04gadxxyn8whmdin83ij735bbggxrnf3mcbxs8svs96";
    buildInputs = [
      go-flags
      go-runewidth
    ];
  };

  ginkgo = buildFromGitHub {
    version = 6;
    rev = "e5e551c38ce87c5b68ee6d93b8dfb576fe590dc3";
    owner = "onsi";
    repo = "ginkgo";
    sha256 = "1ji58vqw3qvci16b5b4lv8ckrkh9khyv009i2g54vz5875qjy3cw";
    buildInputs = [
      sys
    ];
    date = "2018-05-01";
  };

  gitmap = buildFromGitHub {
    version = 6;
    rev = "012701e8669671499fc43e9792335a1dcbfe2afb";
    date = "2018-04-02";
    owner = "bep";
    repo = "gitmap";
    sha256 = "13q9wx6yhcfb78lafb098ccxnrrv5bagb5h1hny9gp4l0nxpk5ki";
  };

  gjson = buildFromGitHub {
    version = 5;
    owner = "tidwall";
    repo = "gjson";
    rev = "v1.1.0";
    sha256 = "0ywwacvfphyrbj579xj45phnxka6j2mpw8ryvnl1xh51vxm7rk1l";
    propagatedBuildInputs = [
      match
    ];
  };

  glob = buildFromGitHub {
    version = 5;
    rev = "v0.2.3";
    owner = "gobwas";
    repo = "glob";
    sha256 = "15vhdakfzbjbz2l7b480db28p4f1srz2bipigcjdjyp8pm98rkd9";
  };

  gnostic = buildFromGitHub {
    version = 6;
    rev = "664776a3b48a89d0b750396afd90a7012657a293";
    owner = "googleapis";
    repo = "gnostic";
    sha256 = "0fd7azfwmb8d8i2g9f9r8gcsrxbqdzbb4zpca68ckgwajhdzcc7q";
    excludedPackages = "tools";
    propagatedBuildInputs = [
      docopt-go
      protobuf
      yaml_v2
    ];
    date = "2018-04-19";
  };

  json-iterator_go = buildFromGitHub {
    version = 6;
    rev = "1.1.3";
    owner = "json-iterator";
    repo = "go";
    sha256 = "13adq3nj1knms75d9i822kki2pvd070hn31g2yr0dbsrd3kbfdbm";
    excludedPackages = "test";
    propagatedBuildInputs = [
      concurrent
      plz
      reflect2
    ];
  };

  namedotcom_go = buildFromGitHub {
    version = 6;
    rev = "08470befbe04613bd4b44cb6978b05d50294c4d4";
    owner = "namedotcom";
    repo = "go";
    sha256 = "09d3kvfsz09q2yaj0mgy06m691fvyl23x24q6dby5g3kfg2rc065";
    date = "2018-04-03";
    propagatedBuildInputs = [
      errors
    ];
  };

  siddontang_go = buildFromGitHub {
    version = 6;
    date = "2017-05-17";
    rev = "cb568a3e5cc06256f91a2da5a87455f717eb33f4";
    owner = "siddontang";
    repo = "go";
    sha256 = "00sn762x47kjg9znah26bvc7kfh0pkfxgnl0wclcd7gbf37hir8m";
  };

  ugorji_go = buildFromGitHub {
    version = 6;
    rev = "v1.1.1";
    owner = "ugorji";
    repo = "go";
    sha256 = "0ypzblak2idf9wf94pzrxj42py49hq8vd3rl3kslzxp8i2bz89kf";
    goPackageAliases = [
      "github.com/hashicorp/go-msgpack"
    ];
  };

  go-acd = buildFromGitHub {
    version = 6;
    owner = "ncw";
    repo = "go-acd";
    rev = "887eb06ab6a255fbf5744b5812788e884078620a";
    date = "2017-11-20";
    sha256 = "0mfab334ls3m26wwh21rf40vslchi87g1cr41b81x802hj0mgddd";
    propagatedBuildInputs = [
      go-querystring
    ];
  };

  go-addr-util = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-addr-util";
    rev = "3bd34419494fb7f15182ddd19a5d92ac017a27c6";
    date = "2018-04-16";
    sha256 = "0vxn377fqghrpf3fhh7xgd3a3yakx9z9ycvc8zkjqjyp445wirm3";
    propagatedBuildInputs = [
      go-log
      go-ws-transport
      go-multiaddr
      go-multiaddr-net
      mafmt
    ];
  };

  go-ansiterm = buildFromGitHub {
    version = 6;
    owner = "Azure";
    repo = "go-ansiterm";
    rev = "d6e3b3328b783f23731bc4d058875b0371ff8109";
    date = "2017-09-29";
    sha256 = "18p4rr8f082m8q5ds6ba1m6h2r4bylldd6fx1r0v0kzryzilbqcn";
    buildInputs = [
      logrus
    ];
  };

  go-http-auth = buildFromGitHub {
    version = 5;
    owner = "abbot";
    repo = "go-http-auth";
    rev = "v0.4.0";
    sha256 = "0bdn2n332zsylc3rjgb7aya5z8wrn5d1zx3j40wjsiinv1z3zbl4";
    propagatedBuildInputs = [
      crypto
      net
    ];
  };

  go4 = buildFromGitHub {
    version = 6;
    date = "2018-04-17";
    rev = "9599cf28b011184741f249bd9f9330756b506cbc";
    owner = "camlistore";
    repo = "go4";
    sha256 = "0fvk9mvwmxy3sz7gdhb95fafmwmzf9c2lxl7hijycbz0l1gvsrqy";
    goPackagePath = "go4.org";
    goPackageAliases = [
      "github.com/camlistore/go4"
      "github.com/juju/go4"
    ];
    propagatedBuildInputs = [
      goexif
      google-api-go-client
      google-cloud-go
      oauth2
      net
      sys
    ];
  };

  gocapability = buildFromGitHub {
    version = 5;
    rev = "33e07d32887e1e06b7c025f27ce52f62c7990bc0";
    owner = "syndtr";
    repo = "gocapability";
    sha256 = "1igpbfw1k6ixy3x525xgw69q7cxibzbb9baxdxqc1gf5h2j2bbnp";
    date = "2018-02-23";
  };

  gocql = buildFromGitHub {
    version = 6;
    rev = "4ba1af8a026b230ce3c646e594865c07ce01b541";
    owner  = "gocql";
    repo   = "gocql";
    sha256 = "0235r08ggaxklwqhy5wpgrhjxp8i8dj1v8d852xa2j7amvllapqi";
    propagatedBuildInputs = [
      inf_v0
      snappy
      go-hostpool
      net
    ];
    date = "2018-04-22";
  };

  godaemon = buildFromGitHub {
    version = 5;
    rev = "3d9f6e0b234fe7d17448b345b2e14ac05814a758";
    owner  = "VividCortex";
    repo   = "godaemon";
    sha256 = "0vxihy5d64ym7k7zragkbyvjbli4f4mg18kmhl5kl0bwfd7vpw9x";
    date = "2015-09-10";
  };

  godo = buildFromGitHub {
    version = 5;
    rev = "v1.1.3";
    owner  = "digitalocean";
    repo   = "godo";
    sha256 = "1wi2iqwjs89lzqk942xpnp1m3dg8kcpnjhrlnfljr19gyxnkwhvz";
    propagatedBuildInputs = [
      go-querystring
      http-link-go
      net
    ];
  };

  godotenv = buildFromGitHub {
    version = 6;
    rev = "1709ab122c988931ad53508747b3c061400c2984";
    owner  = "joho";
    repo   = "godotenv";
    sha256 = "0gh580jlvnwrkyginbkxkrm5y8kpfrb8xryfz72xpbg3gfyiz2i9";
    date = "2018-04-05";
  };

  goendian = buildFromGitHub {
    version = 6;
    rev = "0f5c6873267e5abf306ffcdfcfa4bf77517ef4a7";
    owner  = "gxed";
    repo   = "GoEndian";
    sha256 = "1h05p9xlfayfjj00yjkggbwhsb3m52l5jdgsffs518p9fsddwbfy";
    date = "2016-09-16";
  };

  goexif = buildFromGitHub {
    version = 6;
    rev = "fb35d3c3290d09f3524b684b5d42d0063c227158";
    owner  = "rwcarlsen";
    repo   = "goexif";
    sha256 = "182xhihig988jnv0alc7crq3hh0fcdm3aizc41dl9civchrz0b6p";
    date = "2018-04-10";
  };

  gofuzz = buildFromGitHub {
    version = 6;
    rev = "24818f796faf91cd76ec7bddd72458fbced7a6c1";
    owner  = "google";
    repo   = "gofuzz";
    sha256 = "1ghcx5q9vsgmknl9954cp4ilgayfkg937c1z4m3lqr41fkma9zgi";
    date = "2017-06-12";
  };

  gohistogram = buildFromGitHub {
    version = 3;
    rev = "v1.0.0";
    owner  = "VividCortex";
    repo   = "gohistogram";
    sha256 = "02bikhfr47gp4ww9mmz9pz6q4g6293z0fn8kd83kn0i12x0s8b2l";
  };

  goid = buildFromGitHub {
    version = 5;
    rev = "b0b1615b78e5ee59739545bb38426383b2cda4c9";
    owner  = "petermattis";
    repo   = "goid";
    sha256 = "17wnw44ff0fsfr2c87g35m3bfm4makr0xyixfcv7r56hadll841y";
    date = "2018-02-02";
  };

  gojsondiff = buildFromGitHub {
    version = 6;
    rev = "e21612694bdd50975f93cd5eaccb457477128e28";
    owner  = "yudai";
    repo   = "gojsondiff";
    sha256 = "0pvjsm959xp2vr4pm92g36hil201693b8hv23gn3zlx7066is9p3";
    date = "2017-11-26";
    propagatedBuildInputs = [
      urfave_cli
      go-diff
      golcs
    ];
    excludedPackages = "test";
  };

  gojsonpointer = buildFromGitHub {
    version = 5;
    rev = "4e3ac2762d5f479393488629ee9370b50873b3a6";
    owner  = "xeipuuv";
    repo   = "gojsonpointer";
    sha256 = "1whgpgxjp9v8wxi8qqimsxbx7l4rpaqcdh19pww7xndalsprapi4";
    date = "2018-01-27";
  };

  gojsonreference = buildFromGitHub {
    version = 5;
    rev = "bd5ef7bd5415a7ac448318e64f11a24cd21e594b";
    owner  = "xeipuuv";
    repo   = "gojsonreference";
    sha256 = "1fszjc86996d0r6xbiy06b05ffhpmay4dzxrq0jw0sf3b6hqfplv";
    date = "2018-01-27";
    propagatedBuildInputs = [ gojsonpointer ];
  };

  gojsonschema = buildFromGitHub {
    version = 6;
    rev = "2c8e4be869c17540b336bab0ea18b8d73e6a28b7";
    owner  = "xeipuuv";
    repo   = "gojsonschema";
    sha256 = "0wdbxrn5fc83cyzay14a5sqir0fyjgjwyaxjp4iiqnzbxj2fhb4c";
    date = "2018-04-07";
    propagatedBuildInputs = [ gojsonreference ];
  };

  gomaasapi = buildFromGitHub {
    version = 5;
    rev = "663f786f595ba1707f56f62f7f4f2284c47c0f1d";
    date = "2017-12-05";
    owner = "juju";
    repo = "gomaasapi";
    sha256 = "0fsck2i8izzv195gaw23ba1b30sr9vs7a49yix1mpxcjx2bfshwk";
    propagatedBuildInputs = [
      juju_errors
      loggo
      mgo_v2
      schema
      utils
      juju_version
    ];
  };

  gomail_v2 = buildFromGitHub {
    version = 6;
    rev = "81ebce5c23dfd25c6c67194b37d3dd3f338c98b1";
    date = "2016-04-11";
    owner = "go-gomail";
    repo = "gomail";
    sha256 = "0akjvnrwqipl67rjg0aab0wiqn904d4rszpscgkjw23i1h2h9v3y";
    goPackagePath = "gopkg.in/gomail.v2";
    propagatedBuildInputs = [
      quotedprintable_v3
    ];
  };

  gomemcache = buildFromGitHub {
    version = 6;
    rev = "1952afaa557dc08e8e0d89eafab110fb501c1a2b";
    date = "2017-02-08";
    owner = "bradfitz";
    repo = "gomemcache";
    sha256 = "1h1sjgjv4ay6y26g25vg2q0iawmw8fnlam7r66qiq0hclzb72fcn";
  };

  gomemcached = buildFromGitHub {
    version = 6;
    rev = "bf40830d1642a108b93fe3ae5bc2ae1a703ec9f9";
    date = "2018-05-01";
    owner = "couchbase";
    repo = "gomemcached";
    sha256 = "00nsv2c4jd6634i0v0mf1l4ddx0c7zdrijyfdprh43dlgd2r93x9";
    excludedPackages = "mocks";
    propagatedBuildInputs = [
      crypto
      errors
      goutils_gomemcached
    ];
  };

  gopacket = buildFromGitHub {
    version = 6;
    rev = "f1dcaa0fbe0cbf307fc9247ecc348f48b0c2f4d3";
    owner = "google";
    repo = "gopacket";
    sha256 = "0by40pwq002vqps032drsfydzkz1n4z7ma8n0i7jlzlrnaaxwrwq";
    buildInputs = [
      pkgs.libpcap
      pkgs.pf-ring
    ];
    propagatedBuildInputs = [
      net
      sys
    ];
    date = "2018-05-02";
  };

  gophercloud = buildFromGitHub {
    version = 6;
    rev = "242a24b4f7bc39e508f1b1c7376874d636705a63";
    owner = "gophercloud";
    repo = "gophercloud";
    sha256 = "192dhvfy7dw8d4w7kxv3gfg2y60m9307rmmfm46nc9racph9m17n";
    date = "2018-05-01";
    excludedPackages = "test";
    propagatedBuildInputs = [
      crypto
      yaml_v2
    ];
  };

  google-cloud-go = buildFromGitHub {
    version = 6;
    date = "2018-05-02";
    rev = "eb0079f598a6640ecbb7a4d2d9dcb0278a320b61";
    owner = "GoogleCloudPlatform";
    repo = "google-cloud-go";
    sha256 = "0xyi3007kbq5ghgxy5nm4m84ynhg2ba7wzlir7l8244iyar7mdiz";
    goPackagePath = "cloud.google.com/go";
    goPackageAliases = [
      "google.golang.org/cloud"
    ];
    propagatedBuildInputs = [
      btree
      debug
      gax-go
      genproto
      geo
      glog
      go-cmp
      google-api-go-client
      grpc
      net
      oauth2
      opencensus
      pprof
      protobuf
      sync
      text
      time
    ];
    postPatch = ''
      sed -i 's,bundler.Close,bundler.Stop,g' logging/logging.go
    '';
    excludedPackages = "\\(oauth2\\|readme\\|mocks\\|test\\)";
    meta.useUnstable = true;
  };

  google-cloud-go-compute-metadata = buildFromGitHub {
    inherit (google-cloud-go) rev date owner repo sha256 version goPackagePath goPackageAliases meta;
    subPackages = [
      "compute/metadata"
    ];
    propagatedBuildInputs = [
      net
    ];
  };

  goprocess = buildFromGitHub {
    version = 6;
    rev = "b497e2f366b8624394fb2e89c10ab607bebdde0b";
    date = "2016-08-26";
    owner = "jbenet";
    repo = "goprocess";
    sha256 = "12dibwgdi53dgfc5cv00f4d51xvgmi4xx1hhyz2djki2pp4vnkrf";
  };

  gops = buildFromGitHub {
    version = 6;
    rev = "62b4d222669dc214b631ef9750d7eeaf197ef7a5";
    owner = "google";
    repo = "gops";
    sha256 = "00m4apfq37iw6m7bg3p4kfy3w7d04kzhi5w7r9m622pf98b252h6";
    propagatedBuildInputs = [
      keybase_go-ps
      gopsutil
      goversion
      osext
      treeprint
    ];
    meta.useUnstable = true;
    date = "2018-04-30";
  };

  goterm = buildFromGitHub {
    version = 5;
    rev = "c9def0117b24a53e86f6c4c942e4042090a4fe8c";
    date = "2018-03-07";
    owner = "buger";
    repo = "goterm";
    sha256 = "1a8s0q4riks8w1gcnczkxf71g7fk4ky3xwhbla7h142pxvz2qz1c";
    propagatedBuildInputs = [
      sys
    ];
  };

  gotty = buildFromGitHub {
    version = 6;
    rev = "cd527374f1e5bff4938207604a14f2e38a9cf512";
    date = "2012-06-04";
    owner = "Nvveen";
    repo = "Gotty";
    sha256 = "16slr2a0mzv2bi90s5pzmb6is6h2dagfr477y7g1s89ag1dcayp8";
  };

  goutils = buildFromGitHub {
    version = 6;
    rev = "f98adca8eb365032cab838ef4d99453931afa112";
    date = "2018-04-25";
    owner = "couchbase";
    repo = "goutils";
    sha256 = "0vm0v1qk0gnr1iljpzvrhgjhkpnvv4ayxa6g0h2nlcs6i1nll41i";
    buildInputs = [
      cbauth
      go-couchbase
      gomemcached
    ];
  };

  goutils_gomemcached = buildFromGitHub {
    inherit (goutils) rev date owner repo sha256 version;
    subPackages = [
      "logging"
      "scramsha"
    ];
    propagatedBuildInputs = [
      crypto
      errors
    ];
  };

  hlandau_goutils = buildFromGitHub {
    version = 5;
    rev = "0cdb66aea5b843822af6fdffc21286b8fe8379c4";
    date = "2016-07-22";
    owner = "hlandau";
    repo = "goutils";
    sha256 = "08nm9nxz21km6ivvvr7pg8758bdzrjp3i6hkkf1v051i1hvci7ws";
  };

  golang-lru = buildFromGitHub {
    version = 5;
    date = "2018-02-01";
    rev = "0fb14efe8c47ae851c0034ed7a448854d3d34cf3";
    owner  = "hashicorp";
    repo   = "golang-lru";
    sha256 = "0v3md1h33bisx1dymp1zmy48kikkrjpz5qg7i37zckdlabq5220m";
  };

  golang-petname = buildFromGitHub {
    version = 6;
    rev = "d3c2ba80e75eeef10c5cf2fc76d2c809637376b3";
    owner  = "dustinkirkland";
    repo   = "golang-petname";
    sha256 = "0shg5xfygvkqds0c38dqfk7ivay41xy4cxs8r3yws9lxp60cx0jb";
    date = "2017-09-21";
  };

  golang-text = buildFromGitHub {
    version = 6;
    rev = "048ed3d792f7104850acbc8cfc01e5a6070f4c04";
    owner  = "tonnerre";
    repo   = "golang-text";
    sha256 = "188nzg7dcr3xl8ipgdiks6h3wxi51391y4jza4jcbvw1z1mi7iig";
    date = "2013-09-25";
    propagatedBuildInputs = [
      pty
      kr_text
    ];
    goPackageAliases = [
      "github.com/kr/text"
    ];
    meta.useUnstable = true;
  };

  golang_protobuf_extensions = buildFromGitHub {
    version = 6;
    rev = "v1.0.0";
    owner  = "matttproud";
    repo   = "golang_protobuf_extensions";
    sha256 = "0h81jrphr7cfln91glawvbc8wqf91p1kc2dg7zp30r5axfqfhnqk";
    propagatedBuildInputs = [
      protobuf
    ];
  };

  golcs = buildFromGitHub {
    version = 6;
    rev = "ecda9a501e8220fae3b4b600c3db4b0ba22cfc68";
    date = "2017-03-16";
    owner = "yudai";
    repo = "golcs";
    sha256 = "183cdzwfi0wif082j6w09zr7446sa2kgg6bc7lrhdnh5nvlj3ly0";
  };

  goleveldb = buildFromGitHub {
    version = 6;
    rev = "ae970a0732be3a1f5311da86118d37b9f4bd2a5a";
    date = "2018-05-02";
    owner = "syndtr";
    repo = "goleveldb";
    sha256 = "045labv2kqzdfxpg42jrjxlvhbwh0ggqlxya9fgxb3y9xa718q2z";
    propagatedBuildInputs = [
      ginkgo
      gomega
      snappy
    ];
  };

  gomega = buildFromGitHub {
    version = 5;
    rev = "v1.3.0";
    owner  = "onsi";
    repo   = "gomega";
    sha256 = "12pb6x5inhi0gldnv9l3zn8ldz6l7anb9amqgqlx06z5pbckcp1l";
    propagatedBuildInputs = [
      net
      protobuf
      yaml_v2
    ];
  };

  google-api-go-client = buildGoPackage rec {
    name = nameFunc {
      inherit
        goPackagePath
        rev;
      date = "2018-05-02";
    };
    rev = "ce90db2c36a2cb8c9c06779ed8bb96f92ea6e3b8";
    goPackagePath = "google.golang.org/api";
    src = fetchzip {
      version = 6;
      stripRoot = false;
      purgeTimestamps = true;
      inherit name;
      url = "https://code.googlesource.com/google-api-go-client/+archive/${rev}.tar.gz";
      sha256 = "188ifxw6n4symqjixf999g5sd9knxzxl8ln80ynpwgagfzn82x05";
    };
    buildInputs = [
      appengine
      genproto
      grpc
      net
      oauth2
      opencensus
      sync
    ];
  };

  goorgeous = buildFromGitHub {
    version = 5;
    rev = "dcf1ef873b8987bf12596fe6951c48347986eb2f";
    owner = "chaseadamsio";
    repo = "goorgeous";
    sha256 = "ed381b2e3a17fc988fa48ec98d244def3ff99c67c73dc54a97973ead031fb432";
    propagatedBuildInputs = [
      blackfriday
      sanitized-anchor-name
    ];
    meta.useUnstable = true;
    date = "2017-11-26";
  };

  gopass = buildFromGitHub {
    version = 6;
    date = "2017-01-09";
    rev = "bf9dde6d0d2c004a008c27aaee91170c786f6db8";
    owner = "howeyc";
    repo = "gopass";
    sha256 = "1f1n1qzdbmpss1njljsp58zcvzp0fjkq8830pgwa4y7zi99y2198";
    propagatedBuildInputs = [
      crypto
      sys
    ];
  };

  gopsutil = buildFromGitHub {
    version = 6;
    rev = "v2.18.04";
    owner  = "shirou";
    repo   = "gopsutil";
    sha256 = "03svszbvzlybyi0sdd2q5lwgmk2isy35yjdsls3f4dpvas0p5hmw";
    propagatedBuildInputs = [
      sys
      w32
      wmi
    ];
  };

  goquery = buildFromGitHub {
    version = 6;
    rev = "v1.4.0";
    owner  = "PuerkitoBio";
    repo   = "goquery";
    sha256 = "04awz9ci1mx3a3fczg1nqjyhzgryiqz4bpy5aysfjblbk3jcl9mx";
    propagatedBuildInputs = [
      cascadia
      net
    ];
  };

  gosaml2 = buildFromGitHub {
    version = 6;
    rev = "v0.1.0";
    owner  = "russellhaering";
    repo   = "gosaml2";
    sha256 = "0hwnk1pzn207y7s3lg9spdlb7jj5r28m3zps8m8p3dqbsbfh9gfv";
    excludedPackages = "test";
    propagatedBuildInputs = [
      etree
      goxmldsig
    ];
  };

  gotask = buildFromGitHub {
    version = 6;
    rev = "104f8017a5972e8175597652dcf5a730d686b6aa";
    owner  = "jingweno";
    repo   = "gotask";
    sha256 = "1r289cd3wjkxa4n3lwicd9f58czrn5q99zvf67yb15d5i18qsmbv";
    date = "2014-01-12";
    propagatedBuildInputs = [
      urfave_cli
      go-shellquote
    ];
  };

  goupnp = buildFromGitHub {
    version = 6;
    rev = "1395d1447324cbea88d249fbfcfd70ea878fdfca";
    owner  = "huin";
    repo   = "goupnp";
    sha256 = "0rd9bplqh7z6m6mgy5qlwhdqgji5ds77zj9vf787z81ynh5hdsk1";
    date = "2018-04-15";
    propagatedBuildInputs = [
      goutil
      gotask
      net
    ];
  };

  goutil = buildFromGitHub {
    version = 6;
    rev = "1ca381bf315033e89af3286fdec0109ce8d86126";
    owner  = "huin";
    repo   = "goutil";
    sha256 = "0f3p0aigiappv130zvy94ia3j8qinz4di7akxsm09f0k1cblb82f";
    date = "2017-08-03";
  };

  govalidator = buildFromGitHub {
    version = 6;
    rev = "7d2e70ef918f16bd6455529af38304d6d025c952";
    owner = "asaskevich";
    repo = "govalidator";
    sha256 = "16isnqzdjmn0nflh8jbfylskq1aajinga4gcrr36gsmj51jm22sy";
    date = "2018-03-19";
  };

  goversion = buildFromGitHub {
    version = 6;
    rev = "v1.2.0";
    owner = "rsc";
    repo = "goversion";
    sha256 = "0qadgddl9vfr13mqf7d8v5i016bdjlalfndr5rdzigqyks12465v";
    goPackagePath = "rsc.io/goversion";
  };

  goxmldsig = buildFromGitHub {
    version = 6;
    rev = "bdff9f2fbc4faccdcc71b95dceb5dc3cad952698";
    owner  = "russellhaering";
    repo   = "goxmldsig";
    sha256 = "1izmwdh45y4k4f2sxl6krrv5a57amgswi8hpyrk7ga0mscq8jy6j";
    date = "2018-04-30";
    propagatedBuildInputs = [
      clockwork
      etree
    ];
  };

  go-autorest = buildFromGitHub {
    version = 6;
    rev = "v10.8.0";
    owner  = "Azure";
    repo   = "go-autorest";
    sha256 = "02shajnffbqalhq6j640glx8rrvb4hfifcrwfp9aiklz3bllq0q8";
    propagatedBuildInputs = [
      crypto
      jwt-go
      utfbom
    ];
    excludedPackages = "\\(cli\\|cmd\\|example\\)";
  };

  go-bindata-assetfs = buildFromGitHub {
    version = 5;
    rev = "38087fe4dafb822e541b3f7955075cc1c30bd294";
    owner   = "elazarl";
    repo    = "go-bindata-assetfs";
    sha256 = "1aw8gk3hybhyxjsmnhhli94hc3r43xrwx71kx344mfp1rygc32cj";
    date = "2018-02-23";
  };

  go-bits = buildFromGitHub {
    version = 6;
    owner = "dgryski";
    repo = "go-bits";
    date = "2018-01-13";
    rev = "bd8a69a71dc203aa976f9d918b428db9ac605f57";
    sha256 = "017bhvl223wcnj8z7as0dhxdf2xk20shkylzdcw9rnxgp0h2lc9v";
  };

  go-bitstream = buildFromGitHub {
    version = 6;
    owner = "dgryski";
    repo = "go-bitstream";
    date = "2018-04-13";
    rev = "3522498ce2c8ea06df73e55df58edfbfb33cfdd6";
    sha256 = "1cd737cln47bbhzz37467vhpprqwvjxmlg1fblqd5skr8115r3qc";
  };

  go-buffruneio = buildFromGitHub {
    version = 5;
    owner = "pelletier";
    repo = "go-buffruneio";
    rev = "e2f66f8164ca709d4c21e815860afd2024e9b894";
    sha256 = "05jmk93x2g6803qz6sbwdm922s04hb6k6bqpbmbls8yxm229wid1";
    date = "2018-01-19";
  };

  go-cache = buildFromGitHub {
    version = 6;
    rev = "v2.1.0";
    owner = "patrickmn";
    repo = "go-cache";
    sha256 = "1wzakl35fmspdklgn7q9r4wyiyyl8vb8w8q0iidv83yx3p4qpwyl";
  };

  go-checkpoint = buildFromGitHub {
    version = 6;
    date = "2017-10-09";
    rev = "1545e56e46dec3bba264e41fde2c1e2aa65b5dd4";
    owner  = "hashicorp";
    repo   = "go-checkpoint";
    sha256 = "19ym24jvrvvnk2hbkh3pm9knkpfarg1g44xqlq9zzn7abjd2fi01";
    propagatedBuildInputs = [
      go-cleanhttp
      hashicorp_go-uuid
    ];
  };

  go-cid = buildFromGitHub {
    version = 5;
    date = "2018-01-20";
    rev = "078355866b1dda1658b5fdc5496ed7e25fdcf883";
    owner = "ipfs";
    repo = "go-cid";
    sha256 = "00wbwvbkqcrzcw1ppjynfq6xyzjkiaj3lwhc1sxhrrmk5przx3f7";
    propagatedBuildInputs = [
      go-multibase
      go-multihash
    ];
  };

  go-cleanhttp = buildFromGitHub {
    version = 6;
    date = "2017-12-18";
    rev = "d5fe4b57a186c716b0e00b8c301cbd9b4182694d";
    owner = "hashicorp";
    repo = "go-cleanhttp";
    sha256 = "0w3k7b7pqzd5w92l9ag8g6snbb53vkxnngk9k48zkjv7ljifgfl1";
  };

  go-clocksmith = buildFromGitHub {
    version = 6;
    rev = "c35da9bed550558a4797c74e34957071214342e7";
    owner  = "jedisct1";
    repo   = "go-clocksmith";
    sha256 = "1ylqkk82mkp8lhg0i1z0rzqkgdn6ws2rzz6222dd416irlfd994w";
    date = "2018-03-07";
  };

  go-cmp = buildFromGitHub {
    version = 5;
    rev = "v0.2.0";
    owner  = "google";
    repo   = "go-cmp";
    sha256 = "0zrjxqmwnigyg2087rsdpzqv4rx3v39lylzhs1x5l812kw1sprhs";
  };

  go-conntrack = buildFromGitHub {
    version = 5;
    rev = "cc309e4a22231782e8893f3c35ced0967807a33e";
    owner = "mwitkow";
    repo = "go-conntrack";
    sha256 = "01rrhajlxn6mjim8h0pzhl00s1k6jvssach0r7y81nrx0i299gsn";
    date = "2016-11-29";
    excludedPackages = "example";
    propagatedBuildInputs = [
      net
      prometheus_client_golang
    ];
  };

  go-collectd = buildFromGitHub {
    version = 6;
    owner = "collectd";
    repo = "go-collectd";
    rev = "606bd390f38f050824c77208d6715ed59e3692ac";
    sha256 = "0y3p574si855x586wxvb47hswhcz6kch4yx7xpr7nkc7mx87b4xw";
    goPackagePath = "collectd.org";
    buildInputs = [
      grpc
      net
      pkgs.collectd
      protobuf
    ];
    preBuild = ''
      # Regerate protos
      srcDir="$(pwd)"/go/src
      pushd go/src/$goPackagePath >/dev/null
      find . -name \*pb.go -delete
      for file in $(find . -name \*.proto | sort | uniq); do
        pushd "$(dirname "$file")" > /dev/null
        echo "Regenerating protobuf: $file" >&2
        protoc -I "$srcDir" -I "$srcDir/$goPackagePath" -I . --go_out=plugins=grpc:. "$(basename "$file")"
        popd >/dev/null
      done
      popd >/dev/null

      # Create a config.h and proper headers
      export COLLECTD_SRC="$(pwd)/collectd-src"
      mkdir -pv "$COLLECTD_SRC"
      pushd "$COLLECTD_SRC" >/dev/null
        unpackFile "${pkgs.collectd.src}"
      popd >/dev/null
      srcdir="$(echo "$COLLECTD_SRC"/collectd-*)"
      # Run configure to generate config.h
      pushd "$srcdir" >/dev/null
        ./configure
      popd >/dev/null
      export CGO_CPPFLAGS="-I$srcdir/src/daemon -I$srcdir/src"
    '';
    date = "2017-10-25";
  };

  go-colorable = buildFromGitHub {
    version = 5;
    rev = "efa589957cd060542a26d2dd7832fd6a6c6c3ade";
    owner  = "mattn";
    repo   = "go-colorable";
    sha256 = "14ra2300d9j1jg90anfxq0pck3x3hj22cb2flmaic2744hamic9x";
    propagatedBuildInputs = [
      go-isatty
    ];
    date = "2018-03-10";
  };

  go-connections = buildFromGitHub {
    version = 5;
    rev = "7395e3f8aa162843a74ed6d48e79627d9792ac55";
    owner  = "docker";
    repo   = "go-connections";
    sha256 = "1556r9w8xh4am4xsl2lf681xqipjfhjhnx2krb40lnqq3dy6m8lc";
    propagatedBuildInputs = [
      errors
      go-winio
      logrus
      net
      runc
    ];
    date = "2018-02-28";
  };

  go-couchbase = buildFromGitHub {
    version = 6;
    rev = "16db1f1fe037412f12738fa4d8448c549c4edd77";
    owner  = "couchbase";
    repo   = "go-couchbase";
    sha256 = "10pdlbss4z4v9ahj9x32b68lb65qgbvcmc19nbcq02r23wzafsyl";
    date = "2018-05-01";
    goPackageAliases = [
      "github.com/couchbaselabs/go-couchbase"
    ];
    propagatedBuildInputs = [
      gomemcached
      goutils_gomemcached
    ];
    excludedPackages = "\\(perf\\|example\\)";
  };

  davidlazar_go-crypto = buildFromGitHub {
    version = 6;
    rev = "dcfb0a7ac018a248366f96bcd8a2f8c805d7b268";
    owner  = "davidlazar";
    repo   = "go-crypto";
    sha256 = "19ldvhzvxqby9ir0q7zhwp2c8irid5z1jkj1wycr9m5b4bc3r7ls";
    date = "2017-07-01";
    propagatedBuildInputs = [
      crypto
    ];
  };

  keybase_go-crypto = buildFromGitHub {
    version = 6;
    rev = "d11a37f123888ff060339f516e392032dfcb98ff";
    owner  = "keybase";
    repo   = "go-crypto";
    sha256 = "1y19s77mrvsbs7bjjfy5c6ild9l8668z44abpl6vkra4h1hmvv48";
    date = "2018-03-29";
    propagatedBuildInputs = [
      ed25519
    ];
  };

  go-daemon = buildFromGitHub {
    version = 5;
    rev = "v0.1.3";
    owner  = "sevlyar";
    repo   = "go-daemon";
    sha256 = "15nvjr1lx3fi8q4110c8b0nii25m9sy5ayp2yvgry9m94dspkyf6";
    propagatedBuildInputs = [
      osext
    ];
  };

  go-deadlock = buildFromGitHub {
    version = 5;
    rev = "v0.2.0";
    owner  = "sasha-s";
    repo   = "go-deadlock";
    sha256 = "1nldi10i6yjl1vh526y4v6y13j6a1245vwg39xnr0zmalima9siq";
    propagatedBuildInputs = [
      goid
    ];
  };

  go-diff = buildFromGitHub {
    version = 5;
    rev = "v1.0.0";
    owner  = "sergi";
    repo   = "go-diff";
    sha256 = "1m8svyblsqc460pcanmmp3gvd7zlj8w9rxmgrw6grj0czjmwgg74";
  };

  go-discover = buildFromGitHub {
    version = 6;
    rev = "c7c0eb3fc6b6f8024c39cb24f3fe254a72595dd4";
    owner  = "hashicorp";
    repo   = "go-discover";
    sha256 = "07k718i726iay78y9k7nlyx1i3ki2szyj184z7wk4lb8g6y4zn3x";
    date = "2018-04-27";
    propagatedBuildInputs = [
      aliyungo
      aws-sdk-go
      #azure-sdk-for-go
      #go-autorest
      godo
      google-api-go-client
      gophercloud
      oauth2
      #scaleway-sdk
      softlayer-go
      triton-go
    ];
    postPatch = ''
      rm -r provider/azure
      sed -i '/azure"/d' discover.go
      rm -r provider/scaleway
      sed -i '/scaleway/d' discover.go
    '';
  };

  go-difflib = buildFromGitHub {
    version = 6;
    rev = "v1.0.0";
    owner  = "pmezard";
    repo   = "go-difflib";
    sha256 = "16pdn2qxymqjk3pm3mx8qminyq7p8fjdi7j53mmpmiq00wafm2xa";
  };

  go-digest = buildFromGitHub {
    version = 6;
    rev = "c9281466c8b2f606084ac71339773efd177436e7";
    owner  = "opencontainers";
    repo   = "go-digest";
    sha256 = "05xbs5hx3jlbqlgk14fisa2y5ymw0jmjyzc8p9g8iab6c59qvsdy";
    date = "2018-04-30";
    goPackageAliases = [
      "github.com/docker/distribution/digest"
    ];
  };

  go-dnsstamps = buildFromGitHub {
    version = 6;
    rev = "1e4999280f861b465e03e21e4f84d838f2f02b38";
    owner  = "jedisct1";
    repo   = "go-dnsstamps";
    sha256 = "02sqqqyrjxr0xk29i0gaakrhrv41plsng85p1rsdszmxvl8q181s";
    date = "2018-04-18";
  };

  go-dockerclient = buildFromGitHub {
    version = 6;
    date = "2018-05-02";
    rev = "51bd33c0c7792b2566054672a4915b406d988cc6";
    owner = "fsouza";
    repo = "go-dockerclient";
    sha256 = "0442f8w16qpqhcfvyjr31klgrzgsizcjjpf6ykwdr8qxmpix7z8f";
    propagatedBuildInputs = [
      go-cleanhttp
      go-units
      go-winio
      moby_lib
      mux
      net
    ];
  };

  go-dot = buildFromGitHub {
    version = 6;
    rev = "b11f31f3f44fedd9966e6fc98af5bb52b71a42ee";
    owner  = "zenground0";
    repo   = "go-dot";
    sha256 = "7bf2d54ec2f621552c9b11a1555b54fb0e4832b8c0a68e7467ca0ede1144de79";
    date = "2018-01-30";
    meta.autoUpdate = false;
  };

  go-envparse = buildFromGitHub {
    version = 5;
    rev = "310ca1881b22af3522e3a8638c0b426629886196";
    owner  = "hashicorp";
    repo   = "go-envparse";
    sha256 = "1g9pp9i3za5rhs19y3k2z0bpbdh5zhx8djlbd6m9sd6sj9yc6w4x";
    date = "2018-01-19";
  };

  go-errors = buildFromGitHub {
    version = 6;
    rev = "v1.0.1";
    owner  = "go-errors";
    repo   = "errors";
    sha256 = "1sv8im4hqjq6llx2scr0fzxv3q013m5gybfvp9kyzrs7kd9bdkcl";
  };

  go-events = buildFromGitHub {
    version = 6;
    owner = "docker";
    repo = "go-events";
    rev = "9461782956ad83b30282bf90e31fa6a70c255ba9";
    date = "2017-07-21";
    sha256 = "1x902my10kmp3d24jcd9pxpbhma95jyqdd1k4ndjmcc6z4ygxxz1";
    propagatedBuildInputs = [
      logrus
    ];
  };

  go-farm = buildFromGitHub {
    version = 5;
    rev = "2de33835d10275975374b37b2dcfd22c9020a1f5";
    owner  = "dgryski";
    repo   = "go-farm";
    sha256 = "09c44b7igw7lxnr0in9z4yiqag54wssd4xr5hllhgys0fw1fcskx";
    date = "2018-01-09";
  };

  go-flags = buildFromGitHub {
    version = 6;
    rev = "v1.4.0";
    owner  = "jessevdk";
    repo   = "go-flags";
    sha256 = "0b4qbq5cjm6cgi4nbpxzgznm3v2c237bz1xznhkwrdhwx5nfgy8w";
  };

  go-flow-metrics = buildFromGitHub {
    version = 5;
    rev = "3b3bcfcf78f2dc0e85be13ef3c3adc64cc5a9347";
    owner  = "libp2p";
    repo   = "go-flow-metrics";
    sha256 = "06lw18smzsg5ci6rbdwm5lixcw73z67gix4lk72fw9ixkp055vwx";
    date = "2017-12-27";
  };

  go-flowrate = buildFromGitHub {
    version = 6;
    rev = "cca7078d478f8520f85629ad7c68962d31ed7682";
    owner  = "mxk";
    repo   = "go-flowrate";
    sha256 = "0xypq6z657pxqj5h2mlq22lvr8g6wvpqza1a1fvlq85i7i5nlkx9";
    date = "2014-04-19";
  };

  go-fs-lock = buildFromGitHub {
    version = 6;
    rev = "ce9819a999925cbe4ec0358abcd4f0a5409c8dfb";
    owner  = "ipfs";
    repo   = "go-fs-lock";
    sha256 = "0gzl1ijh0s4ac7m075cxah99gcbviycdql0rzlfwg50glwqry53w";
    date = "2018-03-29";
    propagatedBuildInputs = [
      go-ipfs-util
      go-log
      go4
    ];
  };

  go-getter = buildFromGitHub {
    version = 6;
    rev = "3f60ec5cfbb2a39731571b9ddae54b303bb0a969";
    date = "2018-04-25";
    owner = "hashicorp";
    repo = "go-getter";
    sha256 = "19ppd1h31bak15vh17nr8qmqqmzsflic6nbasysil4q4hnwvs35s";
    propagatedBuildInputs = [
      aws-sdk-go
      go-cleanhttp
      go-homedir
      go-netrc
      go-safetemp
      go-testing-interface
      go-version
      xz
    ];
  };

  go-git-ignore = buildFromGitHub {
    version = 6;
    rev = "1.0.1";
    owner = "sabhiram";
    repo = "go-git-ignore";
    sha256 = "06f042dpfahzf424lqjj0xidiw4sv1zgbl37jyl0hvw506ajzswd";
  };

  go-github = buildFromGitHub {
    version = 5;
    rev = "v15.0.0";
    owner = "google";
    repo = "go-github";
    sha256 = "1sh1xv3bkmdan9xrkx64p81krpgv5mlxx16bgda8vji05kbjzb2v";
    buildInputs = [
      appengine
      oauth2
    ];
    propagatedBuildInputs = [
      go-querystring
    ];
    excludedPackages = "example";
  };

  go-glob = buildFromGitHub {
    version = 6;
    date = "2017-01-28";
    rev = "256dc444b735e061061cf46c809487313d5b0065";
    owner = "ryanuber";
    repo = "go-glob";
    sha256 = "1alfqb04ajgcrdb2927zlxp7b981dix832hn3wikpih4zzhdzc0a";
  };

  go-grpc-sql = buildFromGitHub {
    version = 6;
    rev = "534b56d0c689ed437e6cff44868964d45d3ec85c";
    owner = "CanonicalLtd";
    repo = "go-grpc-sql";
    sha256 = "027spji0307f37f9qpm5ryqbmr89grzwffgl17zwbf4x71vjfffr";
    date = "2018-03-23";
    propagatedBuildInputs = [
      errors
      CanonicalLtd_go-sqlite3
      grpc
      net
      protobuf
    ];
  };

  go-grpc-prometheus = buildFromGitHub {
    version = 6;
    rev = "39de4380c2e0353a115b80b1c730719c79bfb771";
    owner = "grpc-ecosystem";
    repo = "go-grpc-prometheus";
    sha256 = "0m1pvy0c2g3b197rmvl9f70vns6lp9z74vz69wz9d0hs45vvvzad";
    propagatedBuildInputs = [
      grpc
      net
      prometheus_client_golang
    ];
    date = "2018-04-18";
  };

  go-hclog = buildFromGitHub {
    version = 6;
    date = "2018-04-02";
    rev = "69ff559dc25f3b435631604f573a5fa1efdb6433";
    owner  = "hashicorp";
    repo   = "go-hclog";
    sha256 = "04nm5h3yaym6syj84x2d7rkx723npxdjq67y4ihqn0mali8zibwx";
  };

  go-hdb = buildFromGitHub {
    version = 6;
    rev = "v0.11.3";
    owner  = "SAP";
    repo   = "go-hdb";
    sha256 = "1x1hqijkbdyrbxsi4lix2xwf7k8sdvzngkrw5v577mf43bfqbv5f";
    propagatedBuildInputs = [
      text
    ];
  };

  go-homedir = buildFromGitHub {
    version = 6;
    date = "2016-12-03";
    rev = "b8bc1bf767474819792c23f32d8286a45736f1c6";
    owner  = "mitchellh";
    repo   = "go-homedir";
    sha256 = "18j4j5zpxlpqqbdcl7d7cl69gcj747wq3z2m58lb99376w4a5xm6";
    goPackageAliases = [
      "github.com/minio/go-homedir"
    ];
  };

  go-hostpool = buildFromGitHub {
    version = 6;
    rev = "e80d13ce29ede4452c43dea11e79b9bc8a15b478";
    date = "2016-01-25";
    owner  = "hailocab";
    repo   = "go-hostpool";
    sha256 = "09l9ryijsxcggrp28vx1gi2h5nlds4pxz4zf3lzjbcqg58vh7iax";
  };

  gohtml = buildFromGitHub {
    version = 5;
    owner = "yosssi";
    repo = "gohtml";
    rev = "97fbf36f4aa81f723d0530f5495a820ba267ae5f";
    date = "2018-01-30";
    sha256 = "1l3z4b0l1r7pw7njcn3s5jafrvvf3h3ny7989flrmjhk8d4m4p64";
    propagatedBuildInputs = [
      net
    ];
  };

  go-humanize = buildFromGitHub {
    version = 6;
    rev = "02af3965c54e8cacf948b97fef38925c4120652c";
    owner = "dustin";
    repo = "go-humanize";
    sha256 = "0wbln9jp2clw3xaw8ynbz7q5civp154gh64iaq55zliy1mqxjf8x";
    date = "2018-04-21";
  };

  go-i18n = buildFromGitHub {
    version = 6;
    rev = "v1.10.0";
    owner  = "nicksnyder";
    repo   = "go-i18n";
    sha256 = "1z030dy178ppqdipm672rphi6zimrqhfgbi4c7ljlmlhbcdlsygf";
    buildInputs = [
      go-toml
      yaml_v2
    ];
  };

  go-immutable-radix = buildFromGitHub {
    version = 5;
    date = "2018-01-29";
    rev = "7f3cd4390caab3250a57f30efdb2a65dd7649ecf";
    owner = "hashicorp";
    repo = "go-immutable-radix";
    sha256 = "1gxfip1sxbp6c0mmmhqmydrw360xhhgyvkph8nxrhkq0b3xbfvqs";
    propagatedBuildInputs = [
      golang-lru
    ];
  };

  go-ipfs-api = buildFromGitHub {
    version = 6;
    rev = "d204576299ddab1140d043d0abb0d9b60a8a5af4";
    owner  = "ipfs";
    repo   = "go-ipfs-api";
    sha256 = "036nyx4dgdybvnljdph8yaxsb2x3a26dv5v74416k7m11falp7fx";
    excludedPackages = "tests";
    propagatedBuildInputs = [
      go-homedir
      go-ipfs-cmdkit
      go-libp2p-peer
      go-libp2p-pubsub
      go-multiaddr
      go-multiaddr-net
      tar-utils
    ];
    meta.useUnstable = true;
    date = "2018-03-26";
  };

  go-ipfs-cmdkit = buildFromGitHub {
    version = 6;
    rev = "c2103d7ae7f889e7329673cc3ba55df8b3863b0f";
    owner  = "ipfs";
    repo   = "go-ipfs-cmdkit";
    sha256 = "1b1kn28i30ssjnc7x1361djblv4s9ah9wczmkha2qvny24z9ic03";
    date = "2018-04-18";
    propagatedBuildInputs = [
      sys
    ];
  };

  go-ipfs-util = buildFromGitHub {
    version = 5;
    rev = "9ed527918c2f20abdf0adfab0553cd87db34f656";
    owner  = "ipfs";
    repo   = "go-ipfs-util";
    sha256 = "00d8zv07i92fnmdd07368cmk8in8p6daxnkkzgf1cmm09765zi82";
    date = "2018-01-02";
    propagatedBuildInputs = [
      base58
      go-multihash
    ];
  };

  go-isatty = buildFromGitHub {
    version = 6;
    rev = "v0.0.3";
    owner  = "mattn";
    repo   = "go-isatty";
    sha256 = "1rhbq5yc4zkc4yan9caq8azlns3krn4ixk91xlvyxxxf4gipf427";
    buildInputs = [
      sys
    ];
  };

  go-jmespath = buildFromGitHub {
    version = 5;
    rev = "c2b33e8439af944379acbdd9c3a5fe0bc44bd8a5";
    owner = "jmespath";
    repo = "go-jmespath";
    sha256 = "1v8brdfm1fwvsi880v3hb77vdqqq4wpais3kaz8nbcmnrbyh1gih";
    date = "2018-02-06";
  };

  go-jose_v1 = buildFromGitHub {
    version = 6;
    rev = "v1.1.1";
    owner = "square";
    repo = "go-jose";
    sha256 = "1xcrg6gpq0vvx6j4fmr0697m4702cnqa8aqljxy883501m04p0ij";
    goPackagePath = "gopkg.in/square/go-jose.v1";
    buildInputs = [
      urfave_cli
      kingpin_v2
    ];
  };

  go-jose_v2 = buildFromGitHub {
    version = 6;
    rev = "v2.1.6";
    owner = "square";
    repo = "go-jose";
    sha256 = "1mjjgkqzpd181h5qkag0jqrrmbj0zrb3aizhw7jjzklvdvx2wrq2";
    goPackagePath = "gopkg.in/square/go-jose.v2";
    buildInputs = [
      crypto
      urfave_cli
      kingpin_v2
    ];
  };

  go-keyspace = buildFromGitHub {
    version = 6;
    rev = "5b898ac5add1da7178a4a98e69cb7b9205c085ee";
    owner = "whyrusleeping";
    repo = "go-keyspace";
    sha256 = "10g8bj04l819p9494mhn23d8wcvs2jnrmm38zhm4s7l881rwn12n";
    date = "2016-03-22";
  };

  go-libp2p = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p";
    date = "2018-04-16";
    rev = "3b8f2275a2b24de5777aaa4fc77f1af57c5c4387";
    sha256 = "0xddd6v0czkbh9bglyzdwl4bys06bsh3f5z8rji1hkxgdlvjkwka";
    excludedPackages = "mock";
    propagatedBuildInputs = [
      goprocess
      go-ipfs-util
      go-log
      go-libp2p-circuit
      go-libp2p-crypto
      go-libp2p-host
      go-libp2p-interface-connmgr
      go-libp2p-interface-pnet
      go-libp2p-loggables
      go-libp2p-metrics
      go-libp2p-nat
      go-libp2p-net
      go-libp2p-peer
      go-libp2p-peerstore
      go-libp2p-protocol
      go-libp2p-swarm
      go-libp2p-transport
      go-multiaddr
      go-multiaddr-dns
      go-multiaddr-net
      go-multistream
      go-semver
      go-smux-multiplex
      go-smux-multistream
      go-smux-yamux
      go-stream-muxer
      whyrusleeping_mdns
      gogo_protobuf
    ];
  };

  go-libp2p-circuit = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-circuit";
    date = "2018-04-16";
    rev = "772fa57b88017ff6bce887a8d1486b228cacf488";
    sha256 = "04wzdh29386l146hsvvmpnks6lmj7nr2cfm59vy5vbkrc8gg0xdx";
    propagatedBuildInputs = [
      go-addr-util
      go-log
      go-libp2p-crypto
      go-libp2p-host
      go-libp2p-interface-conn
      go-libp2p-net
      go-libp2p-peer
      go-libp2p-peerstore
      go-libp2p-swarm
      go-libp2p-transport
      go-maddr-filter
      go-multiaddr
      go-multiaddr-net
      go-multihash
      gogo_protobuf
    ];
  };

  go-libp2p-conn = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-conn";
    date = "2018-04-16";
    rev = "5c445d258745408186410e0ad5128224b00e47fe";
    sha256 = "1c9fazv7g6fbbrfir65mqsvgrmfg6njrmwr973ih441nbadxpzp5";
    propagatedBuildInputs = [
      go-log
      go-temp-err-catcher
      goprocess
      go-addr-util
      go-libp2p-crypto
      go-libp2p-interface-conn
      go-libp2p-interface-pnet
      go-libp2p-loggables
      go-libp2p-peer
      go-libp2p-secio
      go-libp2p-transport
      go-maddr-filter
      go-msgio
      go-multiaddr
      go-multiaddr-net
      go-multistream
    ];
  };

  go-libp2p-consensus = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-consensus";
    rev = "v0.0.1";
    sha256 = "0ylz4zwpan2nkhyq9ckdclrxhsf86nmwwp8kcwi334v0491963fh";
  };

  go-libp2p-crypto = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-crypto";
    date = "2018-03-18";
    rev = "18915b5467c77ad8c07a35328c2cab468667a4e8";
    sha256 = "1s5yy9p0kgxlrlcyvkjh5wl04gkpsvjcm9gy7rzk1kvvwvz2paly";
    propagatedBuildInputs = [
      btcd
      ed25519
      gogo_protobuf
      sha256-simd
    ];
  };

  go-libp2p-gorpc = buildFromGitHub {
    version = 6;
    owner = "hsanjuan";
    repo = "go-libp2p-gorpc";
    date = "2018-05-02";
    rev = "88c761414d03e3f430840fda6ab35ebbcdbf1b9c";
    sha256 = "1xj2rdr9mhskkni35v62iaicll8rf5a13z6wp62cx7053salaq0b";
    propagatedBuildInputs = [
      go-log
      go-libp2p-host
      go-libp2p-net
      go-libp2p-peer
      go-libp2p-protocol
      go-multicodec
    ];
  };

  go-libp2p-gostream = buildFromGitHub {
    version = 5;
    owner = "hsanjuan";
    repo = "go-libp2p-gostream";
    date = "2018-03-13";
    rev = "3d5cedd5b41b0126cd6323238ebd657973dbc10f";
    sha256 = "1icfkj8b2hhwkd6mnmf62hfwlsyi1bz93r1z4lkhdfdmahypj900";
    propagatedBuildInputs = [
      go-libp2p-host
      go-libp2p-net
      go-libp2p-peer
      go-libp2p-protocol
    ];
  };

  go-libp2p-host = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-host";
    date = "2018-04-16";
    rev = "acf01b322989cf731f66ce70b1ed7c41fe007798";
    sha256 = "0lfyzc3iazqhhxnjsz13cq6s6acqm7mgkb2nhm0560agfvw160dr";
    propagatedBuildInputs = [
      go-libp2p-interface-connmgr
      go-libp2p-net
      go-libp2p-peer
      go-libp2p-peerstore
      go-libp2p-protocol
      go-multiaddr
      go-multistream
      go-semver
    ];
  };

  go-libp2p-http = buildFromGitHub {
    version = 6;
    owner = "hsanjuan";
    repo = "go-libp2p-http";
    date = "2018-03-14";
    rev = "658d66adf1ca9c79c909042935f0a9d2b576a552";
    sha256 = "0r5a03hai8w3nlxnjfx4a56604y7jcwhi9i7vnsl9xvm81zrf8fr";
    propagatedBuildInputs = [
      go-libp2p-gostream
      go-libp2p-host
      go-libp2p-peer
      go-libp2p-protocol
    ];
  };

  go-libp2p-interface-conn = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-interface-conn";
    date = "2018-04-16";
    rev = "47718f905cc3ccd621b65fc106c521555c4040d3";
    sha256 = "0yh6qxi14a6mbrk46fiwjjj7hpa8ink8a8fnhvy1l0cc3d4m0vxf";
    propagatedBuildInputs = [
      go-ipfs-util
      go-libp2p-crypto
      go-libp2p-peer
      go-libp2p-transport
      go-maddr-filter
      go-multiaddr
    ];
  };

  go-libp2p-interface-connmgr = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-interface-connmgr";
    date = "2018-04-16";
    rev = "d00fbee4d35c7b5fdbd12499f673a236c6303865";
    sha256 = "1v98f5mq1vsl5g0g8qw0dds9p61hxsjyb27b0lyks9dpkn8h7x3y";
    propagatedBuildInputs = [
      go-libp2p-net
      go-libp2p-peer
      go-multiaddr
    ];
  };

  go-libp2p-interface-pnet = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-interface-pnet";
    date = "2018-04-16";
    rev = "c6acc383ec0b7b98112971df590d6702885ca821";
    sha256 = "17y4qlf7661his911pl3z8spjnwjc9q9kndj5vg2kqxsijbm2c4g";
    propagatedBuildInputs = [
      go-libp2p-transport
    ];
  };

  go-libp2p-loggables = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-loggables";
    date = "2018-04-16";
    rev = "3a7ad4dd32462b4d9c07a85021e0f5e1110debb2";
    sha256 = "14p7i4r06l1sd0v9xh69qdv7d2410v6a1rrji5mxmd2m4ch2m2kq";
    propagatedBuildInputs = [
      go-log
      go-libp2p-peer
      go-multiaddr
      satori_go-uuid
    ];
  };

  go-libp2p-metrics = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-metrics";
    date = "2018-04-16";
    rev = "2b4a2757a26649c9a603519647cc9d4478ade5c6";
    sha256 = "1cx8sk52h8j7bbjfl59qvly0xrxjj8gin3izppksh2s7fnv3acw4";
    propagatedBuildInputs = [
      go-flow-metrics
      go-libp2p-net
      go-libp2p-peer
      go-libp2p-protocol
      go-libp2p-transport
    ];
  };

  go-libp2p-nat = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-nat";
    date = "2018-04-16";
    rev = "d090f00e553d1b6582e1ec829608a8a9bbf262e1";
    sha256 = "1xs11lcmksrav6kg5c386vscla4m5644z8czs6szs5lj3jh5sbgr";
    propagatedBuildInputs = [
      goprocess
      go-log
      go-multiaddr
      go-multiaddr-net
      go-nat
      go-notifier
    ];
  };

  go-libp2p-net = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-net";
    date = "2018-04-16";
    rev = "70a8d93f2d8c33b5c1a5f6cc4d2aea21663a264c";
    sha256 = "0ppi4ykj690zyd1f1fd729n7cpxr90pnhhfk83wymwa1pd3j2p4b";
    propagatedBuildInputs = [
      goprocess
      go-libp2p-interface-conn
      go-libp2p-peer
      go-libp2p-peerstore
      go-libp2p-protocol
      go-multiaddr
      go-stream-muxer
    ];
  };

  go-libp2p-peer = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-peer";
    date = "2018-04-16";
    rev = "aa0e03e559bde9d4749ad8e38595e15a6fe808fa";
    sha256 = "0bdmyg71a3dc547h6fvn4cd087qjkms8chb1gjbfzw07qz9jn4mc";
    propagatedBuildInputs = [
      base58
      go-ipfs-util
      go-libp2p-crypto
      go-log
      go-multicodec-packed
      go-multihash
    ];
  };

  go-libp2p-peerstore = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-peerstore";
    date = "2018-04-16";
    rev = "7ac092e7f77f5bda1cb6e4ef95efbe911e97db41";
    sha256 = "1p7fgnmnhzmv9bq1c0rbcv5a4g8xfv7hshprw43csb65wr3mk94r";
    excludedPackages = "test";
    propagatedBuildInputs = [
      go-libp2p-crypto
      go-libp2p-peer
      go-log
      go-keyspace
      go-multiaddr
      go-multiaddr-net
      mafmt
    ];
  };

  go-libp2p-pnet = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-pnet";
    date = "2018-04-20";
    rev = "828d69b74b91ce5b709fcccd9a0ef60a45d6b425";
    sha256 = "01ha371xwz9biarxna7drg9zvxk1ad8png3fn6wvy7i68dj5mv9j";
    propagatedBuildInputs = [
      crypto
      davidlazar_go-crypto
      go-libp2p-interface-pnet
      go-libp2p-transport
      go-msgio
      go-multicodec
    ];
  };

  go-libp2p-protocol = buildFromGitHub {
    version = 5;
    owner = "libp2p";
    repo = "go-libp2p-protocol";
    date = "2017-12-12";
    rev = "b29f3d97e3a2fb8b29c5d04290e6cb5c5018004b";
    sha256 = "0igw13rdynkvwvb0p38vvljdbyjz316chbhdrargwhmbbf88pvnh";
  };

  go-libp2p-pubsub = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-pubsub";
    date = "2017-11-18";
    rev = "a031ab4d1b8142714eec946acb7033abafade3d7";
    sha256 = "1rm3z52kwah4x9jwnnf3hlh487parnf9bxlvaskbyv60wry42yw1";
    propagatedBuildInputs = [
      gogo_protobuf
    ];
  };

  go-libp2p-raft = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-raft";
    date = "2018-03-28";
    rev = "203844b488fc32b550069d9a7eebaac060a19961";
    sha256 = "08x5zn7z1lcxaf8r8zavlkbf3079w9hh5f6nkszkw5jcy1p2gamj";
    propagatedBuildInputs = [
      go-libp2p-consensus
      go-libp2p-gostream
      go-libp2p-host
      go-libp2p-peer
      go-libp2p-protocol
      go-log
      go-multicodec
      raft
    ];
  };

  go-libp2p-secio = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-secio";
    date = "2018-04-16";
    rev = "146b7055645501f741c5644d4a3d207614f08899";
    sha256 = "1ag49q16a16xs5q7n0vyqc6djf63sp5qqc15kzmwa0xyamj7p8jc";
    propagatedBuildInputs = [
      crypto
      gogo_protobuf
      go-log
      go-libp2p-crypto
      go-libp2p-peer
      go-msgio
      go-multihash
      sha256-simd
    ];
  };

  go-libp2p-swarm = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-swarm";
    date = "2018-04-16";
    rev = "48d6d0ff2d2a4724f6b47f1ed5ffc0ae63e30460";
    sha256 = "1lcxqcw6yq3qnpsd5yy5p932wfrhbhq6akf5lq9cmc9xzzmg434c";
    propagatedBuildInputs = [
      go-log
      goprocess
      go-addr-util
      go-libp2p-conn
      go-libp2p-crypto
      go-libp2p-interface-conn
      go-libp2p-interface-pnet
      go-libp2p-loggables
      go-libp2p-metrics
      go-libp2p-net
      go-libp2p-peer
      go-libp2p-peerstore
      go-libp2p-protocol
      go-libp2p-transport
      go-maddr-filter
      go-peerstream
      go-stream-muxer
      go-tcp-transport
      go-ws-transport
      go-multiaddr
      go-smux-multistream
      go-smux-spdystream
      go-smux-yamux
      multiaddr-filter
    ];
  };

  go-libp2p-transport = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-libp2p-transport";
    date = "2018-04-16";
    rev = "49533464477a869fee537c8cc3fcee286aa8bdcd";
    sha256 = "12g9rqxk95bqin79p6j4qwyscilvng11v3rd6bccly8mbvv97v1y";
    propagatedBuildInputs = [
      go-log
      go-multiaddr
      go-multiaddr-net
      mafmt
    ];
  };

  go-log = buildFromGitHub {
    version = 6;
    owner = "ipfs";
    repo = "go-log";
    date = "2018-04-30";
    rev = "0ef81702b797a2ecef05f45dcc82b15298f54355";
    sha256 = "1ly0mff3p0fg8zn2k52a3ddqxr4q814ckjr4510cjcallxxny226";
    propagatedBuildInputs = [
      go-colorable
      whyrusleeping_go-logging
      opentracing-go
      gogo_protobuf
    ];
  };

  whyrusleeping_go-logging = buildFromGitHub {
    version = 6;
    owner = "whyrusleeping";
    repo = "go-logging";
    date = "2017-05-15";
    rev = "0457bb6b88fc1973573aaf6b5145d8d3ae972390";
    sha256 = "1nvij6lrhm2smckxkdjm0y50xivc83bq2ymyd1xis0f2qr14x2r6";
  };

  go-logging = buildFromGitHub {
    version = 6;
    owner = "op";
    repo = "go-logging";
    date = "2016-03-15";
    rev = "970db520ece77730c7e4724c61121037378659d9";
    sha256 = "060h5p3qx1ik36p787p2cbzcj2cpl3hn4qj8jaslx6rwg2c161ik";
  };

  go-lxc_v2 = buildFromGitHub {
    version = 5;
    rev = "2660c429a942a4a21455765c7046dde612c1baa7";
    owner  = "lxc";
    repo   = "go-lxc";
    sha256 = "1yhhj2yg6y90qbjgx7kvwig6j2kxvh4fddgyizrkw6rhcwrvmgqb";
    goPackagePath = "gopkg.in/lxc/go-lxc.v2";
    buildInputs = [
      pkgs.lxc
    ];
    date = "2018-02-27";
  };

  go-lz4 = buildFromGitHub {
    version = 6;
    rev = "7224d8d8f27ef618c0a95f1ae69dbb0488abc33a";
    owner  = "bkaradzic";
    repo   = "go-lz4";
    sha256 = "1x5l4najgmmpm5hi00r5a1qzrmbzxm9iabjjnxmbxpnb05jbbsv2";
    date = "2016-09-24";
  };

  go-maddr-filter = buildFromGitHub {
    version = 5;
    owner = "libp2p";
    repo = "go-maddr-filter";
    date = "2018-01-20";
    rev = "3c9947befbb92277cc5f85057d387097debc4139";
    sha256 = "13kmkyr2b7gq79d0dgcx4jmrlib5c8wafzk21blfdqqikhwnj79r";
    propagatedBuildInputs = [
      go-multiaddr
      go-multiaddr-net
    ];
  };

  go-md2man = buildFromGitHub {
    version = 5;
    owner = "cpuguy83";
    repo = "go-md2man";
    rev = "20f5889cbdc3c73dbd2862796665e7c465ade7d1";
    sha256 = "35496b5131a0ff05762877236dedfa91145e36af71b1cac46904e9b1b615c2ff";
    propagatedBuildInputs = [
      blackfriday
    ];
    meta.autoUpdate = false;
    date = "2018-01-19";
  };

  go-mega = buildFromGitHub {
    version = 6;
    date = "2018-04-26";
    rev = "3ba49835f4db01d6329782cbdc7a0a8bb3a26c5f";
    owner = "t3rm1n4l";
    repo = "go-mega";
    sha256 = "17kv0b0cksw9vqg1y3arq5rxr5ilfy1gfwz8gbryarh57i79n0y8";
  };

  go-memdb = buildFromGitHub {
    version = 5;
    date = "2018-02-23";
    rev = "1289e7fffe71d8fd4d4d491ba9a412c50f244c44";
    owner = "hashicorp";
    repo = "go-memdb";
    sha256 = "0pp9slppy3xrnjnz0mpnyskx0czrr523mk89436dn04gk0wmhr8y";
    propagatedBuildInputs = [
      go-immutable-radix
    ];
  };

  armon_go-metrics = buildFromGitHub {
    version = 5;
    date = "2018-02-21";
    rev = "783273d703149aaeb9897cf58613d5af48861c25";
    owner = "armon";
    repo = "go-metrics";
    sha256 = "00kdq4ya43i1x8kyfjfsrq37vnm3dspvb76mad3xi33khwpczwqh";
    propagatedBuildInputs = [
      circonus-gometrics
      datadog-go
      go-immutable-radix
      prometheus_client_golang
    ];
  };

  docker_go-metrics = buildFromGitHub {
    version = 5;
    date = "2018-02-09";
    rev = "399ea8c73916000c64c2c76e8da00ca82f8387ab";
    owner = "docker";
    repo = "go-metrics";
    sha256 = "1nssja0pjqr41ggpiwc9f4ha9w9f9ajrq7jqbk6jsnfzzl4snl6y";
    propagatedBuildInputs = [
      prometheus_client_golang
    ];
    postPatch = ''
      grep -q 'lt.m.WithLabelValues(labels...)}' timer.go
      sed -i '/WithLabelValues/s,)},).(prometheus.Histogram)},' timer.go
    '';
  };

  rcrowley_go-metrics = buildFromGitHub {
    version = 6;
    rev = "d932a24a8ccb8fcadc993e5c6c58f93dac168294";
    date = "2018-04-06";
    owner = "rcrowley";
    repo = "go-metrics";
    sha256 = "0pj3081lb3bk6g7yss45p2kxy3r14vqb365rivaznhq4aj6ps2v7";
    propagatedBuildInputs = [
      stathat
    ];
  };

  go-metro = buildFromGitHub {
    version = 6;
    date = "2015-06-07";
    rev = "d5cb643948fbb1a699e6da1426f0dba75fe3bb8e";
    owner = "dgryski";
    repo = "go-metro";
    sha256 = "5d271cba19ad6aa9b0aaca7e7de6d5473eb4a9e4b682bbb1b7a4b37cca9bb706";
    meta.autoUpdate = false;
  };

  go-minisign = buildFromGitHub {
    version = 5;
    date = "2018-01-13";
    rev = "f404c079ea5f0d4669fe617c553651f75167494e";
    owner = "jedisct1";
    repo = "go-minisign";
    sha256 = "0qal80nfb8hrwvf7mk1ybrg21fmpv7w457pk7v3a1dvmm4fgwpjp";
    propagatedBuildInputs = [
      crypto
    ];
  };

  go-msgio = buildFromGitHub {
    version = 5;
    rev = "d82125c9907e1365775356505f14277d47dfd4d6";
    owner = "libp2p";
    repo = "go-msgio";
    sha256 = "1ivm7hx807ifj5xq4dzp0dx19jn0qyk1alw6dm17al6qajqscy8b";
    date = "2017-12-11";
  };

  go-mssqldb = buildFromGitHub {
    version = 6;
    rev = "e32faac87a2220f9342289f2c3b567d1424b8ec5";
    owner = "denisenkom";
    repo = "go-mssqldb";
    sha256 = "02dhrrj7lq5dxf2paqzjylnfmbfdg5hwbrniixf3s2i3zinzzzp8";
    date = "2018-04-16";
    buildInputs = [
      crypto
      net
    ];
  };

  go-multiaddr = buildFromGitHub {
    version = 5;
    rev = "123a717755e0559ec8fda308019cd24e0a37bb07";
    date = "2018-01-20";
    owner  = "multiformats";
    repo   = "go-multiaddr";
    sha256 = "0fy4ys8qvzsyg2z7ljm25d0wgjnxzfp502b2qmmmlxvn17l25brn";
    goPackageAliases = [ "github.com/jbenet/go-multiaddr" ];
    propagatedBuildInputs = [
      go-multihash
    ];
  };

  go-multiaddr-dns = buildFromGitHub {
    version = 6;
    rev = "c3d4fcd3cbaf54a24b0b68f1461986ede1d59859";
    date = "2018-03-27";
    owner  = "multiformats";
    repo   = "go-multiaddr-dns";
    sha256 = "0gl4q9cvbnq3s53k1668gj796s1if55xmrl31v3rblx2wa547rr2";
    propagatedBuildInputs = [
      go-multiaddr
    ];
  };

  go-multiaddr-net = buildFromGitHub {
    version = 5;
    rev = "97d80565f68c5df715e6ba59c2f6a03d1fc33aaf";
    owner  = "multiformats";
    repo   = "go-multiaddr-net";
    sha256 = "1481gjng97kvbmhk6ia4zns9nyijal5ip40l35jni53sg9d7ra0a";
    date = "2018-03-08";
    goPackageAliases = [ "github.com/jbenet/go-multiaddr-net" ];
    propagatedBuildInputs = [
      go-multiaddr
    ];
  };

  go-multibase = buildFromGitHub {
    version = 5;
    rev = "dfd5076869faca5aed2886dcba60b44a0d0e9c01";
    date = "2017-12-18";
    owner  = "multiformats";
    repo   = "go-multibase";
    sha256 = "1aahbmz3k54i0lsnhjzk9n3x5xq28xz78azd4b0pqzg6fyx9cdbz";
    propagatedBuildInputs = [
      base58
      base32
    ];
  };

  go-multicodec = buildFromGitHub {
    version = 6;
    rev = "4dd9766b3ba78ea1a9807f0cd199d6c383a7ae5f";
    date = "2018-04-20";
    owner  = "multiformats";
    repo   = "go-multicodec";
    sha256 = "0ap6l7yv1cfsgzzzkscq3czbr85drp5xm3c7p6fh43r17k1v7cv0";
    propagatedBuildInputs = [
      cbor
      ugorji_go
      go-msgio
      gogo_protobuf
    ];
  };

  go-multicodec-packed = buildFromGitHub {
    version = 5;
    owner = "multiformats";
    repo = "go-multicodec-packed";
    date = "2018-02-01";
    rev = "9004b413b478e5a878e4a879358cce02e5df4995";
    sha256 = "1a4wmqcmmn1ih7yxnxzirwwxr91czp9rvvf90zl6qsfc97zxlmik";
  };

  go-multierror = buildFromGitHub {
    version = 6;
    date = "2017-12-04";
    rev = "b7773ae218740a7be65057fc60b366a49b538a44";
    owner  = "hashicorp";
    repo   = "go-multierror";
    sha256 = "0c8hps8bq1nlb0xp95mawisn80kdgph18zyn24fpffk1w3d3phrn";
    propagatedBuildInputs = [
      errwrap
    ];
  };

  go-multihash = buildFromGitHub {
    version = 5;
    rev = "265e72146e710ff649c6982e3699d01d4e9a18bb";
    owner  = "multiformats";
    repo   = "go-multihash";
    sha256 = "05a3hk2cv9ny2rkd5sdncqkvrg086dkql4jdldawmvmffy5vrbpi";
    goPackageAliases = [
      "github.com/jbenet/go-multihash"
    ];
    propagatedBuildInputs = [
      base58
      blake2b-simd
      crypto
      hashland
      murmur3
      sha256-simd
    ];
    meta.useUnstable = true;
    date = "2018-03-09";
  };

  go-multiplex = buildFromGitHub {
    version = 6;
    rev = "8b25da2b10bfcccbe3bf8aec22019cb50c8e2b97";
    date = "2018-04-16";
    owner  = "whyrusleeping";
    repo   = "go-multiplex";
    sha256 = "0wl5p4wx64bri8xl3dwclrcsc2lz19zzgnn0xck5z7zm83bzxv02";
    propagatedBuildInputs = [
      go-log
      go-msgio
    ];
  };

  go-multistream = buildFromGitHub {
    version = 5;
    rev = "612ce31c03aebe1d5adbd3c850ee89e05a82b16d";
    date = "2018-03-08";
    owner  = "multiformats";
    repo   = "go-multistream";
    sha256 = "0mw762cnb0zf7na2h5hz78dkyfi4qks74gjf8kg0cc7j9q7zyw7z";
  };

  go-nat = buildFromGitHub {
    version = 6;
    rev = "dcaf50131e4810440bed2cbb6f7f32c4f4cc95dd";
    owner  = "fd";
    repo   = "go-nat";
    sha256 = "1zv8h4s7rqvkd78q4j2fvg2zr94x5gf964q8hq9vh7cj0zrjb150";
    date = "2015-05-08";
    propagatedBuildInputs = [
      gateway
      goupnp
      jackpal_go-nat-pmp
    ];
  };

  AudriusButkevicius_go-nat-pmp = buildFromGitHub {
    version = 6;
    rev = "452c97607362b2ab5a7839b8d1704f0396b640ca";
    owner  = "AudriusButkevicius";
    repo   = "go-nat-pmp";
    sha256 = "1za02f0pf9bl9x6skcdgd1r98ajrqdyvikayx4wjmhldfalnk0d5";
    date = "2016-05-22";
  };

  jackpal_go-nat-pmp = buildFromGitHub {
    version = 6;
    rev = "28a68d0c24adce1da43f8df6a57340909ecd7fdd";
    owner  = "jackpal";
    repo   = "go-nat-pmp";
    sha256 = "0yznawhlp4bz11j2y4b56dqrfm26371jxck9rksy596pjr94f5m6";
    date = "2017-04-05";
  };

  go-nats = buildFromGitHub {
    version = 6;
    rev = "v1.5.0";
    owner = "nats-io";
    repo = "go-nats";
    sha256 = "06h61nw1nd3i2h9g9j8wrwwg84mm2bd625j3qmsfl18xshzsx3mb";
    excludedPackages = "test";
    propagatedBuildInputs = [
      nuid
      protobuf
    ];
    goPackageAliases = [
      "github.com/nats-io/nats"
    ];
  };

  go-nats-streaming = buildFromGitHub {
    version = 6;
    rev = "1662e177fdb0b7964a25e8e7e3570dd49b763c9a";
    owner = "nats-io";
    repo = "go-nats-streaming";
    sha256 = "19vdcvb7pwk90vfqh9hmlaki159rlij1vdlklp6x6gg7jvblyy63";
    propagatedBuildInputs = [
      go-nats
      nuid
      gogo_protobuf
    ];
    date = "2018-03-19";
  };

  go-netrc = buildFromGitHub {
    version = 6;
    owner = "bgentry";
    repo = "go-netrc";
    date = "2014-04-22";
    rev = "9fd32a8b3d3d3f9d43c341bfe098430e07609480";
    sha256 = "16qzlynvx0v6fjlpnc9mfbkvk1ch1r42p1ykaapgrli17mmb5cl3";
  };

  go-notifier = buildFromGitHub {
    version = 6;
    owner = "whyrusleeping";
    repo = "go-notifier";
    date = "2017-08-27";
    rev = "097c5d47330ff6a823f67e3515faa13566a62c6f";
    sha256 = "0syzw67lyy1prvcrlyfac6kxib6271lkrg8b389ll05jp47dp5w3";
    propagatedBuildInputs = [
      goprocess
    ];
  };

  go-observer = buildFromGitHub {
    version = 6;
    date = "2017-06-22";
    rev = "a52f2342449246d5bcc273e65cbdcfa5f7d6c63c";
    owner  = "opentracing-contrib";
    repo   = "go-observer";
    sha256 = "17mxbj220pispjk2601phnkkj64qxc6kq12kq4f1h41hdrl2jacv";
    propagatedBuildInputs = [
      opentracing-go
    ];
  };

  go-oidc = buildFromGitHub {
    version = 6;
    date = "2017-10-26";
    rev = "a93f71fdfe73d2c0f5413c0565eea0af6523a6df";
    owner  = "coreos";
    repo   = "go-oidc";
    sha256 = "5053ff90109c64fbf49eae61164e36caafb3dd0e34ae68639c95e906cb55d317";
    propagatedBuildInputs = [
      cachecontrol
      clockwork
      go-jose_v2
      oauth2
      pkg
    ];
    meta.autoUpdate = false;
    excludedPackages = "example";
  };

  go-ole = buildFromGitHub {
    version = 5;
    rev = "v1.2.1";
    owner  = "go-ole";
    repo   = "go-ole";
    sha256 = "1v7v4kacvsq1hfznkmab5hfzg6s9zn24ns3nz4dg9p75wn76s7kz";
    excludedPackages = "example";
  };

  go-os-rename = buildFromGitHub {
    version = 6;
    rev = "3ac97f61ef67a6b87b95c1282f6c317ed0e693c2";
    owner  = "jbenet";
    repo   = "go-os-rename";
    sha256 = "0s8yk3yyx6y49y31nj3cmb28xrmszrjsakg2ww6gldskzxnqca00";
    date = "2015-04-28";
  };

  go-ovh = buildFromGitHub {
    version = 6;
    rev = "34b9ffdf98692f9e9b57724d180549f88725b605";
    owner = "ovh";
    repo = "go-ovh";
    sha256 = "0pjnlqhdbq0yqvm36d38mahm380wbkkgvm6qsrl1q35mdd9alsw6";
    date = "2018-04-04";
    propagatedBuildInputs = [
      ini_v1
    ];
  };

  go-peerstream = buildFromGitHub {
    version = 6;
    rev = "2679b7430e519fc39f9cfbb0c7b7d016705b4ce1";
    date = "2018-04-16";
    owner  = "libp2p";
    repo   = "go-peerstream";
    sha256 = "0xh7j9cdh2qd2qqxdld3mddcvvmjngg1msacqhn9y3042ipnv9kh";
    excludedPackages = "\\(example\\|test\\)";
    propagatedBuildInputs = [
      go-temp-err-catcher
      go-libp2p-protocol
      go-libp2p-transport
      go-stream-muxer
    ];
  };

  go-plugin = buildFromGitHub {
    version = 6;
    rev = "e8d22c780116115ae5624720c9af0c97afe4f551";
    date = "2018-03-31";
    owner  = "hashicorp";
    repo   = "go-plugin";
    sha256 = "0y9vr3r6wgvjchhjvzvgzwfsjpwl82x8m61j0k3jf1dvfsn7hicz";
    propagatedBuildInputs = [
      go-hclog
      go-testing-interface
      grpc
      net
      protobuf
      run
      hashicorp_yamux
    ];
  };

  go-prompt = buildFromGitHub {
    version = 5;
    rev = "f0d19b6901ade831d5a3204edc0d6a7d6457fbb2";
    date = "2016-10-17";
    owner  = "segmentio";
    repo   = "go-prompt";
    sha256 = "08lf80hw2wlmahxbrbmpq1gs8ss9ixwc54zim33zw0hg98r4dsp4";
    propagatedBuildInputs = [
      gopass
    ];
  };

  go-proxyproto = buildFromGitHub {
    version = 5;
    date = "2018-02-02";
    rev = "5b7edb60ff5f69b60d1950397f7bde6171f1807d";
    owner  = "armon";
    repo   = "go-proxyproto";
    sha256 = "0b47i56ph4k7z02c8xw0wkcpvfs631zksgl78hli16vpmswh3qal";
  };

  go-ps = buildFromGitHub {
    version = 6;
    rev = "4fdf99ab29366514c69ccccddab5dc58b8d84062";
    date = "2017-03-09";
    owner  = "mitchellh";
    repo   = "go-ps";
    sha256 = "1x70gc6y9licdi6qww1lkwx1wkwwkqylzhkfl0wpnizl8m7vpdmp";
  };

  keybase_go-ps = buildFromGitHub {
    version = 6;
    rev = "668c8856d9992f97248b3177d45743d2cc1068db";
    date = "2016-10-05";
    owner  = "keybase";
    repo   = "go-ps";
    sha256 = "0phx2zlxwmzsv2s1h891gps1hyy2wwl7w7wi7s2hgys076xcgiqf";
  };

  go-python = buildFromGitHub {
    version = 6;
    owner = "sbinet";
    repo = "go-python";
    date = "2018-03-27";
    rev = "f976f61134dc6f5b4920941eb1b0e7cec7e4ef4c";
    sha256 = "1x61ra7kmi7gp9z6n6x9flavhnwbqzpav5wk9ai98ray9q2xy49w";
    propagatedBuildInputs = [
      pkgs.python2Packages.python
    ];
  };

  go-querystring = buildFromGitHub {
    version = 6;
    date = "2017-01-11";
    rev = "53e6ce116135b80d037921a7fdd5138cf32d7a8a";
    owner  = "google";
    repo   = "go-querystring";
    sha256 = "1ibpx1hpqjkvcmn4gsz54k9p62sl1iac2kgb97spcl630nn4p0yj";
  };

  go-radix = buildFromGitHub {
    version = 6;
    rev = "1fca145dffbcaa8fe914309b1ec0cfc67500fe61";
    owner  = "armon";
    repo   = "go-radix";
    sha256 = "1lwh7qfsn0nk20jprdfa79ibnz9vw8yljhcvw7c2sqhss4lwyvkz";
    date = "2017-07-27";
  };

  go-resiliency = buildFromGitHub {
    version = 6;
    rev = "v1.1.0";
    owner  = "eapache";
    repo   = "go-resiliency";
    sha256 = "1m8vz7mgmkjfjr925dgmz30bxm7fl7rskan8j6bgy8dbsjwdskc8";
  };

  go-restful = buildFromGitHub {
    version = 6;
    rev = "v2.7.0";
    owner = "emicklei";
    repo = "go-restful";
    sha256 = "1ryswrajq68z5incvyh3mlcyjyv08sj9sr3x6birh91mx1y3hzfd";
  };

  go-retryablehttp = buildFromGitHub {
    version = 6;
    rev = "794af36148bf63c118d6db80eb902a136b907e71";
    owner = "hashicorp";
    repo = "go-retryablehttp";
    sha256 = "1s4901pwfnis7qarhkyq64nh4zza5l383p3h3pqz0cy9xhyk0h0c";
    date = "2017-08-24";
    propagatedBuildInputs = [
      go-cleanhttp
    ];
  };

  go-reuseport = buildFromGitHub {
    version = 6;
    rev = "15a1cd37f0502f3b2eccb6d71a7958edda314633";
    owner = "libp2p";
    repo = "go-reuseport";
    sha256 = "1pjlpyxzmxg1h7xdzad7vsxw3045n7xq9zvdwilqs9krzhdnrkpw";
    date = "2018-04-16";
    excludedPackages = "test";
    propagatedBuildInputs = [
      eventfd
      go-log
      libp2p_go-sockaddr
      sys
    ];
  };

  go-rootcerts = buildFromGitHub {
    version = 6;
    rev = "6bb64b370b90e7ef1fa532be9e591a81c3493e00";
    owner = "hashicorp";
    repo = "go-rootcerts";
    sha256 = "1q6fkwji12hcnp90wsz506fkc9nxjvpzjz4fs6v6z52iba1zymbm";
    date = "2016-05-03";
    buildInputs = [
      go-homedir
    ];
  };

  go-runewidth = buildFromGitHub {
    version = 6;
    rev = "ce7b0b5c7b45a81508558cd1dba6bb1e4ddb51bb";
    owner = "mattn";
    repo = "go-runewidth";
    sha256 = "10bchclblrbva05cyr29l16im4j3v9n33wipq1vjf1z4b6p7v1qr";
    date = "2018-04-08";
  };

  go-safetemp = buildFromGitHub {
    version = 6;
    rev = "b1a1dbde6fdc11e3ae79efd9039009e22d4ae240";
    owner  = "hashicorp";
    repo   = "go-safetemp";
    sha256 = "16aqn987gflps6w00rin36fdny1p6vwc15qx516kjskmp2j6vah5";
    date = "2018-03-26";
  };

  go-semver = buildFromGitHub {
    version = 5;
    rev = "e214231b295a8ea9479f11b70b35d5acf3556d9b";
    owner  = "coreos";
    repo   = "go-semver";
    sha256 = "1fhs8mc9xa5prm7cy05lppag4ll6hdf45bn7469ng9xzyg6jdsw4";
    date = "2018-01-08";
  };

  go-shared = buildFromGitHub {
    version = 6;
    rev = "807ee759d82c84982a89fb3dc875ef884942f1e5";
    owner  = "pengsrc";
    repo   = "go-shared";
    sha256 = "0ay6ak588xsgwpcr8hiz05gi9ysjdgdqj8g6x9cqs5x5n1vl4kg6";
    propagatedBuildInputs = [
      gabs
    ];
    meta.useUnstable = true;
    date = "2018-04-25";
  };

  go-shellquote = buildFromGitHub {
    version = 6;
    rev = "95032a82bc518f77982ea72343cc1ade730072f0";
    owner  = "kballard";
    repo   = "go-shellquote";
    sha256 = "1sp0wyb56q03pnd2bdqsa267kx1rvfc51dvjnnghi4h6hrvr7vg6";
    date = "2018-04-28";
  };

  go-shellwords = buildFromGitHub {
    version = 5;
    rev = "39dbbfa24bbc39559b61cae9b20b0e8db0e55525";
    owner  = "mattn";
    repo   = "go-shellwords";
    sha256 = "0hgjrrgh2nszq7j4f8l71l7gs6ifz50ak1130abm6dzf3rn2mmch";
    date = "2018-02-01";
  };

  go-shuffle = buildFromGitHub {
    version = 5;
    owner = "shogo82148";
    repo = "go-shuffle";
    date = "2018-02-18";
    rev = "27e6095f230d6c769aafa7232db643a628bd87ad";
    sha256 = "1s0hfhw7w18kdndl053i0rs72dmmwprjd1qhwfcpbz0lszavi125";
  };

  go-smux-multiplex = buildFromGitHub {
    version = 6;
    rev = "5abcc6929ae3a6164818c9d85df242df1cbfcb61";
    owner  = "whyrusleeping";
    repo   = "go-smux-multiplex";
    sha256 = "0nlcxz1racz20pg7qasy78iqficg4hx12a28mhwh29zqyg1403ka";
    date = "2018-04-16";
    propagatedBuildInputs = [
      go-stream-muxer
      go-multiplex
    ];
  };

  go-smux-multistream = buildFromGitHub {
    version = 6;
    rev = "afa6825376c14a0462fd420a7d4b4d157c937a42";
    owner  = "whyrusleeping";
    repo   = "go-smux-multistream";
    sha256 = "1fdib9l4rhidbasqszndq2s8w3pzy62jdpjcl4wi8zaz5xs9r7gz";
    date = "2017-09-12";
    propagatedBuildInputs = [
      go-stream-muxer
      go-multistream
    ];
  };

  go-smux-spdystream = buildFromGitHub {
    version = 6;
    rev = "a6182ff2a058b177f3dc7513fe198e6002f7be78";
    owner  = "whyrusleeping";
    repo   = "go-smux-spdystream";
    sha256 = "1kifzd34j5pcigl47ly5m0jzgl5z0kjk7sa5jfcd4jpx2h3anf2c";
    date = "2017-09-12";
    propagatedBuildInputs = [
      go-stream-muxer
      spdystream
    ];
  };

  go-smux-yamux = buildFromGitHub {
    version = 6;
    rev = "49f324a2b63e778df703cf8e5a502bd56a683ef3";
    owner  = "whyrusleeping";
    repo   = "go-smux-yamux";
    sha256 = "1hp9naxq57dmpvcm6ghvggg7cw5gxm7r0q8jq7fm7lndn9xh4mnh";
    date = "2018-03-22";
    propagatedBuildInputs = [
      go-stream-muxer
      whyrusleeping_yamux
    ];
  };

  go-snappy = buildFromGitHub {
    version = 6;
    rev = "d8f7bb82a96d89c1254e5a6c967134e1433c9ee2";
    owner  = "siddontang";
    repo   = "go-snappy";
    sha256 = "1zifpmzxn5659lvn7bxi2a3460jwax1sr566zzispsksawzxlx61";
    date = "2014-07-04";
  };

  hashicorp_go-sockaddr = buildFromGitHub {
    version = 6;
    rev = "6d291a969b86c4b633730bfc6b8b9d64c3aafed9";
    owner  = "hashicorp";
    repo   = "go-sockaddr";
    sha256 = "0fkcjb66i2rfbdnwry6j43p36nxkpb8mlc8z3abbk04y0ji6p9wd";
    date = "2018-03-20";
    propagatedBuildInputs = [
      mitchellh_cli
      columnize
      errwrap
      go-wordwrap
    ];
  };

  libp2p_go-sockaddr = buildFromGitHub {
    version = 6;
    rev = "f3e9f73a53d14d8257cb9da3d83dda07bbd8b2fe";
    owner  = "libp2p";
    repo   = "go-sockaddr";
    sha256 = "0xsh5jp44vwpvqhpkxni5y7w7x4cnmvqnpn6sf144jj68fx9pw1x";
    date = "2018-03-29";
    propagatedBuildInputs = [
      sys
    ];
  };

  go-spew = buildFromGitHub {
    version = 5;
    rev = "8991bc29aa16c548c550c7ff78260e27b9ab7c73";
    owner  = "davecgh";
    repo   = "go-spew";
    sha256 = "1cjs23xhbpk5blv7wbnbn79xzkdnidhs448mzn2qkrddjkhbgs4y";
    date = "2018-02-21";
  };

  go-sqlite3 = buildFromGitHub {
    version = 6;
    rev = "a72efd674f654961a11ac41aae72c0e43963fe6c";
    owner  = "mattn";
    repo   = "go-sqlite3";
    sha256 = "0ljrn2r117bnvlva8vl4g788dsagrz8bvr1x17ahpyvrss78zyza";
    excludedPackages = "test";
    meta.useUnstable = true;
    date = "2018-04-19";
  };

  CanonicalLtd_go-sqlite3 = buildFromGitHub {
    version = 6;
    rev = "730012cee3364e7717c28f7e9b05ee6dd8684bae";
    owner  = "CanonicalLtd";
    repo   = "go-sqlite3";
    sha256 = "0p6z2ssca5n0mg7avaylkcrc47n7m5aaqqy9sqlzs7sxpmj8abi7";
    excludedPackages = "test";
    meta.useUnstable = true;
    date = "2018-03-29";
  };

  go-stdlib = buildFromGitHub {
    version = 5;
    rev = "36723135187404d2f4002f4f189938565e64cc5c";
    owner  = "opentracing-contrib";
    repo   = "go-stdlib";
    sha256 = "1kr8npx9yakil6xyjbsr9dz8qapjwcxsyxy8xl7nbcdpiqa8hjpl";
    date = "2018-03-13";
    propagatedBuildInputs = [
      opentracing-go
    ];
  };

  go-stream-muxer = buildFromGitHub {
    version = 6;
    rev = "6ebe3f58af097068454b167a89442050b023b571";
    owner  = "libp2p";
    repo   = "go-stream-muxer";
    sha256 = "1mkd94g881nhwklc5bjqfcl7w1gpvjh9zdkk9b9labbrlbipbqs9";
    date = "2017-09-11";
  };

  go-syslog = buildFromGitHub {
    version = 6;
    date = "2017-08-29";
    rev = "326bf4a7f709d263f964a6a96558676b103f3534";
    owner  = "hashicorp";
    repo   = "go-syslog";
    sha256 = "0xn6ybw807nv4cniq6iqhjzyk4civv2j5lym2wsdzmff6vrbgq06";
  };

  go-systemd = buildFromGitHub {
    version = 6;
    rev = "d1b7d058aa2adfc795ad17ff4aaa2bc64ec11c78";
    owner = "coreos";
    repo = "go-systemd";
    sha256 = "1jyhsbii2fj0nxlp08ibgpps1drm3f26i432zgb9jfhyay73srl2";
    propagatedBuildInputs = [
      dbus
      pkg
      pkgs.systemd_lib
    ];
    date = "2018-04-09";
  };

  go-systemd_journal = buildFromGitHub {
    inherit (go-systemd) rev owner repo sha256 version date;
    subPackages = [
      "journal"
    ];
  };

  go-tcp-transport = buildFromGitHub {
    version = 6;
    owner = "libp2p";
    repo = "go-tcp-transport";
    rev = "2852032418949429c7d683502e7ea9bff2e951e7";
    sha256 = "0sv5l0vpaqvdbx3zbyz9q2jqjirvfz48x8i612rj1hblq0n7n8as";
    date = "2018-04-16";
    propagatedBuildInputs = [
      go-log
      go-libp2p-transport
      go-multiaddr
      go-multiaddr-net
      go-reuseport
      mafmt
    ];
  };

  go-temp-err-catcher = buildFromGitHub {
    version = 6;
    owner = "jbenet";
    repo = "go-temp-err-catcher";
    rev = "aac704a3f4f27190b4ccc05f303a4931fd1241ff";
    sha256 = "1kc54g07a979ak76ngfwssfwz09z3pp3iyhdh536yb26agkwi0nh";
    date = "2015-01-20";
  };

  go-testing-interface = buildFromGitHub {
    version = 6;
    owner = "mitchellh";
    repo = "go-testing-interface";
    rev = "a61a99592b77c9ba629d254a693acffaeb4b7e28";
    sha256 = "1mc2ig4m9igl60r14y26mdn2nlm36saxg7wk2qwif4i0mpzdd91p";
    date = "2017-10-04";
  };

  go-toml = buildFromGitHub {
    version = 6;
    owner = "pelletier";
    repo = "go-toml";
    rev = "66540cf1fcd2c3aee6f6787dfa32a6ae9a870f12";
    sha256 = "0hk2350hvzjx0rrjk2s1qq96x3zj01sz0ks2idyablz5dx5b0x7v";
    propagatedBuildInputs = [
      go-buffruneio
    ];
    meta.useUnstable = true;
    date = "2018-03-23";
  };

  go-units = buildFromGitHub {
    version = 6;
    rev = "v0.3.3";
    owner = "docker";
    repo = "go-units";
    sha256 = "03l2crcb056sadamm4yljzjw1jqzydjs0n7i4qbyzcyl3zgwnmvp";
  };

  go-unsnap-stream = buildFromGitHub {
    version = 6;
    rev = "9f0cb55181dd3a0a4c168d3dbc72d4aca4853126";
    owner = "glycerine";
    repo = "go-unsnap-stream";
    sha256 = "0fx4cd1b2rf71dmfhcvn0f100h4qas169wb6vs07k0h7w5x92sa7";
    date = "2018-03-23";
    propagatedBuildInputs = [
      snappy
    ];
  };

  go-update = buildFromGitHub {
    version = 6;
    rev = "8152e7eb6ccf8679a64582a66b78519688d156ad";
    owner = "inconshreveable";
    repo = "go-update";
    sha256 = "0rwxd9acgxqcz7wlv6fwcabkdicb6afyfvhqglic11cndcjapkd1";
    date = "2016-01-12";
  };

  hashicorp_go-uuid = buildFromGitHub {
    version = 6;
    rev = "27454136f0364f2d44b1276c552d69105cf8c498";
    date = "2018-02-28";
    owner  = "hashicorp";
    repo   = "go-uuid";
    sha256 = "09bz8mvswqmbkwnm71pdndpyscsyyk3yx9hphysdmnrad1mkazbi";
  };

  satori_go-uuid = buildFromGitHub {
    version = 6;
    rev = "36e9d2ebbde5e3f13ab2e25625fd453271d6522e";
    owner  = "satori";
    repo   = "go.uuid";
    sha256 = "0k0lwkqjpypawnw8p874i2qscqzk4xi8vsvnl0llmjpq2knphnf4";
    goPackageAliases = [
      "github.com/satori/uuid"
    ];
    meta.useUnstable = true;
    date = "2018-01-03";
  };

  go-version = buildFromGitHub {
    version = 6;
    rev = "23480c0665776210b5fbbac6eaaee40e3e6a96b7";
    owner  = "hashicorp";
    repo   = "go-version";
    sha256 = "115v0i2mwzjixmp5967gkra8h3ldfly503bi2qmhfwabd75j0glj";
    date = "2018-03-22";
  };

  go-winio = buildFromGitHub {
    version = 5;
    rev = "v0.4.7";
    owner  = "Microsoft";
    repo   = "go-winio";
    sha256 = "1w18syhq8pkxhqfp3x8krxn4j8508x64j7r1y1kw0x36piyw3laf";
    buildInputs = [
      sys
    ];
    # Doesn't build on non-windows machines
    postPatch = ''
      rm vhd/zvhd.go
    '';
  };

  go-wordwrap = buildFromGitHub {
    version = 6;
    rev = "ad45545899c7b13c020ea92b2072220eefad42b8";
    owner  = "mitchellh";
    repo   = "go-wordwrap";
    sha256 = "0yj17x3c1mr9l3q4dwvy8y2xgndn833rbzsjf10y48yvr12zqjd0";
    date = "2015-03-14";
  };

  go-ws-transport = buildFromGitHub {
    version = 6;
    rev = "2c20090616127904f706139653cd40ecac600227";
    owner  = "libp2p";
    repo   = "go-ws-transport";
    sha256 = "0lgjrvwvxqiipzwlbwncr9cp7i2xqqsbrqx92aa9ddj7rk2fqxd4";
    date = "2018-04-16";
    propagatedBuildInputs = [
      go-libp2p-transport
      go-multiaddr
      go-multiaddr-net
      mafmt
      websocket
    ];
  };

  go-xerial-snappy = buildFromGitHub {
    version = 6;
    rev = "bb955e01b9346ac19dc29eb16586c90ded99a98c";
    owner  = "eapache";
    repo   = "go-xerial-snappy";
    sha256 = "055fdp516prfb61sl4gww6mkj0wd909n3m80l5mvhbyngsh67h8i";
    date = "2016-06-09";
    propagatedBuildInputs = [
      snappy
    ];
  };

  go-zookeeper = buildFromGitHub {
    version = 5;
    rev = "c4fab1ac1bec58281ad0667dc3f0907a9476ac47";
    date = "2018-01-30";
    owner  = "samuel";
    repo   = "go-zookeeper";
    sha256 = "1zqywcxm3d4v0xfqnwcgb34d2v7p2hrc1r7964ssarz1p496cl6l";
  };

  gocertifi = buildFromGitHub {
    version = 6;
    owner = "certifi";
    repo = "gocertifi";
    rev = "2018.01.18";
    sha256 = "0vjky8wyxb2mn6lx7qycbrmyv2cz0zywx78ndfysk6jvw6a6axkv";
  };

  goconfig = buildFromGitHub {
    version = 5;
    owner = "Unknwon";
    repo = "goconfig";
    rev = "ef1e4c783f8f0478bd8bff0edb3dd0bade552599";
    date = "2018-03-08";
    sha256 = "0ja27xc55wvj83z21cksp36vb9jhfw7lakkxsa8i8vvqp47sb1ai";
  };

  gorequest = buildFromGitHub {
    version = 6;
    owner = "parnurzeal";
    repo = "gorequest";
    rev = "8e3aed27fe49f7fdc765dad067845f600fc984e8";
    sha256 = "0s1gg9knh7qsmd7mggr062iwri1dwl5m2nkyqlxalf5yrcivdqhf";
    propagatedBuildInputs = [
      errors
      http2curl
      net
    ];
    date = "2017-10-15";
  };

  graceful_v1 = buildFromGitHub {
    version = 6;
    owner = "tylerb";
    repo = "graceful";
    rev = "v1.2.15";
    sha256 = "0bc3hb3g62q12kfm91h4szx8svdmpjn9qy7dbj3wrxzwmjzv0q60";
    goPackagePath = "gopkg.in/tylerb/graceful.v1";
    excludedPackages = "test";
  };

  grafana = buildFromGitHub {
    version = 6;
    owner = "grafana";
    repo = "grafana";
    rev = "v5.1.0";
    sha256 = "121q4sfzrsvf6pmq7ylqmd2fvjcdn3zdylshxkn9iadnis2c5m9j";
    buildInputs = [
      aws-sdk-go
      binding
      urfave_cli
      clock
      color
      com
      core
      gojsondiff
      gomail_v2
      go-cache
      go-hclog
      go-isatty
      go-mssqldb
      go-spew
      go-plugin
      go-sqlite3
      go-version
      grafana_plugin_model
      gzip
      ini_v1
      ldap
      log15
      macaron_v1
      mail_v2
      mysql
      net
      oauth2
      opentracing-go
      pq
      prometheus_client_golang
      prometheus_client_model
      prometheus_common
      session
      shortid
      slug
      stack
      sync
      toml
      websocket
      xorm
      yaml_v2
    ];
    postPatch = ''
      rm -r pkg/tracing
      sed -e '/tracing\.Init/,+4d' -e '\#pkg/tracing#d' -i pkg/cmd/grafana-server/server.go
    '';
    excludedPackages = "test";
    postInstall = ''
      rm "$bin"/bin/build
    '';
  };

  grafana_plugin_model = buildFromGitHub {
    version = 5;
    owner = "grafana";
    repo = "grafana_plugin_model";
    rev = "dfe5dc0a6ce05825ba7fe2d0323d92e631bffa89";
    sha256 = "0qsklh7809ddnwcc75lrjy6zw0lbj6p4ffnicm3dm8bawx83gvi4";
    date = "2018-01-18";
    propagatedBuildInputs = [
      go-plugin
      grpc
      net
      protobuf
    ];
  };

  graphite-golang = buildFromGitHub {
    version = 5;
    owner = "marpaia";
    repo = "graphite-golang";
    date = "2017-12-31";
    rev = "134b9af18cf31f936ebddbd11c03eead4d501601";
    sha256 = "13pywiz2jr835i0kd8msw8gl1aabrjswwh2vgr2q24pyc9vblgcn";
  };

  groupcache = buildFromGitHub {
    version = 5;
    date = "2018-02-03";
    rev = "66deaeb636dff1ac7d938ce666d090556056a4b0";
    owner  = "golang";
    repo   = "groupcache";
    sha256 = "1csg84lqxxldg17jkh9bfwn0a83abn18yki8wr2srx49hn95dql5";
    buildInputs = [ protobuf ];
  };

  grpc = buildFromGitHub rec {
    version = 6;
    rev = "v1.10.1";
    owner = "grpc";
    repo = "grpc-go";
    sha256 = "65a812baf1d3eb6693d334e53d6cdec18779775763f92131187a3c8722bbbcce";
    goPackagePath = "google.golang.org/grpc";
    goPackageAliases = [
      "github.com/grpc/grpc-go"
    ];
    excludedPackages = "\\(test\\|benchmark\\)";
    propagatedBuildInputs = [
      genproto_for_grpc
      glog
      net
      oauth2
      protobuf
    ];
    # GRPC 1.11.0 is broken with swarmkit 2018-03-27
    meta.autoUpdate = false;
  };

  grpc_for_gax-go = grpc.override {
    propagatedBuildInputs = [
      genproto_for_grpc
      net
      protobuf
    ];
    subPackages = [
      "."
      "balancer"
      "balancer/base"
      "balancer/roundrobin"
      "codes"
      "connectivity"
      "credentials"
      "encoding"
      "encoding/proto"
      "grpclb/grpc_lb_v1"
      "grpclb/grpc_lb_v1/messages"
      "grpclog"
      "internal"
      "keepalive"
      "metadata"
      "naming"
      "peer"
      "resolver"
      "resolver/dns"
      "resolver/manual"
      "resolver/passthrough"
      "stats"
      "status"
      "tap"
      "transport"
    ];
  };

  grpc-gateway = buildFromGitHub {
    version = 5;
    rev = "v1.3.1";
    owner = "grpc-ecosystem";
    repo = "grpc-gateway";
    sha256 = "1rn8ar7qdkl8qxv688z23jfzd2w9y7qymghynyh21cs0caqh8q5p";
    propagatedBuildInputs = [
      genproto
      glog
      grpc
      net
      protobuf
    ];
  };

  grpc-websocket-proxy = buildFromGitHub {
    version = 6;
    rev = "830351dc03c6f07d625727d5f993a463babb20e1";
    owner = "tmc";
    repo = "grpc-websocket-proxy";
    sha256 = "1wknphrvfa0x5k6sml6fcx4835wq7pmlnxml9jcbdyl5h1d9ywzc";
    date = "2017-10-17";
    propagatedBuildInputs = [
      logrus
      net
      websocket
    ];
  };

  grumpy = buildFromGitHub {
    version = 3;
    owner = "google";
    repo = "grumpy";
    rev = "f1446cd91c750b2439a1eb9a1e92f736a9fbb551";
    sha256 = "6ad8e8b05e189d7c288963c1f1eeed433c6b333ad51c89ec788ae2b1f52b4c03";

    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.which
    ];

    buildInputs = [
      pkgs.python2
    ];

    postPatch = ''
      # FIXME: fix executables not installing to $bin correctly
      sed -i Makefile \
        -e "s,[^@]/usr/bin,\)$out/bin,g" \
        -e "s,/usr/lib,$out/lib,g"
    '';

    preBuild = ''
      cd go/src/github.com/google/grumpy
    '';

    buildPhase = ''
      runHook preBuild
      make
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      make install "PY_INSTALL_DIR=$out/${pkgs.python2.sitePackages}"
      runHook postInstall
    '';

    preFixup = ''
      for i in $out/bin/grump{c,run}; do
        wrapProgram  "$i" \
          --set 'GOPATH' : "$out" \
          --prefix 'PYTHONPATH' : "$out/${pkgs.python2.sitePackages}"
      done
      # FIXME: prevent failures
      mkdir -p $bin
    '';

    buildDirCheck = false;

    meta = with lib; {
      description = "Python to Go source code transcompiler and runtime";
      homepage = https://github.com/google/grumpy;
      license = licenses.asl20;
      maintainers = with maintainers; [
        codyopel
      ];
      platforms = with platforms;
        x86_64-linux;
    };
  };

  gspt = buildFromGitHub {
    version = 6;
    owner = "erikdubbelboer";
    repo = "gspt";
    rev = "08ed213262b5bb2cf6ccb0baa71c6b201d353e63";
    sha256 = "1lsv9314qma8fbdwyklbwz83a0lafwxi75f0lklcfhlh79z93gmz";
    date = "2018-05-01";
  };

  guid = buildFromGitHub {
    version = 6;
    rev = "v1.1.0";
    owner = "marstr";
    repo = "guid";
    sha256 = "0i7dlyaxyhlhp6z3m6n29cjsjlb55cwcjvc0qb88r9f5ixgbrpy0";
  };

  gx = buildFromGitHub {
    version = 6;
    rev = "v0.12.1";
    owner = "whyrusleeping";
    repo = "gx";
    sha256 = "17gi19qaal6lg1063qnz4wlaqv4gbsbmcz27p9xphl3zhvn8yrpl";
    propagatedBuildInputs = [
      urfave_cli
      go-git-ignore
      go-homedir
      go-ipfs-api
      go-multiaddr
      go-multiaddr-net
      go-multihash
      go-os-rename
      json-filter
      progmeter
      semver
      stump
    ];
    excludedPackages = [
      "tests"
    ];
  };

  gx-go = buildFromGitHub {
    version = 6;
    rev = "v1.6.0";
    owner = "whyrusleeping";
    repo = "gx-go";
    sha256 = "1b9dwacxz9h3i5ba5wig3qg737xssk7lyp1c3sj03nhsyz5fb32y";
    buildInputs = [
      urfave_cli
      fs
      go-homedir
      gx
      stump
    ];
  };

  gzip = buildFromGitHub {
    version = 6;
    date = "2016-02-22";
    rev = "cad1c6580a07c56f5f6bc52d66002a05985c5854";
    owner = "go-macaron";
    repo = "gzip";
    sha256 = "0kc7xqp9kafpp0dqlkmkqgz1d179j4dxahqwp1hd776qkaqhn9ii";
    propagatedBuildInputs = [
      compress
      macaron_v1
    ];
  };

  gziphandler = buildFromGitHub {
    version = 5;
    rev = "v1.0.1";
    owner = "NYTimes";
    repo = "gziphandler";
    sha256 = "0l1gmrffjji0pxm5w3alr1d8df7qcymsvmlb04hil0f3xnbf8inl";
  };

  hashland = buildFromGitHub {
    version = 6;
    rev = "07375b562deaa8d6891f9618a04e94a0b98e2ee7";
    owner  = "tildeleb";
    repo   = "hashland";
    sha256 = "c70ea6068865fcc2cb7df1ebff0d7964a0a7a884918575ec445d3d57b45de4ec";
    goPackagePath = "leb.io/hashland";
    goPackageAliases = [
      "github.com/gxed/hashland"
    ];
    meta.autoUpdate = false;
    date = "2017-10-03";
    excludedPackages = "example";
    propagatedBuildInputs = [
      aeshash
      blake2b-simd
      cuckoo
      go-farm
      go-metro
      hrff
      whirlpool
    ];
  };

  hashland_for_aeshash = hashland.override {
    subPackages = [
      "nhash"
    ];
    propagatedBuildInputs = [ ];
  };

  handlers = buildFromGitHub {
    version = 6;
    owner = "gorilla";
    repo = "handlers";
    rev = "v1.3.0";
    sha256 = "1f37c3zv5014jwa8a7mn40nm7viihz8brm5ni46y3lwrhgrhwavx";
  };

  hashstructure = buildFromGitHub {
    version = 6;
    date = "2017-06-09";
    rev = "2bca23e0e452137f789efbc8610126fd8b94f73b";
    owner  = "mitchellh";
    repo   = "hashstructure";
    sha256 = "12z3vcxbdgkn1hfisj3m23kgq9lkl1rby5cik7878sbdy9zkl0bw";
  };

  hcl = buildFromGitHub {
    version = 6;
    date = "2018-04-04";
    rev = "ef8a98b0bbce4a65b5aa4c368430a80ddc533168";
    owner  = "hashicorp";
    repo   = "hcl";
    sha256 = "021d9wa412zyr4ak7sh1zb1mr9rg8iqw2ha5pn2ixb41sb8f4a31";
  };

  hdrhistogram = buildFromGitHub {
    version = 6;
    date = "2016-10-10";
    rev = "3a0bb77429bd3a61596f5e8a3172445844342120";
    owner  = "codahale";
    repo   = "hdrhistogram";
    sha256 = "02f2m6blg0bij0kc06r1zkhf088nlksfkdhd2lhyv7wh1963isxc";
    propagatedBuildInputs = [
      #mgo_v2
    ];
  };

  highwayhash = buildFromGitHub {
    version = 6;
    date = "2018-05-01";
    rev = "85fc8a2dacad36a6beb2865793cd81363a496696";
    owner  = "minio";
    repo   = "highwayhash";
    sha256 = "0737lhfhdgf5rgjv3gq55jglfdknvvmj30zvs81h0smk76wkd3s0";
    propagatedBuildInputs = [
      sys
    ];
  };

  hil = buildFromGitHub {
    version = 6;
    date = "2017-06-27";
    rev = "fa9f258a92500514cc8e9c67020487709df92432";
    owner  = "hashicorp";
    repo   = "hil";
    sha256 = "1m0gzss7vgq9jdc4sx4cjlid1r1zahf0mi0mc4q6b7hz25zkmkwk";
    propagatedBuildInputs = [
      mapstructure
      reflectwalk
    ];
    meta.useUnstable = true;
  };

  hllpp = buildFromGitHub {
    version = 6;
    owner = "retailnext";
    repo = "hllpp";
    date = "2018-03-08";
    rev = "101a6d2f8b52abfc409ac188958e7e7be0116331";
    sha256 = "1prk8yvr9i9dzj3r32hchrwbrm1h9j5z47acskncma3irbvnszxb";
  };

  holster = buildFromGitHub {
    version = 5;
    rev = "v1.7.0";
    owner = "mailgun";
    repo = "holster";
    sha256 = "0z551bvx25iwxhmzbj73nxscd9nsyjzarkhfs7yhmjxlj8q8cqbm";
    subPackages = [
      "."
    ];
    propagatedBuildInputs = [
      errors
      logrus
      structs
    ];
  };

  hotp = buildFromGitHub {
    version = 6;
    rev = "c180d57d286b385101c999a60087a40d7f48fc77";
    owner  = "gokyle";
    repo   = "hotp";
    sha256 = "1d5yn6xjclakdc5d4mg3izgjrs5klgbm1x0y85zpf2fsy94dh20h";
    date = "2016-02-18";
    propagatedBuildInputs = [
      rsc
    ];
  };

  hrff = buildFromGitHub {
    version = 6;
    rev = "757f8bd43e20ae62b376efce979d8e7082c16362";
    owner  = "tildeleb";
    repo   = "hrff";
    sha256 = "660e1161c0fad9377d24164ddab3d9baffd94947cbac06ef7d0147ec34efbb3d";
    goPackagePath = "leb.io/hrff";
    date = "2017-09-27";
    meta.autoUpdate = false;
  };

  http2curl = buildFromGitHub {
    version = 6;
    owner = "moul";
    repo = "http2curl";
    date = "2017-09-19";
    rev = "9ac6cf4d929b2fa8fd2d2e6dec5bb0feb4f4911d";
    sha256 = "17v1xp38rww73fj42zqgp4xi9r2h3clwhrp4n46hri69xm4hi4f1";
  };

  httpcache = buildFromGitHub {
    version = 5;
    rev = "9cad4c3443a7200dd6400aef47183728de563a38";
    owner  = "gregjones";
    repo   = "httpcache";
    sha256 = "04g601pps7nkaq1j1wsjc5krmi1j8zp8kir5yyb9929cpxah8lr8";
    date = "2018-03-05";
    propagatedBuildInputs = [
      diskv
      goleveldb
      gomemcache
      redigo
    ];
    postPatch = ''
      grep -r '+build appengine' -l | xargs rm
    '';
  };

  http-link-go = buildFromGitHub {
    version = 6;
    rev = "ac974c61c2f990f4115b119354b5e0b47550e888";
    owner  = "tent";
    repo   = "http-link-go";
    sha256 = "05zir2mh47n1mlrnxgahxplxnaib0248xijd26mfs4ws88507bv3";
    date = "2013-07-02";
  };

  httprequest_v1 = buildFromGitHub {
    version = 5;
    rev = "v1.1.1";
    owner  = "go-httprequest";
    repo   = "httprequest";
    sha256 = "1xlgv41m98xvs0psrv399ml47fi4cx07vch07ygpcgrw8a8vrd5v";
    goPackagePath = "gopkg.in/httprequest.v1";
    goPackageAliases = [
      "github.com/juju/httprequest"
    ];
    propagatedBuildInputs = [
      errgo_v1
      httprouter
      net
      tools
    ];
  };

  httprouter = buildFromGitHub {
    version = 6;
    rev = "adbc77eec0d91467376ca515bc3a14b8434d0f18";
    owner  = "julienschmidt";
    repo   = "httprouter";
    sha256 = "1x1py2mqm7wjdirpj5kh39p130vag4xqylryjxjn267awksqcqs5";
    date = "2018-04-11";
  };

  httpunix = buildFromGitHub {
    version = 6;
    rev = "b75d8614f926c077e48d85f1f8f7885b758c6225";
    owner  = "tv42";
    repo   = "httpunix";
    sha256 = "03pz7s57v5hmy1hlsannj48zxy1rl8d4rymdlvqh3qisz7705izw";
    date = "2015-04-27";
  };

  hugo = buildFromGitHub {
    version = 6;
    owner = "gohugoio";
    repo = "hugo";
    rev = "v0.40.2";
    sha256 = "0wbi6dcsl7mc4lsmxy5xwpzry9hccvl2gh9wcsj0ykns5b71ic65";
    buildInputs = [
      ace
      afero
      amber
      blackfriday
      cast
      chroma
      cobra
      debounce
      emoji
      fsnotify
      fsync
      gitmap
      glob
      go-i18n
      go-immutable-radix
      go-toml
      goorgeous
      image
      imaging
      inflect
      jwalterweatherman
      mage
      mapstructure
      mmark
      net
      nitro
      osext
      pflag
      prose
      purell
      smartcrop
      sync
      tablewriter
      text
      toml
      viper
      websocket
      yaml_v2
    ];
  };

  idmclient = buildFromGitHub {
    version = 6;
    rev = "15392b0e99abe5983297959c737b8d000e43b34c";
    owner  = "juju";
    repo   = "idmclient";
    sha256 = "06fbsl1f2r2jrk9gfv9qm8yxczdm1azv66kvryzmf6r0i9kf6jxl";
    date = "2017-11-10";
    excludedPackages = "test";
    propagatedBuildInputs = [
      environschema_v1
      errgo_v1
      httprequest_v1
      macaroon_v2
      macaroon-bakery_v2
      names_v2
      net
      usso
      utils
    ];
  };

  image-spec = buildFromGitHub {
    version = 6;
    rev = "v1.0.1";
    owner  = "opencontainers";
    repo   = "image-spec";
    sha256 = "0nbdx1qz40d35b2gibj8gddsc83bnpk1ilah641smkf7i8zk5py0";
    propagatedBuildInputs = [
      errors
      go4
      go-digest
      gojsonschema
    ];
  };

  imaging = buildFromGitHub {
    version = 5;
    rev = "v1.4.1";
    owner  = "disintegration";
    repo   = "imaging";
    sha256 = "071xq8lc87awfc0lcldb4m5v23b6naav5zi48565sga95bwd4air";
    propagatedBuildInputs = [
      image
    ];
  };

  inf_v0 = buildFromGitHub {
    version = 6;
    rev = "v0.9.1";
    owner  = "go-inf";
    repo   = "inf";
    sha256 = "14v751j7wigydxmvvv075dfdb6ahd53rqrbfvx01b5va6kdnczjn";
    goPackagePath = "gopkg.in/inf.v0";
  };

  inflect = buildFromGitHub {
    version = 6;
    owner = "markbates";
    repo = "inflect";
    rev = "fbc6b23ce49e2578f572d2e72bb72fa03c7145de";
    date = "2018-04-05";
    sha256 = "0br3d2z577ccfwxc98r38fbksrvx8246sq1ddgxnnvm8j5lg3698";
    propagatedBuildInputs = [
      envy
    ];
  };

  influxdb = buildFromGitHub {
    version = 6;
    owner = "influxdata";
    repo = "influxdb";
    rev = "v1.5.2";
    sha256 = "0yhl528wrhp3dva08kz1b8zbyqm284qbxly10ibhxbw3id1mdv9k";
    propagatedBuildInputs = [
      bolt
      crypto
      encoding
      go-bits
      go-bitstream
      #go-collectd
      go-isatty
      hllpp
      influxql
      jwt-go
      liner
      msgp
      opentracing-go
      pat
      prometheus_client_golang
      gogo_protobuf
      ratecounter
      roaring
      snappy
      sync
      sys
      text
      time
      toml
      treeprint
      usage-client
      cespare_xxhash
      yarpc
      zap
      zap-logfmt
    ];
    goPackageAliases = [
      "github.com/influxdb/influxdb"
    ];
    postPatch = /* Remove broken tests */ ''
      rm -rf services/collectd/test_client
    '';
  };

  influxdb_client = influxdb.override {
    subPackages = [
      "client"
      "models"
      "pkg/escape"
    ];
    propagatedBuildInputs = [
    ];
  };

  influxql = buildFromGitHub {
    version = 6;
    rev = "145e0677ff6418fa00ee7e5dd434305631ab44ea";
    owner  = "influxdata";
    repo   = "influxql";
    sha256 = "104kimpf7dbkvpcvvbni9vnwwiac3v68qsg2qa2plg51dbpfn9yl";
    date = "2018-03-30";
    propagatedBuildInputs = [
      gogo_protobuf
    ];
  };

  ini = buildFromGitHub {
    version = 6;
    rev = "v1.36.0";
    owner  = "go-ini";
    repo   = "ini";
    sha256 = "13490jyxlr886yp6shff406x353kd05by2wxsr3a35r02sd54h50";
  };

  ini_v1 = buildFromGitHub {
    version = 6;
    rev = "v1.36.0";
    owner  = "go-ini";
    repo   = "ini";
    goPackagePath = "gopkg.in/ini.v1";
    sha256 = "0azx5d7idj3ps7jxxn1a7abs4103qnsbji9sq6r1hq7mv8kn074i";
  };

  inject = buildFromGitHub {
    version = 6;
    date = "2016-06-27";
    rev = "d8a0b8677191f4380287cfebd08e462217bac7ad";
    owner = "go-macaron";
    repo = "inject";
    sha256 = "1yqbh7gbv1awlf231d5k6qy7aq2r808np643ih1pzjskmaln72in";
  };

  ipfs = buildFromGitHub {
    version = 6;
    rev = "v0.4.15-rc1";
    owner = "ipfs";
    repo = "go-ipfs";
    sha256 = "94b432f71a1ae25afd82e6441eb7010951b037b98ca3bae7686b8213a69b45e8";
    gxSha256 = "0acj58jrjdfh376fp2chyz8i6m3wxxiqywinnbvrzdl69wfr9dzr";
    nativeBuildInputs = [
      gx-go.bin
    ];
    allowVendoredSources = true;
    excludedPackages = "test";
    meta.autoUpdate = false;
    postInstall = ''
      find "$bin"/bin -not -name ipfs\* -mindepth 1 -maxdepth 1 -delete
    '';
  };

  ipfs-cluster = buildFromGitHub {
    version = 6;
    rev = "a0a08987191b36d610bf1edaf39dd72cd924f0eb";
    owner = "ipfs";
    repo = "ipfs-cluster";
    sha256 = "01swf3zzalmp18wh29g4ixbsalkz3k5ywpj0hiypgvr81xcmp2fg";
    meta.useUnstable = true;
    date = "2018-05-01";
    excludedPackages = "test";
    propagatedBuildInputs = [
      urfave_cli
      go-cid
      go-dot
      go-fs-lock
      go-ipfs-api
      go-libp2p
      go-libp2p-consensus
      go-libp2p-crypto
      go-libp2p-host
      go-libp2p-http
      go-libp2p-interface-pnet
      go-libp2p-gorpc
      go-libp2p-gostream
      go-libp2p-peer
      go-libp2p-peerstore
      go-libp2p-pnet
      go-libp2p-protocol
      go-libp2p-raft
      go-log
      go-multiaddr
      go-multiaddr-dns
      go-multiaddr-net
      go-multicodec
      go-ws-transport
      mux
      raft
      raft-boltdb
    ];
  };

  jaeger-client-go = buildFromGitHub {
    version = 5;
    owner = "jaegertracing";
    repo = "jaeger-client-go";
    rev = "v2.12.0";
    sha256 = "1cvggvzj5ysjr7y6sbz20qf078w48rr8zfinb1cq2b5806yxvq6p";
    goPackagePath = "github.com/uber/jaeger-client-go";
    excludedPackages = "crossdock";
    nativeBuildInputs = [
      pkgs.thrift
    ];
    propagatedBuildInputs = [
      errors
      jaeger-lib
      net
      opentracing-go
      thrift
      zap
    ];
    postPatch = ''
      rm -r thrift-gen
      mkdir -p thrift-gen

      grep -q 'a.client.SeqId = 0' utils/udp_client.go
      sed -i '/a.client.SeqId/d' utils/udp_client.go

      grep -q 'EmitBatch(batch)' utils/udp_client.go
      sed \
        -e 's#EmitBatch(batch)#EmitBatch(context.TODO(), batch)#g' \
        -e '/"errors"/a"context"' \
        -i utils/udp_client.go

      grep -q 's.manager.GetSamplingStrategy(s.serviceName)' sampler.go
      sed \
        -e '/"math"/a"context"' \
        -e 's#GetSamplingStrategy(serviceName string)#GetSamplingStrategy(ctx context.Context,serviceName string)#' \
        -e 's#s.manager.GetSamplingStrategy(s.serviceName)#s.manager.GetSamplingStrategy(context.TODO(), s.serviceName)#' \
        -i sampler.go
    '';
    preBuild = ''
      unpackFile '${jaeger-idl.src}'
      for file in jaeger-idl*/thrift/*.thrift; do
        thrift --gen go:thrift_import="github.com/apache/thrift/lib/go/thrift",package_prefix="github.com/uber/jaeger-client-go/thrift-gen/" --out go/src/$goPackagePath/thrift-gen "$file"
      done
    '';
  };

  jaeger-idl = buildFromGitHub {
    version = 6;
    owner = "jaegertracing";
    repo = "jaeger-idl";
    rev = "c5ee6caa3cf2bbaeec6ad6c8595e7c5c73e54c00";
    sha256 = "0rbih18b6j1sx4pikwwway5qw5kjlay7fsj72z47zs58cciqsfri";
    date = "2018-02-01";
  };

  jaeger-lib = buildFromGitHub {
    version = 5;
    owner = "jaegertracing";
    repo = "jaeger-lib";
    rev = "v1.4.0";
    sha256 = "1siq6lzkykml33ad9i523ahlzzqy1hdm8ikzkbq2mvn9n3ijfiax";
    goPackagePath = "github.com/uber/jaeger-lib";
    excludedPackages = "test";
    propagatedBuildInputs = [
      hdrhistogram
      kit
      prometheus_client_golang
      tally
    ];
    postPatch = ''
      grep -q 'hv.WithLabelValues' metrics/prometheus/factory.go
      sed -i '/hv.WithLabelValues/s#),#).(prometheus.Histogram),#g' metrics/prometheus/factory.go
    '';
  };

  jose = buildFromGitHub {
    version = 5;
    owner = "SermoDigital";
    repo = "jose";
    rev = "803625baeddc3526d01d321b5066029f53eafc81";
    sha256 = "02ik4nmdnc3v04qgg3f06xgyinyzqa3vxg8zj13sa84vwfz1k9kw";
    date = "2018-01-04";
  };

  json-filter = buildFromGitHub {
    version = 6;
    owner = "whyrusleeping";
    repo = "json-filter";
    rev = "ff25329a9528f01c5175414f16cc0a6a162a5b8b";
    date = "2016-06-15";
    sha256 = "01ljz4l1scfwa4w71fjl2clgnln3nkysm8dijp8qvn02a2yq3fq2";
  };

  json-patch = buildFromGitHub {
    version = 6;
    owner = "evanphx";
    repo = "json-patch";
    rev = "v3.0.0";
    sha256 = "0fh1xj7za9xcdbbmyxj6m57gn3kcl0dasqi1zazhcim3bzk11m5v";
    propagatedBuildInputs = [
      go-flags
    ];
  };

  jsonpointer = buildFromGitHub {
    version = 6;
    owner = "go-openapi";
    repo = "jsonpointer";
    rev = "3a0015ad55fa9873f41605d3e8f28cd279c32ab2";
    date = "2018-03-22";
    sha256 = "0xp09p2hqw11k3f2s5ya4hflw4i4h924krlvsl4mv28f37kvscaw";
    propagatedBuildInputs = [
      swag
    ];
  };

  jsonreference = buildFromGitHub {
    version = 6;
    owner = "go-openapi";
    repo = "jsonreference";
    rev = "3fb327e6747da3043567ee86abd02bb6376b6be2";
    date = "2018-03-22";
    sha256 = "1s7xp9pjvyyp4a3a353pwrqqwhjni9wyq9hwgkmhdslfccg6mdxw";
    propagatedBuildInputs = [
      jsonpointer
      purell
    ];
  };

  jsonx = buildFromGitHub {
    version = 6;
    owner = "jefferai";
    repo = "jsonx";
    rev = "9cc31c3135eef39b8e72585f37efa92b6ca314d0";
    date = "2016-07-21";
    sha256 = "1h4y2g59qkjw1syim3lf69hmp1f6bk7s4xirw1qpc0rm5ji8blpl";
    propagatedBuildInputs = [
      gabs
    ];
  };

  jwalterweatherman = buildFromGitHub {
    version = 5;
    owner = "spf13";
    repo = "jWalterWeatherman";
    rev = "7c0cea34c8ece3fbeb2b27ab9b59511d360fb394";
    date = "2018-01-09";
    sha256 = "0a0wbsgaah9v383hh66sshnmmw4jck3krlms35dxpjm2hxfsb9l2";
    goPackageAliases = [
      "github.com/spf13/jwalterweatherman"
    ];
  };

  jwt-go = buildFromGitHub {
    version = 5;
    owner = "dgrijalva";
    repo = "jwt-go";
    rev = "v3.2.0";
    sha256 = "0xlri0sdphab7xs9drg06fckb11ysyj9xhlbparclr6wfh648612";
  };

  gravitational_kingpin = buildFromGitHub {
    version = 6;
    rev = "52bc17adf63c0807b5e5b5d91350703630f621c7";
    owner = "gravitational";
    repo = "kingpin";
    sha256 = "1hal9vrx113pbz68k9z1pqbz8vaahgf93i9bb4iia2a57z53k7m7";
    propagatedBuildInputs = [
      template
      units
    ];
    meta.useUnstable = true;
    date = "2017-09-06";
  };

  kingpin = buildFromGitHub {
    version = 6;
    rev = "v2.2.6";
    owner = "alecthomas";
    repo = "kingpin";
    sha256 = "00g6cnx6vl7yhhcy18q5im9wb2spsjp59hxmdqcaivha74zc6whp";
    propagatedBuildInputs = [
      template
      units
    ];
  };

  kingpin_v2 = buildFromGitHub {
    version = 5;
    rev = "v2.2.6";
    owner = "alecthomas";
    repo = "kingpin";
    sha256 = "0hphhyvvp5dmqzkb80wfxdir7dqf645gmppfqqv2yiswyl7d0cqh";
    goPackagePath = "gopkg.in/alecthomas/kingpin.v2";
    propagatedBuildInputs = [
      template
      units
    ];
  };

  kit = buildFromGitHub {
    version = 6;
    rev = "v0.7.0";
    owner = "go-kit";
    repo = "kit";
    sha256 = "1wf764qbq7apl4sri8924qxkipw544hbcx9vkvqbxx41wf88w905";
    subPackages = [
      "log"
      "log/level"
      "metrics"
      "metrics/expvar"
      "metrics/generic"
      "metrics/influx"
      "metrics/internal/lv"
      "metrics/prometheus"
    ];
    propagatedBuildInputs = [
      gohistogram
      influxdb_client
      logfmt
      prometheus_client_golang
      stack
    ];
  };

  kit_for_prometheus = kit.override {
    subPackages = [
      "log"
      "log/level"
    ];
    propagatedBuildInputs = [
      logfmt
      stack
    ];
  };

  kubernetes-api = buildFromGitHub {
    version = 6;
    rev = "b7d77fa220f5130ec63c2ca7167dd9653449c64d";
    owner  = "kubernetes";
    repo   = "api";
    sha256 = "0v9k9whmwmjyz7hfya3iqmnr5c5x8xlmj30wc33xbf5v43mp5kwk";
    goPackagePath = "k8s.io/api";
    propagatedBuildInputs = [
      gogo_protobuf
      kubernetes-apimachinery
    ];
    meta.useUnstable = true;
    date = "2018-04-28";
  };

  kubernetes-apimachinery = buildFromGitHub {
    version = 6;
    rev = "6426d21f392c6d0e710af98bdfe6fb7334b3e11a";
    owner  = "kubernetes";
    repo   = "apimachinery";
    sha256 = "0n113cfxgf1b0zwhkmvimjz2x3lg7s217d3kg1i6dgxify1mgy0r";
    goPackagePath = "k8s.io/apimachinery";
    excludedPackages = "\\(testing\\|testapigroup\\|fuzzer\\)";
    propagatedBuildInputs = [
      glog
      gofuzz
      go-flowrate
      go-spew
      golang-lru
      kubernetes-kube-openapi
      inf_v0
      json-iterator_go
      json-patch
      net
      pflag
      gogo_protobuf
      spdystream
      yaml
    ];
    postPatch = ''
      rm -r pkg/util/uuid
    '';
    meta.useUnstable = true;
    date = "2018-05-02";
  };

  kubernetes-kube-openapi = buildFromGitHub {
    version = 6;
    rev = "f08db293d3ef80052d6513ece19792642a289fea";
    date = "2018-05-01";
    owner  = "kubernetes";
    repo   = "kube-openapi";
    sha256 = "16s6y1hsvdx0wdca2wchbn6gvqbnp1dzvjf3r33g0sa338jvaxb7";
    goPackagePath = "k8s.io/kube-openapi";
    subPackages = [
      "pkg/common"
      "pkg/util/proto"
    ];
    propagatedBuildInputs = [
      gnostic
      go-restful
      spec_openapi
      yaml_v2
    ];
  };

  kubernetes-client-go = buildFromGitHub {
    version = 6;
    rev = "01d6a1350dd5c61a498fd3a5bdafd9151cac4e9a";
    owner  = "kubernetes";
    repo   = "client-go";
    sha256 = "05vcki72dnw8n083y9649ql6dvgxwgzc3i97wj93xyhyg07zyr0v";
    goPackagePath = "k8s.io/client-go";
    excludedPackages = "\\(test\\|fake\\)";
    propagatedBuildInputs = [
      crypto
      glog
      gnostic
      go-autorest
      gophercloud
      groupcache
      kubernetes-api
      kubernetes-apimachinery
      mergo
      net
      oauth2
      pflag
      protobuf
      time
    ];
    meta.useUnstable = true;
    date = "2018-05-01";
  };

  ldap = buildFromGitHub {
    version = 6;
    rev = "v2.5.1";
    owner  = "go-ldap";
    repo   = "ldap";
    sha256 = "1rdbcziyikdkv3bhbqpxcbngbxh00yb9crkps0ynw1nv5apb3k26";
    goPackageAliases = [
      "github.com/nmcclain/ldap"
      "github.com/vanackere/ldap"
    ];
    propagatedBuildInputs = [
      asn1-ber
    ];
  };

  ledisdb = buildFromGitHub {
    version = 6;
    rev = "v0.6";
    owner  = "siddontang";
    repo   = "ledisdb";
    sha256 = "1lys13h4w10gf9hvn1bm915mxxnxkrdmy88ajy9d59hglxj4sxzr";
    prePatch = ''
      dirs=($(find . -type d -name vendor | sort))
      echo "''${dirs[@]}" | xargs -n 1 rm -r
    '';
    subPackages = [
      "config"
      "ledis"
      "rpl"
      "store"
      "store/driver"
      "store/goleveldb"
      "store/leveldb"
      "store/rocksdb"
    ];
    propagatedBuildInputs = [
      siddontang_go
      go-toml
      net
      goleveldb
      mmap-go
      siddontang_rdb
    ];
  };

  lego = buildFromGitHub {
    version = 6;
    rev = "8e9c5ac3e6bf1392a581eece36752e7360a3414b";
    owner = "xenolf";
    repo = "lego";
    sha256 = "1rs0dkqmdiarlb5x8qdg7h22k77hdz1hw1w25di3n7fn6viqnw2x";
    buildInputs = [
      akamaiopen-edgegrid-golang
      auroradnsclient
      aws-sdk-go
      #azure-sdk-for-go
      urfave_cli
      crypto
      dns
      dnspod-go
      dnsimple-go
      go-autorest
      go-jose_v1
      go-ovh
      google-api-go-client
      linode
      memcache
      namedotcom_go
      ns1-go_v2
      oauth2
      net
      testify
      vultr
    ];
    postPatch = ''
      rm -r providers/dns/azure
      sed -i '/azure/d' providers/dns/dns_providers.go

      rm -r providers/dns/exoscale
      sed -i '/exoscale/d' providers/dns/dns_providers.go

      grep -q 'FormatInt(whoamiResponse.Data.Account.ID,' providers/dns/dnsimple/dnsimple.go
      sed -i 's#FormatInt(whoamiResponse.Data.Account.ID,#FormatInt(int64(whoamiResponse.Data.Account.ID),#' providers/dns/dnsimple/dnsimple.go
    '';
    date = "2018-04-25";
  };

  lemma = buildFromGitHub {
    version = 6;
    rev = "4214099fb348c416514bc2c93087fde56216d7b5";
    owner = "mailgun";
    repo = "lemma";
    sha256 = "0nyrryphjwn85xjr8s9rrnaqwys7fl7m4g7n30bfbw8ji54afvdq";
    date = "2017-06-19";
    propagatedBuildInputs = [
      crypto
      metrics
      timetools
      mailgun_ttlmap
    ];
  };

  libkv = buildFromGitHub {
    version = 5;
    rev = "791d3fcb5d1b1af9a0ad6700cd8956b2f7a0a518";
    owner = "docker";
    repo = "libkv";
    sha256 = "1pdzi2axvgqi4fva0mv25281chprybw5hwmzxmk8xk4n51pd5y7i";
    date = "2017-12-19";
    excludedPackages = "\\(mock\\|testutils\\)";
    propagatedBuildInputs = [
      bolt
      consul_api
      etcd_client
      go-zookeeper
      net
    ];
  };

  libnetwork = buildFromGitHub {
    version = 6;
    rev = "1aac06b241ca37d1514edf38112355545f6edb65";
    owner = "docker";
    repo = "libnetwork";
    sha256 = "0dxj5n13gzsh2q7cq2jbhkl4add1rd38glbkq2g9dl1sknb3fdxf";
    date = "2018-04-26";
    subPackages = [
      "datastore"
      "discoverapi"
      "types"
    ];
    propagatedBuildInputs = [
      libkv
      sctp
    ];
  };

  libseccomp-golang = buildFromGitHub {
    version = 6;
    rev = "v0.9.0";
    owner = "seccomp";
    repo = "libseccomp-golang";
    sha256 = "0cpzyr5hqp9z2v0l2ismn89b0k91m8lnw34gl5na7khlq872w93c";
    buildInputs = [
      pkgs.libseccomp
    ];
  };

  lightstep-tracer-go = buildFromGitHub {
    version = 6;
    rev = "v0.15.2";
    owner  = "lightstep";
    repo   = "lightstep-tracer-go";
    sha256 = "1i0dpvwrbxn2k45v54ahjn0l2h9xdyvrbk51yiwlqili2l971s2l";
    propagatedBuildInputs = [
      genproto
      grpc
      net
      opentracing-go
      protobuf
    ];
  };

  liner = buildFromGitHub {
    version = 6;
    rev = "6106ee4fe3e8435f18cd10e34557e5e50f0e792a";
    owner = "peterh";
    repo = "liner";
    sha256 = "06d445jb63dl3kpngrwn342llnhlamnx1zdn6bnlfrmf3xqsl3fr";
    date = "2018-03-10";
  };

  link = buildFromGitHub {
    version = 6;
    rev = "6d32b8d78d1e440948a1c461c5abcc6bf7881641";
    owner  = "peterhellberg";
    repo   = "link";
    sha256 = "18449lb5g7pad88ljl73mhb5nmlxc78dfq9a1fdiz13x185i784r";
    date = "2018-01-24";
  };

  linode = buildFromGitHub {
    version = 6;
    rev = "37e84520dcf74488f67654f9c775b9752c232dc1";
    owner = "timewasted";
    repo = "linode";
    sha256 = "05p94l2k9jnnsqm6plslb169n36b53r6hsl0jsp0msr4ig2n33vv";
    date = "2016-08-29";
  };

  lockfile = buildFromGitHub {
    version = 5;
    rev = "6a197d5ea61168f2ac821de2b7f011b250904900";
    owner = "nightlyone";
    repo = "lockfile";
    sha256 = "1pl63q7bgjl651z9f2750iapnwlgnswk4cncn7f32hsq3y3gd825";
    date = "2017-08-04";
  };

  log15 = buildFromGitHub {
    version = 6;
    rev = "0decfc6c20d9ca0ad143b0e89dcaa20f810b4fb3";
    owner  = "inconshreveable";
    repo   = "log15";
    sha256 = "14nbvlq60aj16vjpajrccvl31kb5a214lyzy6z8hqrm4sb16adix";
    propagatedBuildInputs = [
      go-colorable
      go-isatty
      stack
      sys
    ];
    date = "2017-10-19";
  };

  kr_logfmt = buildFromGitHub {
    version = 6;
    rev = "b84e30acd515aadc4b783ad4ff83aff3299bdfe0";
    owner  = "kr";
    repo   = "logfmt";
    sha256 = "1p9z8ni7ijg0qxqyhkqr2aq80ll0mxkq0fk5mgsd8ly9l9f73mjc";
    date = "2014-02-26";
  };

  logfmt = buildFromGitHub {
    version = 6;
    rev = "v0.3.0";
    owner  = "go-logfmt";
    repo   = "logfmt";
    sha256 = "104vw0802vk9rmwdzqfqdl616q2g8xmzbwmqcl35snl2dggg5sia";
    propagatedBuildInputs = [
      kr_logfmt
    ];
  };

  lunny_log = buildFromGitHub {
    version = 6;
    rev = "7887c61bf0de75586961948b286be6f7d05d9f58";
    owner = "lunny";
    repo = "log";
    sha256 = "00impglzjzlc1aqhgg21avpms02q7vm3063ngwn6f4ihk99r2xq1";
    date = "2016-09-21";
  };

  mailgun_log = buildFromGitHub {
    version = 6;
    rev = "2f35a4607f1abf71f97f77f99b0de8493ef6f4ef";
    owner = "mailgun";
    repo = "log";
    sha256 = "0ykzq36pbzjyhsvpj2whcl26fyi0ibjlgl7x8zf5mbp71i47dxjq";
    date = "2015-09-26";
  };

  loggo = buildFromGitHub {
    version = 6;
    rev = "7f1609ff1f3fcf3519ed62ccaaa9e609ea287838";
    owner = "juju";
    repo = "loggo";
    sha256 = "0jc3bml282w54gwgp0gyjfw1g282slg3irlfv645sba90lvdc4gn";
    date = "2018-03-27";
    propagatedBuildInputs = [
      ansiterm
    ];
  };

  logrus = buildFromGitHub {
    version = 6;
    rev = "778f2e774c725116edbc3d039dc0dfc1cc62aae8";
    owner = "sirupsen";
    repo = "logrus";
    sha256 = "1cak6rpvrcqsjm8fnsnj0cyi5zbbk39bmy5w7gqpgb9vr3619981";
    goPackageAliases = [
      "github.com/Sirupsen/logrus"
    ];
    propagatedBuildInputs = [
      crypto
      sys
    ];
    meta.useUnstable = true;
    date = "2018-03-29";
  };

  logutils = buildFromGitHub {
    version = 6;
    date = "2015-06-09";
    rev = "0dc08b1671f34c4250ce212759ebd880f743d883";
    owner  = "hashicorp";
    repo   = "logutils";
    sha256 = "1g005p42a22ag4qvkb2jx50z638r21vrvvgpwpd3c1d3qazjg7ha";
  };

  lsync = buildFromGitHub {
    version = 6;
    rev = "f332c3883f63c75ea6c95eae3aec71a2b2d88b49";
    owner = "minio";
    repo = "lsync";
    sha256 = "0ifljlsl3f67hlkgzzrl6ffzwbxximw445v574ljd6nqs4j3c4rn";
    date = "2018-03-28";
  };

  lumberjack_v2 = buildFromGitHub {
    version = 6;
    rev = "v2.1";
    owner  = "natefinch";
    repo   = "lumberjack";
    sha256 = "06k6f5gy2ba35z2dcmv62415frf7jbdcnxrlvwn1bky8q8zp4m1l";
    goPackagePath = "gopkg.in/natefinch/lumberjack.v2";
  };

  lxd = buildFromGitHub {
    version = 6;
    rev = "lxd-3.0.0";
    owner  = "lxc";
    repo   = "lxd";
    sha256 = "084sivbypahhgz299m9ia0chkzvhiw9dqqacnckj6zmhwkcgn53j";
    postPatch = ''
      find . -name \*.go -exec sed -i 's,uuid.NewRandom(),uuid.New(),g' {} \;
    '';
    excludedPackages = "\\(test\\|benchmark\\)"; # Don't build the binary called test which causes conflicts
    buildInputs = [
      pkgs.acl
      pkgs.lxc
    ];
    propagatedBuildInputs = [
      bolt
      cobra
      crypto
      dqlite
      environschema_v1
      errors
      gettext
      gocapability
      golang-petname
      gomaasapi
      go-colorable
      go-grpc-sql
      go-lxc_v2
      CanonicalLtd_go-sqlite3
      grpc
      idmclient
      macaroon-bakery_v2
      mux
      net
      google_uuid
      persistent-cookiejar
      pongo2
      protobuf
      raft
      raft-boltdb
      raft-http
      raft-membership
      testify
      tablewriter
      tomb_v2
      yaml_v2
      websocket
    ];
  };

  lz4 = buildFromGitHub {
    version = 5;
    rev = "v1.1";
    owner  = "pierrec";
    repo   = "lz4";
    sha256 = "0v9bqxkq6l8d04jh951m3aqjjmx0xjfgsg09wgis51k60wpjh89y";
    propagatedBuildInputs = [
      pierrec_xxhash
    ];
  };

  macaroon-bakery_v2 = buildFromGitHub {
    version = 5;
    rev = "v2.0.1";
    owner  = "go-macaroon-bakery";
    repo   = "macaroon-bakery";
    sha256 = "0rdb7as8y25wqb02r553xra1paqmq93n512nrs92yvnjd4511z0l";
    goPackagePath = "gopkg.in/macaroon-bakery.v2";
    excludedPackages = "\\(test\\|example\\)";
    propagatedBuildInputs = [
      crypto
      environschema_v1
      errgo_v1
      fastuuid
      httprequest_v1
      httprouter
      loggo
      macaroon_v2
      mgo_v2
      net
      protobuf
      webbrowser
    ];
  };

  macaroon_v2 = buildFromGitHub {
    version = 5;
    rev = "v2.0.0";
    owner  = "go-macaroon";
    repo   = "macaroon";
    sha256 = "1jlfv4s09q0i62vkwya4jbivfhy65qgyk6i971lscrxg5hffx3vn";
    goPackagePath = "gopkg.in/macaroon.v2";
    propagatedBuildInputs = [
      crypto
    ];
  };

  macaron_v1 = buildFromGitHub {
    version = 5;
    rev = "v1.3.1";
    owner  = "go-macaron";
    repo   = "macaron";
    sha256 = "181p251asm4vz56a87ah9xi1zpq6z095ybxrj4ybnwgrhrv4x8dj";
    goPackagePath = "gopkg.in/macaron.v1";
    propagatedBuildInputs = [
      com
      crypto
      ini_v1
      inject
    ];
  };

  mafmt = buildFromGitHub {
    version = 5;
    date = "2018-01-20";
    rev = "ab6a47300c1df531e468771e7d08fcd6d33f032e";
    owner = "whyrusleeping";
    repo = "mafmt";
    sha256 = "1271ff3nx64gin1z6hhxml1vzyjq934cys8bs02i809zimrwyh2x";
    propagatedBuildInputs = [
      go-multiaddr
    ];
  };

  mail_v2 = buildFromGitHub {
    version = 6;
    rev = "2.2.0";
    owner = "go-mail";
    repo = "mail";
    sha256 = "0xf504bi297w733pcjrxbh74ap5ylh0agqxblfwvzfm30x6jxpgi";
    goPackagePath = "gopkg.in/mail.v2";
    propagatedBuildInputs = [
      quotedprintable_v3
    ];
  };

  mage = buildFromGitHub {
    version = 6;
    rev = "2.1";
    owner = "magefile";
    repo = "mage";
    sha256 = "1psd827jpwr2xl13jxj9b820hdmydglwfgjnb5im2rcagbszs0ay";
    excludedPackages = "testdata";
  };

  mapstructure = buildFromGitHub {
    version = 5;
    date = "2018-02-20";
    rev = "00c29f56e2386353d58c599509e8dc3801b0d716";
    owner  = "mitchellh";
    repo   = "mapstructure";
    sha256 = "034n8nmfbx5873s84ymyxlxv2458ivj21g2wi96dfj425pfa2rsk";
  };

  match = buildFromGitHub {
    version = 6;
    owner = "tidwall";
    repo = "match";
    date = "2017-10-02";
    rev = "1731857f09b1f38450e2c12409748407822dc6be";
    sha256 = "1ydj4jkyx89q3v2z4apj66vmfr5dcc227vg4a4izhca41mf11cbk";
  };

  maxminddb-golang = buildFromGitHub {
    version = 5;
    rev = "v1.3.0";
    owner  = "oschwald";
    repo   = "maxminddb-golang";
    sha256 = "1srrf03bm32dfb8hzpmh698f4vf8aqbxxlqwwdln3z20iagh4fvv";
    propagatedBuildInputs = [
      sys
    ];
  };

  mc = buildFromGitHub {
    version = 6;
    owner = "minio";
    repo = "mc";
    rev = "1b794a4ae1af46bdeb86fbdb7ba16bbd31366d83";
    sha256 = "05x92p09pfkkw6gdrhcmvkkz3kipd7vkzfy8bmjg2c685c30b8s4";
    propagatedBuildInputs = [
      cli_minio
      color
      crypto
      go-colorable
      go-homedir
      go-humanize
      go-isatty
      go-version
      minio_pkg
      minio-go
      net
      notify
      pb
      profile
      text
      xattr
    ];
    meta.useUnstable = true;
    date = "2018-04-26";
  };

  mc_pkg = mc.override {
    subPackages = [
      "pkg/console"
    ];
    propagatedBuildInputs = [
      color
      go-colorable
      go-isatty
    ];
  };

  hashicorp_mdns = buildFromGitHub {
    version = 6;
    date = "2017-02-21";
    rev = "4e527d9d808175f132f949523e640c699e4253bb";
    owner = "hashicorp";
    repo = "mdns";
    sha256 = "0d7hknw06jsk3w7cvy5hrwg3y4dhzc5d2176vr0g624ww5jdzh64";
    propagatedBuildInputs = [
      dns
      net
    ];
  };

  whyrusleeping_mdns = buildFromGitHub {
    version = 6;
    date = "2017-02-03";
    rev = "348bb87e5cd39b33dba9a33cb20802111e5ee029";
    owner = "whyrusleeping";
    repo = "mdns";
    sha256 = "1vr6p0qjbwq5mk7zsxf40zzhxmik6sb2mnqdggz7r6lp3i7z736l";
    propagatedBuildInputs = [
      dns
      net
    ];
  };

  memberlist = buildFromGitHub {
    version = 5;
    rev = "2288bf30e9c8d7b5f6549bf62e07120d72fd4b6c";
    owner = "hashicorp";
    repo = "memberlist";
    sha256 = "1kgak886pkig6a52q7jb8h8dfz350j2zl2aq55798l1l0cywhdx4";
    propagatedBuildInputs = [
      dns
      ugorji_go
      armon_go-metrics
      go-multierror
      hashicorp_go-sockaddr
      seed
    ];
    meta.useUnstable = true;
    date = "2018-02-09";
  };

  memcache = buildFromGitHub {
    version = 6;
    date = "2015-06-22";
    rev = "1031fa0ce2f20c1c0e1e1b51951d8ea02c84fa05";
    owner = "rainycape";
    repo = "memcache";
    sha256 = "0fqi1yy90dgf82l7zr8hgn4jp5r5gg7wr3bb62mpjy9431bdkw1a";
  };

  mergo = buildFromGitHub {
    version = 6;
    rev = "v0.3.4";
    owner = "imdario";
    repo = "mergo";
    sha256 = "0bfriajr3wh1cm4c9yz6fklwjx9py49rh2488h8nw46aw6j0klj1";
  };

  mesh = buildFromGitHub {
    version = 6;
    rev = "61ba45522f8a5ac096d36674144357341b8ccea9";
    owner = "weaveworks";
    repo = "mesh";
    sha256 = "1qgw389yjf5208x6lpyvjzag55jh42qs8bgf2ai1xgjdnw75h6z9";
    date = "2018-04-16";
    propagatedBuildInputs = [
      crypto
    ];
  };

  metrics = buildFromGitHub {
    version = 6;
    date = "2017-07-14";
    rev = "fd99b46995bd989df0d163e320e18ea7285f211f";
    owner = "mailgun";
    repo = "metrics";
    sha256 = "0v7wmcjj4g04ggdcv6ncd4p7wprwmzjgld9c77w9yv6h4v7blnax";
    propagatedBuildInputs = [
      holster
      timetools
    ];
  };

  mgo_v2 = buildFromGitHub {
    version = 6;
    rev = "r2016.08.01";
    owner = "go-mgo";
    repo = "mgo";
    sha256 = "04mpjagap39x10pjxrxf4v90g7461qsx92llzqjnz1a1m1isba6v";
    goPackagePath = "gopkg.in/mgo.v2";
    excludedPackages = "dbtest";
    buildInputs = [
      pkgs.cyrus-sasl
    ];
  };

  minheap = buildFromGitHub {
    version = 6;
    rev = "3dbe6c6bf55f94c5efcf460dc7f86830c21a90b2";
    owner = "mailgun";
    repo = "minheap";
    sha256 = "1d0j7vzvqizq56dxb8kcp0krlnm18qsykkd064hkiafwapc3lbyd";
    date = "2017-06-19";
  };

  minio = buildFromGitHub {
    version = 6;
    owner = "minio";
    repo = "minio";
    rev = "d6df9b16ac537288eef5be2fc5ff22a43afd9400";
    sha256 = "1nh9q52xjfm3zq61qb4l9p52djaaf0i3wsncqhwcbr97g82kmi3g";
    propagatedBuildInputs = [
      aliyun-oss-go-sdk
      amqp
      atime
      azure-sdk-for-go
      atomic
      blazer
      cli_minio
      color
      cors
      crypto
      dsync
      elastic_v5
      gjson
      go-bindata-assetfs
      go-homedir
      go-humanize
      go-nats
      go-nats-streaming
      go-prompt
      go-update
      go-version
      google-api-go-client
      google-cloud-go
      handlers
      highwayhash
      jwt-go
      lsync
      mc_pkg
      minio-go
      mux
      mysql
      paho-mqtt-golang
      pb
      pq
      profile
      prometheus_client_golang
      redigo
      klauspost_reedsolomon
      rpc
      sarama_v1
      sio
      sha256-simd
      skyring-common
      structs
      sys
      time
      triton-go
      yaml_v2
    ];
    meta.useUnstable = true;
    date = "2018-05-02";
  };

  # The pkg package from minio, for bootstrapping minio
  minio_pkg = minio.override {
    propagatedBuildInputs = [
      gjson
      minio-go
      pb
      sha256-simd
      structs
      yaml_v2
    ];
    subPackages = [
      "pkg/madmin"
      "pkg/quick"
      "pkg/safe"
      "pkg/trie"
      "pkg/wildcard"
      "pkg/words"
    ];
  };

  minio-go = buildFromGitHub {
    version = 6;
    owner = "minio";
    repo = "minio-go";
    rev = "6.0.1";
    sha256 = "0jijxx1g90lpja0m2ffdm3mi7wa5liy8pc7bfc4kj4nyg29mf4vl";
    propagatedBuildInputs = [
      crypto
      go-homedir
      ini
      net
    ];
  };

  mmap-go = buildFromGitHub {
    version = 6;
    owner = "edsrzf";
    repo = "mmap-go";
    rev = "0bce6a6887123b67a60366d2c9fe2dfb74289d2e";
    sha256 = "0s4wdrflb0qscrf2yr00wm00sgjz9w6dcknyxxwr2zy4larli2nl";
    date = "2017-03-20";
  };

  mmark = buildFromGitHub {
    version = 6;
    owner = "miekg";
    repo = "mmark";
    rev = "v1.3.6";
    sha256 = "1prcgb8xqvzqvwky9mz5yq386hjhl2194ly6rg4aakqc3651rspi";
    propagatedBuildInputs = [
      toml
    ];
  };

  moby = buildFromGitHub {
    version = 6;
    owner = "moby";
    repo = "moby";
    rev = "51a9119f6b817bbae21805ec05787d462c9492cd";
    date = "2018-05-02";
    sha256 = "163bkmsk0s35xv87r792xmpyw31cmygnz0d7lfscpxipk700csah";
    goPackageAliases = [
      "github.com/docker/docker"
    ];
    postPatch = ''
      find . -name \*.go -exec sed -i 's,github.com/docker/docker,github.com/moby/moby,g' {} \;
    '';
    meta.useUnstable = true;
  };

  moby_lib = moby.override {
    subPackages = [
      "api/types"
      "api/types/blkiodev"
      "api/types/container"
      "api/types/filters"
      "api/types/mount"
      "api/types/network"
      "api/types/registry"
      "api/types/strslice"
      "api/types/swarm"
      "api/types/swarm/runtime"
      "api/types/versions"
      "daemon/caps"
      "daemon/cluster/convert"
      "errdefs"
      "opts"
      "pkg/archive"
      "pkg/fileutils"
      "pkg/homedir"
      "pkg/idtools"
      "pkg/ioutils"
      "pkg/jsonmessage"
      "pkg/longpath"
      "pkg/mount"
      "pkg/namesgenerator"
      "pkg/pools"
      "pkg/stdcopy"
      "pkg/stringid"
      "pkg/system"
      "pkg/tarsum"
      "pkg/term"
      "pkg/term/windows"
      "reference"
      "registry"
      "registry/resumable"
    ];
    propagatedBuildInputs = [
      continuity
      distribution_for_moby
      errors
      go-ansiterm
      go-connections
      go-digest
      go-units
      go-winio
      gocapability
      gogo_protobuf
      gotty
      image-spec
      libnetwork
      logrus
      net
      pflag
      runc
      swarmkit
      sys
    ];
  };

  mongo-tools = buildFromGitHub {
    version = 6;
    rev = "r3.7.9";
    owner  = "mongodb";
    repo   = "mongo-tools";
    sha256 = "1pgcg6949yia0kv804iv6fsrmzcy9phjjb8qk904ls5d9bn7jfhq";
    buildInputs = [
      pkgs.libpcap
    ];
    propagatedBuildInputs = [
      crypto
      escaper
      go-cache
      go-flags
      gopacket
      gopass
      mgo_v2
      openssl
      snappy
      termbox-go
      tomb_v2
    ];
    excludedPackages = "test";
    postPatch = ''
      mv vendor/src/github.com/10gen/llmgo "$NIX_BUILD_TOP"/llmgo
    '';
    preBuild = ''
      mkdir -p $(echo unpack/mgo*)/src/github.com/10gen
      mv llmgo unpack/mgo*/src/github.com/10gen
    '';
    extraSrcs = [ {
      goPackagePath = "github.com/10gen/llmgo";
      src = null;
    } ];

    # Mongodb incorrectly names all of their binaries main
    # Let's work around this with our own installer
    preInstall = ''
      mkdir -p $bin/bin
      while read b; do
        rm -f go/bin/main
        go install $buildFlags "''${buildFlagsArray[@]}" $goPackagePath/$b/main
        cp go/bin/main $bin/bin/$b
      done < <(find go/src/$goPackagePath -name main | xargs dirname | xargs basename -a)
      rm -r go/bin
    '';
  };

  mousetrap = buildFromGitHub {
    version = 6;
    rev = "v1.0";
    owner = "inconshreveable";
    repo = "mousetrap";
    sha256 = "1sy1m32bi57ihnji1aidmmrvnpgl65rr46pz229nx0384girslzk";
  };

  mow-cli = buildFromGitHub {
    version = 6;
    rev = "v1.0.3";
    owner  = "jawher";
    repo   = "mow.cli";
    sha256 = "0ws8z79dvdi2i3227sg0a80fapvwv9m1pcxy10ypn55vhw9qypvn";
  };

  ns1-go_v2 = buildFromGitHub {
    version = 5;
    rev = "a5bcac82d3f637d3928d30476610891935b2d691";
    owner  = "ns1";
    repo   = "ns1-go";
    sha256 = "03wrg73xg2gl115f1pbz86qzxyjhcac56yc2chkq7ip0xig3pc3w";
    goPackagePath = "gopkg.in/ns1/ns1-go.v2";
    date = "2018-03-15";
  };

  msgp = buildFromGitHub {
    version = 6;
    rev = "3b5c87ab5fb00c660bf85b888445d9a01db64db4";
    owner  = "tinylib";
    repo   = "msgp";
    sha256 = "197zvpmpcri8hlkrjcvv4cal7689x3ynccdp8j9b868gkmxs64lf";
    propagatedBuildInputs = [
      fwd
      chalk
      tools
    ];
    date = "2018-02-15";
  };

  multiaddr-filter = buildFromGitHub {
    version = 6;
    rev = "e903e4adabd70b78bc9293b6ee4f359afb3f9f59";
    owner  = "whyrusleeping";
    repo   = "multiaddr-filter";
    sha256 = "0p8d06rm2zazq14ri9890q9n62nli0jsfyy15cpfy7wxryql84n7";
    date = "2016-05-16";
  };

  multibuf = buildFromGitHub {
    version = 6;
    rev = "565402cd71fbd9c12aa7e295324ea357e970a61e";
    owner  = "mailgun";
    repo   = "multibuf";
    sha256 = "1csjfl3bcbya7dq3xm1nqb5rwrpw5migrqa4ajki242fa5i66mdr";
    date = "2015-07-14";
  };

  multierr = buildFromGitHub {
    version = 5;
    rev = "ddea229ff1dff9e6fe8a6c0344ac73b09e81fce5";
    owner  = "uber-go";
    repo   = "multierr";
    sha256 = "14gj29ikqr1jx7sgyh8zd55r8vn5wiyi0r0dss45fgpn5nnibgxz";
    goPackagePath = "go.uber.org/multierr";
    propagatedBuildInputs = [
      atomic
    ];
    date = "2018-01-22";
  };

  murmur3 = buildFromGitHub {
    version = 5;
    rev = "v1.1";
    owner  = "spaolacci";
    repo   = "murmur3";
    sha256 = "0g576p7ma7r4r1dcbiqi704i3mqnab0nygpya5lrc3g7ia39prmb";
  };

  mux = buildFromGitHub {
    version = 5;
    rev = "v1.6.1";
    owner = "gorilla";
    repo = "mux";
    sha256 = "0mjnfrimyq8ggld7swissyyr9kk8nxy3knv1ndqv8n0h6mfbxkw1";
    propagatedBuildInputs = [
      context
    ];
  };

  mysql = buildFromGitHub {
    version = 6;
    rev = "3287d94d4c6a48a63e16fffaabf27ab20203af2a";
    owner  = "go-sql-driver";
    repo   = "mysql";
    sha256 = "05bbq6ypnl4zkdrj3miyyb5kwscagrqmhkmnkhm7b5vb6l298lnv";
    postPatch = ''
      grep -r '+build appengine' -l | xargs rm
    '';
    date = "2018-04-13";
  };

  names_v2 = buildFromGitHub {
    version = 6;
    date = "2017-11-13";
    rev = "54f00845ae470a362430a966fe17f35f8784ac92";
    owner = "juju";
    repo = "names";
    sha256 = "1cb6zk2l5n89w2pdm7lcq8bbfa4bskbfcqcl00yhnj8pm82r049v";
    goPackagePath = "gopkg.in/juju/names.v2";
    propagatedBuildInputs = [
      juju_errors
      utils_for_names
    ];
  };

  net-rpc-msgpackrpc = buildFromGitHub {
    version = 6;
    date = "2015-11-16";
    rev = "a14192a58a694c123d8fe5481d4a4727d6ae82f3";
    owner = "hashicorp";
    repo = "net-rpc-msgpackrpc";
    sha256 = "1mnhdy4mj279q9sn3rmrpcz66fivv9grfkj73kia82vmxs78b6y8";
    propagatedBuildInputs = [
      ugorji_go
      go-multierror
    ];
  };

  netlink = buildFromGitHub {
    version = 5;
    rev = "v1.0.0";
    owner  = "vishvananda";
    repo   = "netlink";
    sha256 = "1fp489fj5kd4bqf2c7qkhcb12gyndn9s87cv0bmwkxazs5zzrqmh";
    propagatedBuildInputs = [
      netns
      sys
    ];
  };

  netns = buildFromGitHub {
    version = 6;
    rev = "be1fbeda19366dea804f00efff2dd73a1642fdcc";
    owner  = "vishvananda";
    repo   = "netns";
    sha256 = "1v0azn8ndn1cdx254rs5v9agwqkiwn7bgfrshvx6gxhpghxk1x26";
    date = "2017-11-11";
  };

  nitro = buildFromGitHub {
    version = 6;
    owner = "spf13";
    repo = "nitro";
    rev = "24d7ef30a12da0bdc5e2eb370a79c659ddccf0e8";
    date = "2013-10-03";
    sha256 = "0207jgc4wpkp1867c0vanimvr3x1ksawb5xi8ilf5rq88jbdlx5v";
  };

  nodb = buildFromGitHub {
    version = 6;
    owner = "lunny";
    repo = "nodb";
    rev = "fc1ef06ad4af0da31cdb87e3fa5ec084c67e6597";
    date = "2016-06-21";
    sha256 = "0smrcavlglwsb15fqissgh9rs63cf5yqff68s1jxggmcnmw6cxhx";
    propagatedBuildInputs = [
      goleveldb
      lunny_log
      go-snappy
      toml
    ];
  };

  nomad = buildFromGitHub {
    version = 6;
    rev = "v0.8.3";
    owner = "hashicorp";
    repo = "nomad";
    sha256 = "1kq29dfm7g8z4blk2n7z9rb3p0883mbdxrmz17k87lmcpc26z94h";

    nativeBuildInputs = [
      ugorji_go.bin
    ];

    buildInputs = [
      armon_go-metrics
      bolt
      circbuf
      colorstring
      columnize
      complete
      consul_api
      consul-template
      copystructure
      cors
      cronexpr
      crypto
      distribution_for_moby
      docker_cli
      go-checkpoint
      go-cleanhttp
      go-bindata-assetfs
      go-dockerclient
      go-envparse
      go-getter
      go-humanize
      go-immutable-radix
      go-lxc_v2
      go-memdb
      go-multierror
      go-plugin
      go-ps
      go-rootcerts
      hashicorp_go-sockaddr
      go-semver
      go-syslog
      go-testing-interface
      go-version
      hashicorp_go-uuid
      golang-lru
      gopsutil
      gziphandler
      hashstructure
      hcl
      logutils
      mapstructure
      memberlist
      mitchellh_cli
      moby_lib
      net-rpc-msgpackrpc
      open-golang
      prometheus_client_golang
      raft
      raft-boltdb
      rkt
      runc
      seed
      serf
      snappy
      spec_appc
      srslog
      sync
      sys
      tail
      kr_text
      time
      tomb_v1
      tomb_v2
      ugorji_go
      vault_api
      hashicorp_yamux
    ];

    excludedPackages = "\\(test\\|mock\\)";

    postPatch = ''
      find . -name \*.go -exec sed \
        -e 's,"github.com/docker/docker/reference","github.com/docker/distribution/reference",g' \
        -e 's,github.com/docker/docker/cli,github.com/docker/cli/cli,' \
        -e 's,.ParseNamed,.ParseNormalizedNamed,g' \
        -i {} \;

      # Remove test junk
      find . \( -name testutil -or -name testagent.go \) -prune -exec rm -r {} \;

      # Remove all autogenerate stuff
      find . -name \*.generated.go -delete
    '';

    #preBuild = ''
    #  pushd go/src/$goPackagePath
    #  go list ./... | xargs go generate
    #  popd
    #'';

    postInstall = ''
      rm "$bin"/bin/app
    '';
  };

  nomad_api = nomad.override {
    nativeBuildInputs = [
    ];
    buildInputs = [
    ];
    postPatch = ''
    '';
    preBuild = ''
    '';
    postInstall = ''
    '';
    subPackages = [
      "acl"
      "api"
      "api/contexts"
      "helper"
      "helper/args"
      "helper/flatmap"
      "helper/uuid"
      "nomad/structs"
    ];
    propagatedBuildInputs = [
      consul_api
      copystructure
      cronexpr
      crypto
      go-cleanhttp
      go-immutable-radix
      go-multierror
      go-rootcerts
      go-version
      ugorji_go
      golang-lru
      hashstructure
      hcl
      raft
    ];
  };

  notify = buildFromGitHub {
    version = 6;
    owner = "syncthing";
    repo = "notify";
    date = "2018-04-20";
    rev = "b9ceffc925039c77cd9e0d38f248279ccc4399e2";
    sha256 = "1cqs9p3nkx221949jrndky2qcyh4x24skw54r82mq00c62v206rc";
    goPackageAliases = [
      "github.com/rjeczalik/notify"
    ];
    propagatedBuildInputs = [
      sys
    ];
  };

  nuid = buildFromGitHub {
    version = 6;
    rev = "3e58d42c9cfe5cd9429f1a21ad8f35cd859ba829";
    owner = "nats-io";
    repo = "nuid";
    sha256 = "1n4jr4x7s3dcm4z6ac6badsz538acr4ghw0lmv8rmzixv0mxnvd4";
    date = "2018-03-17";
  };

  objx = buildFromGitHub {
    version = 5;
    rev = "v0.1";
    owner  = "stretchr";
    repo   = "objx";
    sha256 = "16krz6gc190c870wjvffz8z3n1wrm37qnmp0fy1wr5ds1kvh80qj";
  };

  oklog = buildFromGitHub {
    version = 6;
    rev = "v0.3.2";
    owner = "oklog";
    repo = "oklog";
    sha256 = "0idkybsskw18zw7gba17bmwcxdri0xn465b9hr02bc6gslg8vzvb";
    subPackages = [
      "pkg/group"
    ];
    propagatedBuildInputs = [
      run
    ];
  };

  oktasdk-go = buildFromGitHub {
    version = 5;
    owner = "chrismalek";
    repo = "oktasdk-go";
    rev = "d0c464c6e7d0c3407d2ec2da7a5818536e600515";
    date = "2018-02-13";
    sha256 = "0cd2h42z9m69g6gmyqf8w9ga24yc53v27bwxx47pf8ynjc63ipaq";
    propagatedBuildInputs = [
      go-querystring
    ];
  };

  opencensus = buildFromGitHub {
    version = 6;
    owner = "census-instrumentation";
    repo = "opencensus-go";
    rev = "c11636694056ed1d664b058521f3aa61016da8ba";
    sha256 = "10qhjajyf1y9a0sm14if7gn1xihjs3p5nawdxihs291ymkrw5212";
    goPackagePath = "go.opencensus.io";
    subPackages = [
      "exporter/stackdriver/propagation"
      "internal"
      "internal/tagencoding"
      "plugin/ocgrpc"
      "plugin/ochttp"
      "plugin/ochttp/propagation/b3"
      "stats"
      "stats/internal"
      "stats/view"
      "tag"
      "trace"
      "trace/internal"
      "trace/propagation"
    ];
    propagatedBuildInputs = [
      grpc
      net
    ];
    meta.useUnstable = true;
    date = "2018-05-02";
  };

  open-golang = buildFromGitHub {
    version = 6;
    owner = "skratchdot";
    repo = "open-golang";
    rev = "75fb7ed4208cf72d323d7d02fd1a5964a7a9073c";
    date = "2016-03-02";
    sha256 = "18rwj86iwsh417vzn5877lbx4gky2fxnp8840p663p924l0hz46s";
  };

  openid-go = buildFromGitHub {
    version = 6;
    owner = "yohcop";
    repo = "openid-go";
    rev = "cfc72ed89575fe6b1b7b880d537ba0c5e37f7391";
    date = "2017-09-01";
    sha256 = "0dp2nkqxcc5hqnw0p2y1ak6cxjhf51mzxy344igaqnpf5aydx0n6";
    propagatedBuildInputs = [
      net
    ];
  };

  openssl = buildFromGitHub {
    version = 6;
    date = "2018-04-27";
    rev = "58f60a8e59ba35b53e6821bda7003c4ea626dbf9";
    owner = "10gen";
    repo = "openssl";
    sha256 = "0j42fj00gxpx9psadanwj5fxz354gdzd9lnw7iv8f2drwja3md48";
    goPackageAliases = [
      "github.com/spacemonkeygo/openssl"
    ];
    buildInputs = [
      pkgs.openssl
    ];
    propagatedBuildInputs = [
      spacelog
    ];
  };

  opentracing-go = buildFromGitHub {
    version = 6;
    owner = "opentracing";
    repo = "opentracing-go";
    rev = "6c572c00d1830223701e155de97408483dfcd14a";
    sha256 = "0j8m0bjk07ad1r1km8m6g5hwlqcjaffrnn9n9xiryha9m856fjmq";
    goPackageAliases = [
      "github.com/frrist/opentracing-go"
    ];
    excludedPackages = "harness";
    propagatedBuildInputs = [
      net
    ];
    date = "2018-04-12";
  };

  osext = buildFromGitHub {
    version = 6;
    date = "2017-05-10";
    rev = "ae77be60afb1dcacde03767a8c37337fad28ac14";
    owner = "kardianos";
    repo = "osext";
    sha256 = "0xbz5vjmgv6gf9f2xrhz48kcfmx5623fbcsw5x22s4hzwmvnb588";
    goPackageAliases = [
      "github.com/bugsnag/osext"
      "bitbucket.org/kardianos/osext"
    ];
  };

  otp = buildFromGitHub {
    version = 5;
    rev = "40d624026db6bba02e9ad012a27ed01ca9f4984b";
    owner = "pquerna";
    repo = "otp";
    sha256 = "1a861abj0hb0xaa0fvxymfl99hrz862y0bm55fygsnprqmb50vsm";
    propagatedBuildInputs = [
      barcode
    ];
    date = "2018-02-20";
  };

  oxy = buildFromGitHub {
    version = 6;
    owner = "vulcand";
    repo = "oxy";
    date = "2016-07-23";
    rev = "db85f00cac5466def1f6f2667063e6e38c1fe606";
    sha256 = "5e3941f2116168854f012b731efda9b22f41118b8149dd220abe44f810e9a49e";
    goPackageAliases = [ "github.com/mailgun/oxy" ];
    propagatedBuildInputs = [
      hdrhistogram
      mailgun_log
      multibuf
      predicate
      timetools
      mailgun_ttlmap
    ];
    meta.autoUpdate = false;
  };

  paho-mqtt-golang = buildFromGitHub {
    version = 6;
    owner = "eclipse";
    repo = "paho.mqtt.golang";
    rev = "v1.1.1";
    sha256 = "0nqziiql7fvkwr69hx3jd4q79lk2qxxspiijkdq1k7f5dsr6j3ls";
    propagatedBuildInputs = [
      net
    ];
  };

  pat = buildFromGitHub {
    version = 6;
    owner = "bmizerany";
    repo = "pat";
    date = "2017-08-15";
    rev = "6226ea591a40176dd3ff9cd8eff81ed6ca721a00";
    sha256 = "00ykc2zv61zlw3ai22cvldc85ljs92wijkcn7ijj5bb2hmx773p4";
  };

  pb = buildFromGitHub {
    version = 5;
    owner = "cheggaaa";
    repo = "pb";
    date = "2018-03-05";
    rev = "75a8cbd866a7bad0d4a3b2b8cb6cab48a1475155";
    sha256 = "12pl91n0pd161vzwdlgbklvhmn267ir9zy5hgr0jnz845dvyhi98";
    propagatedBuildInputs = [
      go-runewidth
      sys
    ];
    meta.useUnstable = true;
  };

  pb_v1 = buildFromGitHub {
    version = 5;
    owner = "cheggaaa";
    repo = "pb";
    rev = "v1.0.22";
    sha256 = "0ccj5h9x88dq6pf4j1b5v706vybx793d291bafkkn6wd7f6k3x8c";
    goPackagePath = "gopkg.in/cheggaaa/pb.v1";
    propagatedBuildInputs = [
      go-runewidth
      sys
    ];
  };

  perks = buildFromGitHub {
    version = 6;
    date = "2018-03-21";
    owner  = "beorn7";
    repo   = "perks";
    rev = "3a771d992973f24aa725d07868b467d1ddfceafb";
    sha256 = "1k2szih4wj386wmh2z2kdhmr3iifl90jc856pnfx29ckyzz54zb8";
  };

  persistent = buildFromGitHub {
    version = 5;
    date = "2018-03-01";
    owner  = "xiaq";
    repo   = "persistent";
    rev = "cd415c64068256386eb46bbbb1e56b461872feed";
    sha256 = "1nha332n4n4px21cilixy4y2zjjja79vab03f4hlx08syfyq5yqk";
  };

  persistent-cookiejar = buildFromGitHub {
    version = 6;
    date = "2017-10-26";
    owner  = "juju";
    repo   = "persistent-cookiejar";
    rev = "d5e5a8405ef9633c84af42fbcc734ec8dd73c198";
    sha256 = "06y2xzvhic8angzbv5pgwqh51k2m0s9f9flmdn9lzzzd677may9f";
    excludedPackages = "test";
    propagatedBuildInputs = [
      errgo_v1
      go4
      net
      retry_v1
    ];
  };

  pester = buildFromGitHub {
    version = 6;
    owner = "sethgrid";
    repo = "pester";
    rev = "03e26c9abbbf5accb8349790bf9f41bde09d72c3";
    date = "2018-04-30";
    sha256 = "1lxg20ysqh4r1j7b9wavi7p6rsn25j0a1dqrn05iqkh9qmzh3kqy";
  };

  pflag = buildFromGitHub {
    version = 6;
    owner = "spf13";
    repo = "pflag";
    rev = "v1.0.1";
    sha256 = "0b8l4pwv0i55m4wm482kd1vdzjslzispva5qplasdvz6vvirgq0m";
    goPackageAliases = [
      "github.com/ogier/pflag"
    ];
  };

  pidfile = buildFromGitHub {
    version = 6;
    owner = "facebookgo";
    repo = "pidfile";
    rev = "f242e2999868dcd267a2b86e49ce1f9cf9e15b16";
    sha256 = "0qhn6c5ax28dz4c6aqib0wrsr6k3nbm2v4189f7ig6dads1npjhj";
    date = "2015-06-12";
    propagatedBuildInputs = [
      atomicfile
    ];
  };

  pkcs7 = buildFromGitHub {
    version = 6;
    owner = "fullsailor";
    repo = "pkcs7";
    rev = "ae226422660e5ca10db350d33f81c6608f3fbcdd";
    date = "2018-04-22";
    sha256 = "120bx10nklrfrxpn6ffzn44dfysyzcpfsrwc90llfa1n7h7y5vqf";
  };

  pkg = buildFromGitHub {
    version = 5;
    date = "2018-01-08";
    owner  = "coreos";
    repo   = "pkg";
    rev = "97fdf19511ea361ae1c100dd393cc47f8dcfa1e1";
    sha256 = "0y3day5j98a52dpf8y4rcp9ayizgml02vljg4rfvfl26wg11rlsr";
    propagatedBuildInputs = [
      crypto
      go-systemd_journal
      yaml_v1
    ];
  };

  plz = buildFromGitHub {
    version = 5;
    owner  = "v2pro";
    repo   = "plz";
    rev = "0.9.1";
    sha256 = "0blavw4cyw7n46n81q7rjmn3jb8dgs24mcvkk80baj5xflbrn2x8";
    excludedPackages = "\\(witch\\|test\\|dump\\)";
  };

  poly1305 = buildFromGitHub {
    version = 6;
    rev = "969857f48f7ae439b6d2449ed1dcd9aaabc49c67";
    owner  = "aead";
    repo   = "poly1305";
    sha256 = "19ysvx7sy9wf79yy3af0ba45sj659rpkkmbrfkh8yc6jq6k61vxy";
    date = "2018-04-11";
  };

  pongo2 = buildFromGitHub {
    version = 6;
    rev = "e7cf9ea5ca9c574f3fd5f83f7eed4a6162a67dea";
    owner  = "flosch";
    repo   = "pongo2";
    sha256 = "0qnqpqiakmsfl4gx5syi15ivc9y2dyyppzlgq0mz1j66zbpdwffn";
    date = "2018-04-12";
    propagatedBuildInputs = [
      juju_errors
    ];
  };

  pprof = buildFromGitHub {
    version = 6;
    rev = "12989e0267c12f1b111ed0a7bebbf5ae4f34d5b9";
    owner  = "google";
    repo   = "pprof";
    sha256 = "1jwnpk29f3bpmnfn96b1ki9mkyvwm8zgycmkhiy92iibabblsqnw";
    date = "2018-05-01";
    propagatedBuildInputs = [
      demangle
      readline
    ];
  };

  pq = buildFromGitHub {
    version = 6;
    rev = "d34b9ff171c21ad295489235aec8b6626023cd04";
    owner  = "lib";
    repo   = "pq";
    sha256 = "134lqw3f9j8bdxghzddr3dx713lbzpi5f4s7c9x85mgvk0v252pj";
    date = "2018-03-27";
  };

  predicate = buildFromGitHub {
    version = 6;
    rev = "v1.1.0";
    owner  = "vulcand";
    repo   = "predicate";
    sha256 = "0p35vp2vjhkrkni24l1gcm4c7dccllgd6f8v3cjs0gnmxf7zqfll";
    propagatedBuildInputs = [
      trace
    ];
  };

  probing = buildFromGitHub {
    version = 6;
    rev = "0.0.1";
    owner  = "xiang90";
    repo   = "probing";
    sha256 = "0wjjml1dg64lfq4s1b6kqabz35pm02yfgc0nc8cp8y4aw2ip49vr";
  };

  procfs = buildFromGitHub {
    version = 6;
    rev = "8b1c2da0d56deffdbb9e48d4414b4e674bd8083e";
    date = "2018-04-08";
    owner  = "prometheus";
    repo   = "procfs";
    sha256 = "1p8m1lnsm094s59ffdk59xv2dbidn20q4vkig4rd5hwhijz6r87v";
  };

  profile = buildFromGitHub {
    version = 6;
    owner = "pkg";
    repo = "profile";
    rev = "v1.2.1";
    sha256 = "1r0kcrfn4vn6q5zcdmdkxiad4mlwxy8h0bmgffqvhn7y626cpjb5";
  };

  progmeter = buildFromGitHub {
    version = 6;
    owner = "whyrusleeping";
    repo = "progmeter";
    rev = "30d42a105341e640d284d9920da2078029764980";
    sha256 = "162rlxy065dq1acdwcr9y9lc6zx2pjqdqvngrq6bnrargw15avid";
    date = "2017-11-15";
  };

  prometheus = buildFromGitHub {
    version = 5;
    rev = "v2.2.1";
    owner  = "prometheus";
    repo   = "prometheus";
    sha256 = "1nym99y77v7ccnnjvsnb1j806w1nm6gzhvzkvl8srvh7r96a03fq";
    buildInputs = [
      aws-sdk-go
      cockroach
      cmux
      consul_api
      dns
      errors
      fsnotify_v1
      genproto
      go-autorest
      go-conntrack
      goleveldb
      gophercloud
      go-stdlib
      govalidator
      go-zookeeper
      google-api-go-client
      grpc
      grpc-gateway
      kingpin_v2
      kit_for_prometheus
      kubernetes-api
      kubernetes-apimachinery
      kubernetes-client-go
      net
      oauth2
      oklog
      opentracing-go
      prometheus_client_golang
      prometheus_client_model
      prometheus_common
      prometheus_tsdb
      gogo_protobuf
      snappy
      time
      cespare_xxhash
      yaml_v2
    ];
    postPatch = ''
      rm -r discovery/azure
      sed -i '/azure/d' discovery/config/config.go
      sed -e '/azure/d' -e '/Azure/,+2d' -i discovery/manager.go

      grep -q 'NodeLegacyHostIP' discovery/kubernetes/node.go
      sed \
        -e '/\.NodeLegacyHostIP/,+2d' \
        -e '\#"k8s.io/client-go/pkg/api"#d' \
        -i discovery/kubernetes/node.go

      grep -q 'k8s.io/client-go/pkg/apis' discovery/kubernetes/*.go
      sed \
        -e 's,k8s.io/client-go/pkg/apis,k8s.io/api,' \
        -e 's,k8s.io/client-go/pkg/api/v1,k8s.io/api/core/v1,' \
        -e 's,"k8s.io/client-go/pkg/api",api "k8s.io/api/core/v1",' \
        -i discovery/kubernetes/*.go
    '';
  };
  prometheus_pkg = prometheus.override {
    buildInputs = [
    ];
    propagatedBuildInputs = [
      cespare_xxhash
    ];
    subPackages = [
      "pkg/labels"
    ];
    postPatch = null;
  };

  prometheus_client_golang = buildFromGitHub {
    version = 6;
    rev = "82f5ff156b29e276022b1a958f7d385870fb9814";
    owner = "prometheus";
    repo = "client_golang";
    sha256 = "0k6a8sh6p2j0aqn33r75ywf0q25x8sw7q29gz0gmpn1fk7msiq32";
    propagatedBuildInputs = [
      net
      protobuf
      prometheus_client_model
      prometheus_common_for_client
      procfs
      perks
    ];
    date = "2018-04-16";
  };

  prometheus_client_model = buildFromGitHub {
    version = 6;
    rev = "99fa1f4be8e564e8a6b613da7fa6f46c9edafc6c";
    date = "2017-11-17";
    owner  = "prometheus";
    repo   = "client_model";
    sha256 = "0cv75ws6yba5a57616gfpb2n4pixcmcfq71fhins0qzqx1bgwvyx";
    buildInputs = [
      protobuf
    ];
  };

  prometheus_common = buildFromGitHub {
    version = 6;
    date = "2018-04-26";
    rev = "d811d2e9bf898806ecfb6ef6296774b13ffc314c";
    owner = "prometheus";
    repo = "common";
    sha256 = "1yxrk6xfw4isnmhwzrraqrlrbjh6cs9nzmn41n9955khhpc6zsqv";
    propagatedBuildInputs = [
      errors
      go-conntrack
      golang_protobuf_extensions
      httprouter
      logrus
      kit_for_prometheus
      kingpin_v2
      net
      prometheus_client_golang
      prometheus_client_model
      protobuf
      sys
      yaml_v2
    ];
  };

  prometheus_common_for_client = prometheus_common.override {
    subPackages = [
      "expfmt"
      "model"
      "internal/bitbucket.org/ww/goautoneg"
    ];
    propagatedBuildInputs = [
      golang_protobuf_extensions
      prometheus_client_model
      protobuf
    ];
  };

  prometheus_tsdb = buildFromGitHub {
    version = 6;
    date = "2018-04-13";
    rev = "def6e5a57439cffe7b44a619c05bce4ac513a63e";
    owner = "prometheus";
    repo = "tsdb";
    sha256 = "1zsbz9vyxwjgmgl1rrnpz8z642wig4hs8xvrjmggd13dyw5xqmm9";
    propagatedBuildInputs = [
      cespare_xxhash
      errors
      kingpin_v2
      kit_for_prometheus
      lockfile
      prometheus_client_golang
      sync
      sys
      ulid
    ];
  };

  properties = buildFromGitHub {
    version = 5;
    owner = "magiconair";
    repo = "properties";
    rev = "v1.7.6";
    sha256 = "1bnvwplxrp88vnmmaygfk08a93jai7pgbgryjc6wyxqd91716rpl";
  };

  prose = buildFromGitHub {
    version = 6;
    owner = "jdkato";
    repo = "prose";
    rev = "v1.1.0";
    sha256 = "1v334ys6m4zmknqa1f5nzzncaz0vybfc6mh3pliw2yn7ma39yjzb";
    propagatedBuildInputs = [
      urfave_cli
      go-shuffle
      sentences_v1
      stats
    ];
  };

  gogo_protobuf = buildFromGitHub {
    version = 5;
    owner = "gogo";
    repo = "protobuf";
    rev = "v1.0.0";
    sha256 = "1cfng3fx9mgi96bbi0z5phlz2bylfmgy80rzmwb2jqryafdgms2b";
    excludedPackages = "test";
  };

  pty = buildFromGitHub {
    version = 5;
    owner = "kr";
    repo = "pty";
    rev = "v1.1.1";
    sha256 = "0k507mp3j6vbx7vdlhp6dpbr5syh4zn14c1rqgf1p5jbh3raqbxb";
  };

  purell = buildFromGitHub {
    version = 5;
    owner = "PuerkitoBio";
    repo = "purell";
    rev = "975f53781597ed779763b7b65566e74c4004d8de";
    sha256 = "01bdjh5g5gx8b0jszxp4bz8l5y62q7mca5q9h607wn2lynz0akfx";
    propagatedBuildInputs = [
      net
      text
      urlesc
    ];
    date = "2018-03-10";
  };

  qart = buildFromGitHub {
    version = 6;
    rev = "0.1";
    owner  = "vitrun";
    repo   = "qart";
    sha256 = "1wka69q9yyryiyylrcwjnhv0mhlkk04b1nxzvhflbhqv1rz8y0g7";
  };

  qingstor-sdk-go = buildFromGitHub {
    version = 6;
    rev = "v2.2.12";
    owner  = "yunify";
    repo   = "qingstor-sdk-go";
    sha256 = "0wqks53af46jwlrlpfpizfm82zyspw695vmsbg1rqawwm24049f7";
    excludedPackages = "test";
    propagatedBuildInputs = [
      go-shared
      yaml_v2
    ];
    postPatch = ''
      grep -q 'StringToUnixTimestamp' request/signer/qingstor.go
      find . -name \*.go -exec sed -i 's,convert.StringToUnixTimestamp,convert.StringToTimestamp,g' {} \;
    '';
  };

  queue = buildFromGitHub {
    version = 5;
    rev = "093482f3f8ce946c05bcba64badd2c82369e084d";
    owner  = "eapache";
    repo   = "queue";
    sha256 = "02wayp8qdqkqvhfc6h3pqp9xfma38ls9ldjwb2zcj3dm3y9rl025";
    date = "2018-02-27";
  };

  quotedprintable_v3 = buildFromGitHub {
    version = 6;
    rev = "2caba252f4dc53eaf6b553000885530023f54623";
    owner  = "alexcesaro";
    repo   = "quotedprintable";
    sha256 = "1vxbp1n7439gb3vwynqaxdqcv0xlkzzxv88mpcvhsshzbiqhb1cs";
    goPackagePath = "gopkg.in/alexcesaro/quotedprintable.v3";
    date = "2015-07-16";
  };

  rabbit-hole = buildFromGitHub {
    version = 5;
    rev = "8ea6071d12bbf59ed5a948573bc0e3c350bbbc32";
    owner  = "michaelklishin";
    repo   = "rabbit-hole";
    sha256 = "0zbmri6wimpw12kna6vbr9jpszwb2452r9bf7kqii9gmygwjdvyf";
    date = "2018-03-09";
  };

  radius = buildFromGitHub {
    version = 6;
    rev = "8bc72f43fc7c1e5e9633adaca9531ee7231c542f";
    date = "2018-04-10";
    owner  = "layeh";
    repo   = "radius";
    sha256 = "1wihspqy891wch6r4gq82kgcjk6sgwrlz4xs7wga2hpq5hgc4fc4";
    goPackagePath = "layeh.com/radius";
  };

  raft = buildFromGitHub {
    version = 5;
    date = "2018-02-12";
    rev = "a3fb4581fb07b16ecf1c3361580d4bdb17de9d98";
    owner  = "hashicorp";
    repo   = "raft";
    sha256 = "17gx1nn3wgma4j3iqcpviyxjyy4zava69zx0gskvpxvp94cf9p53";
    meta.useUnstable = true;
    propagatedBuildInputs = [
      armon_go-metrics
      ugorji_go
    ];
    subPackages = [
      "."
    ];
  };

  raft-boltdb = buildFromGitHub {
    version = 6;
    date = "2017-10-10";
    rev = "6e5ba93211eaf8d9a2ad7e41ffad8c6f160f9fe3";
    owner  = "hashicorp";
    repo   = "raft-boltdb";
    sha256 = "0kircjb4ly26q9331pc45cdjhicm13zpgj4dq8azcxaj9gypd53g";
    propagatedBuildInputs = [
      bolt
      ugorji_go
      raft
    ];
  };

  raft-http = buildFromGitHub {
    version = 6;
    date = "2018-04-14";
    rev = "4c2dd679d3b46c11b250d63ae43467d4c4ab0962";
    owner  = "CanonicalLtd";
    repo   = "raft-http";
    sha256 = "0fi205a5liqav2hp4zm67wlpn6b65axrzp606zrcl70iv463l7dd";
    propagatedBuildInputs = [
      errors
      raft
      raft-membership
    ];
  };

  raft-membership = buildFromGitHub {
    version = 6;
    date = "2018-04-13";
    rev = "3846634b0164affd0b3dfba1fdd7f9da6387e501";
    owner  = "CanonicalLtd";
    repo   = "raft-membership";
    sha256 = "149wsy3lgsn2jzxl0sja4y8d1x9m5cpf97jl2zybgamxagc7jxy1";
    propagatedBuildInputs = [
      raft
    ];
  };

  ratecounter = buildFromGitHub {
    version = 6;
    owner = "paulbellamy";
    repo = "ratecounter";
    rev = "v0.2.0";
    sha256 = "0nivwcvpx1zsdysyn0ww3hl3ihayplh3hkw7qszmm9jii4ccrh9a";
  };

  ratelimit = buildFromGitHub {
    version = 5;
    rev = "1.0.1";
    owner  = "juju";
    repo   = "ratelimit";
    sha256 = "0lg302miyrkff04a1jqfrz1kdb96miw7qrm3x3g21n7w3vp40y4g";
  };

  raven-go = buildFromGitHub {
    version = 6;
    date = "2018-04-30";
    rev = "263040ce1a362270b5897a5982572ddc1fe807be";
    owner  = "getsentry";
    repo   = "raven-go";
    sha256 = "12kyd28xlw8zgqj7qx91h09r5phzszywlxy6i5xjcpqa791l0jd0";
    propagatedBuildInputs = [
      errors
      gocertifi
    ];
  };

  rclone = buildFromGitHub {
    version = 6;
    owner = "ncw";
    repo = "rclone";
    date = "2018-05-01";
    rev = "f2608e2a64455ef70be69c17a3d3e488d78cfa3e";
    sha256 = "1sidwdjxiqjgnl2g1da1yw4nsmkxc8f7bmhkljh7vclza6hj994h";
    propagatedBuildInputs = [
      appengine
      aws-sdk-go
      bbolt
      cgofuse
      cobra
      crypto
      eme
      errors
      ewma
      fs
      ftp
      fuse
      go-acd
      go-cache
      go-daemon
      go-http-auth
      go-mega
      goconfig
      google-api-go-client
      net
      oauth2
      open-golang
      pflag
      qingstor-sdk-go
      sdnotify
      sftp
      ssh-agent
      swift
      sys
      termbox-go
      testify
      text
      time
      times
      tree
    ];
    postPatch = ''
      # Azure-sdk-for-go does not provide a stable api
      rm -r backend/azureblob/
      sed -i backend/all/all.go \
        -e '/azureblob/d'

      # Dropbox doesn't build easily
      rm -r backend/dropbox/
      sed -i backend/all/all.go \
        -e '/dropbox/d'
      sed -i fs/hash/hash.go \
        -e '/dbhash/d'
    '';
    meta.useUnstable = true;
  };

  cupcake_rdb = buildFromGitHub {
    version = 6;
    date = "2016-11-07";
    rev = "43ba34106c765f2111c0dc7b74cdf8ee437411e0";
    owner = "cupcake";
    repo = "rdb";
    sha256 = "07gi5a9293y7lic7w5n6g5nckvhvx9xpny9sp7zsy2c2rjx1ij65";
  };

  siddontang_rdb = buildFromGitHub {
    version = 6;
    date = "2015-03-07";
    rev = "fc89ed2e418d27e3ea76e708e54276d2b44ae9cf";
    owner = "siddontang";
    repo = "rdb";
    sha256 = "0q2jpnjyr1gqjl50m3xwa3mqwryn14i9jcl7nwxw0yvxh6vlvnhh";
    propagatedBuildInputs = [
      cupcake_rdb
    ];
  };

  readline = buildFromGitHub {
    version = 6;
    owner = "chzyer";
    repo = "readline";
    date = "2017-12-08";
    rev = "f6d7a1f6fbf35bbf9beb80dc63c56a29dcfb759f";
    sha256 = "0b9yzr959iqc5kyisxpw6vp2wra5jm59ql2bkkcdz0a91b6mial3";
    excludedPackages = "example";
    propagatedBuildInputs = [
      sys
    ];
  };

  redigo = buildFromGitHub {
    version = 6;
    owner = "garyburd";
    repo = "redigo";
    date = "2018-04-04";
    rev = "569eae59ada904ea8db7a225c2b47165af08735a";
    sha256 = "0fzyzwszy9pa6izra69slj8izj7s15gndcj7zffyqnlh3y6ds2d6";
    meta.useUnstable = true;
  };

  redis_v2 = buildFromGitHub {
    version = 6;
    rev = "v2.3.2";
    owner  = "go-redis";
    repo   = "redis";
    sha256 = "0cy5r0s4wzg39cxr2c06sg7pvivnxsdzh1340qimf3399bjz0i99";
    goPackagePath = "gopkg.in/redis.v2";
    propagatedBuildInputs = [
      bufio_v1
    ];
  };

  klauspost_reedsolomon = buildFromGitHub {
    version = 5;
    owner = "klauspost";
    repo = "reedsolomon";
    date = "2017-12-19";
    rev = "0b30fa71cc8e4e9010c9aba6d0320e2e5b163b29";
    sha256 = "1dki3v9qjx47lwr4d0bb05r7bncl4yy6issnf05dc706aara4mr6";
    propagatedBuildInputs = [
      cpuid
    ];
    meta.useUnstable = true;
  };

  reflect2 = buildFromGitHub {
    version = 5;
    rev = "1.0.0";
    owner  = "modern-go";
    repo   = "reflect2";
    sha256 = "0algyl8i67y5i6c28c2hf31i9jxqb3q2pi1acz1y2b5hrj68w6wz";
    propagatedBuildInputs = [
      concurrent
    ];
  };

  reflectwalk = buildFromGitHub {
    version = 6;
    date = "2017-07-26";
    rev = "63d60e9d0dbc60cf9164e6510889b0db6683d98c";
    owner  = "mitchellh";
    repo   = "reflectwalk";
    sha256 = "1xpgzn3rgc222yz09nmn1h8xi2769x3b5cmb23wch0w43cj8inkz";
  };

  regexp2 = buildFromGitHub {
    version = 6;
    rev = "v1.1.6";
    owner  = "dlclark";
    repo   = "regexp2";
    sha256 = "1jb5ln420ic5w719msd6sdyd5ck88fxj50wxy7g2lyirm1mklgsd";
  };

  resize = buildFromGitHub {
    version = 5;
    owner = "nfnt";
    repo = "resize";
    date = "2018-02-21";
    rev = "83c6a9932646f83e3267f353373d47347b6036b2";
    sha256 = "051hb20f94gy5s8ng9x9zldikwrva10nq0mg9qlv6g7h99yl5xia";
  };

  retry_v1 = buildFromGitHub {
    version = 5;
    owner = "go-retry";
    repo = "retry";
    rev = "v1.0.0";
    sha256 = "181q1f5w65j1y068rz8rm1yv8rpm86fbzfmb81h03jh0s5w14w6d";
    goPackagePath = "gopkg.in/retry.v1";
  };

  rkt = buildFromGitHub {
    version = 6;
    owner = "rkt";
    repo = "rkt";
    rev = "601d9887c5f3659c0e5f72ce1f839787c55fd1f3";
    sha256 = "182as2wn5w75jyh7zs5bzz0wlwsikgrmls96b4y2fv5rqqckxgp8";
    subPackages = [
      "api/v1"
      "networking/netinfo"
    ];
    propagatedBuildInputs = [
      cni
    ];
    meta.useUnstable = true;
    date = "2018-04-16";
  };

  roaring = buildFromGitHub {
    version = 6;
    rev = "v0.4.6";
    owner  = "RoaringBitmap";
    repo   = "roaring";
    sha256 = "10li208g5hwxifhcvn7c49vp6xbmz26729s5z6vvx2cvsw06kzpp";
    propagatedBuildInputs = [
      go-unsnap-stream
      msgp
    ];
  };

  rollinghash = buildFromGitHub {
    version = 5;
    rev = "v3.0.1";
    owner  = "chmduquesne";
    repo   = "rollinghash";
    sha256 = "0vypx2hv37fqhrfcvqy208bvyvq25zr9w830xfmh6nscxb9dfrdd";
    propagatedBuildInputs = [
      bytefmt
    ];
  };

  roundtrip = buildFromGitHub {
    version = 6;
    owner = "gravitational";
    repo = "roundtrip";
    rev = "0.0.2";
    sha256 = "12qqkm9pn398g5bfnaknynii4yqc2sa1i8qhzpp8jkdqf3bczcvz";
    propagatedBuildInputs = [
      trace
    ];
  };

  rpc = buildFromGitHub {
    version = 6;
    owner = "gorilla";
    repo = "rpc";
    rev = "v1.1.0";
    sha256 = "0a546446ybispwpvqnwz3bm3pzldfjg97d6x11svhgsc9fl7hn1p";
  };

  rsc = buildFromGitHub {
    version = 6;
    owner = "mdp";
    repo = "rsc";
    date = "2016-01-31";
    rev = "90f07065088deccf50b28eb37c93dad3078c0f3c";
    sha256 = "1isnkr17k3h6bfvhhwdhdyprhmgsgm9zd9ir1x3yz5ym99w3di1i";
    buildInputs = [
      pkgs.qrencode
    ];
  };

  run = buildFromGitHub {
    version = 5;
    rev = "v1.0.0";
    owner = "oklog";
    repo = "run";
    sha256 = "0m6zlr3dric91r1fina1ng26zj7zpq97rqmnxgxj5ylmw3ah3jw9";
  };

  runc = buildFromGitHub {
    version = 6;
    rev = "0cbfd8392fff2462701507296081e835b3b0b99a";
    owner = "opencontainers";
    repo = "runc";
    sha256 = "06n3dmj5s2l3x13wpkm2dbyvwidz6jpy0galaz6ny9cxzxral8gg";
    propagatedBuildInputs = [
      urfave_cli
      console
      dbus
      filepath-securejoin
      fileutils
      go-systemd
      go-units
      gocapability
      libseccomp-golang
      logrus
      netlink
      protobuf
      runtime-spec
      selinux
      sys
    ];
    date = "2018-04-26";
    postPatch = ''
      grep -q 'unix.SIGUNUSED' signalmap.go
      sed -i '/unix.SIGUNUSED/d' signalmap.go
    '';
  };

  runtime-spec = buildFromGitHub {
    version = 6;
    rev = "a1998ecf27964b493231626886dea534e2cfadc2";
    owner = "opencontainers";
    repo = "runtime-spec";
    sha256 = "1fqypfsi116h9q867jmap27aprmkh6kwnl8pd3j1c6qi321yqpz6";
    buildInputs = [
      gojsonschema
    ];
    #meta.autoUpdate = false;
    date = "2018-04-06";
  };

  safefile = buildFromGitHub {
    version = 5;
    owner = "dchest";
    repo = "safefile";
    rev = "855e8d98f1852d48dde521e0522408d1fe7e836a";
    date = "2015-10-22";
    sha256 = "0kpirwpndc7jy4plibbvz1yjbh10aa41a91jmsr7qixpif5m91zk";
  };

  sanitized-anchor-name = buildFromGitHub {
    version = 6;
    owner = "shurcooL";
    repo = "sanitized_anchor_name";
    rev = "86672fcb3f950f35f2e675df2240550f2a50762f";
    date = "2017-09-18";
    sha256 = "0sv8yfml115gd6wls4jnh9k476dlhhwkdk5x1dz5lypczv8w065v";
  };

  sarama = buildFromGitHub {
    version = 6;
    owner = "Shopify";
    repo = "sarama";
    rev = "v1.16.0";
    sha256 = "0l7msr5yra3fk7mh8bib47mglm4sdjzx448farcnr5z60hvdnyx9";
    propagatedBuildInputs = [
      go-resiliency
      go-spew
      go-xerial-snappy
      lz4
      queue
      rcrowley_go-metrics
    ];
  };

  sarama_v1 = buildFromGitHub {
    version = 5;
    owner = "Shopify";
    repo = "sarama";
    rev = "v1.16.0";
    sha256 = "0ns2cr1qzsslcdgfwbfwjffx2h3a1ywwlrlx3iky8m095qwd9d5g";
    goPackagePath = "gopkg.in/Shopify/sarama.v1";
    excludedPackages = "\\(mock\\|tools\\)";
    propagatedBuildInputs = [
      go-resiliency
      go-spew
      go-xerial-snappy
      lz4
      queue
      rcrowley_go-metrics
    ];
  };

  scaleway-sdk = buildFromGitHub {
    version = 6;
    owner = "nicolai86";
    repo = "scaleway-sdk";
    rev = "d749f7b83389f1afe19b81a610fad5ebb7a12744";
    sha256 = "0lp7a62h7d2arx8sfvacrvzqhpxwn9qyr8j5gs6lydyxvnq5lx9f";
    meta.useUnstable = true;
    date = "2018-04-01";
    goPackageAliases = [
      "github.com/nicolai86/scaleway-sdk/api"
    ];
    propagatedBuildInputs = [
      sync
    ];
  };

  schema = buildFromGitHub {
    version = 5;
    owner = "juju";
    repo = "schema";
    rev = "e4f08199aa80d3194008c0bd2e14ef5edc0e6be6";
    sha256 = "16drvgd3rgwda6wz6ivav9qrlzaasbjl8ardkkq9is4igxnjj1pg";
    date = "2018-01-09";
    propagatedBuildInputs = [
      utils
    ];
  };

  sctp = buildFromGitHub {
    version = 5;
    owner = "ishidawataru";
    repo = "sctp";
    rev = "07191f837fedd2f13d1ec7b5f885f0f3ec54b1cb";
    sha256 = "4ff89c03e31decd45b106e5c70d5250e131bd05162b1d42f55ba176231d85299";
    date = "2018-02-18";
    meta.autoUpdate = false;
  };

  sdnotify = buildFromGitHub {
    version = 6;
    rev = "ed8ca104421a21947710335006107540e3ecb335";
    owner = "okzk";
    repo = "sdnotify";
    sha256 = "089plny2r6hf1h8zwf97zfahdkizvnnla4ybd04likinvh45hb38";
    date = "2016-08-04";
  };

  seed = buildFromGitHub {
    version = 6;
    rev = "e2103e2c35297fb7e17febb81e49b312087a2372";
    owner = "sean-";
    repo = "seed";
    sha256 = "0hnkw8zjiqkyffxfbgh1020dgy0vxzad1kby0kkm8ld3i5g0aq7a";
    date = "2017-03-13";
  };

  selinux = buildFromGitHub {
    version = 6;
    rev = "85296ae73fc746c142a92bd4477ea0ba5bd1b39d";
    owner = "opencontainers";
    repo = "selinux";
    sha256 = "14jmmpsbwl71clpimjl448wg1x965nq08nk2d5v4sp3ffy2fxr8b";
    date = "2018-04-24";
  };

  semver = buildFromGitHub {
    version = 5;
    rev = "c5e971dbed7850a93c23aa6ff69db5771d8e23b3";
    owner = "blang";
    repo = "semver";
    sha256 = "16mdgsmh63alzrdisqygnqbi1ls4f56fwd6lhkvsbbbh944a6krl";
    date = "2018-03-05";
  };

  sentences_v1 = buildFromGitHub {
    version = 6;
    rev = "v1.0.6";
    owner = "neurosnap";
    repo = "sentences";
    sha256 = "1y42a5ynxrfs6bsipr7ysdw8vyfgwl4y7f739bziqfvpxrzg09ix";
    goPackagePath = "gopkg.in/neurosnap/sentences.v1";
  };

  serf = buildFromGitHub {
    version = 6;
    rev = "fc4bdedf2366c64984e280c6eefc703ca7812585";
    owner  = "hashicorp";
    repo   = "serf";
    sha256 = "1zbrj6vaz6d6arywh83krpwyb1pd4cihz3p80zzryq3d19byhgf8";

    propagatedBuildInputs = [
      armon_go-metrics
      circbuf
      columnize
      go-syslog
      logutils
      mapstructure
      hashicorp_mdns
      memberlist
      mitchellh_cli
      ugorji_go
    ];
    meta.useUnstable = true;
    date = "2018-04-11";
  };

  service = buildFromGitHub {
    version = 6;
    rev = "615a14ed75099c9eaac6949e22ac2341bf9d3197";
    owner  = "kardianos";
    repo   = "service";
    sha256 = "0ncwicq2rf2gna88hiwg1dy56d363b7w7v3dnc34h8lfh4p66wba";
    date = "2018-03-20";
    propagatedBuildInputs = [
      osext
      sys
    ];
  };

  service_v2 = buildFromGitHub {
    version = 6;
    rev = "v2.0.16";
    owner = "hlandau";
    repo = "service";
    sha256 = "0yqzpkb6frm6zpp6cq80qv2vjfwd5a4d19hn7qja6z98y1r839yw";
    goPackagePath = "gopkg.in/hlandau/service.v2";
    propagatedBuildInputs = [
      easyconfig_v1
      gspt
      svcutils_v1
      winsvc
    ];
  };

  session = buildFromGitHub {
    version = 6;
    rev = "b8e286a0dba8f4999042d6b258daf51b31d08938";
    owner  = "go-macaron";
    repo   = "session";
    sha256 = "0qjdlwjkfhdm33bxdym0bvgfp40sbbqak8ihsjnbgc83srdsp2y1";
    date = "2017-03-20";
    propagatedBuildInputs = [
      com
      gomemcache
      go-couchbase
      ini_v1
      ledisdb
      macaron_v1
      mysql
      nodb
      pq
      redis_v2
    ];
  };

  sftp = buildFromGitHub {
    version = 6;
    owner = "pkg";
    repo = "sftp";
    rev = "1.6.0";
    sha256 = "0vjmw0nxjafc4fqhm1h07hlwziwl1w1z794i7xrd1wzbsaxb2vg1";
    propagatedBuildInputs = [
      crypto
      errors
      fs
    ];
  };

  sha256-simd = buildFromGitHub {
    version = 5;
    owner = "minio";
    repo = "sha256-simd";
    date = "2017-12-13";
    rev = "ad98a36ba0da87206e3378c556abbfeaeaa98668";
    sha256 = "1qprs68yr4md5mvqsj7nlzkc708l1kas44n242fzlfy51bix1xwn";
  };

  shortid = buildFromGitHub {
    version = 5;
    owner = "teris-io";
    repo = "shortid";
    rev = "771a37caa5cf0c81f585d7b6df4dfc77e0615b5c";
    sha256 = "14wn8n6ap5f69np70h44h1gk0x8g8wr8wcsqjb7qcipnjib67rpc";
    date = "2017-10-29";
  };

  sio = buildFromGitHub {
    version = 6;
    date = "2018-03-27";
    rev = "6a41828a60f0ec95a159ce7921ca3dd566ebd7e3";
    owner  = "minio";
    repo   = "sio";
    sha256 = "0hvlh9mxzhcgrahp50mfgjz9fdszc2d6q0pymdjlb5p7zy1b1gq9";
    propagatedBuildInputs = [
      crypto
    ];
  };

  skyring-common = buildFromGitHub {
    version = 6;
    owner = "skyrings";
    repo = "skyring-common";
    date = "2016-09-29";
    rev = "d1c0bb1cbd5ed8438be1385c85c4f494608cde1e";
    sha256 = "1x1pdsm7n7acsszwzydqcv0qcq9f73rivgvh2dsi3s9dljxnnwiy";
    buildInputs = [
      crypto
      go-logging
      go-python
      gorequest
      graphite-golang
      influxdb_client
      mgo_v2
    ];
    postPatch = /* go-python now uses float64 */ ''
      sed -i tools/gopy/gopy.go \
        -e 's/python.PyFloat_FromDouble(f32)/python.PyFloat_FromDouble(f64)/'
    '';
  };

  slug = buildFromGitHub {
    version = 6;
    rev = "v1.1.1";
    owner  = "gosimple";
    repo   = "slug";
    sha256 = "0xnyg82hpvm91pbwp5nf0ayqb0lwyjqrskbni0grhxi9fhakrvpj";
    propagatedBuildInputs = [
      macaron_v1
      unidecode
    ];
  };

  smartcrop = buildFromGitHub {
    version = 5;
    rev = "f6ebaa786a12a0fdb2d7c6dee72808e68c296464";
    owner  = "muesli";
    repo   = "smartcrop";
    sha256 = "1fcbivf87z5kx9y87xmgmnfqp3llnrpm1jv5ci5g1czz9dggzh4b";
    date = "2018-02-28";
    propagatedBuildInputs = [
      image
      resize
    ];
  };

  softlayer-go = buildFromGitHub {
    version = 6;
    date = "2018-04-18";
    rev = "b48f721534f4df1c9e6e718f85ebd4c4d6f3e356";
    owner = "softlayer";
    repo = "softlayer-go";
    sha256 = "0sqlp87i9czns69h1kxjy11p2gdh34rvx3q85837cp9fp0mrbl2p";
    propagatedBuildInputs = [
      tools
      xmlrpc
    ];
  };

  spacelog = buildFromGitHub {
    version = 6;
    date = "2018-04-20";
    rev = "2296661a0572a51438413369004fa931c2641923";
    owner = "spacemonkeygo";
    repo = "spacelog";
    sha256 = "1b6v3kqva3m8abpahykzwqgs4w2zqjmcd6wh3sa5k80kji33ny5v";
    buildInputs = [
      flagfile
      sys
    ];
  };

  spdystream = buildFromGitHub {
    version = 6;
    rev = "bc6354cbbc295e925e4c611ffe90c1f287ee54db";
    owner = "docker";
    repo = "spdystream";
    sha256 = "1xj663cshf7cfm7kpd6zixij10lb2nvpv8h1h16g2vb9akyyvlx1";
    date = "2017-09-12";
    propagatedBuildInputs = [
      websocket
    ];
  };

  speakeasy = buildFromGitHub {
    version = 6;
    rev = "v0.1.0";
    owner = "bgentry";
    repo = "speakeasy";
    sha256 = "0vm6q73kczfjllxsag6ighc23s96xkzs0ibrgpy021rlkjqskrcd";
  };

  spec_appc = buildFromGitHub {
    version = 6;
    rev = "v0.8.11";
    owner  = "appc";
    repo   = "spec";
    sha256 = "04af8rpiapriy0izsqx417f932868imbqh54gz2sj59b44p0xbcp";
    propagatedBuildInputs = [
      go4
      go-semver
      inf_v0
      net
      pflag
    ];
  };

  spec_openapi = buildFromGitHub {
    version = 6;
    date = "2018-04-15";
    rev = "bcff419492eeeb01f76e77d2ebc714dc97b607f5";
    owner  = "go-openapi";
    repo   = "spec";
    sha256 = "1dy1cy0b0zr7kgraijyjwn1m6lkjg7nskg4i9ilfaxpyydcjmrbx";
    propagatedBuildInputs = [
      jsonpointer
      jsonreference
      swag
    ];
  };

  srslog = buildFromGitHub {
    version = 5;
    rev = "f6152a1bd05565e87729ad672a792b951046d235";
    date = "2018-01-18";
    owner  = "RackSec";
    repo   = "srslog";
    sha256 = "0v9f0v51q1rnsbs671zvmdbn7whrlmmc65drpjsac7bszhirihfv";
  };

  ssh-agent = buildFromGitHub {
    version = 6;
    rev = "ba9c9e33906f58169366275e3450db66139a31a9";
    date = "2015-12-15";
    owner  = "xanzy";
    repo   = "ssh-agent";
    sha256 = "1334004122rcqvs45sn0ikdak95zbjcrqkdbsmnhr3fmv9zch5fj";
    propagatedBuildInputs = [
      crypto
    ];
  };

  stack = buildFromGitHub {
    version = 6;
    rev = "v1.7.0";
    owner = "go-stack";
    repo = "stack";
    sha256 = "12mzkgxayiblwzdharhi7wqf6wmwn69k4bdvpyzn3xyw5czws9z3";
  };

  stathat = buildFromGitHub {
    version = 6;
    date = "2016-07-15";
    rev = "74669b9f388d9d788c97399a0824adbfee78400e";
    owner = "stathat";
    repo = "go";
    sha256 = "04jfh6i5wshjlm3j252llw6dj9szp3s5ad730vd036d263fk15j7";
  };

  stats = buildFromGitHub {
    version = 6;
    rev = "1bf9dbcd8cbe1fdb75add3785b1d4a9a646269ab";
    owner = "montanaflynn";
    repo = "stats";
    sha256 = "0plm40aq9ilc3j3gcr3ijrvg9lc64j3p613dwbi714qh8yhh9fni";
    date = "2017-12-01";
  };

  structs = buildFromGitHub {
    version = 5;
    rev = "ebf56d35bba727c68ac77f56f2fcf90b181851aa";
    owner  = "fatih";
    repo   = "structs";
    sha256 = "0n7y3m141mzl5r9a19ffvdrb9ifqvk52ba2br6f9l2vy6q8d07sc";
    date = "2018-01-23";
  };

  stump = buildFromGitHub {
    version = 6;
    date = "2016-06-11";
    rev = "206f8f13aae1697a6fc1f4a55799faf955971fc5";
    owner = "whyrusleeping";
    repo = "stump";
    sha256 = "024gilapc226id7a6zh5c1cfgfqxayhqn0h8m5l9p5lb2va5bzmd";
  };

  suture = buildFromGitHub {
    version = 6;
    rev = "v2.0.3";
    owner  = "thejerf";
    repo   = "suture";
    sha256 = "05ivm92dcrvj1x761yz1ykkp0kbm4pz2q31j95wmd6xwg8sacfs9";
  };

  svcutils_v1 = buildFromGitHub {
    version = 6;
    rev = "v1.0.10";
    owner  = "hlandau";
    repo   = "svcutils";
    sha256 = "12liac8vqcx04aqw5gwdywz89fg8327nkx0zrw7iw133pb20mf7v";
    goPackagePath = "gopkg.in/hlandau/svcutils.v1";
    buildInputs = [
      pkgs.libcap
    ];
  };

  swag = buildFromGitHub {
    version = 6;
    rev = "811b1089cde9dad18d4d0c2d09fbdbf28dbd27a5";
    owner = "go-openapi";
    repo = "swag";
    sha256 = "1n18dry66qp18g7gc0qfjxmdn31x4hsb7m1m1kyackxihxsls4jg";
    date = "2018-04-05";
    propagatedBuildInputs = [
      easyjson
      yaml_v2
    ];
  };

  swarmkit = buildFromGitHub {
    version = 6;
    rev = "bd69f6e8e301645afd344913fa1ede53a0a111fb";
    owner = "docker";
    repo = "swarmkit";
    sha256 = "0sxqz2i6g3yi8acawza604xlkgbd6dg0wny5vj8i3629pr2dlsw2";
    date = "2018-05-01";
    subPackages = [
      "api"
      "api/deepcopy"
      "api/equality"
      "api/genericresource"
      "api/naming"
      "ca"
      "ca/keyutils"
      "ca/pkcs8"
      "connectionbroker"
      "identity"
      "ioutils"
      "log"
      "manager/raftselector"
      "manager/state"
      "manager/state/store"
      "protobuf/plugin"
      "remotes"
      "watch"
      "watch/queue"
    ];
    propagatedBuildInputs = [
      cfssl
      crypto
      errors
      etcd_for_swarmkit
      go-digest
      go-events
      go-grpc-prometheus
      go-memdb
      docker_go-metrics
      gogo_protobuf
      grpc
      logrus
      net
    ];
    postPatch = ''
      find . \( -name \*.pb.go -or -name forward.go \) -exec sed -i {} \
        -e 's,metadata\.FromContext,metadata.FromIncomingContext,' \
        -e 's,metadata\.NewContext,metadata.NewOutgoingContext,' \;
    '';
  };

  swift = buildFromGitHub {
    version = 6;
    rev = "b2a7479cf26fa841ff90dd932d0221cb5c50782d";
    owner  = "ncw";
    repo   = "swift";
    sha256 = "1rj3zc0yhryw0zhbnrq0w5d6a4qylj4hxk582vszad95kmfi4j56";
    date = "2018-03-27";
  };

  syncthing = buildFromGitHub rec {
    version = 6;
    rev = "v0.14.47";
    owner = "syncthing";
    repo = "syncthing";
    sha256 = "1kcfpjdz7jki11v4d54ca04ci2g2zl4nq1pgvsm99h5xqmcq28mg";
    buildFlags = [ "-tags noupgrade" ];
    buildInputs = [
      AudriusButkevicius_cli
      crypto
      du
      errors
      gateway
      geoip2-golang
      glob
      go-deadlock
      go-lz4
      AudriusButkevicius_go-nat-pmp
      go-shellquote
      gogo_protobuf
      goleveldb
      groupcache
      net
      notify
      osext
      pq
      prometheus_client_golang
      qart
      rcrowley_go-metrics
      rollinghash
      sha256-simd
      suture
      text
      time
      xdr
    ];
    postPatch = ''
      # Mostly a cosmetic change
      sed -i 's,unknown-dev,${rev},g' cmd/syncthing/main.go
    '';
    preBuild = ''
      pushd go/src/$goPackagePath
      go run script/genassets.go gui > lib/auto/gui.files.go
      popd
    '';
  };

  tablewriter = buildFromGitHub {
    version = 6;
    rev = "d5dd8a50526aadb3d5f2c9b5233277bc2db90e88";
    date = "2018-04-18";
    owner  = "olekukonko";
    repo   = "tablewriter";
    sha256 = "0qisnxd5kvh61zsvqkjlh4p1wvv0gia9i5m7gbxz56jnc8gp8llh";
    propagatedBuildInputs = [
      go-runewidth
    ];
  };

  tail = buildFromGitHub {
    version = 6;
    rev = "37f4271387456dd1bf82ab1ad9229f060cc45386";
    owner  = "hpcloud";
    repo   = "tail";
    sha256 = "06f4vz0ch6m2na6z4gvhjzbaza83p2rhbn3rr4lmgslx9q6r6piw";
    propagatedBuildInputs = [
      fsnotify_v1
      tomb_v1
    ];
    date = "2017-08-14";
  };

  tally = buildFromGitHub {
    version = 5;
    rev = "v3.3.2";
    owner  = "uber-go";
    repo   = "tally";
    sha256 = "133bymqshc65cdc01wwxq2dncjkdfqbqp57ssbcpjjxgy3kpda26";
    subPackages = [
      "."
    ];
    propagatedBuildInputs = [
      clock
    ];
  };

  tar-utils = buildFromGitHub {
    version = 6;
    rev = "da98221b13fe8e6f9981d712ddac0f0329d7a45a";
    date = "2018-03-23";
    owner  = "whyrusleeping";
    repo   = "tar-utils";
    sha256 = "1jdcjn0mymz6bsmlsifj9x7w0yn3vd0q9q81j07pi9fanyp8xr31";
  };

  teleport = buildFromGitHub {
    version = 6;
    rev = "v2.5.6";
    owner = "gravitational";
    repo = "teleport";
    sha256 = "d2821f3231ea1b5a76db2b1f1fbd53d5697703b014900a1cf5a92e5b8700c1a6";
    nativeBuildInputs = [
      pkgs.protobuf-cpp
      gogo_protobuf.bin
      pkgs.zip
    ];
    buildInputs = [
      aws-sdk-go
      backoff
      bolt
      configure
      clockwork
      crypto
      etcd_client
      etree
      form
      genproto
      go-oidc
      go-semver
      gops
      gosaml2
      goxmldsig
      grpc
      grpc-gateway
      hdrhistogram
      hotp
      httprouter
      gravitational_kingpin
      lemma
      logrus
      kubernetes-apimachinery
      moby_lib
      net
      osext
      otp
      oxy
      predicate
      prometheus_client_golang
      protobuf
      pty
      roundtrip
      text
      timetools
      trace
      gravitational_ttlmap
      mailgun_ttlmap
      u2f
      pborman_uuid
      yaml
      yaml_v2
    ];
    excludedPackages = "\\(suite\\|fixtures\\|test\\|mock\\)";
    meta.autoUpdate = false;
    patches = [
      (fetchTritonPatch {
        rev = "ef43c5626941774c41bdbdda0a59d18c220fe742";
        file = "t/teleport/2.5.2.patch";
        sha256 = "c6a045be6770316942ba533f6c3450ea4871a27b5124c5562d86d094bc15dcc4";
      })
    ];
    postPatch = ''
      # Only used for tests
      rm lib/auth/helpers.go
      # Make sure we regenerate this
      rm lib/events/slice.pb.go
      # We don't need integration test stuff
      rm -r integration
    '';
    preBuild = ''
      GATEWAY_SRC=$(readlink -f unpack/grpc-gateway*)/src
      API_SRC=$GATEWAY_SRC/github.com/grpc-ecosystem/grpc-gateway/third_party/googleapis
      PROTO_INCLUDE=$GATEWAY_SRC:$API_SRC \
        make -C go/src/$goPackagePath buildbox-grpc
    '';
    preFixup = ''
      test -f "$bin"/bin/tctl
    '';
    postFixup = ''
      pushd go/src/$goPackagePath/web/dist >/dev/null
      zip -r "$NIX_BUILD_TOP"/assets.zip .
      popd >/dev/null
      cat assets.zip >>"$bin"/bin/teleport
      zip -A "$bin"/bin/teleport
    '';
  };

  template = buildFromGitHub {
    version = 6;
    rev = "a0175ee3bccc567396460bf5acd36800cb10c49c";
    owner = "alecthomas";
    repo = "template";
    sha256 = "17d1mby8cmxz50pv20r4dhdw01dkkamljng556kf35ls0jg9p9wp";
    date = "2016-04-05";
  };

  termbox-go = buildFromGitHub {
    version = 6;
    rev = "5a49b82160547cc98fca189a677a1c14eff796f8";
    date = "2018-05-02";
    owner = "nsf";
    repo = "termbox-go";
    sha256 = "1zqf31m13q953ambgpp7ndr8zz8ai3cjfx40p0xxpsqvpf3md7ic";
    propagatedBuildInputs = [
      go-runewidth
    ];
  };

  testify = buildFromGitHub {
    version = 5;
    rev = "v1.2.1";
    owner = "stretchr";
    repo = "testify";
    sha256 = "0f0alv3mrz38f71wb8zlavy75p27am96rgq24qbbd4mkr3pin9as";
    propagatedBuildInputs = [
      go-difflib
      go-spew
      objx
    ];
  };

  kr_text = buildFromGitHub {
    version = 6;
    rev = "7cafcd837844e784b526369c9bce262804aebc60";
    date = "2016-05-04";
    owner = "kr";
    repo = "text";
    sha256 = "0qmc5rl6rhafiqiqnfrajngzr7qmwfwnj18yccd8jkpd5ix4r70d";
    propagatedBuildInputs = [
      pty
    ];
  };

  thrift = buildFromGitHub {
    version = 6;
    rev = "0.11.0";
    owner  = "apache";
    repo   = "thrift";
    sha256 = "317586a96ef1f134172ac334791279885474294488b399e8aa6e94b20b902822";
    subPackages = [
      "lib/go/thrift"
    ];
    propagatedBuildInputs = [
      net
    ];
  };

  times = buildFromGitHub {
    version = 6;
    rev = "d25002f62be22438b4cd804b9d3c8db1231164d0";
    date = "2017-02-15";
    owner  = "djherbis";
    repo   = "times";
    sha256 = "046yb83vwa6r5xhrm70bz6dwzja3zw0l9yvv77kdhx5nagfhhc3j";
  };

  timetools = buildFromGitHub {
    version = 6;
    rev = "f3a7b8ffff474320c4f5cc564c9abb2c52ded8bc";
    date = "2017-06-19";
    owner = "mailgun";
    repo = "timetools";
    sha256 = "0kjrg9l3w7znm26anbb655ncgw0ya2lcjry78lk77j08a9hmj6r2";
    propagatedBuildInputs = [
      mgo_v2
    ];
  };

  tomb_v2 = buildFromGitHub {
    version = 6;
    date = "2016-12-08";
    rev = "d5d1b5820637886def9eef33e03a27a9f166942c";
    owner = "go-tomb";
    repo = "tomb";
    sha256 = "0azb4hkv41wl750wapl4jbnpvn1jg54z1clcnqvvs84rh75ywqj1";
    goPackagePath = "gopkg.in/tomb.v2";
    buildInputs = [
      net
    ];
  };

  tomb_v1 = buildFromGitHub {
    version = 6;
    date = "2014-10-24";
    rev = "dd632973f1e7218eb1089048e0798ec9ae7dceb8";
    owner = "go-tomb";
    repo = "tomb";
    sha256 = "17ij7zjw58949hrjmq4kjysnd7cqrawlzmwafrf4msxi1mylkk7q";
    goPackagePath = "gopkg.in/tomb.v1";
  };

  toml = buildFromGitHub {
    version = 6;
    owner = "BurntSushi";
    repo = "toml";
    rev = "v0.3.0";
    sha256 = "0cby7gc7iimbjawg8z5zm3nn70f6mj2lw7qvamh9hrnf81yp5wq3";
    goPackageAliases = [
      "github.com/burntsushi/toml"
    ];
  };

  trace = buildFromGitHub {
    version = 6;
    owner = "gravitational";
    repo = "trace";
    rev = "1.1.4";
    sha256 = "1svspbnjy7yr1jwp7rha34wgj42s1y6vzjy3wymk9azry6g2g6vk";
    propagatedBuildInputs = [
      clockwork
      grpc
      logrus
      net
    ];
    postPatch = ''
      sed \
        -e 's,metadata\.FromContext,metadata.FromIncomingContext,' \
        -e 's,metadata\.NewContext,metadata.NewOutgoingContext,' \
        -i trail/trail.go
    '';
  };

  tree = buildFromGitHub {
    version = 6;
    rev = "3cf936ce15d6100c49d9c75f79c220ae7e579599";
    owner  = "a8m";
    repo   = "tree";
    sha256 = "1viwc3d8fd441hrmvxdvrkpd5qnwr1bci2krkad6wg0j023cbw9x";
    date = "2018-03-21";
  };

  treeprint = buildFromGitHub {
    version = 6;
    rev = "505f0eee75dcba5ccb00cf81eea7f5b836b28e7c";
    owner  = "xlab";
    repo   = "treeprint";
    sha256 = "0zadq4cnqpmjy9cp6l497fa30l8wmkw9lil0g437f128x15fcf6b";
    date = "2018-03-24";
  };

  triton-go = buildFromGitHub {
    version = 6;
    rev = "1.3.1";
    owner  = "joyent";
    repo   = "triton-go";
    sha256 = "07md2gh4r00m14skzia09frca00pvzwywkjfvwcw85f0wyr6dvx4";
    subPackages = [
      "."
      "authentication"
      "client"
      "compute"
      "errors"
      "storage"
    ];
    propagatedBuildInputs = [
      crypto
      errors
    ];
  };

  gravitational_ttlmap = buildFromGitHub {
    version = 6;
    owner = "gravitational";
    repo = "ttlmap";
    rev = "91fd36b9004c1ee5a778739752ea1aba5638c03a";
    sha256 = "02babvj8xj4s6njrjd14l1il1zl35bfxkrb77bfslvv3wfz66b15";
    propagatedBuildInputs = [
      clockwork
      minheap
      trace
    ];
    meta.useUnstable = true;
    date = "2017-11-16";
  };

  mailgun_ttlmap = buildFromGitHub {
    version = 6;
    owner = "mailgun";
    repo = "ttlmap";
    rev = "c1c17f74874f2a5ea48bfb06b5459d4ef2689749";
    sha256 = "0v0ib54klps23bziczws1vk5vqv3649pl0gamirzzj6z0fcmn08s";
    date = "2017-06-19";
    propagatedBuildInputs = [
      minheap
      timetools
    ];
  };

  u2f = buildFromGitHub {
    version = 6;
    rev = "eb799ce68da4150b16ff5d0c89a24e2a2ad993d8";
    owner = "tstranex";
    repo = "u2f";
    sha256 = "077ead659217b4dfaa8f5399d3e45a15713464bd5603704810715e0090aa4064";
    date = "2016-05-08";
    meta.autoUpdate = false;
  };

  ulid = buildFromGitHub {
    version = 5;
    rev = "7e1bd8a9a281b5abdf651a430b918bb0ecdbceda";
    owner = "oklog";
    repo = "ulid";
    sha256 = "1dfpjnw44n1ffx7gxbh0gibkjain70dsljx8dp187waasljbfwg0";
    date = "2018-03-14";
    propagatedBuildInputs = [
      getopt
    ];
  };

  unidecode = buildFromGitHub {
    version = 6;
    rev = "cb7f23ec59bec0d61b19c56cd88cee3d0cc1870c";
    owner = "rainycape";
    repo = "unidecode";
    sha256 = "0pp6ip8fxwc96l667yskzr7qz7cas5z51a7arqq3hr30awd7zj5s";
    date = "2015-09-07";
  };

  units = buildFromGitHub {
    version = 6;
    rev = "2efee857e7cfd4f3d0138cc3cbb1b4966962b93a";
    owner = "alecthomas";
    repo = "units";
    sha256 = "11y8v2djk33kw0fc21wvcm0s329n3y9n2nldma5n23rfrwzdz6kq";
    date = "2015-10-22";
  };

  urlesc = buildFromGitHub {
    version = 6;
    owner = "PuerkitoBio";
    repo = "urlesc";
    rev = "de5bf2ad457846296e2031421a34e2568e304e35";
    sate = "2015-02-08";
    sha256 = "0knsqhv2fykspzk1gkl15h0a71x40z472fydq4n4wsh720a60560";
    date = "2017-08-10";
  };

  usage-client = buildFromGitHub {
    version = 6;
    owner = "influxdata";
    repo = "usage-client";
    date = "2016-08-29";
    rev = "6d3895376368aa52a3a81d2a16e90f0f52371967";
    sha256 = "15krz9ws44zcf4q7nckxyppayvyxh731fwfb1hvsqzra1hrs7a9p";
  };

  usso = buildFromGitHub {
    version = 6;
    rev = "5b79b358f4bb6735c1b00f6ad051c07c1a1a03e9";
    owner = "juju";
    repo = "usso";
    sha256 = "1gxdyailrrd0y4ssk9wmf4awm9lymlj6781yr46i7gfybsj5n2j4";
    date = "2016-04-18";
    propagatedBuildInputs = [
      errgo_v1
      openid-go
    ];
  };

  utils = buildFromGitHub {
    version = 6;
    rev = "2000ea4ff0431598aec2b7e1d11d5d49b5384d63";
    owner = "juju";
    repo = "utils";
    sha256 = "1k4rgvvwh4xph9al5mhzim8by70nmwwfbpziwa7qlajhr471k29l";
    date = "2018-04-24";
    subPackages = [
      "."
      "cache"
      "clock"
      "keyvalues"
      "set"
    ];
    propagatedBuildInputs = [
      crypto
      errgo_v1
      juju_errors
      loggo
      names_v2
      net
      yaml_v2
    ];
  };

  utils_for_names = utils.override {
    subPackages = [
      "."
      "clock"
    ];
    propagatedBuildInputs = [
      crypto
      juju_errors
      loggo
      net
      yaml_v2
    ];
  };

  utfbom = buildFromGitHub {
    version = 6;
    rev = "6c6132ff69f0f6c088739067407b5d32c52e1d0f";
    owner = "dimchansky";
    repo = "utfbom";
    sha256 = "06gr9hxflz72lg5h3wxyk7nyjz2qyrl09p88bnc2y3ds85i3l8rl";
    date = "2017-03-28";
  };

  google_uuid = buildFromGitHub {
    version = 6;
    rev = "dec09d789f3dba190787f8b4454c7d3c936fed9e";
    owner = "google";
    repo = "uuid";
    sha256 = "06y940a5bsy0zhbpbp7v9n4a2n7d9x1wg1j3cij817ij547llrn0";
    date = "2017-11-29";
    goPackageAliases = [
      "github.com/pborman/uuid"
    ];
  };

  pborman_uuid = buildFromGitHub {
    version = 6;
    rev = "c65b2f87fee37d1c7854c9164a450713c28d50cd";
    owner = "pborman";
    repo = "uuid";
    sha256 = "1d73sl1nzmn38rgp2yl5iz3m6bpi80m6h4n4b9a4fdi9ra7f3kzm";
    date = "2018-01-22";
  };

  vault = buildFromGitHub {
    version = 6;
    rev = "v0.10.1";
    owner = "hashicorp";
    repo = "vault";
    sha256 = "0bfjcrmvxw80qlcv04qqdklr7wy12y3isr1w5ig3ci88y6zc371f";

    nativeBuildInputs = [
      pkgs.protobuf-cpp
      protobuf.bin
    ];

    buildInputs = [
      armon_go-metrics
      aws-sdk-go
      columnize
      cockroach-go
      color
      complete
      consul_api
      copystructure
      crypto
      duo_api_golang
      errwrap
      errors
      etcd_client
      go-bindata-assetfs
      go-cache
      go-cleanhttp
      go-colorable
      keybase_go-crypto
      go-errors
      go-github
      go-glob
      go-hclog
      go-hdb
      go-homedir
      go-memdb
      go-mssqldb
      go-multierror
      go-plugin
      go-proxyproto
      go-radix
      go-rootcerts
      go-semver
      go-version
      hashicorp_go-sockaddr
      go-syslog
      go-testing-interface
      hashicorp_go-uuid
      go-zookeeper
      gocql
      golang-lru
      google-api-go-client
      google-cloud-go
      govalidator
      grpc
      hcl
      jose
      jsonx
      ldap
      mapstructure
      mgo_v2
      mitchellh_cli
      mysql
      net
      #nomad_api
      oauth2
      oktasdk-go
      otp
      pester
      pkcs7
      pq
      protobuf
      gogo_protobuf
      rabbit-hole
      radius
      reflectwalk
      snappy
      structs
      swift
      sys
      kr_text
      triton-go
      vault-plugin-auth-azure
      vault-plugin-auth-centrify
      vault-plugin-auth-gcp
      vault-plugin-auth-kubernetes
      yaml
    ];

    postPatch = ''
      rm -r physical/azure
      sed -i '/physAzure/d' command/commands.go
    '';

    # Regerate protos
    preBuild = ''
      srcDir="$(pwd)"/go/src
      pushd go/src/$goPackagePath >/dev/null
      find . -name \*pb.go -delete
      for file in $(find . -name \*.proto | sort | uniq); do
        pushd "$(dirname "$file")" > /dev/null
        echo "Regenerating protobuf: $file" >&2
        protoc -I "$srcDir" -I "$srcDir/$goPackagePath" -I . --go_out=plugins=grpc:. "$(basename "$file")"
        popd >/dev/null
      done
      popd >/dev/null
    '';
  };

  vault_api = vault.override {
    subPackages = [
      "api"
      "helper/compressutil"
      "helper/jsonutil"
      "helper/parseutil"
      "helper/strutil"
    ];
    nativeBuildInputs = [
    ];
    buildInputs = [
    ];
    preBuild = ''
    '';
    propagatedBuildInputs = [
      errwrap
      go-cleanhttp
      go-glob
      go-multierror
      go-rootcerts
      hashicorp_go-sockaddr
      hcl
      mapstructure
      net
      pester
      snappy
    ];
  };

  vault_for_plugins = vault.override {
    subPackages = [
      "api"
      "helper/certutil"
      "helper/compressutil"
      "helper/consts"
      "helper/errutil"
      "helper/jsonutil"
      "helper/locksutil"
      "helper/logging"
      "helper/mlock"
      "helper/parseutil"
      "helper/password"
      "helper/pluginutil"
      "helper/policyutil"
      "helper/salt"
      "helper/strutil"
      "helper/wrapping"
      "logical"
      "logical/framework"
      "logical/plugin"
      "logical/plugin/pb"
      "physical"
      "physical/inmem"
      "version"
    ];
    nativeBuildInputs = [
    ];
    buildInputs = [
    ];
    preBuild = ''
    '';
    propagatedBuildInputs = [
      crypto
      errwrap
      go-cleanhttp
      go-glob
      go-hclog
      go-multierror
      go-plugin
      go-radix
      go-rootcerts
      go-version
      golang-lru
      grpc
      hashicorp_go-uuid
      hashicorp_go-sockaddr
      hcl
      jose
      mapstructure
      net
      pester
      protobuf
      snappy
      sys
    ];
  };

  vault-plugin-auth-azure = buildFromGitHub {
    version = 6;
    owner = "hashicorp";
    repo = "vault-plugin-auth-azure";
    rev = "ef1aebd830562fe9a1c629102fcb156a536e8a0a";
    sha256 = "0phyg7zi17xdnfzrn7lmvsgcfqrh3y8bwdmczxjv31p9m405dq65";
    date = "2018-04-09";
    propagatedBuildInputs = [
      azure-sdk-for-go
      errwrap
      go-autorest
      go-cleanhttp
      go-oidc
      oauth2
      vault_for_plugins
    ];
  };

  vault-plugin-auth-centrify = buildFromGitHub {
    version = 6;
    owner = "hashicorp";
    repo = "vault-plugin-auth-centrify";
    rev = "3bf2341fe15ee93c6b42c600c51eadde9a707941";
    sha256 = "11blnq4pcwkbf9xryn40bc4izs972a8zy2ds8hdl64g7n25kpb2h";
    date = "2018-04-03";
    propagatedBuildInputs = [
      cloud-golang-sdk
      go-cleanhttp
      go-hclog
      vault_for_plugins
    ];
  };

  vault-plugin-auth-gcp = buildFromGitHub {
    version = 6;
    owner = "hashicorp";
    repo = "vault-plugin-auth-gcp";
    rev = "c1f38c311636440ff37e1f655f9722d3d9c1c0cc";
    sha256 = "0jf092m3l4a7ammdbm7ssxnpj6ahadrrgvg01x66fv7lpnpln8x4";
    date = "2018-04-08";
    propagatedBuildInputs = [
      go-cleanhttp
      google-api-go-client
      go-jose_v2
      jose
      oauth2
      vault_for_plugins
    ];
  };

  vault-plugin-auth-kubernetes = buildFromGitHub {
    version = 6;
    owner = "hashicorp";
    repo = "vault-plugin-auth-kubernetes";
    rev = "d3c2f16719dedd34911cd626a98bd5879e1caaff";
    sha256 = "1kd6y2s1c9bq4khzmbky69cx4hdgq0gvq2mgbcvm9xazzplxxnq6";
    date = "2018-04-03";
    propagatedBuildInputs = [
      go-cleanhttp
      go-hclog
      go-multierror
      jose
      kubernetes-api
      kubernetes-apimachinery
      mapstructure
      vault_for_plugins
    ];
  };

  juju_version = buildFromGitHub {
    version = 5;
    owner = "juju";
    repo = "version";
    rev = "b64dbd566305c836274f0268fa59183a52906b36";
    sha256 = "0s42sxll6k4k50i2fv3dh3l6iirwpa3mv1nzliawdk0nxgwqdvgn";
    date = "2018-01-08";
    propagatedBuildInputs = [
      mgo_v2
    ];
  };

  viper = buildFromGitHub {
    version = 6;
    owner = "spf13";
    repo = "viper";
    rev = "v1.0.2";
    sha256 = "0nz8av4qjj07ikdz1v8v0za0nasa02hy6phr6j1g3fpy48rs25pg";
    buildInputs = [
      crypt
      pflag
    ];
    propagatedBuildInputs = [
      afero
      cast
      fsnotify
      go-toml
      hcl
      jwalterweatherman
      mapstructure
      properties
      #toml
      yaml_v2
    ];
  };

  vtclean = buildFromGitHub {
    version = 6;
    rev = "d14193dfc626125c831501c1c42340b4248e1f5a";
    owner  = "lunixbochs";
    repo   = "vtclean";
    sha256 = "0562s4r8hkn479kv1mp0l136r8syy0a53n21ql4i44h622nf72jh";
    date = "2017-05-04";
  };

  vultr = buildFromGitHub {
    version = 5;
    rev = "1.15.0";
    owner  = "JamesClonk";
    repo   = "vultr";
    sha256 = "12aawg9hzqc989aqsmnl0n1m9awbw8g8xwrry2vxb2ac17i2c445";
    propagatedBuildInputs = [
      crypto
      mow-cli
      ratelimit
    ];
  };

  w32 = buildFromGitHub {
    version = 6;
    rev = "bb4de0191aa41b5507caa14b0650cdbddcd9280b";
    owner = "shirou";
    repo = "w32";
    sha256 = "1shbj8zkz0mqr47iij8v6wm2zdznml9pafhj4g2njg093yxw998l";
    date = "2016-09-30";
  };

  webbrowser = buildFromGitHub {
    version = 6;
    rev = "54b8c57083b4afb7dc75da7f13e2967b2606a507";
    owner  = "juju";
    repo   = "webbrowser";
    sha256 = "0i98zmgrl6zdrg8brjyyr04krpcn01ssvv5g85fmwpiq9qlis12a";
    date = "2016-03-09";
  };

  websocket = buildFromGitHub {
    version = 6;
    rev = "21ab95fa12b9bdd8fecf5fa3586aad941cc98785";
    owner  = "gorilla";
    repo   = "websocket";
    sha256 = "1jgwh9pj0z46pyzhhjrq4d175zajk5njscwcd2assv53nj4yg0hf";
    date = "2018-04-20";
  };

  whirlpool = buildFromGitHub {
    version = 6;
    rev = "c19460b8caa623b49cd9060e866f812c4b10c4ce";
    owner = "jzelinskie";
    repo = "whirlpool";
    sha256 = "09lgsrf0fig8m5ac81flxp6jg1dz6vnym6az2b9w5af2j59n1lil";
    date = "2017-06-03";
  };

  winsvc = buildFromGitHub {
    version = 6;
    rev = "f8fb11f83f7e860e3769a08e6811d1b399a43722";
    owner = "btcsuite";
    repo = "winsvc";
    sha256 = "0g9c7dqhsc20xkcdn30nrjapdpvyx56vlspkgs65abljya3lkmpm";
    date = "2015-01-17";
  };

  wmi = buildFromGitHub {
    version = 5;
    rev = "1.0.0";
    owner = "StackExchange";
    repo = "wmi";
    sha256 = "1il8zwa8r4n7g1xiw58jslxj8r6dgmxrdgapplzlfzz078rvvdw6";
    buildInputs = [
      go-ole
    ];
  };

  yaml = buildFromGitHub {
    version = 6;
    rev = "v1.0.0";
    owner = "ghodss";
    repo = "yaml";
    sha256 = "00g8p1grc0m34m55s3572d0d22f4vmws39f4vxp6djs4i2rzrqx3";
    propagatedBuildInputs = [
      yaml_v2
    ];
  };

  yaml_v2 = buildFromGitHub {
    version = 6;
    rev = "v2.2.1";
    owner = "go-yaml";
    repo = "yaml";
    sha256 = "0w1gan4v27nh2g90qsy9c1blrk3hbnprchr679xvjsa8d02m3mh4";
    goPackagePath = "gopkg.in/yaml.v2";
  };

  yaml_v1 = buildFromGitHub {
    version = 6;
    rev = "9f9df34309c04878acc86042b16630b0f696e1de";
    date = "2014-09-24";
    owner = "go-yaml";
    repo = "yaml";
    sha256 = "03bax5w4li71im848k789iih9pjh6ajgvnfi4s8im9limnfrj34c";
    goPackagePath = "gopkg.in/yaml.v1";
  };

  hashicorp_yamux = buildFromGitHub {
    version = 5;
    date = "2018-03-14";
    rev = "2658be15c5f05e76244154714161f17e3e77de2e";
    owner  = "hashicorp";
    repo   = "yamux";
    sha256 = "08v7ghpmcrmh1a0awm4jd0rby6ds6mbmrxchb5fvighc39r92xx1";
    goPackageAliases = [
      "github.com/influxdata/yamux"
    ];
  };

  whyrusleeping_yamux = buildFromGitHub {
    version = 6;
    date = "2018-03-22";
    rev = "63d22127b261bf7014885d25fabe034bed14f04b";
    owner  = "whyrusleeping";
    repo   = "yamux";
    sha256 = "0snvj9ckkb71q495yp2krn67bsa6ykvqvq32n13dxckml1g0s5vb";
  };

  yarpc = buildFromGitHub {
    version = 6;
    rev = "f0da2db138cad2fb425541938fc28dd5a5bc6918";
    owner = "influxdata";
    repo = "yarpc";
    sha256 = "15dhch4sd9fmzwk28fva6lggzs15sqfsqdsjdvx7j91ry70fkq86";
    date = "2018-02-22";
    excludedPackages = "test";
    propagatedBuildInputs = [
      gogo_protobuf
      hashicorp_yamux
    ];
  };

  xattr = buildFromGitHub {
    version = 6;
    rev = "v0.2.3";
    owner  = "pkg";
    repo   = "xattr";
    sha256 = "1fkvplmyr8yhr9nprnpx0jnfrdb9v1vanvkijb3ama1dgdy92ybh";
  };

  xdr = buildFromGitHub {
    version = 5;
    rev = "v1.1.0";
    owner  = "calmh";
    repo   = "xdr";
    sha256 = "001zdv75v0ksw55p2qqddjraqwhssjxfiachwic8jl60p365mwpp";
  };

  xlog = buildFromGitHub {
    version = 5;
    rev = "v1.0.0";
    owner  = "hlandau";
    repo   = "xlog";
    sha256 = "106gc5cpxavpxndkb516fvy4zn81h0jp9wvzxss4f9pvdi3zxvwd";
    propagatedBuildInputs = [
      go-isatty
      ansicolor
    ];
  };

  xmlrpc = buildFromGitHub {
    version = 6;
    rev = "ce4a1a486c03a3c6e1816df25b8c559d1879d380";
    owner  = "renier";
    repo   = "xmlrpc";
    sha256 = "09s4fvc1f7d95fqs74y13x2h05xd9qc39xvwn3w687glni3r06ah";
    date = "2017-07-08";
    propagatedBuildInputs = [
      text
    ];
  };

  xorm = buildFromGitHub {
    version = 6;
    rev = "v0.6.6";
    owner  = "go-xorm";
    repo   = "xorm";
    sha256 = "0j8q5abfp8qvfgzk86ss3gxaramrdfsgbycdfkibm9c1wk3460f2";
    propagatedBuildInputs = [
      builder
      core
    ];
  };

  xsecretbox = buildFromGitHub {
    version = 6;
    rev = "e790e3a36d5cdde0f309753d16100f2e7b396482";
    owner  = "jedisct1";
    repo   = "xsecretbox";
    sha256 = "0jl8rwhc3z75qzcw6lvdhn56vl3nwixm4pxk928s16hsryfnqc5g";
    date = "2018-04-26";
    propagatedBuildInputs = [
      chacha20
      crypto
      poly1305
    ];
  };

  cespare_xxhash = buildFromGitHub {
    version = 5;
    rev = "48099fad606eafc26e3a569fad19ff510fff4df6";
    owner  = "cespare";
    repo   = "xxhash";
    sha256 = "1gcq2ydv6s23lsb1da8hydc3sbydxjxdac9s22g8nb7jxs0rqgym";
    date = "2018-01-29";
  };

  pierrec_xxhash = buildFromGitHub {
    version = 6;
    rev = "a0006b13c722f7f12368c00a3d3c2ae8a999a0c6";
    owner  = "pierrec";
    repo   = "xxHash";
    sha256 = "0zzllb2d027l3862rz3r77a07pvfjv4a12jhv4ncj0y69gw4lf7l";
    date = "2017-07-14";
  };

  xz = buildFromGitHub {
    version = 6;
    rev = "v0.5.4";
    owner  = "ulikunitz";
    repo   = "xz";
    sha256 = "1xr4vvp27d9vc6crfp98rhb8dc7giq2jsf3hm829nq2fidjwpydd";
  };

  zap = buildFromGitHub {
    version = 6;
    rev = "v1.8.0";
    owner  = "uber-go";
    repo   = "zap";
    sha256 = "0ai9282ncmp43mg9y2a75li52l5lq5r8cj9c9vv5f9qzcwhd12db";
    goPackagePath = "go.uber.org/zap";
    goPackageAliases = [
      "github.com/uber-go/zap"
    ];
    propagatedBuildInputs = [
      atomic
      multierr
    ];
  };

  zap-logfmt = buildFromGitHub {
    version = 6;
    rev = "v1.0.0";
    owner  = "jsternberg";
    repo   = "zap-logfmt";
    sha256 = "1619ma694s85np6a3ckr9gq6cf3y3kmrqd1m3cwfwf2r4a3ylbc5";
    propagatedBuildInputs = [
      zap
    ];
  };

  zipkin-go-opentracing = buildFromGitHub {
    version = 6;
    rev = "v0.3.3";
    owner  = "openzipkin";
    repo   = "zipkin-go-opentracing";
    sha256 = "10g48n1307s2qbadp2hrncf85nnlmr4k9x93hwfcyknnda9a8z00";
    propagatedBuildInputs = [
      go-observer
      logfmt
      net
      opentracing-go
      gogo_protobuf
      sarama
      thrift
    ];
  };
}; in self
