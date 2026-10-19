{{-- the preview of a text written in Marktwin, in a form of the admin (<kado-marktwin>, resources/js/admin/marktwin.js) --}}
@if (trim($text ?? '') === '')
    <p style="margin: 0; font-size: .875rem; opacity: .6; font-style: italic">Le message s'affichera ici.</p>
@else
    <kado-marktwin text="{{ $text }}"></kado-marktwin>
@endif
