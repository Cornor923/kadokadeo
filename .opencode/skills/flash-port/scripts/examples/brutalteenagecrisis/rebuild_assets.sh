#!/bin/sh
# Brutal Teenage Crisis: atlases of the Arkadeo game -> single images + Data.hx -> sprite sheet, written into this
# repository. The source is the `btc/web` folder of the Arkadeo HTML5 port (sheet.png/xml, sheet.anims.xml,
# backgrounds.png/xml, testLevel.png: the SpriteLib atlases of the original game).
# usage: sh rebuild_assets.sh <btc/web folder>          env: KKP_WORK (default ~/kadokadeo-port)
set -e
if [ -z "$1" ]; then sed -n 2,5p "$0"; exit 1; fi
HERE=$(cd "$(dirname "$0")" && pwd)
T="$HERE/../../tools"
REPO=$(cd "$HERE/../../../../../.." && pwd)
W="${KKP_WORK:-$HOME/kadokadeo-port}/brutalteenagecrisis"
SRC=$(cd "$1" && pwd)
mkdir -p "$W" && cd "$W"
python3 "$HERE/brutalteenagecrisis_assets.py" "$SRC" "$W/out" > assets.log 2>&1 || { tail -20 assets.log; exit 1; }
head -1 assets.log
python3 "$HERE/brutalteenagecrisis_data.py" "$W/out" "$REPO/resources/hx/games/brutalteenagecrisis/Data.hx"
rm -rf sheet && mkdir sheet
# 2040, not 2048: a power-of-two sheet gets mipmaps that bleed into the neighbouring sprites
PACK_MAX=2040 python3 "$T/pack_multi.py" out/src sheet/brutalteenagecrisis out/pivots.json | tail -1
D="$REPO/public/assets/img/content/brutalteenagecrisis"
rm -rf "$D" && mkdir -p "$D"
cp sheet/brutalteenagecrisis-*.json sheet/brutalteenagecrisis-*.png "$D/"
cp -r out/src "$D/src"
python3 "$T/make_tps.py" "$T/tpl.tps" out/src out/pivots.json "$D/brutalteenagecrisis.tps" brutalteenagecrisis
