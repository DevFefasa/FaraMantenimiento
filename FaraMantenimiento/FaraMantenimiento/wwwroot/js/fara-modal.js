/**
 * Patrón "modal en computadora / página en teléfono" (docs/CONVENCIONES.md §4.1).
 *
 * Enlace que abre un formulario:
 *   <a href="/Seguridad/Usuario" class="btn btn-primary" data-fara-modal data-fara-titulo="Nuevo usuario">Nuevo usuario</a>
 * - Pantalla >= 992 px: se pide la URL con cabecera X-Fara-Modal: 1; el controlador devuelve un PartialView
 *   que se muestra en #faraModal. Al enviar un <form> dentro del modal se hace POST AJAX (misma cabecera);
 *   el controlador responde JSON estándar { fiCodigo, fcMensaje, fbSucces, fjData }.
 *   Éxito: toast + recarga de la página (o la URL de data-fara-recargar). Error: SweetAlert y el modal sigue abierto.
 * - Pantalla < 992 px: navegación normal a la página completa.
 *
 * Tras inyectar el HTML se dispara el evento 'fara:modal-cargado' en el modal (para iniciar select2, dropzone, etc.).
 */
(function (window, $) {
    'use strict';
    if (!$) return;

    var ESCRITORIO = 992;
    var CABECERA = 'X-Fara-Modal';

    function asegurarModal() {
        var el = document.getElementById('faraModal');
        if (el) return el;
        el = document.createElement('div');
        el.className = 'modal fade';
        el.id = 'faraModal';
        el.tabIndex = -1;
        el.setAttribute('aria-hidden', 'true');
        el.innerHTML =
            '<div class="modal-dialog modal-lg modal-dialog-scrollable"><div class="modal-content">' +
            '<div class="modal-header"><h2 class="modal-title h5" id="faraModalTitulo"></h2>' +
            '<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button></div>' +
            '<div class="modal-body" id="faraModalCuerpo"></div></div></div>';
        document.body.appendChild(el);
        return el;
    }

    function esOk(r) { return !!(r && (r.fbSucces === true || r.fbSucces === 1 || r.fbSucces === '1' || r.FbSucces === true)); }

    function abrir(url, titulo, recargar) {
        var el = asegurarModal();
        var cuerpo = el.querySelector('#faraModalCuerpo');
        el.querySelector('#faraModalTitulo').textContent = titulo || '';
        cuerpo.innerHTML = '<div class="text-center py-5"><div class="spinner-border text-primary" role="status"></div></div>';
        var modal = bootstrap.Modal.getOrCreateInstance(el);
        modal.show();

        $.ajax({ url: url, method: 'GET', headers: { 'X-Fara-Modal': '1' } }).then(function (html) {
            cuerpo.innerHTML = html;
            // Botones "Cancelar" de la página completa cierran el modal
            $(cuerpo).find('a[data-fara-cancelar], a.btn-cancelar').attr('href', 'javascript:void(0)').attr('data-bs-dismiss', 'modal');
            if (window.FaraSelects && typeof window.FaraSelects.init === 'function') window.FaraSelects.init(cuerpo);
            el.dispatchEvent(new CustomEvent('fara:modal-cargado', { detail: { url: url } }));
        }, function () {
            modal.hide();
            FaraComun.mostrarMensaje({ fbSucces: false, fcMensaje: 'No se pudo abrir el formulario' });
        });

        $(cuerpo).off('submit.faraModal').on('submit.faraModal', 'form', function (e) {
            var form = this;
            if (form.hasAttribute('data-fara-no-ajax')) return;
            e.preventDefault();
            if (typeof form.reportValidity === 'function' && !form.reportValidity()) return;
            var datos = new FormData(form);
            var destino = form.getAttribute('action') || url;
            var btn = $(form).find('[type=submit]').prop('disabled', true);
            FaraComun.ajaxPost(destino, datos, { silent: true, headers: { 'X-Fara-Modal': '1' } }).then(function (r) {
                btn.prop('disabled', false);
                if (esOk(r)) {
                    modal.hide();
                    FaraComun.toast(true, r.fcMensaje || r.FcMensaje || 'Guardado correctamente');
                    setTimeout(function () { if (recargar) window.location.href = recargar; else window.location.reload(); }, 700);
                } else {
                    FaraComun.mostrarMensaje(r);
                }
            }, function (r) {
                btn.prop('disabled', false);
                FaraComun.mostrarMensaje(r);
            });
        });
    }

    $(document).on('click', '[data-fara-modal]', function (e) {
        if (window.innerWidth < ESCRITORIO) return; // teléfono: página completa
        var url = this.getAttribute('href') || this.getAttribute('data-url');
        if (!url) return;
        e.preventDefault();
        abrir(url, this.getAttribute('data-fara-titulo') || this.textContent.trim(), this.getAttribute('data-fara-recargar'));
    });

    window.FaraModal = { abrir: abrir, cabecera: CABECERA };
})(window, window.jQuery);
