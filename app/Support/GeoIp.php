<?php

namespace App\Support;

use MaxMind\Db\Reader;

// the country of an IP, read in the local database of kado:geoip:update: no IP leaves the server
class GeoIp
{
    // ISO 3166-1 alpha-2 code, null when it is not known (no database yet, private address)
    public function country(?string $ip): ?string
    {
        $path = config('kado.geoip.path');
        if (!is_file($path) || !filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) {
            return null;
        }
        $reader = new Reader($path);
        try {
            return $reader->get($ip)['country']['iso_code'] ?? null;
        } finally {
            $reader->close();
        }
    }
}
