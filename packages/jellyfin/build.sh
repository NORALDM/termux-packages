TERMUX_PKG_HOMEPAGE="https://jellyfin.org"
TERMUX_PKG_DESCRIPTION="A free media system for organizing and streaming media"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION="10.10.6"
TERMUX_PKG_REVISION=1
_FFMPEG_VERSION="7.0.2-9"
TERMUX_PKG_SRCURL=( "https://github.com/jellyfin/jellyfin/archive/refs/tags/v${TERMUX_PKG_VERSION}.tar.gz"
                    "https://github.com/jellyfin/jellyfin-ffmpeg/archive/refs/tags/v${_FFMPEG_VERSION}.tar.gz"
                    "https://github.com/jellyfin/jellyfin-web/archive/refs/tags/v${TERMUX_PKG_VERSION}.tar.gz" )
_GIT_URL=( "git+https://github.com/ericsink/cb.git"
           "git+https://github.com/ericsink/SQLitePCL.raw.git"
           "git+https://github.com/mono/skia.git" )
_GIT_COMMIT=( "cd2922b8867e4360f0976601414bd24a3ad613d8"
               "7521c274efb2b49855b192f17862e87964460bac"
               "4bed689c9c9eb77a120c6a9d54af6a572c85d1c2" )
_GIT_BRANCH=( "master"
              "no-xamarin"
              "release/2.x" )
_GIT_SHA256=( "1107df127ead66ace2baf92467fa10a8215371741e0b0b6a0580496ff1ae0bcf"
              "8cd1b773026da818c47c693cf7a4bb81ab927b869a0ce2c6abcdbbe38d79922b"
              "46c733f05df257e4bec13c09b53e7ef39bb80f21acb435d206dce609f4175ab1" )
TERMUX_PKG_SHA256=(
	77aad87db2bf59bf25d1496c5fa92c92c93738d1a80fc6d53308db5850bf2818
	ae4ea57516e606a73fd2745b21284c65d41d3851d05a2ac17c425d7488192ba0
	690ed4f2e65137028896dbd77be41d5968d87203911ea5da53fa513bd370d2c7
)
TERMUX_PKG_BUILD_DEPENDS="aspnetcore-targeting-pack-8.0, dotnet-targeting-pack-8.0"
TERMUX_PKG_DEPENDS="libc++, fontconfig, aspnetcore-runtime-8.0, dotnet-host, dotnet-runtime-8.0, sqlite, chromaprint, libdrm, libexpat, libpng, libwebp, freetype, libpciaccess, xcb-util-image, libxshmfence, libxpresent, libxfixes, libxrandr, zstd"
TERMUX_PKG_SERVICE_SCRIPT=(
	"jellyfin"
	"${TERMUX_PREFIX}/bin/dotnet ${TERMUX_PREFIX}/share/jellyfin/jellyfin.dll --datadir ${TERMUX_ANDROID_HOME}/jellyfin"
)
TERMUX_PKG_BLACKLISTED_ARCHES="arm"

