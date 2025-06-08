TERMUX_SUBPKG_DESCRIPTION="C library for generating audio fingerprints used by AcoustID (libraries)"
TERMUX_SUBPKG_DEPENDS="libc++, fftw"
TERMUX_SUBPKG_DEPEND_ON_PARENT=false
TERMUX_SUBPKG_INCLUDE="lib/libchromaprint.so
lib/pkgconfig/libchromaprint.pc
include/chromaprint.h
share/doc/chromaprint/copyright.1
"
