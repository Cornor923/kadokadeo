<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Http;
use MaxMind\Db\Reader;
use Throwable;

/**
 * The IP -> country database of App\Support\GeoIp: DB-IP Lite (CC BY 4.0, the link back is in the admin widget), a new
 * file each month. Run every few minutes because storage/ is wiped at each deploy: nothing to do most of the time, the
 * date of the file is the month of its release.
 */
class UpdateGeoIpDatabase extends Command
{
    protected $signature = 'kado:geoip:update {--force : download it even when it is up to date}';

    protected $description = 'Download the IP to country database when it is missing or from an older month';

    private const URL = 'https://download.db-ip.com/free/dbip-country-lite-%s.mmdb.gz';

    // the release of the month comes some time after its first day: an older file still works, so it is not asked for
    // every 5 minutes
    private const RETRY_KEY = 'geoip.update_tried';

    private const RETRY_HOURS = 6;

    public function handle(): int
    {
        $path = config('kado.geoip.path');
        $thisMonth = now()->startOfMonth();

        if (!$this->option('force') && is_file($path)) {
            if (filemtime($path) >= $thisMonth->getTimestamp() || !Cache::add(self::RETRY_KEY, true, now()->addHours(self::RETRY_HOURS))) {
                return self::SUCCESS;
            }
        }

        foreach ([$thisMonth, $thisMonth->copy()->subMonthNoOverflow()] as $month) {
            if ($this->download($month, $path)) {
                $this->info("IP database of {$month->format('Y-m')} installed");

                return self::SUCCESS;
            }
        }
        $this->warn('no IP database could be downloaded');

        return self::FAILURE;
    }

    private function download(Carbon $month, string $path): bool
    {
        $partial = "{$path}.tmp";
        try {
            $response = Http::timeout(120)->get(sprintf(self::URL, $month->format('Y-m')));
            $database = $response->successful() ? gzdecode($response->body()) : false;
            if ($database === false) {
                return false;
            }
            File::ensureDirectoryExists(dirname($path));
            File::put($partial, $database);
            // (throws on a file that is not a database, before the good one is replaced)
            (new Reader($partial))->close();
            rename($partial, $path);
            touch($path, $month->getTimestamp());

            return true;
        } catch (Throwable $e) {
            $this->warn($e->getMessage());
            File::delete($partial);

            return false;
        }
    }
}
