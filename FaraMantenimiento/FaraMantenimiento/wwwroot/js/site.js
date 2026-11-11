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
        var tipoActual = (new URLSearchParams(window.location.search).get('tipo') || '').toLowerCase();
        var mejor = null, largo = -1;
        nav.querySelectorAll('a.sidebar-link[href^="/"]').forEach(function (a) {
            var partes = (a.getAttribute('href') || '').split('?');
            var h = partes[0].replace(/\/+$/, '').toLowerCase();
            if (!h) return;
            // Catálogos: todas las opciones comparten ruta y se distinguen por ?tipo=
            var tipoLink = (new URLSearchParams(partes[1] || '').get('tipo') || '').toLowerCase();
            if (tipoLink && tipoLink !== tipoActual) return;
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

    // Menú colapsado (escritorio): el nombre de cada opción sale en un tooltip y los submenús
    // (p. ej. Seguridad) se abren como desplegable flotante a la derecha del icono.
    function menuColapsado() {
        return document.body.getAttribute('data-sidebartype') === 'mini-sidebar'
            && window.matchMedia('(min-width: 1200px)').matches;
    }

    var flotante = null, enlaceFlotante = null;

    function cerrarFlotante() {
        if (flotante) { flotante.remove(); flotante = null; }
        if (enlaceFlotante) {
            enlaceFlotante.classList.remove('fara-flotante-abierto');
            enlaceFlotante.setAttribute('aria-expanded', 'false');
            enlaceFlotante = null;
        }
    }

    function abrirFlotante(enlace, submenu) {
        cerrarFlotante();
        var menu = document.createElement('div');
        menu.className = 'fara-menu-flotante';
        menu.setAttribute('role', 'menu');
        var titulo = enlace.querySelector('.hide-menu');
        if (titulo) {
            var cab = document.createElement('div');
            cab.className = 'fara-menu-flotante-titulo';
            cab.textContent = titulo.textContent.trim();
            menu.appendChild(cab);
        }
        submenu.querySelectorAll('a.sidebar-link').forEach(function (a) {
            var item = document.createElement('a');
            item.href = a.getAttribute('href');
            item.setAttribute('role', 'menuitem');
            item.textContent = (a.querySelector('.hide-menu') || a).textContent.trim();
            if (a.href === window.location.href) item.classList.add('active');
            menu.appendChild(item);
        });
        document.body.appendChild(menu);
        var r = enlace.getBoundingClientRect();
        var top = Math.min(r.top, window.innerHeight - menu.offsetHeight - 8);
        menu.style.left = (r.right + 10) + 'px';
        menu.style.top = Math.max(8, top) + 'px';
        flotante = menu;
        enlaceFlotante = enlace;
        enlace.classList.add('fara-flotante-abierto');
        enlace.setAttribute('aria-expanded', 'true');
        var primero = menu.querySelector('a');
        if (primero) primero.focus({ preventScroll: true });
    }

    function conectarMenuColapsado() {
        var nav = document.getElementById('sidebarnav');
        if (!nav) return;

        // Tooltips con el nombre (solo se muestran con el menú colapsado).
        if (window.bootstrap && bootstrap.Tooltip) {
            nav.querySelectorAll(':scope > .sidebar-item > .sidebar-link').forEach(function (a) {
                var texto = a.querySelector('.hide-menu');
                if (!texto) return;
                a.setAttribute('aria-label', texto.textContent.trim());
                var tip = new bootstrap.Tooltip(a, {
                    title: texto.textContent.trim(), placement: 'right', trigger: 'hover focus', container: 'body'
                });
                a.addEventListener('show.bs.tooltip', function (e) {
                    if (!menuColapsado() || a === enlaceFlotante) e.preventDefault();
                });
                a.addEventListener('click', function () { tip.hide(); });
            });
        }

        // Submenús como desplegable flotante.
        nav.querySelectorAll('.sidebar-link.has-arrow').forEach(function (a) {
            var submenu = a.nextElementSibling;
            if (!submenu || !submenu.classList.contains('first-level')) return;
            a.addEventListener('click', function (e) {
                if (!menuColapsado()) return;
                e.preventDefault();
                if (enlaceFlotante === a) cerrarFlotante(); else abrirFlotante(a, submenu);
            });
        });

        document.addEventListener('click', function (e) {
            if (!flotante) return;
            if (flotante.contains(e.target) || (enlaceFlotante && enlaceFlotante.contains(e.target))) return;
            cerrarFlotante();
        });
        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && flotante) {
                var volver = enlaceFlotante;
                cerrarFlotante();
                if (volver) volver.focus();
            }
        });
        window.addEventListener('resize', cerrarFlotante);
        document.addEventListener('scroll', cerrarFlotante, true);
        // Al expandir/colapsar el menú se cierra el desplegable.
        new MutationObserver(cerrarFlotante).observe(document.body, { attributes: true, attributeFilter: ['data-sidebartype'] });
    }

    function iniciar() {
        restaurarScroll();
        conectarToggleMenu();
        conectarMenuColapsado();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', iniciar);
    } else {
        iniciar();
    }
})();

/* Botón "Ahora" junto a un campo de fecha (data-fara-ahora="#idDelInput"): llena la fecha/hora local actual.
   No hay selector de fechas en wwwroot; se usa el input nativo (datetime-local / date). */
document.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('[data-fara-ahora]') : null;
    if (!btn) return;
    var input = document.querySelector(btn.getAttribute('data-fara-ahora'));
    if (!input) return;
    var d = new Date();
    var p = function (n) { return (n < 10 ? '0' : '') + n; };
    var fecha = d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
    input.value = input.type === 'date' ? fecha : fecha + 'T' + p(d.getHours()) + ':' + p(d.getMinutes());
    input.dispatchEvent(new Event('change', { bubbles: true }));
});
