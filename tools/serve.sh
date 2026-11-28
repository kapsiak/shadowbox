#!/bin/sh
# Builds the web release (tools/release.sh) and serves it to the local network for testing on a
# phone. Usage: tools/serve.sh [--demo] [--no-build] [--open] [port] (default 8000).
# --open allows the port through ufw while serving and removes the rule on exit (asks for sudo).
# Responses are sent uncached so the phone always loads the newest build.
set -eu
cd "$(dirname "$0")/.."
demo=""
build=1
open=""
port=8000
for arg in "$@"; do
	case "$arg" in
		--demo) demo=--demo ;;
		--no-build) build="" ;;
		--open) open=1 ;;
		*) port=$arg ;;
	esac
done
version=$(sed -n 's/^version = //p' game.project | head -n 1)
[ -n "$demo" ] && version="$version-demo"
[ -n "$build" ] && tools/release.sh $demo wasm-web
root=$(dirname "$(ls bundles/"$version"/wasm-web/*/index.html | head -n 1)")
if [ -n "$open" ]; then
	sudo ufw allow "$port/tcp" comment third-angle-serve
	trap 'sudo ufw delete allow "$port/tcp"' EXIT
	trap 'exit 0' INT TERM
fi
echo "Serving $root"
ip -4 -o addr show scope global | awk -v port="$port" '{ split($4, a, "/"); print "  http://" a[1] ":" port "/" }'
python3 - "$root" "$port" <<'EOF'
import functools, http.server, sys

class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

handler = functools.partial(Handler, directory=sys.argv[1])
try:
    http.server.ThreadingHTTPServer(("0.0.0.0", int(sys.argv[2])), handler).serve_forever()
except KeyboardInterrupt:
    pass
EOF
