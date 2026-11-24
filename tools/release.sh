#!/bin/sh
# Bundles release builds of the version in game.project into bundles/<version>/ and zips each
# platform. Usage: tools/release.sh [--demo] [platform...] (default: wasm-web; e.g. x86_64-linux,
# x86_64-win32). --demo builds only the levels in levels/demo.lua (tools/demo_resources.lua) into
# bundles/<version>-demo/.
# Web zips hold index.html at their root, as itch.io expects. Bob's build_input_data.json (git
# remote, commit, library versions) stays beside each bundle as a record, out of the zips.
# Each zip carries the licences the game must ship with (Defold, the Outfit font).
set -eu
cd "$(dirname "$0")/.."
version=$(sed -n 's/^version = //p' game.project | head -n 1)
name=$(sed -n 's/^title = //p' game.project | head -n 1 | tr 'A-Z ' 'a-z-')
settings=""
if [ "${1:-}" = --demo ]; then
	shift
	version="$version-demo"
	mkdir -p build
	{ luajit tools/demo_resources.lua; echo "version = $version"; } > build/demo.project_settings
	settings="--settings build/demo.project_settings"
fi
out="bundles/$version"
java="$HOME/Defold/packages/jdk-25+36/bin/java"
jar=$(ls "$HOME"/Defold/packages/defold-*.jar | head -n 1)

for platform in ${*:-wasm-web}; do
	rm -rf "$out/$platform" "$out/$name-$version-$platform.zip"
	"$java" -cp "$jar" com.dynamo.bob.Bob --archive --platform "$platform" --variant release $settings \
		--output build/release --bundle-output "$out/$platform" resolve build bundle
	zip_path="$PWD/$out/$name-$version-$platform.zip"
	if [ "$platform" = wasm-web ]; then
		(cd "$out/$platform"/*/ && zip -qr "$zip_path" .)
	else
		(cd "$out/$platform" && zip -qr "$zip_path" . -x build_input_data.json)
	fi
	zip -qj "$zip_path" legal/Defold-LICENSE.txt assets/fonts/OFL-Outfit.txt
	echo "$zip_path"
done
