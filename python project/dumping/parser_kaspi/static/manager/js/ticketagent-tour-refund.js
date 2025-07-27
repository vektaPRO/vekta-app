show_error = (error_message) => {
    toastr.error(error_message, 'Ошибка!');
}

$('#calculate_button').on('click', (e) => {
    e.preventDefault();
    $.ajax({
        type: "POST",
        url: refund_page_url,
        data: {
            'calculate_request': 1,
            'csrfmiddlewaretoken': csrfmiddlewaretoken,
            'refund_penalty_sum': parseFloat($('#refund_penalty_sum').val()),
            'refund_currency': $('#refund_currency').val(),
        },
    }).done(
        (data) => {
            if (data.hasOwnProperty('error_message')) {
                show_error(data['error_message'])
                $('#accept_button').addClass('disabled');
                let amount_to_pay = '-'
                let penalty_sum = '-'
                $('b.previewed_refund_penalty_sum').html(penalty_sum)
                $('#previewed_amount_to_pay').html(amount_to_pay)
                $('input.previewed_refund_penalty_sum').val('')
                $('#previewed_refund_currency').val('')
            } else {
                let amount_to_pay = data['amount_to_pay']
                let amount_to_pay_in_currency = data['amount_to_pay_in_currency']
                let penalty_sum = data['penalty_sum']
                let penalty_sum_in_currency = data['penalty_sum_in_currency']
                $('input.previewed_refund_penalty_sum').val(parseFloat($('#refund_penalty_sum').val()))
                $('#previewed_refund_currency').val($('#refund_currency').val())
                $('b.previewed_refund_penalty_sum').html(penalty_sum + " KZT (" + penalty_sum_in_currency + " " + from_currency + ")")
                $('#previewed_amount_to_pay').html(amount_to_pay + " KZT (" + amount_to_pay_in_currency + " " + from_currency + ")")
                $('#accept_button').removeClass('disabled');
            }
        }
    ).fail(
        () => {
            show_error('Сервис не доступен')
        }
    )
})

$('#accept_confirm_button').on('click', (e) => {
    e.preventDefault()
    $('#accept_form').submit()
})
