#!/bin/sh
# NosuShi (Arkadeo): gfx.swf -> images + timeline tables -> Data.hx -> sprite sheet, written into this repository.
# Once: sh ../../tools/prepare_game.sh <WebGamesArchives>/Arkadeo/games/nosushi nosushi gfx
#   (FFDec: FFDEC="java -jar <ffdec.jar>"; the points use the system Arial Bold: ARIAL_BOLD=<arialbd.ttf>)
# The start screen is made after a build of the game: node artwork.mjs, then artwork.py (see artwork.py).
# usage: sh rebuild_assets.sh          env: KKP_WORK (default ~/kadokadeo-port)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
T="$HERE/../../tools"
REPO=$(cd "$HERE/../../../../../.." && pwd)
W="${KKP_WORK:-$HOME/kadokadeo-port}/nosushi"
PY=${PYTHON:-python3}
cd "$W"
$PY "$HERE/nosushi_assets.py" "$W/out" > assets.log 2>&1 || { tail -20 assets.log; exit 1; }
grep -E "WARN|clips [0-9]|moves field" assets.log || true
$PY "$HERE/nosushi_data.py" "$W/out" "$REPO/resources/hx/games/nosushi/Data.hx"
rm -rf sheet && mkdir sheet
# 2040, not 2048: a power-of-two sheet gets mipmaps that bleed into the neighbouring sprites
PACK_MAX=2040 $PY "$T/pack_multi.py" out/src sheet/nosushi out/pivots.json | tail -1
D="$REPO/public/assets/img/content/nosushi"
rm -rf "$D" && mkdir -p "$D"
cp sheet/nosushi-*.json sheet/nosushi-*.png "$D/"
cp -r out/src "$D/src"
$PY "$T/make_tps.py" "$T/tpl.tps" out/src out/pivots.json "$D/nosushi.tps" nosushi
