/**
 * Select2 global para todos los <select> (excepto data-no-select2).
 * Tema bootstrap-5, español, ancho 100%.
 */
(function (window, $) {
    'use strict';
    if (!$ || !$.fn || !$.fn.select2) return;

    var LANG = {
        errorLoading: function () { return 'No se pudieron cargar los resultados'; },
        inputTooLong: function (args) {
            var n = args.input.length - args.maximum;
            return 'Elimine ' + n + ' caracter' + (n === 1 ? '' : 'es');
        },
        inputTooShort: function (args) {
            var n = args.minimum - args.input.length;
            return 'Escriba ' + n + ' caracter' + (n === 1 ? '' : 'es') + ' más';
        },
        loadingMore: function () { return 'Cargando más resultados…'; },
        maximumSelected: function (args) {
            return 'Solo puede seleccionar ' + args.maximum + ' elemento' + (args.maximum === 1 ? '' : 's');
        },
        noResults: function () { return 'No se encontraron resultados'; },
        searching: function () { return 'Buscando...'; },
        removeAllItems: function () { return 'Eliminar todos'; }
    };

    function dropdownParentFor($el) {
        var $modal = $el.closest('.modal');
        if ($modal.length) return $modal;
        var $off = $el.closest('.offcanvas');
        if ($off.length) return $off;
        return $(document.body);
    }

    function hasEmptyOption($el) {
        var found = false;
        $el.find('option').each(function () {
            if (this.value === '' || this.value == null) { found = true; return false; }
        });
        return found;
    }

    function placeholderFor($el) {
        var ph = $el.data('placeholder');
        if (ph) return ph;
        var $empty = $el.find('option').filter(function () {
            return this.value === '' || this.value == null;
        }).first();
        if ($empty.length) {
            var t = ($empty.text() || '').trim();
            if (t && t !== '--' && t.indexOf('--') !== 0) return t;
        }
        return 'Seleccionar...';
    }

    function shouldSkip(el) {
        var $el = $(el);
        if (!$el.is('select')) return true;
        if ($el.attr('data-no-select2') != null) return true;
        if ($el.attr('data-select2-ajax') != null) return true;
        // SweetAlert2 trae un <select> oculto propio; con select2 aparecía "Seleccionar..." en cada alerta
        if ($el.hasClass('swal2-select') || $el.closest('.swal2-container').length) return true;
        return false;
    }

    function initOne(el) {
        var $el = $(el);
        if (shouldSkip(el)) return;
        if ($el.hasClass('select2-hidden-accessible')) return;

        var allowClear = true;
        if ($el.data('allow-clear') === false || $el.data('allow-clear') === 'false') {
            allowClear = false;
        } else if (!hasEmptyOption($el) || $el.prop('required')) {
            // Un campo obligatorio no ofrece la "×" para vaciarlo
            allowClear = false;
        }

        $el.select2({
            theme: 'bootstrap-5',
            width: '100%',
            language: LANG,
            placeholder: placeholderFor($el),
            allowClear: allowClear,
            dropdownParent: dropdownParentFor($el)
        });

        $el.on('select2:select select2:clear select2:unselect', function () {
            $el.trigger('change');
            if ($.fn.valid) {
                try { $el.valid(); } catch (e) { /* sin reglas */ }
            }
        });
    }

    function initAll(root) {
        var $root = root ? $(root) : $(document);
        $root.find('select').addBack('select').each(function () { initOne(this); });
    }

    function refresh(el) {
        var $el = $(el);
        if (!$el.length) return;
        if ($el.hasClass('select2-hidden-accessible')) {
            try { $el.select2('destroy'); } catch (e) { /* ignore */ }
        }
        initOne($el[0]);
    }

    function refreshAll(root) {
        var $root = root ? $(root) : $(document);
        $root.find('select').addBack('select').each(function () {
            if (shouldSkip(this)) return;
            refresh(this);
        });
    }

    window.FaraSelects = { init: initAll, initOne: initOne, refresh: refresh, refreshAll: refreshAll };

    $(function () {
        initAll(document);
        if (window.MutationObserver) {
            var timer = null;
            var obs = new MutationObserver(function (mutations) {
                var needs = false;
                for (var i = 0; i < mutations.length; i++) {
                    var m = mutations[i];
                    if (!m.addedNodes || !m.addedNodes.length) continue;
                    for (var j = 0; j < m.addedNodes.length; j++) {
                        var n = m.addedNodes[j];
                        if (n.nodeType !== 1) continue;
                        if (n.matches && n.matches('select')) { needs = true; break; }
                        if (n.querySelector && n.querySelector('select')) { needs = true; break; }
                    }
                    if (needs) break;
                }
                if (!needs) return;
                if (timer) clearTimeout(timer);
                timer = setTimeout(function () { initAll(document); }, 50);
            });
            obs.observe(document.body, { childList: true, subtree: true });
        }
    });
})(window, window.jQuery);
