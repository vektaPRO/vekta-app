
$.ajaxSetup({
    // Disable caching of AJAX responses
    cache: false
});

$(document).ready(function () {
    var paths = location.href.split('/');
    var status = paths[paths.length-3];
    function load() {
        var timer = setTimeout(function (timer) {
            $.ajax({
                url: "?get_status",
                type: "GET",
                dataType: 'json',
                cache: false,
                success: function (data) {
                    if (data.status != status){
                        location.reload();
                        clearTimeout(timer);
                    }
                },
                complete: load
            });
        }, 5000);
        document.GET_STATUS_TIMER = timer;
    }
    document.unloadGetStatusTimer = function() {
        console.log(document.GET_STATUS_TIMER)
        clearTimeout(document.GET_STATUS_TIMER)
        console.log(document.GET_STATUS_TIMER)
    }
    load();

    // $(document).on('click', '#cancel_refund', function(){
    //     var link = $(this).attr('href')+'&additional_info='+$('#additional_info').val();
    //     $(this).attr('href', link)
    //     window.location.href = link;
    //     return false;
    // });

    // Нельзя нажать кнопку отмену возврата без описания причины в модалке
    // $("#refund_cancel_reason_comment").bind('input propertychange', function () {
    //     console.log("typing...", this.value.length)
    //     if (this.value.length) {
    //         $("#cancelButton").attr('disabled', false);
    //     } else {
    //         $("#cancelButton").attr('disabled', true);
    //     }
    // });

    // Отправка возврата на отмену с причиной в модалке
    // $(document).on('click', '#cancelButton', function () {
    //     var message = $('#message-cancel-text').val()
    //     var linkWithMessage = $(this).attr('href') + '&additional_info=' + message;
    //     $(this).attr('href', linkWithMessage)
    //     $(this ).attr('disabled', true)
    //     setTimeout(function () {
    //         document.location.href = linkWithMessage;
    //     }, 250);
    //
    //     return false;
    // });
});