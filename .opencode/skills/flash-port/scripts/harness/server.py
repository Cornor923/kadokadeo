"""Test server of the harness: no cache, serves
  /<pkg>.js, /<pkg>.js.map     the bundles written by build.sh   ($KKP_WORK/build)
  /modes/<pkg>.js              the test modes of a game          (modes/ next to this file)
  /assets/..., /fonts/...      the repository's public/ folder   (the game's sprite sheets, fonts)
  /vendor/<file>               PIXI 6.0.2 and pixi-filters 5.0.0: the files of the site (public/vendor of the
                               repository)
  anything else                www/ next to this file            (game.html, pixi-tween.js)
usage: python3 server.py [port]   (default 8765; one port per session if several run at the same time)
env: KKP_WORK (default ~/kadokadeo-port), KK_PUBLIC (default: public/ of the repository holding this file)"""
import http.server, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..', '..'))
WORK = os.environ.get('KKP_WORK', os.path.expanduser('~/kadokadeo-port'))
ROOT_BUILD = os.path.join(WORK, 'build')
ROOT_WWW = os.path.join(HERE, 'www')
ROOT_MODES = os.path.join(HERE, 'modes')
ROOT_PUBLIC = os.environ.get('KK_PUBLIC', os.path.join(REPO, 'public'))
# the files of the site (resources/views/layouts/default.blade.php)
VENDOR = {
    'pixi.js': 'vendor/pixi.js/6.0.2/pixi.min.js',
    'pixi-filters.min.js': 'vendor/pixi-filters/5.0.0/pixi-filters.min.js',
}


class H(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        p = path.split('?', 1)[0].split('#', 1)[0].lstrip('/')
        if p.startswith('assets/') or p.startswith('fonts/'):
            return os.path.join(ROOT_PUBLIC, p)
        if p.startswith('vendor/') and p[len('vendor/'):] in VENDOR:
            return os.path.join(ROOT_PUBLIC, VENDOR[p[len('vendor/'):]])
        if p.startswith('modes/'):
            return os.path.join(ROOT_MODES, p[len('modes/'):])
        if os.path.exists(os.path.join(ROOT_BUILD, p)) and p:
            return os.path.join(ROOT_BUILD, p)
        return os.path.join(ROOT_WWW, p or 'index.html')

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *a):
        pass


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
print('harness on http://127.0.0.1:%d/game.html?game=<pkg>&cls=Game<Name>&seed=123  (public: %s)' % (port, ROOT_PUBLIC), flush=True)
http.server.ThreadingHTTPServer(('127.0.0.1', port), H).serve_forever()
