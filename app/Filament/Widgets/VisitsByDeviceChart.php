<?php

namespace App\Filament\Widgets;

use App\Enums\DeviceType;

class VisitsByDeviceChart extends VisitsChart
{
    protected ?string $heading = 'Appareils';

    protected ?string $maxHeight = '260px';

    protected function getType(): string
    {
        return 'doughnut';
    }

    protected function getData(): array
    {
        $visitors = $this->visitors('device');
        $counts = $colors = [];
        foreach (DeviceType::cases() as $i => $device) {
            $counts[$device->getLabel()] = $visitors[$device->value] ?? 0;
            $colors[] = self::COLORS[$i];
        }

        return $this->parts($counts, $colors);
    }

    protected function getOptions(): array
    {
        return $this->doughnutOptions();
    }
}