termux_step_post_get_source() {
	local _idx;
	local _sha256sums=();
	local _error=0;
	for (( _idx=0; _idx < "${#_GIT_URL[@]}"; _idx++ )); do
		# the git commands can be replaced with git clone --revision "${_GIT_COMMIT[${_idx}]}" --depth 1 in git 2.49
		git clone -b "${_GIT_BRANCH[${_idx}]}" --depth 1 "${_GIT_URL[${_idx}]:4}"
		pushd "$( printf "%s" "${_GIT_URL[${_idx}]}" | sed -E 's|^.*/(.*).git$|\1|' )"
		git fetch --depth 1 origin "${_GIT_COMMIT[${_idx}]}"
		git checkout "${_GIT_COMMIT[${_idx}]}"
		_sha256sums["$_idx"]="$(find . -type f ! -path '*/.git/*' -print0 | xargs -0 sha256sum | LC_ALL=C sort | sha256sum | awk '{print $1}')"
		! [ "${_sha256sums["$_idx"]}" = "${_GIT_SHA256[${_idx}]}" ] && _error=1;
		popd
	done
	if ! ( exit "$_error" ); then
		_error='_GIT_SHA256=( '
		_error+='"'"${_sha256sums[0]}"'"'$'\n'
		for (( _idx=1; _idx < $(( "${#_sha256sums[@]}" - 1 )); _idx++ )); do
			_error+="$(printf '%14s"%s"' '' "${_sha256sums["$_idx"]}")"$'\n'
		done
		_error+="$(printf '%14s"%s" )' '' "${_sha256sums["$_idx"]}")"$'\n'
		termux_error_exit "Error: checksums for sources do not match. To update checksums, put the following lines in build.sh:"$'\n'"${_error}"
	fi
	pushd jellyfin-ffmpeg-"${_FFMPEG_VERSION}"
	# If quilt is added to termux-build-helper:
	# if [[ -f "debian/patches/series" ]]; then
	# quilt push -a
	# fi
	for i in $(cat debian/patches/series); do git apply --whitespace=nowarn debian/patches/$i; done
	popd
}
termux_step_pre_configure() {
	termux_setup_dotnet && termux_setup_gn
	local _target_cpu=""
	if [ "$TERMUX_ARCH" = "aarch64" ]; then
		_target_cpu="arm64"
#	elif [ "$TERMUX_ARCH" = "arm" ]; then
#		_target_cpu="arm"
	elif [ "$TERMUX_ARCH" = "x86_64" ]; then
		_target_cpu="x64"
	elif [ "$TERMUX_ARCH" = "i686" ]; then
		_target_cpu="x86"
	else
		termux_error_exit  "Unsupported arch: $TERMUX_ARCH"
	fi

	pushd skia
	# we must use version 62 of libjpeg-turbo
	# https://github.com/libjpeg-turbo/libjpeg-turbo/issues/795#issuecomment-2484148592
	local _args_pre=""
	local _args=""
	_args_pre="target_os='android' \
	target_cpu='${_target_cpu}' \
	skia_use_icu=false \
	skia_use_harfbuzz=false \
	skia_use_piex=true \
	skia_use_sfntly=false \
	skia_enable_gpu=false \
	skia_enable_tools=false \
	skia_use_dng_sdk=false \
	skia_use_gl=false \
	skia_use_vulkan=false \
	skia_use_system_expat=true \
	skia_use_system_libjpeg_turbo=false \
	skia_use_system_freetype2=true \
	skia_use_system_libpng=true \
	skia_use_system_libwebp=true \
	skia_use_system_zlib=true \
	skia_enable_skottie=true \
	third_party_isystem=false \
	cc='$CC' \
	cxx='$CXX' \
	ar='$AR' \
	ndk='${TERMUX_STANDALONE_TOOLCHAIN}' \
	ndk_api=${TERMUX_PKG_API_LEVEL} \
	extra_asmflags=[] \
	extra_cflags=[ '-DSKIA_C_DLL', '-DHAVE_SYSCALL_GETRANDOM', '-DXML_DEV_URANDOM' ] \
	extra_ldflags=[ '-static-libstdc++', '-Wl,--no-undefined', '-Wl,-z,max-page-size=16384' ] \
	is_official_build=true \
	extra_asmflags+=[ '-no-integrated-as', '-I${TERMUX_PREFIX}/include' ] \
	extra_cflags+=[ '-I${TERMUX_PREFIX}/include', $(pkg-config --cflags freetype2 libpng libwebp expat | awk '{for (i=1;i<NF;i++) { printf "\"%s\", ",$i}; printf "\"%s\"",$i}') ] \
	extra_ldflags+=[ '-L${TERMUX_PREFIX}/lib', '-Wl,-rpath,${TERMUX_PREFIX}/lib', $(pkg-config --libs freetype2 libpng libwebp expat | awk '{for (i=1;i<NF;i++) { printf "\"%s\", ",$i}; printf "\"%s\"",$i}') ]"
	_args="$(printf "%s\n" "${_args_pre}" | sed "s/'/\\\"/g" | sed "s/\\t//g")"

	# ( export _args TERMUX_PREFIX TERMUX_STANDALONE_TOOLCHAIN && bash -il ) && exit
	./tools/git-sync-deps
	gn gen 'out' --args="${_args}"
	ninja -v -C out SkiaSharp

	_args_pre="target_os='android' \
	target_cpu='${_target_cpu}' \
	visibility_hidden=false \
	cc='$CC' \
	cxx='$CXX' \
	ar='$AR' \
	ndk='${TERMUX_STANDALONE_TOOLCHAIN}' \
	ndk_api=${TERMUX_PKG_API_LEVEL} \
	extra_asmflags=[] \
	extra_cflags=[] \
	extra_ldflags=[ '-static-libstdc++', '-Wl,--no-undefined', '-Wl,-z,max-page-size=16384' ] \
	is_official_build=true \
	extra_asmflags+=[ '-no-integrated-as', '-I${TERMUX_PREFIX}/include' ] \
	extra_cflags+=[ '-I${TERMUX_PREFIX}/include' ] \
	extra_ldflags+=[ '-L${TERMUX_PREFIX}/lib', '-Wl,-rpath,${TERMUX_PREFIX}/lib' ]"
	_args="$(printf "%s\n" "${_args_pre}" | sed "s/'/\\\"/g" | sed "s/\\t//g")"

	gn gen 'out' --args="${_args}"
	ninja -v -C out HarfBuzzSharp

	cp out/libSkiaSharp.so out/libHarfBuzzSharp.so "$TERMUX_PKG_BUILDDIR"
	popd

