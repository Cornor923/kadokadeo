#!/bin/sh
# Charlotte's Quest (Arkadeo): game.swf -> images + timeline tables -> Data.hx -> sprite sheets, written into this repository.
# Once: sh ../../tools/prepare_game.sh <WebGamesArchives>/Arkadeo/games/charlotteQuest charlottequest game
#   (swf/game.swf is the released game: the symbols of gfx.swf and the font "def"; FFDec: FFDEC="java -jar <ffdec.jar>")
# The start screen is made after a build of the game: node artwork.mjs, then artwork.py (see artwork.py).
# usage: sh rebuild_assets.sh <WebGamesArchives>/Arkadeo/games/charlotteQuest          env: KKP_WORK (default ~/kadokadeo-port)
set -e
if [ -z "$1" ]; then sed -n 2,6p "$0"; exit 1; fi
HERE=$(cd "$(dirname "$0")" && pwd)
T="$HERE/../../tools"
REPO=$(cd "$HERE/../../../../../.." && pwd)
W="${KKP_WORK:-$HOME/kadokadeo-port}/charlottequest"
ARCH=$(cd "$1" && pwd)
PY=${PYTHON:-python3}
cd "$W"
$PY "$HERE/charlottesquest_assets.py" "$ARCH" "$W/out" > assets.log 2>&1 || { tail -20 assets.log; exit 1; }
grep -E "WARN|clips [0-9]|font " assets.log || true
$PY "$HERE/charlottesquest_data.py" "$W/out" "$REPO/resources/hx/games/charlottesquest/Data.hx"
rm -rf sheet && mkdir sheet
# 2040, not 2048: a power-of-two sheet gets mipmaps that bleed into the neighbouring sprites
PACK_MAX=2040 PACK_SCALE=1.5 $PY "$T/pack_multi.py" out/src sheet/charlottesquest out/pivots.json | tail -1
D="$REPO/public/assets/img/content/charlottesquest"
rm -rf "$D" && mkdir -p "$D"
cp sheet/charlottesquest-*.json sheet/charlottesquest-*.png "$D/"
cp -r out/src "$D/src"
$PY "$T/make_tps.py" "$T/tpl.tps" out/src out/pivots.json "$D/charlottesquest.tps" charlottesquest
