{ stdenv, fetchurl, fetchpatch, python2, zlib, pkgconfig, glib
, ncurses, perl, pixman, vde2, alsaLib, texinfo, libuuid, flex
, bison, lzo, snappy, libaio, gnutls, nettle, curl
, makeWrapper
, attr, libcap, libcap_ng
, CoreServices, Cocoa, rez, setfile
, numactl
, libseccomp
, libpulseaudio
, SDL
, libjpeg, libpng
, spice, spice_protocol, usbredir
}:

with stdenv.lib;
let
  version = "2.8.0";
  numaSupport = true;
  seccompSupport = true;
  pulseSupport = true;
  sdlSupport = false;
  vncSupport = true;
  spiceSupport = true;
  x86Only = false;
  nixosTestRunner = false;
  audio = optionalString (hasSuffix "linux" stdenv.system) "alsa,"
    + optionalString pulseSupport "pa,"
    + optionalString sdlSupport "sdl,";
in

stdenv.mkDerivation rec {
  name = "qemu-"  
    + stdenv.lib.optionalString x86Only "x86-only-"
    + stdenv.lib.optionalString nixosTestRunner "for-vm-tests-"
    + version;

  src = fetchurl {
    url = "http://download.qemu-project.org/qemu-${version}.tar.xz";
    sha256 = "134kdfyj95ajdfbb3h3d9a7wddsvili8i92ym3nffz9nir03sv35";
  };

  buildInputs =
    [ python2 zlib pkgconfig glib ncurses perl pixman
      vde2 texinfo libuuid flex bison makeWrapper lzo snappy
      gnutls nettle curl
    ]
    ++ optionals stdenv.isDarwin [ CoreServices Cocoa rez setfile ]
    ++ optionals seccompSupport [ libseccomp ]
    ++ optionals numaSupport [ numactl ]
    ++ optionals pulseSupport [ libpulseaudio ]
    ++ optionals sdlSupport [ SDL ]
    ++ optionals vncSupport [ libjpeg libpng ]
    ++ optionals spiceSupport [ spice_protocol spice usbredir ]
    ++ optionals stdenv.isLinux [ alsaLib libaio libcap_ng libcap attr ];

  enableParallelBuilding = true;

  patches = [
    ./no-etc-install.patch
  ] ++ optional nixosTestRunner ./force-uid0-on-9p.patch;
  hardeningDisable = [ "stackprotector" ];

  configureFlags =
    [ "--smbd=smbd" # use `smbd' from $PATH
      "--audio-drv-list=${audio}"
      "--sysconfdir=/etc"
      "--localstatedir=/var"
    ]
    ++ optional numaSupport "--enable-numa"
    ++ optional seccompSupport "--enable-seccomp"
    ++ optional spiceSupport "--enable-spice"
    ++ optional x86Only "--target-list=i386-softmmu,x86_64-softmmu"
    ++ optional stdenv.isDarwin "--enable-cocoa"
    ++ optional stdenv.isLinux "--enable-linux-aio";

  postFixup =
    ''
      for exe in $out/bin/qemu-system-* ; do
        paxmark m $exe
      done
    '';

  postInstall =
    ''
      # Add a ‘qemu-kvm’ wrapper for compatibility/convenience.
      p="$out/bin/qemu-system-${if stdenv.system == "x86_64-linux" then "x86_64" else "i386"}"
      if [ -e "$p" ]; then
        makeWrapper "$p" $out/bin/qemu-kvm --add-flags "\$([ -e /dev/kvm ] && echo -enable-kvm)"
      fi
    '';

  meta = with stdenv.lib; {
    homepage = http://www.qemu.org/;
    description = "A generic and open source machine emulator and virtualizer";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ viric eelco ];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
