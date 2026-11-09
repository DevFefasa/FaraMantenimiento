(function ($) {
    if (!$ || !$.validator) return;
    $.extend($.validator.messages, {
        required: "Este campo es obligatorio.",
        remote: "Corrija este campo.",
        email: "Escriba un correo válido.",
        url: "Escriba una dirección web válida.",
        date: "Escriba una fecha válida.",
        dateISO: "Escriba una fecha válida (AAAA-MM-DD).",
        number: "Escriba un número válido.",
        digits: "Escriba solo dígitos.",
        equalTo: "Escriba el mismo valor de nuevo.",
        maxlength: $.validator.format("No escriba más de {0} caracteres."),
        minlength: $.validator.format("Escriba al menos {0} caracteres."),
        rangelength: $.validator.format("Escriba entre {0} y {1} caracteres."),
        range: $.validator.format("Escriba un valor entre {0} y {1}."),
        max: $.validator.format("Escriba un valor menor o igual a {0}."),
        min: $.validator.format("Escriba un valor mayor o igual a {0}."),
        step: $.validator.format("Escriba un múltiplo de {0}.")
    });
})(window.jQuery);
