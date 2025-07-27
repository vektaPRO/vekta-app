/**
 * Created with PyCharm.
 * User: lyazka
 * Date: 3/4/15
 * Time: 5:30 PM
 * To change this template use File | Settings | File Templates.
 */
$(document).ready(function () {

    $('#PurchaseModal .btn-primary').on('click', function(){
        $('#purchase_form').submit();
    });
    // temporary script for going to detail info
    // $(document).on('click', '#purchased_booking tr', function(){
    //    window.location.href = $(this).data('url');
    // });

    // $(document).on('click', '#refunds_table .refund-status', function(){
    //    window.location.href = $(this).parent().data('url');
    // });


    $(document).on('click', '.purchase-btn', function(){
        $(".alert-success-send").hide();
        $(".alert-success").show();
    });

    $('.after-open-modal').on('click', function(){
        var process = $(this).data('order_id');
        var amount = $(this).data('amount');
        var comment = $(this).data('comment');
        var $modalprocesscompany = $('#processcompany');
        $modalprocesscompany.find('#process_id').val(process);
        $modalprocesscompany.find('#amount_sender').val(amount);
        $modalprocesscompany.find('#amount_comment').val(comment);
        var $modalcancelprocesscompany = $('#cancelprocesscompany');
        $modalcancelprocesscompany.find('#process_id').val(process);
        var $modaladdcompany = $('#addcompany');
        $modaladdcompany.find('#process_id').val(process);
    });

   /* var $filterForm = $('#filter-form');
    $filterForm.find('select, input').on('change', function() {
        $filterForm.submit();
    });*/
});
