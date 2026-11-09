/*
 * Tablas Fara: mostrar N, buscar, orden y paginación.
 * Uso: <table data-fara-tabla> ... </table>
 *   - data-por-pagina="25"
 *   - data-orden en celdas
 *   - clase "fara-col-accion" no ordenable
 */
(function () {
    'use strict';

    var OPCIONES = [5, 10, 15, 20, 25, 0];

    function texto(el) { return (el.textContent || '').replace(/\s+/g, ' ').trim(); }
    function esMensaje(tr) { return tr.cells.length <= 1; }
    function valorOrden(td) {
        if (!td) return '';
        var v = td.getAttribute('data-orden');
        if (v === null) v = texto(td);
        var n = Number(String(v).replace(/,/g, ''));
        return v !== '' && !isNaN(n) ? n : String(v).toLowerCase();
    }
    function crear(tag, cls, html) {
        var el = document.createElement(tag);
        if (cls) el.className = cls;
        if (html !== undefined) el.innerHTML = html;
        return el;
    }

    function iniciar(tabla) {
        var tbody = tabla.tBodies[0];
        if (!tbody || tabla.dataset.faraListo) return;
        tabla.dataset.faraListo = '1';

        var inicial = (tabla.dataset.porPagina || '10').toLowerCase();
        var porPagina = inicial === 'todos' ? 0 : parseInt(inicial, 10);
        if (OPCIONES.indexOf(porPagina) < 0) porPagina = 10;

        var filas = [], mensajes = [];
        var pagina = 1, busqueda = '', filtroExtra = null, ordenCol = -1, ordenAsc = true;
        if (!tabla.id) tabla.id = 'tabla-' + Math.random().toString(36).slice(2, 8);

        var scroll = crear('div', 'fara-tabla-scroll');
        tabla.parentNode.insertBefore(scroll, tabla);
        scroll.appendChild(tabla);

        var arriba = crear('div', 'fara-tabla-top');
        arriba.innerHTML =
            '<label class="fara-tabla-ctl">Mostrar ' +
            '<select class="form-select form-select-sm" aria-label="Registros por página">' +
            OPCIONES.map(function (n) {
                return '<option value="' + n + '"' + (n === porPagina ? ' selected' : '') + '>' +
                    (n === 0 ? 'Todos' : n) + '</option>';
            }).join('') + '</select> registros</label>' +
            '<label class="fara-tabla-ctl">Buscar: <input type="search" class="form-control form-control-sm" aria-controls="' + tabla.id + '" /></label>';
        scroll.parentNode.insertBefore(arriba, scroll);

        var abajo = crear('div', 'fara-tabla-bottom');
        var info = crear('span', 'fara-tabla-info');
        info.setAttribute('aria-live', 'polite');
        var nav = crear('nav', 'fara-paginacion');
        nav.setAttribute('aria-label', 'Paginación');
        abajo.appendChild(info);
        abajo.appendChild(nav);
        scroll.parentNode.insertBefore(abajo, scroll.nextSibling);

        var select = arriba.querySelector('select');
        var input = arriba.querySelector('input');

        function leerFilas() {
            var todas = Array.prototype.slice.call(tbody.rows);
            filas = todas.filter(function (tr) { return !esMensaje(tr); });
            mensajes = todas.filter(esMensaje);
        }

        function visibles() {
            return filas.filter(function (tr) {
                if (filtroExtra && !filtroExtra(tr)) return false;
                return !busqueda || texto(tr).toLowerCase().indexOf(busqueda) >= 0;
            });
        }

        function boton(etq, pag, deshabilitado, activo) {
            var b = crear('button', 'fara-pag-btn' + (activo ? ' activo' : ''), etq);
            b.type = 'button';
            b.disabled = !!deshabilitado;
            if (activo) b.setAttribute('aria-current', 'page');
            b.addEventListener('click', function () { pagina = pag; pintar(); });
            return b;
        }

        function pintar() {
            var hayDatos = filas.length > 0;
            arriba.style.display = hayDatos ? '' : 'none';
            abajo.style.display = hayDatos ? '' : 'none';
            mensajes.forEach(function (tr) { tr.style.display = hayDatos ? 'none' : ''; });
            if (!hayDatos) return;

            var lista = visibles();
            var total = lista.length;
            var tam = porPagina === 0 ? Math.max(total, 1) : porPagina;
            var paginas = Math.max(1, Math.ceil(total / tam));
            if (pagina > paginas) pagina = paginas;
            if (pagina < 1) pagina = 1;
            var ini = (pagina - 1) * tam;
            var fin = Math.min(ini + tam, total);

            filas.forEach(function (tr) { tr.style.display = 'none'; });
            lista.slice(ini, fin).forEach(function (tr) { tr.style.display = ''; tbody.appendChild(tr); });

            info.textContent = total === 0
                ? 'Sin resultados para la búsqueda'
                : 'Mostrando ' + (ini + 1) + ' a ' + fin + ' de ' + total + ' registros' +
                  (total < filas.length ? ' (filtrado de ' + filas.length + ')' : '');

            nav.innerHTML = '';
            nav.style.display = paginas > 1 ? '' : 'none';
            if (paginas <= 1) return;
            nav.appendChild(boton('Anterior', pagina - 1, pagina <= 1));
            var desde = Math.max(1, pagina - 2), hasta = Math.min(paginas, desde + 4);
            desde = Math.max(1, hasta - 4);
            for (var p = desde; p <= hasta; p++) nav.appendChild(boton(String(p), p, false, p === pagina));
            nav.appendChild(boton('Siguiente', pagina + 1, pagina >= paginas));
        }

        function ordenar(col) {
            ordenAsc = ordenCol === col ? !ordenAsc : true;
            ordenCol = col;
            filas.sort(function (a, b) {
                var x = valorOrden(a.cells[col]), y = valorOrden(b.cells[col]);
                if (x === y) return 0;
                return (x > y ? 1 : -1) * (ordenAsc ? 1 : -1);
            });
            Array.prototype.forEach.call(tabla.tHead.rows[0].cells, function (th, i) {
                if (th.classList.contains('fara-ordenable'))
                    th.setAttribute('aria-sort', i === col ? (ordenAsc ? 'ascending' : 'descending') : 'none');
            });
            pagina = 1;
            pintar();
        }

        if (tabla.tHead && tabla.tHead.rows[0]) {
            Array.prototype.forEach.call(tabla.tHead.rows[0].cells, function (th, i) {
                if (th.classList.contains('fara-col-accion') || !texto(th)) return;
                th.classList.add('fara-ordenable');
                th.tabIndex = 0;
                th.setAttribute('aria-sort', 'none');
                th.addEventListener('click', function () { ordenar(i); });
                th.addEventListener('keydown', function (e) {
                    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); ordenar(i); }
                });
            });
        }

        select.addEventListener('change', function () { porPagina = parseInt(select.value, 10); pagina = 1; pintar(); });
        input.addEventListener('input', function () { busqueda = input.value.trim().toLowerCase(); pagina = 1; pintar(); });

        tabla.faraFiltro = function (fn) { filtroExtra = fn; pagina = 1; pintar(); };
        tabla.faraRecargar = function () { leerFilas(); ordenCol = -1; pagina = 1; pintar(); };

        leerFilas();
        pintar();
    }

    function todo() { document.querySelectorAll('table[data-fara-tabla]').forEach(iniciar); }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', todo);
    else todo();
})();
