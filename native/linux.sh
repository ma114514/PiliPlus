#!/usr/bin/env bash
set -euo pipefail
source_dir=$1
output_dir=$2
prefix="$source_dir/capture-prefix"
mkdir -p "$prefix"
cd "$source_dir"
curl --fail --location https://ffmpeg.org/releases/ffmpeg-7.0.2.tar.xz -o ffmpeg.tar.xz
echo '8646515b638a3ad303e23af6a3587734447cb8fc0a0c064ecdb8e95c4fd8b389  ffmpeg.tar.xz' | sha256sum -c -
tar xf ffmpeg.tar.xz
pushd ffmpeg-7.0.2
./configure --prefix="$prefix" --enable-shared --disable-static --enable-libwebp --enable-libdav1d --enable-gnutls --disable-doc
make -j2
make install
popd
export PKG_CONFIG_PATH="$prefix/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
meson setup capture-build --prefix="$prefix" -Dlibmpv=true -Dcplayer=true -Dgpl=false
meson compile -C capture-build
meson install -C capture-build
mkdir -p "$output_dir/lib" "$output_dir/bin"
cp -a "$prefix"/lib/*.so* "$output_dir/lib/"
cp "$prefix/bin/mpv" "$output_dir/bin/"
# Bundle non-glibc transitive dependencies as well. Preserve SONAMEs.
for library in "$prefix/bin/mpv" "$prefix"/lib/*.so; do
  ldd "$library" | awk '/=> \/.*\// { print $3 }' | while read -r dependency; do
    case "$(basename "$dependency")" in
      libc.so.*|libm.so.*|libpthread.so.*|libdl.so.*|librt.so.*|ld-linux*) ;;
      *) cp -Ln "$dependency" "$output_dir/lib/" ;;
    esac
  done
done
# A Flutter executable's RUNPATH does not apply to dependencies of dlopen'd
# libmpv. Each bundled media library must find its siblings after relocation.
find "$output_dir/lib" -type f -name '*.so*' -exec patchelf --set-rpath '$ORIGIN' {} \;
