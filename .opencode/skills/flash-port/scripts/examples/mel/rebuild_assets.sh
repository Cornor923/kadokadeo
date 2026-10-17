#!/bin/sh
# Mel (Arkadeo): game.swf -> images + timeline tables -> Art.hx -> sprite sheets, start screen, written into this repository.
# Once: sh ../../tools/prepare_game.sh <WebGamesArchives>/Arkadeo/games/mel mel game
#   (swf/game.swf is the released game: gfx/gfx.swf only wraps its graphics in a DefineBinaryData)
# usage: sh rebuild_assets.sh          env: KKP_WORK (default ~/kadokadeo-port)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
T="$HERE/../../tools"
REPO=$(cd "$HERE/../../../../../.." && pwd)
W="${KKP_WORK:-$HOME/kadokadeo-port}/mel"
PY=${PYTHON:-python3}
cd "$W"
$PY "$HERE/mel_assets.py" "$W/out" > assets.log 2>&1 || { tail -20 assets.log; exit 1; }
grep -E "WARN|clips [0-9]" assets.log || true
$PY "$HERE/mel_data.py" "$W/out" "$REPO/resources/hx/games/mel/Art.hx"
rm -rf sheet && mkdir sheet
# 2040, not 2048: a power-of-two sheet gets mipmaps that bleed into the neighbouring sprites
PACK_MAX=2040 $PY "$T/pack_multi.py" out/src sheet/mel out/pivots.json | tail -1
D="$REPO/public/assets/img/content/mel"
rm -rf "$D" && mkdir -p "$D"
cp sheet/mel-*.json sheet/mel-*.png "$D/"
cp -r out/src "$D/src"
$PY "$T/make_tps.py" "$T/tpl.tps" out/src out/pivots.json "$D/mel.tps" mel
# start screen (600 x 460: the game area of an Arkadeo game)
$PY "$HERE/mel_artwork.py" "$REPO/public/assets/img/gfx/artwork/mel.jpg" "$W/out/Mel_thumb.png"
