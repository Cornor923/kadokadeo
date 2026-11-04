<?php

use App\Providers\AppServiceProvider;
use App\Providers\Filament\AdminPanelProvider;
use App\Providers\HelperServiceProvider;

return [
    AppServiceProvider::class,
    AdminPanelProvider::class,
    HelperServiceProvider::class,
];
