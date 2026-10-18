{{-- <kado-marktwin>: the texts written in Marktwin (resources/js/admin/marktwin.js), when the bundles exist --}}
@if (file_exists(public_path('build/manifest.json')) || file_exists(public_path('hot')))
    @vite(['resources/js/admin/marktwin.js'])
@endif