#	if [ "$TERMUX_ARCH" = "arm" ]; then
#		_target_cpu="armhf"
#	fi
	local _tmpdir="$(mktemp -d)"
	[ -d "${_tmpdir}" ] || termux_error_exit "mktemp failed"
	# dotnet traverses up to find a project root, which is bad for us
	# SQLitePCL.raw needs it at "../cb"
	mv "cb" "${_tmpdir}/cb"
	mv "SQLitePCL.raw" "${_tmpdir}/SQLitePCL.raw"
	pushd "${_tmpdir}/SQLitePCL.raw"
	dotnet tool install --global dotnet-t4
	( cd gen_providers; dotnet run )
	cd src/SQLitePCLRaw.lib.e_sqlite3 && dotnet pack -c Release
	cd ../SQLitePCLRaw.bundle_e_sqlite3 && dotnet build -p:TargetFrameworks=net8.0
	cd "${_tmpdir}"
	pushd "cb/bld" && dotnet run && "$CC" @linux_e_sqlite3_"${_target_cpu}".gccargs -lm -ldl; popd
	cp "cb/bld/bin/e_sqlite3/linux/${_target_cpu}/libe_sqlite3.so" SQLitePCL.raw/src/SQLitePCLRaw.bundle_e_sqlite3/bin/Debug/net8.0/*dll "$TERMUX_PKG_BUILDDIR"
	popd # $TERMUX_PKG_SRCDIR
	rm -rf "$_tmpdir"

	pushd jellyfin-ffmpeg-"${_FFMPEG_VERSION}"
	local _ARCH=""
	local _FFMPEG_PREFIX="${TERMUX_PREFIX}/lib/jellyfin-ffmpeg"
	local _FFMPEG_LDFLAGS="-Wl,-rpath=${_FFMPEG_PREFIX}/lib ${LDFLAGS}"
	local _EXTRA_CONFIGURE_FLAGS=""
	if [ "$TERMUX_ARCH" = "i686" ]; then
		_ARCH="x86"
		# Specify --disable-asm to prevent text relocations on i686,
		# see https://trac.ffmpeg.org/ticket/4928
		_EXTRA_CONFIGURE_FLAGS="--disable-asm"
#	elif [ "$TERMUX_ARCH" = "arm" ]; then
#		_ARCH="armeabi-v7a"
#		_EXTRA_CONFIGURE_FLAGS="--enable-neon"
	elif [ "$TERMUX_ARCH" = "x86_64" ]; then
		_ARCH="x86_64"
	elif [ "$TERMUX_ARCH" = "aarch64" ]; then
		_ARCH="$TERMUX_ARCH"
		_EXTRA_CONFIGURE_FLAGS="--enable-neon"
	else
		termux_error_exit  "Unsupported arch: $TERMUX_ARCH"
	fi

	cd builder
	<build.sh awk '{print} $0 ~ /^FF_LIBS/ {exit}' > configure.sh
	cat <<'EOF' >>configure.sh
cd ..
./configure --prefix="${_FFMPEG_PREFIX}" \
        --arch="${_ARCH}" \
        --as="$AS" \
        --cc="$CC" \
        --cxx="$CXX" \
        --nm="$NM" \
        --ar="$AR" \
        --ranlib="llvm-ranlib" \
        --pkg-config="$PKG_CONFIG" \
        --strip="$STRIP" \
        --enable-cross-compile \
        --extra-version="Jellyfin" \
        --extra-cflags="$FF_CFLAGS" \
        --extra-cxxflags="$FF_CXXFLAGS" \
        --extra-ldflags="$FF_LDFLAGS" \
        --extra-ldexeflags="$FF_LDEXEFLAGS" \
        --extra-libs="$FF_LIBS -landroid-glob" \
        --target-os=android \
        --disable-static \
        --enable-shared \
        $FF_CONFIGURE \
        ${_EXTRA_CONFIGURE_FLAGS} \
	--disable-vulkan
EOF
	# disable rockchip, vulkan, and zvbi configure options
	rm -rf scripts.d/*rkrga* scripts.d/*vulkan* scripts.d/*rkmpp* scripts.d/*fdk-aac* scripts.d/*zvbi*
	LDFLAGS="${_FFMPEG_LDFLAGS}" _ARCH="${_ARCH}" _FFMPEG_PREFIX="${_FFMPEG_PREFIX}" _EXTRA_CONFIGURE_FLAGS="${_EXTRA_CONFIGURE_FLAGS}" bash ./configure.sh linuxarm64 gpl
	cd ..
	LDFLAGS="${_FFMPEG_LDFLAGS}" make -j"$TERMUX_PKG_MAKE_PROCESSES"
	make install
	rm -rf "${_FFMPEG_PREFIX}/"{share,include}
	popd
}

termux_step_make() {
	dotnet publish "$TERMUX_PKG_SRCDIR"/Jellyfin.Server --configuration Release --runtime "$DOTNET_TARGET_NAME" --output "$TERMUX_PKG_BUILDDIR"/build --no-self-contained -p:DebugType=None
}

termux_step_make_install() {
	chmod 0700 "${TERMUX_PKG_BUILDDIR}/build"
	find "${TERMUX_PKG_BUILDDIR}/build" -name '*.xml' -type f -exec rm '{}' +
	find "$TERMUX_PKG_BUILDDIR" -maxdepth 1 -type f -exec mv -t "${TERMUX_PKG_BUILDDIR}/build" '{}' +
	find "${TERMUX_PKG_BUILDDIR}/build" ! \( -name '*.so' -o -name 'jellyfin' -o -type d \) -exec chmod 0600 '{}' \;
	find "${TERMUX_PKG_BUILDDIR}/build" \( -name 'jellyfin' -o -name '*.so' -o -type d \) -exec chmod 0700 '{}' \;
	local _i=""
	for _i in "$TERMUX_PREFIX/lib/jellyfin-ffmpeg/bin/ff"{probe,mpeg}; do
		ln -s "$_i" "${TERMUX_PKG_BUILDDIR}/build"
	done
	mv "${TERMUX_PKG_BUILDDIR}/build" "${TERMUX_PREFIX}/lib/jellyfin"
	ln -s "${TERMUX_PREFIX}/lib/jellyfin/jellyfin" "${TERMUX_PREFIX}/bin/jellyfin"
}
# References
# - SkiaSharp
# https://cgit.freebsd.org/ports/tree/graphics/libskiasharp
# https://bugs.freebsd.org/bugzilla/show_bug.cgi?id=282704
# https://github.com/mono/SkiaSharp/blob/release/2.88.9/native/android/build.cake
# https://gn.googlesource.com/gn/+/main/docs/reference.md
# - Jellyfin-FFMPEG
# https://github.com/jellyfin/jellyfin-ffmpeg/blob/jellyfin/builder/build.sh
# https://github.com/termux/termux-packages/tree/master/packages/ffmpeg
# Note: All patches for Jellyfin-FFMPEG should be based off the patched version, see termux_step_post_get_source
# TODO: jellyfin-web, either subpackage or bundled
