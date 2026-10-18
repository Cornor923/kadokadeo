#!/bin/sh
# Rock Faller: pictures of the Arkadeo HTML5 port + font of the original gfx.swf -> single images + Data.hx -> sprite
# sheet, sounds, written into this repository. Sources: the `rockfaller/web` folder of the Arkadeo HTML5 port
# (img/content/rockfaller: the symbols of gfx.swf rendered by the port, sounds: the sounds of the original in mp3) and
# the original gfx.swf (<WebGamesArchives>/Arkadeo/games/rockFaller/gfx/gfx.swf, its embedded font).
# The start screen is made after a build of the game: node artwork.mjs, then artwork.py (see artwork.py).
# usage: sh rebuild_assets.sh <rockfaller/web folder> <gfx.swf>          env: KKP_WORK (default ~/kadokadeo-port)
set -e
if [ -z "$2" ]; then sed -n 2,7p "$0"; exit 1; fi
HERE=$(cd "$(dirname "$0")" && pwd)
T="$HERE/../../tools"
REPO=$(cd "$HERE/../../../../../.." && pwd)
W="${KKP_WORK:-$HOME/kadokadeo-port}/rockfaller"
SRC=$(cd "$1" && pwd)
SWF=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
PY=${PYTHON:-python3}
mkdir -p "$W" && cd "$W"
$PY "$HERE/rockfaller_assets.py" "$SRC/img/content/rockfaller" "$SWF" "$W/out" > assets.log 2>&1 || { tail -20 assets.log; exit 1; }
grep -E "WARN|atlas" assets.log || true
$PY "$HERE/rockfaller_data.py" "$W/out" "$REPO/resources/hx/games/rockfaller/Data.hx"
rm -rf sheet && mkdir sheet
# 2040, not 2048: a power-of-two sheet gets mipmaps that bleed into the neighbouring sprites
PACK_MAX=2040 $PY "$T/pack_multi.py" out/src sheet/rockfaller out/pivots.json | tail -1
D="$REPO/public/assets/img/content/rockfaller"
rm -rf "$D" && mkdir -p "$D"
cp sheet/rockfaller-*.json sheet/rockfaller-*.png "$D/"
cp -r out/src "$D/src"
$PY "$T/make_tps.py" "$T/tpl.tps" out/src out/pivots.json "$D/rockfaller.tps" rockfaller
S="$REPO/public/assets/sound/rockfaller"
rm -rf "$S" && mkdir -p "$S"
cp "$SRC"/sounds/*.mp3 "$S/"
echo "sounds: $(ls "$S" | wc -l)"
