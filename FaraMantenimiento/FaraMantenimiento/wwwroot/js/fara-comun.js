/**
 * Helpers comunes: antiforgery + ajaxPost + SweetAlert para respuesta estándar
 * { fiCodigo, fcMensaje, fbSucces, fjData, datos }
 */
(function (window, $) {
    'use strict';

    function antiforgeryToken() {
        var el = document.querySelector('input[name="__RequestVerificationToken"]');
        return el ? el.value : '';
    }

    function mostrarMensaje(resp, fallbackOk, fallbackError) {
        var ok = !!(resp && (resp.fbSucces === true || resp.fbSucces === 1 || resp.fbSucces === '1'));
        var msg = (resp && resp.fcMensaje) || (ok ? (fallbackOk || 'Operación correcta') : (fallbackError || 'Ocurrió un error'));
        if (!window.Swal) {
            window.alert(msg);
            return Promise.resolve({ isConfirmed: true });
        }
        return Swal.fire({
            icon: ok ? 'success' : 'error',
            title: ok ? 'Listo' : 'Atención',
            text: msg,
            confirmButtonText: 'Aceptar'
        });
    }

    function ajaxPost(url, data, options) {
        options = options || {};
        var payload = data || {};
        var token = antiforgeryToken();
        var headers = options.headers || {};
        if (token) headers['RequestVerificationToken'] = token;

        if (payload instanceof FormData) {
            if (token && !payload.has('__RequestVerificationToken')) {
                payload.append('__RequestVerificationToken', token);
            }
            return $.ajax({
                url: url,
                method: 'POST',
                data: payload,
                processData: false,
                contentType: false,
                headers: headers
            }).then(function (resp) {
                if (options.silent !== true) mostrarMensaje(resp);
                return resp;
            }, function (xhr) {
                var resp = xhr.responseJSON || { fiCodigo: xhr.status || 500, fcMensaje: 'No se pudo completar la solicitud', fbSucces: false };
                if (options.silent !== true) mostrarMensaje(resp);
                return $.Deferred().reject(resp).promise();
            });
        }

        if (typeof payload === 'object' && token && payload.__RequestVerificationToken == null) {
            payload = $.extend({}, payload, { __RequestVerificationToken: token });
        }

        return $.ajax({
            url: url,
            method: 'POST',
            data: payload,
            headers: headers
        }).then(function (resp) {
            if (options.silent !== true) mostrarMensaje(resp);
            return resp;
        }, function (xhr) {
            var resp = xhr.responseJSON || { fiCodigo: xhr.status || 500, fcMensaje: 'No se pudo completar la solicitud', fbSucces: false };
            if (options.silent !== true) mostrarMensaje(resp);
            return $.Deferred().reject(resp).promise();
        });
    }

    window.FaraComun = {
        antiforgeryToken: antiforgeryToken,
        mostrarMensaje: mostrarMensaje,
        ajaxPost: ajaxPost
    };
    window.ajaxPost = ajaxPost;
})(window, window.jQuery);
