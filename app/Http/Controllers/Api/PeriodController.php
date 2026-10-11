<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\PeriodResource;
use Illuminate\Http\Request;

class PeriodController extends Controller
{
    public function current(Request $request)
    {
        // dd('no');
        $currentPeriod = \App\Models\Period::current()->first();

        $res = PeriodResource::make($currentPeriod);
        $maxAge = now()->diffInSeconds(now()->endOfDay());
        $etag = md5('daily-'.now()->endOfDay()->toDateString());

        return $res->toResponse($request)
            ->setEtag($etag)
            ->setPublic()
            ->setMaxAge($maxAge)
            ->expire()
            ->setExpires(now()->endOfDay()->toDateTime());
    }
}
