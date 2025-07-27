
$(document).ready(function () {

    /*$('textarea').redactor({
        lang: 'ru',
        buttons: [
            'html', '|', 'formatting', '|',
            'bold', 'italic', 'deleted', '|',
            'horizontalrule', '|',
            'image', 'video', 'file', 'table', 'link', '|',
            'unorderedlist', 'orderedlist', 'outdent', 'indent', '|',
            'alignment'],
        emptyHtml: '',
    });*/
    $('.datetimeinput').datetimepicker({
        format:'DD.MM.YYYY HH:mm',
        pickDate: true,
        useCurrent: true
    });
});
