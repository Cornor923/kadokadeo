<?php

namespace App\Models;

use App\Enums\DeviceType;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\MassPrunable;
use Illuminate\Database\Eloquent\Model;

/**
 * A player seen on a day, with what and from where (App\Services\VisitService): the stats of the admin page « Fréquentation ». Never
 * holds the IP.
 *
 * @property string $date
 * @property int $user_id
 * @property DeviceType $device
 * @property string $browser
 * @property string $country
 */
class SiteVisit extends Model
{
    use MassPrunable;

    public const KEEP_DAYS = 90;

    // the code that ISO 3166 leaves free, used by the IP databases too (null would escape the unique index of the table)
    public const UNKNOWN_COUNTRY = 'ZZ';

    public const UNKNOWN_BROWSER = 'Autre';

    public $timestamps = false;

    protected $fillable = ['date', 'user_id', 'device', 'browser', 'country'];

    protected $casts = [
        'device' => DeviceType::class,
    ];

    public function prunable(): Builder
    {
        return static::where('date', '<', today()->subDays(self::KEEP_DAYS)->toDateString());
    }
}
