{{-- a report in the admin (App\Filament\Resources\Reports\Tables\ReportsTable): the content and every report on it --}}
<div style="font-size: .875rem">
    <p style="margin: 0 0 .25rem">
        Par <strong>{{ $report->reportedUser?->display_name ?? '—' }}</strong>
        @if ($deleted) · <em>supprimé</em> @endif
    </p>
    <blockquote style="margin: 0 0 1rem; padding: .5rem .75rem; border-left: 3px solid #f59e0b; background: rgba(245, 158, 11, .08); white-space: pre-wrap; word-break: break-word">{{ $content?->reportExcerpt() ?? 'Le contenu a été effacé.' }}</blockquote>
    <p style="margin: 0 0 .25rem; font-weight: 600">Signalements</p>
    <ul style="margin: 0; padding-left: 1.25rem">
        @foreach ($others->prepend($report) as $item)
            <li>
                {{ $item->created_at?->format('d/m/Y H:i') }} — <strong>{{ $item->reporter?->display_name ?? '?' }}</strong> :
                {{ $item->reason->getLabel() }} ({{ $item->status->getLabel() }})
                @if ($item->details) <br><span style="opacity: .8">« {{ $item->details }} »</span> @endif
            </li>
        @endforeach
    </ul>
</div>
