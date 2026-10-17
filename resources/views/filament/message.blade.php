{{-- a private message, in the admin (App\Filament\Resources\Messages\Tables\MessagesTable): its body written in Marktwin --}}
<div style="font-size: .875rem">
    <p style="margin: 0 0 .25rem">
        De <strong>{{ $message->sender?->display_name ?? 'KadoKado' }}</strong>
        à <strong>{{ $message->recipient?->display_name ?? '?' }}</strong>,
        le {{ $message->created_at?->format('d/m/Y à H:i') }}
    </p>
    <p style="margin: 0 0 1rem; opacity: .7">
        {{ $message->read_at ? 'Lu le '.$message->read_at->format('d/m/Y à H:i') : 'Pas encore lu' }}
        @if ($message->sender_deleted_at) · supprimé par l'expéditeur @endif
        @if ($message->recipient_deleted_at) · supprimé par le destinataire @endif
    </p>
    <kado-marktwin text="{{ $message->body }}"></kado-marktwin>
</div>
