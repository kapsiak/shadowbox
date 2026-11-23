#!/bin/sh
# Bundles release builds of the version in game.project into bundles/<version>/ and zips each
# platform. Usage: tools/release.sh [platform...] (default: wasm-web; e.g. x86_64-linux, x86_64-win32).
# Web zips hold index.html at their root, as itch.io expects.
set -eu
cd "$(dirname "$0")/.."
version=$(sed -n 's/^version = //p' game.project | head -n 1)
name=$(sed -n 's/^title = //p' game.project | head -n 1 | tr 'A-Z ' 'a-z-')
out="bundles/$version"
java="$HOME/Defold/packages/jdk-25+36/bin/java"
jar=$(ls "$HOME"/Defold/packages/defold-*.jar | head -n 1)

for platform in ${*:-wasm-web}; do
	rm -rf "$out/$platform" "$out/$name-$version-$platform.zip"
	"$java" -cp "$jar" com.dynamo.bob.Bob --archive --platform "$platform" --variant release \
		--output build/release --bundle-output "$out/$platform" resolve build bundle
	zip_path="$PWD/$out/$name-$version-$platform.zip"
	if [ "$platform" = wasm-web ]; then
		(cd "$out/$platform"/*/ && zip -qr "$zip_path" .)
	else
		(cd "$out/$platform" && zip -qr "$zip_path" .)
	fi
	echo "$zip_path"
done
