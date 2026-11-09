# Skin de La Brute

Chaque image de ce dossier remplace un dessin du jeu, d'après son nom (sans l'extension). Aucune n'est obligatoire :
sans elle, le jeu garde son dessin. Formats : png, webp, jpg, gif, svg (polices : woff2, woff, ttf, otf).

Après avoir ajouté, renommé ou supprimé une image :

    docker exec kadokadeo_front node .opencode/skills/flash-port/scripts/examples/labrute/build_skin.mjs

    node .opencode/skills/flash-port/scripts/examples/labrute/build_skin.mjs

(depuis la racine du projet), qui met à jour `skin.json`. Puis recharger la page du jeu.

Pour un chargement léger, les SVG, les animaux et les polices sont convertis une fois pour toutes :

    docker exec -w /www -e NODE_TOOLS=/tmp/lbtools kadokadeo_front node .opencode/skills/flash-port/scripts/examples/labrute/optimize_skin.mjs .

(une première fois : `docker exec kadokadeo_front sh -c 'mkdir -p /tmp/lbtools && cd /tmp/lbtools && npm i sharp@0.33.5 wawoff2@2.0.1'`).
Il dessine chaque SVG en WebP au double de sa plus grande taille dans le jeu (son origine dans `origins.json`), réduit
les animaux au double de leur taille, passe les polices en WOFF2, range les originaux dans `src/` (jamais chargé), puis
refait `skin.json`. Pour changer une image : mettre la nouvelle (SVG, PNG…) ici, relancer le script.

Les icônes des compétences ne sont pas dans le skin : elles sont dans la planche `labrute-1.webp`, faite par
`build_skills.mjs` à partir des SVG de labrute-react (`client/public/images/skills`, un dossier `tier-1/`, `tier-2/`,
`tier-3/` donné en argument).

| Nom | Où | Taille d'affichage |
| --- | --- | --- |
| `background` | fond de la boutique et du choix (étiré) | 600 × 460 | ✅
| `topbar` | bandeau du haut (étiré) | 600 × 44 | ✅
| `card` | cartes des adversaires (bords de 16 px conservés) | 186 × 400 | ✅
| `recap` | fond du récap de victoire (bords de 16 px conservés) | 360 × ~250 | ✅
| `button`, `button-hover` | boutons (étirés) | variable, ~272 × 32 | ✅
| `button-square`, `button-square-hover` | achat des stats | 42 × 37 | ✅
| `fight`, `fight-hover` | bouton du combat | 166 × 46 | ✅
| `hp` | cœur des PV (le nombre est écrit dessus) | ~40 × 34 | ✅
| `strength`, `agility`, `speed` | icônes des stats | 13 × 13 | ✅
| `gold` | pièce d'or | ~20 × 20 | ✅
| `ear` | oreille coupée : la monnaie des améliorations (bandeau du haut à droite de l'or, prix des niveaux dans les infobulles, gain du récap) | ~24 × 24 |
| `rank-1` … `rank-12` | ligues (1 = la première) | 36 × 36 | ✅
| `ranking` | icône devant les cases de progression de ligue | 22 × 20 | ✅
| `pet-dog1`, `pet-dog2`, `pet-dog3`, `pet-panther`, `pet-bear` | animaux | ~48 × 42 | ✅
| `confetti-1`, `confetti-2`… | confettis de victoire (images de l'animation) | 12 × 12 | ✅
| `header` | bandeau du haut du combat, tout en haut, contour noir de 1,5 px ajouté par le code (sous les têtes : leurs fenêtres x 8-62 et 538-592, y 43-91 peuvent être transparentes) | 600 × 93 | ✅
| `font` | police de tous les textes (woff2, woff, ttf, otf) | | ✅ (helvetica ou sans serif de base)
| `font-body` | police des tooltips seulement (sans elle : `font`) | | ✅ (inutilisée)
| `font-title` | police des titres de page, du bandeau du vainqueur, des textes des boutons, de l'or du bandeau et des récompenses, du nom des combattants (sans elle : `font`) | | ✅
| `button-recap`, `button-recap-hover` | bouton Continuer du récap (le texte reste dessus) | 140 de large | ✅
| `panel-weapons` | tableau des armes de la boutique (étiré) | 311 × 210 × 0,85 | ✅
| `weapon-knife`, `weapon-sword`… (nom de l'arme dans le code), `weapon-bare-hands` | armes posées sur le tableau, au même endroit que dans LaBrute (`WEAPON_PLACES` de ShopScreen.hx) ; aussi l'image de leur infobulle | SVG : leur point (0, 0) est l'origine du dessin, leur viewBox peut commencer avant | ✅
| `notif-banner` | bannière du dernier achat ou amélioration, entre « Nouvelle arme » et le combat (les 8 px du bas : son ombre ; à gauche la case de l'icône 72 × 69, à droite celle du texte 294 × 69, contours de 3 px) | 375 × 82, mis à 37 de haut (sans l’ombre), la partie texte resserrée | ✅
| `weapon-tip-knife`, `weapon-tip-sword`… | image horizontale de l'arme dans son infobulle (sans elle : `weapon-…`) | taille de l'image, 50 de haut au plus |  ❌ not necessary
| `flag-fr`, `flag-en`, `flag-de`… | drapeau de la langue, en bas à gauche après la touche L (sans lui : l'italien et le coréen dessinés), mis en WebP 32 × 24 par optimize_skin.mjs (recadré, rempli) | 16 × 12 | ✅

Langues : toute image peut avoir sa version par langue, `<nom>-<langue>` (`fight-en`, `fight-hover-en`…), prise à la
place de `<nom>` dans cette langue ; sans elle, la version anglaise (`-en`), puis `<nom>` (le français : le nom seul).

`fight` sert aussi aux boutons du choix des combats, sans texte par-dessus (le texte est dans
l'image). Les boutons gardent les proportions de leur image : le code fixe leur largeur (`fight` 166, `button` 168,
`button-recap` 140), la hauteur en découle.

Les images sont réduites ou étirées à ces tailles : les fournir au double donne un rendu net.
