/* Comportamiento general del layout (menú lateral). Otros scripts: selects.js, fara-comun.js, fara-modal.js. */
(function () {
    'use strict';

    var CLAVE_SCROLL = 'fara.sidebar.scroll';

    function contenedorScroll() {
        var raiz = document.querySelector('.left-sidebar .scroll-sidebar');
        if (!raiz) return null;
        if (window.SimpleBar && SimpleBar.instances && SimpleBar.instances.get(raiz)) {
            return SimpleBar.instances.get(raiz).getScrollElement();
        }
        return raiz.querySelector('.simplebar-content-wrapper') || raiz;
    }

    // Si sidebarmenu.js no encontró coincidencia exacta (p. ej. URL con filtros), marcar por ruta.
    function marcarActivo() {
        var nav = document.getElementById('sidebarnav');
        if (!nav) return null;
        var activo = nav.querySelector('a.sidebar-link.active');
        if (activo) return activo;
        var ruta = window.location.pathname.replace(/\/+$/, '').toLowerCase() || '/';
        var mejor = null, largo = -1;
        nav.querySelectorAll('a.sidebar-link[href^="/"]').forEach(function (a) {
            var h = (a.getAttribute('href') || '').replace(/\/+$/, '').toLowerCase();
            if (!h) return;
            if ((ruta === h || ruta.indexOf(h + '/') === 0) && h.length > largo) { mejor = a; largo = h.length; }
        });
        if (mejor) {
            mejor.classList.add('active');
            var ul = mejor.closest('ul.first-level');
            if (ul) { ul.classList.add('in'); if (ul.parentElement) ul.parentElement.classList.add('selected'); }
        }
        return mejor;
    }

    function restaurarScroll() {
        var cont = contenedorScroll();
        if (!cont) return;
        var guardado = null;
        try { guardado = sessionStorage.getItem(CLAVE_SCROLL); } catch (e) { /* sin storage */ }
        var activo = marcarActivo();
        if (guardado !== null && !isNaN(+guardado)) {
            cont.scrollTop = +guardado;
        }
        // Si el ítem activo quedó fuera de la vista, centrarlo dentro del contenedor del menú.
        if (activo) {
            var rc = cont.getBoundingClientRect(), ra = activo.getBoundingClientRect();
            if (ra.top < rc.top || ra.bottom > rc.bottom) {
                cont.scrollTop += (ra.top - rc.top) - (rc.height / 2) + (ra.height / 2);
            }
        }
        cont.addEventListener('scroll', function () {
            try { sessionStorage.setItem(CLAVE_SCROLL, String(cont.scrollTop)); } catch (e) { /* sin storage */ }
        }, { passive: true });
    }

    // Abrir/cerrar menú. app.min.js de la plantilla solo lo conecta si existe el panel
    // ".customizer" (que aquí no se usa), así que se maneja aquí.
    function conectarToggleMenu() {
        if (document.querySelector('.customizer')) return; // la plantilla ya lo maneja
        var wrapper = document.getElementById('main-wrapper');
        if (!wrapper) return;
        if (!document.body.getAttribute('data-sidebartype')) {
            document.body.setAttribute('data-sidebartype', 'full');
        }
        document.querySelectorAll('.sidebartoggler').forEach(function (el) {
            el.addEventListener('click', function (e) {
                e.preventDefault();
                wrapper.classList.toggle('show-sidebar');
                document.querySelectorAll('.sidebarmenu').forEach(function (m) { m.classList.toggle('close'); });
                if (window.matchMedia('(min-width: 1200px)').matches) {
                    var tipo = document.body.getAttribute('data-sidebartype');
                    document.body.setAttribute('data-sidebartype', tipo === 'full' ? 'mini-sidebar' : 'full');
                }
            });
        });
    }

    function iniciar() {
        restaurarScroll();
        conectarToggleMenu();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', iniciar);
    } else {
        iniciar();
    }
})();
