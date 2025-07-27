"Redactor widget initializer";

!(function($, window, document) {
    "use strict";

    $(function() {
        $('[data-redactor-meta]').each(function() {
            var
                $textarea = $(this),
                options = $textarea.data('redactor-meta');

            $textarea.redactor($.extend(options,
                               Santufei.contextData.redactorOptions));
        });
    });

})(window.jQuery, window, document, undefined);
