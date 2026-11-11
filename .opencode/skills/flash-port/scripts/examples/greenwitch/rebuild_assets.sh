#!/bin/sh
# Green Witch (Arkadeo): the PNG atlases, the font, the plans of the dungeons, the texts and the sounds of the original
# game folder -> Data.hx + sprite sheet + mp3 files, written into this repository. The source is Arkadeo/games/greenWitch
# (assets/*.png, obj/greenwitchResources.swf, levelInfos.xml, texts.fr.xml, sounds/). Needs Pillow, numpy and lameenc.
# The start screen is made after a build of the game: node artwork.mjs, then artwork.py (see artwork.py).
# usage: sh rebuild_assets.sh <Arkadeo/games/greenWitch>          env: KKP_WORK (default ~/kadokadeo-port)
set -e
if [ -z "$1" ]; then sed -n 2,7p "$0"; exit 1; fi
HERE=$(cd "$(dirname "$0")" && pwd)
T="$HERE/../../tools"
REPO=$(cd "$HERE/../../../../../.." && pwd)
W="${KKP_WORK:-$HOME/kadokadeo-port}/greenwitch"
ARCH=$(cd "$1" && pwd)
PY=${PYTHON:-python3}
mkdir -p "$W" && cd "$W"
$PY "$HERE/greenwitch_assets.py" "$ARCH" "$W/out" > assets.log 2>&1 || { tail -20 assets.log; exit 1; }
grep -E "atlas|dungeon|font|sounds" assets.log || true
$PY "$HERE/greenwitch_data.py" "$W/out" "$REPO/resources/hx/games/greenwitch/Data.hx"
rm -rf sheet && mkdir sheet
# 2040, not 2048: a power-of-two sheet gets mipmaps that bleed into the neighbouring sprites
PACK_MAX=2040 $PY "$T/pack_multi.py" out/src sheet/greenwitch out/pivots.json | tail -1
D="$REPO/public/assets/img/content/greenwitch"
rm -rf "$D" && mkdir -p "$D"
cp sheet/greenwitch-*.json sheet/greenwitch-*.png "$D/"
cp -r out/src "$D/src"
$PY "$T/make_tps.py" "$T/tpl.tps" out/src out/pivots.json "$D/greenwitch.tps" greenwitch
S="$REPO/public/assets/sound/greenwitch"
rm -rf "$S" && mkdir -p "$S"
cp out/sound/*.mp3 "$S/"
