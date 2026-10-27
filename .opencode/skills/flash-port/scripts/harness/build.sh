#!/bin/sh
# Compiles one game of this repository for the test harness (like compile-dev.hxml) and bundles it like
# resources/js/games/build-games.mjs, into $KKP_WORK/build/<pkg>.js (served by server.py).
# usage: sh build.sh <pkg> [prod]      prod: without -debug (no window.__over, live seed from the context)
# env: KKP_WORK (default ~/kadokadeo-port), HAXE (default haxe; the libs pixijs, crypto, jsImport must be installed:
#      haxelib install resources/hx/install.hxml once), BUILD_NAME (default <pkg>: the bundle <name>.js, loaded by the
#      harness with &js=<name>: two builds side by side)
set -e
G="$1"
if [ -z "$G" ]; then sed -n 2,7p "$0"; exit 1; fi
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../../.." && pwd)
WORK=${KKP_WORK:-$HOME/kadokadeo-port}
OUT="$WORK/build"
N=${BUILD_NAME:-$G}
mkdir -p "$OUT/src"
DEBUG=-debug
if [ "$2" = "prod" ]; then DEBUG=; fi
cd "$REPO"
${HAXE:-haxe} -L pixijs -L crypto -L jsImport -cp ./resources/hx/lib -cp ./resources/hx/games $DEBUG \
    -js "$OUT/src/$N.js" "$G.Game"
# @:expose writes on `exports` when it exists: the page needs the classes on window
perl -pi -e 's/\}\)\(typeof exports != "undefined" \? exports : typeof window/})(typeof window/' "$OUT/src/$N.js"
# esbuild of the repository, or the one of npx when node_modules was installed in Docker (Linux binary)
ESB="$REPO/node_modules/.bin/esbuild"
if ! "$ESB" --version >/dev/null 2>&1; then ESB="npx --yes esbuild@0.25"; fi
# the Math functions of the bundles of the site (resources/js/games/builds/bundle.mjs, kado.ExactMath)
EXACT_MATH=""
for F in sin cos atan2 pow acos exp log; do EXACT_MATH="$EXACT_MATH --define:Math.$F=__kadoMath.$F"; done
cd "$OUT"   # (npx run from the repository would pick its node_modules/.bin again)
NODE_PATH="$REPO/node_modules" $ESB "$OUT/src/$N.js" --bundle --format=iife --target=es2018 --platform=browser \
    --sourcemap --outfile="$OUT/$N.js" --log-level=warning \
    --inject:"$REPO/resources/js/games/builds/exact-math.mjs" $EXACT_MATH
echo BUILD_OK
