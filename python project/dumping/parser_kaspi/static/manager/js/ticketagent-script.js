/**
 * Created by lyazka on 2/10/15.
 */
$(document).ready(function () {

    $('#SendToPayModal .btn-primary').on('click', function(){
        $('#request_update_form').submit();
    });

    $('#PurchaseModal .btn-primary').on('click', function(){
        $('#purchase_form').submit();
    });

    $('#SendMailModal .btn-primary').on('click', function(){
        $('#send_mail_form').submit();
    });

    $('#SendCustomMailModal .btn-primary').on('click', function(){
        $('#send_custom_mail_form').submit();
    });

    $('#SendPushWithTicketModal .btn-primary').on('click', function () {
        $('#send_push_with_ticket_form').submit();
    });

    $('#RefundModal .btn-primary').on('click', function(){
        $('#refund_form').submit();
    });

    $('#RefundRequestModal .btn-primary').on('click', function(){
        var tickets_arr=[];
        $('#RefundRequestModal .ticket_id:checked').each(function() {
            tickets_arr.push($(this).val());
        });
        var input = $("<input>")
               .attr("type", "hidden")
               .attr("name", "tickets").val(tickets_arr);
        $('#refund_request_form').append($(input));
        $('#refund_request_form').submit();
    });

    $('#BspRefundRequestModal .btn-primary').on('click', function(){
        var tickets_arr=[];
        $('#BspRefundRequestModal .ticket_id:checked').each(function() {
            tickets_arr.push($(this).val());
        });
        var input = $("<input>")
               .attr("type", "hidden")
               .attr("name", "tickets").val(tickets_arr);
        $('#bsp_refund_request_form').append($(input));
        $('#bsp_refund_request_form').submit();
    });

    $('#VoidModal .btn-primary').on('click', function(){
        $('#void_booking_form').submit();
    });

    $(document).on('submit', '#add_balance_form', function(){
        $(this).find('button[type=submit]').prop('disabled', true);
    });
     $(document).on('submit', '.refund-form', function(){
        $(this).find('button[type=submit]').prop('disabled', true);
    });

    $(document).on('click', '#refunds_table .refund-status', function(){
        window.location.href = $(this).parent().data('url');
    });

    $(document).on('click', '#changes_table .change-status', function(){
        window.location.href = "/manager/ticketagent/changes_detail.html";
    });

     $(document).on('click', '#bookings_table .booking-status', function(){
        window.location.href = $(this).parent().data('url');
    });

    // Scripts for refund pages
    $(document).on('click', '.refunds-detail .send-returns-button', function(){
        $(this).closest('form').submit();
        return false;
        // $(".status-request-processing").hide();
        // $(".alert-sucсess").show();
        // $(".status-return-send").show();
    });

    $(document).on('click', '.refunds-detail .cancel-return', function(){
        $(".first").removeClass("current").addClass("done disabled");
        $(".status-request-processing").hide();
        $(".status-return-send").hide();
        $(".alert-sucсess").hide();
        $(".status-return-cancel").show();
        $(".alert-danger").show();

    });

    $(document).on('click', '.refunds-detail .formalize-return', function(){
        $(".status-request-processing").hide();
        $(".status-return-send").hide();
        $(".alert-success").show();
    });

    $(document).on('click', '.refunds-detail .accountant-response ', function(){
//        $(".status-request-processing").hide();
        $(".status-return-send").hide();
        $(".alert-success").show();
    });

    $(document).on('click', '.refunds-detail .finish-case ', function(){
        $(".status-return-send").hide();
        $(".alert-success").hide();
        $(".alert-info").show();
    });
    //end refund

    //Scripts for changes-passport-detail
    $(document).on('click', '.load-tickets-detail', function(){
        $(this).hide();
        var $changed_detail= $(".changed-detail");
        $(".cancel-tickets-detail").hide();
        $changed_detail.show();
        $changed_detail.find(".table-customer").show();
        $changed_detail.find(".table-passenger").show();
    });

    $(document).on('click', '.change-passport-detail .send-changes-button', function(){
        $(this).hide();
        $(".additional-info").hide();
        $(".alert-success").show();
    });

    $(document).on('click', '.case-finish-button', function(){
        $(".alert-success").hide();
        $(".alert-success-finish").hide();
        $(".alert-info").show();
    });

    $(document).on('click', '.cancel-tickets-detail', function(){
        $(this).hide();
        $(".load-tickets-detail").hide();
        $(".cancel-change").show();
    });

    $(document).on('click', '.cancel-button', function(){
        $(".cancel-change").hide();
        $(".alert-danger").show();
        $(".first").removeClass("current").addClass("done disabled");
    });

    //Scripts for change-tickets-detail
    $(document).on('click', '.table-new-detail .fa-times', function(){
        $(this).closest('.flight-variant').remove();
    });

    $(document).on("click", '.changes-detail .cancel-user', function(){
        $(".alert-success").hide();
        $(".alert-danger").show();
    });

    $(document).on('click','.payment-page', function(){
        $(".alert-success-send").hide();
        $(".alert-success").show();

    });

    $(document).on('click','.expired-page', function(){
        $(".status-request-processing").hide();
        $(".status-changes-send").hide();
        $(".status-changes-expired").show();
        $(".alert-simple").show();
        $(".first").removeClass("current").addClass("done disabled");
    });

    $(document).on('click','.cancel-page', function(){
        $(".status-request-processing").hide();
        $(".status-changes-send").hide();
        $(".status-changes-cancel").show();
        $(".alert-cancel").show();
        $(".first").removeClass("current").addClass("done disabled");
    });

    $(document).on('click', '.change-tickets-detail .send-changes-button', function(){
        $(".alert-success-send").show();
        $(".status-changes-send").show();
    });

    $(document).on('click', '.case-send-button', function(){
        $(this).closest(".alert-success").hide();
        $(".alert-success-finish").show();
    });
    //end changes

    //Scripts for booking pages
    $('#datetimepicker').datetimepicker({
        format: 'LT',
        pickDate: false,
        useCurrent: true
    });

    $('#datepicker').datepicker({
        format:'dd/mm/yyyy',
        todayBtn: "linked",
        keyboardNavigation: false,
        forceParse: false,
        autoclose: true,
        todayHighlight:true,
        defaultDate: new Date(),
        language:"ru"
    });
    //end bookings



    initRefundForm();

    $(document).on('click', 'a.popup-show-ajax', function(e){

        var target = $(this).data('target') || '#popup-ajax';
        var $target_popup = $(target);
        var url = $(this).attr('href');

        $target_popup.find('.modal-body').empty();

        $.get(url, function(response){
            $target_popup.find('.modal-body').html(response).append('<div style="clear:both;"></div>');
            $target_popup.modal('show');
        });

        e.preventDefault();
    });

/*    var $filterForm = $('#filter-form');
    $filterForm.find('select, input').on('change', function() {
        $filterForm.submit();
    });*/

});

function initRefundForm(){
    var $refundForm = $('#refund_form'),
        $fields = $('#refund_form .penalty input[type="text"]'),
        $sum = $('#refund_form .fine-cost');
    $fields.on('change', function(){
        var sum = 0;
        $.each($fields, function(){
            var val = parseFloat($(this).val().replace(',', '.').replace(' ', ''));
            if (!isNaN(val)){
                sum +=val;
            }
        });
        $sum.html(sum+' KZT');
    });

    $refundForm.on('submit', function(e) {
        e.preventDefault();
        $.post(this.action, $(this).serialize(), function() {
            location.reload();
        });
    });
}

function clickAndDisable(link) {
    // disable subsequent clicks
    link.onclick = function(event) {
        event.preventDefault();
    }
}