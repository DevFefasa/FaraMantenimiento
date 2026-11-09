/**
 * Dropzone de adjuntos (fotos/videos/documentos) sin librerías externas.
 * Contenedor: .js-dropzone con data-max-mb, data-max-count, data-input-name, data-accept.
 * En móvil el input puede usar capture="environment".
 */
(function (window, document) {
    'use strict';

    var EXT_IMG = { '.jpg': 1, '.jpeg': 1, '.png': 1, '.webp': 1, '.gif': 1 };
    var EXT_VID = { '.mp4': 1, '.webm': 1, '.mov': 1, '.avi': 1, '.mkv': 1 };
    var EXT_DOC = { '.pdf': 1, '.doc': 1, '.docx': 1, '.xls': 1, '.xlsx': 1, '.txt': 1, '.csv': 1 };

    function formatSize(bytes) {
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }

    function extOf(name) {
        var i = (name || '').lastIndexOf('.');
        return i < 0 ? '' : name.slice(i).toLowerCase();
    }

    function escapeHtml(s) {
        return String(s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }

    function allowedExt(root) {
        var accept = (root.getAttribute('data-accept') || 'image/*,video/*,.pdf,.doc,.docx,.xls,.xlsx').toLowerCase();
        var map = {};
        if (accept.indexOf('image') >= 0) Object.keys(EXT_IMG).forEach(function (k) { map[k] = 1; });
        if (accept.indexOf('video') >= 0) Object.keys(EXT_VID).forEach(function (k) { map[k] = 1; });
        Object.keys(EXT_DOC).forEach(function (k) {
            if (accept.indexOf(k) >= 0 || accept.indexOf('*') >= 0) map[k] = 1;
        });
        // también extensiones explícitas en data-accept
        accept.split(',').forEach(function (p) {
            p = p.trim();
            if (p.charAt(0) === '.') map[p] = 1;
        });
        if (!Object.keys(map).length) {
            Object.assign(map, EXT_IMG, EXT_VID, EXT_DOC);
        }
        return map;
    }

    function iconFor(ext) {
        if (EXT_IMG[ext]) return null;
        if (EXT_VID[ext]) return 'ti ti-video';
        return 'ti ti-file';
    }

    function initZone(root) {
        if (!root || root.getAttribute('data-dz-ready') === '1') return;
        root.setAttribute('data-dz-ready', '1');

        var maxMb = parseFloat(root.getAttribute('data-max-mb') || '10') || 10;
        var maxCount = parseInt(root.getAttribute('data-max-count') || '10', 10) || 10;
        var maxBytes = Math.max(1, maxMb) * 1024 * 1024;
        var inputName = root.getAttribute('data-input-name') || 'Adjuntos';
        var okExt = allowedExt(root);

        var input = root.querySelector('input[type="file"]');
        var surface = root.querySelector('[data-dz-surface]');
        var list = root.querySelector('[data-dz-list]');
        var errors = root.querySelector('[data-dz-errors]');
        if (!input || !surface || !list) return;

        input.setAttribute('name', inputName);
        input.setAttribute('multiple', 'multiple');
        if (!input.getAttribute('accept')) {
            input.setAttribute('accept', root.getAttribute('data-accept') || 'image/*,video/*,.pdf,.doc,.docx,.xls,.xlsx');
        }
        if (!input.getAttribute('capture') && /Mobi|Android|iPhone/i.test(navigator.userAgent || '')) {
            input.setAttribute('capture', 'environment');
        }
        input.classList.add('dz-input-hidden');
        input.setAttribute('tabindex', '-1');
        input.setAttribute('aria-hidden', 'true');

        var files = [];

        function showErrors(msgs) {
            if (!errors) return;
            if (!msgs || !msgs.length) {
                errors.classList.add('d-none');
                errors.innerHTML = '';
                return;
            }
            errors.classList.remove('d-none');
            errors.innerHTML = msgs.map(function (m) {
                return '<div>' + escapeHtml(m) + '</div>';
            }).join('');
        }

        function syncInput() {
            var dt = new DataTransfer();
            files.forEach(function (f) { dt.items.add(f); });
            input.files = dt.files;
        }

        function sameFile(a, b) {
            return a.name === b.name && a.size === b.size && a.lastModified === b.lastModified;
        }

        function render() {
            list.innerHTML = '';
            files.forEach(function (f, idx) {
                var card = document.createElement('div');
                card.className = 'dz-thumb';
                var ext = extOf(f.name);
                var icon = iconFor(ext);
                if (icon) {
                    card.innerHTML =
                        '<div class="dz-thumb-icon"><i class="' + icon + '"></i></div>' +
                        '<div class="dz-thumb-meta">' +
                        '<div class="dz-thumb-name" title="' + escapeHtml(f.name) + '">' + escapeHtml(f.name) + '</div>' +
                        '<div class="dz-thumb-size">' + formatSize(f.size) + '</div>' +
                        '</div>' +
                        '<button type="button" class="dz-thumb-remove" data-idx="' + idx + '" title="Quitar" aria-label="Quitar">&times;</button>';
                } else {
                    var url = URL.createObjectURL(f);
                    card.innerHTML =
                        '<img src="' + url + '" alt="' + escapeHtml(f.name) + '" />' +
                        '<div class="dz-thumb-meta">' +
                        '<div class="dz-thumb-name" title="' + escapeHtml(f.name) + '">' + escapeHtml(f.name) + '</div>' +
                        '<div class="dz-thumb-size">' + formatSize(f.size) + '</div>' +
                        '</div>' +
                        '<button type="button" class="dz-thumb-remove" data-idx="' + idx + '" title="Quitar" aria-label="Quitar">&times;</button>';
                    var img = card.querySelector('img');
                    if (img) img.addEventListener('load', function () { URL.revokeObjectURL(url); });
                }
                list.appendChild(card);
            });
            syncInput();
        }

        function addFiles(fileList) {
            var msgs = [];
            var incoming = Array.prototype.slice.call(fileList || []);
            incoming.forEach(function (f) {
                var ext = extOf(f.name);
                if (!okExt[ext]) {
                    msgs.push('«' + f.name + '»: tipo no permitido.');
                    return;
                }
                if (f.size > maxBytes) {
                    msgs.push('«' + f.name + '» supera ' + maxMb + ' MB.');
                    return;
                }
                if (files.some(function (x) { return sameFile(x, f); })) return;
                if (files.length >= maxCount) {
                    msgs.push('Máximo ' + maxCount + ' archivos por subida.');
                    return;
                }
                files.push(f);
            });
            showErrors(msgs);
            render();
        }

        surface.addEventListener('click', function (e) {
            if (e.target.closest('.dz-thumb-remove')) return;
            input.click();
        });
        surface.addEventListener('keydown', function (e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                input.click();
            }
        });
        ['dragenter', 'dragover'].forEach(function (ev) {
            surface.addEventListener(ev, function (e) {
                e.preventDefault();
                e.stopPropagation();
                surface.classList.add('dz-dragover');
            });
        });
        ['dragleave', 'drop'].forEach(function (ev) {
            surface.addEventListener(ev, function (e) {
                e.preventDefault();
                e.stopPropagation();
                surface.classList.remove('dz-dragover');
            });
        });
        surface.addEventListener('drop', function (e) {
            if (e.dataTransfer && e.dataTransfer.files) addFiles(e.dataTransfer.files);
        });
        input.addEventListener('change', function () {
            addFiles(input.files);
            try { input.value = ''; } catch (err) { /* ignore */ }
            syncInput();
        });
        list.addEventListener('click', function (e) {
            var btn = e.target.closest('.dz-thumb-remove');
            if (!btn) return;
            e.preventDefault();
            e.stopPropagation();
            var idx = parseInt(btn.getAttribute('data-idx'), 10);
            if (isNaN(idx) || idx < 0 || idx >= files.length) return;
            files.splice(idx, 1);
            showErrors([]);
            render();
        });
    }

    function initAll(root) {
        (root || document).querySelectorAll('.js-dropzone').forEach(initZone);
    }

    window.FaraDropzone = { init: initAll, initOne: initZone };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function () { initAll(document); });
    } else {
        initAll(document);
    }
})(window, document);
