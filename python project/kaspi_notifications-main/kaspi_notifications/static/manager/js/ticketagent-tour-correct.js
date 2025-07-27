$('.tourist-penalty input').on('keyup', function(e) {
    $('input[name="accept_request"]').attr('disabled', false)
    var refundFullPrice = 0;
    var refundPenaltySum = 0;
    var refundAmountToPay = 0;
    $('.tourist-penalty .full-price-input').each(function(i, elem){
        if (elem.value) {
            refundFullPrice += parseInt(elem.value)
        }
    })
    $('.all-tourist-penalty .full-price-input').val(refundFullPrice)

    $('.tourist-penalty .penalty-sum-input').each(function(i, elem){
        if (elem.value) {
            refundPenaltySum += parseInt(elem.value)
        }
    })
    $('.all-tourist-penalty .penalty-sum-input').val(refundPenaltySum)

    $('.tourist-penalty .amount-to-pay-input').each(function(i, elem){
        if (elem.value) {
            refundAmountToPay += parseInt(elem.value)
        }
        var tourist_amount_to_pay = elem.value
        var tourist_full_price = $(elem).parents('.tourist-penalty').find('.full-price-input').val()
        var tourist_penalty_sum = $(elem).parents('.tourist-penalty').find('.penalty-sum-input').val()
        console.log(tourist_amount_to_pay, tourist_full_price, tourist_penalty_sum, (tourist_amount_to_pay === tourist_full_price - tourist_penalty_sum))
        if (tourist_amount_to_pay && tourist_full_price && tourist_penalty_sum) {
            if (parseInt(tourist_amount_to_pay) !== parseInt(tourist_full_price) - parseInt(tourist_penalty_sum)) {
                $(elem).parents('.input-group').addClass('has-error')
                $('input[name="accept_request"]').attr('disabled', true)
            } else {
                $(elem).parents('.input-group').removeClass('has-error')
            }
        } else {
            $('input[name="accept_request"]').attr('disabled', true)
        }
    })
    $('.all-tourist-penalty .amount-to-pay-input').val(refundAmountToPay)
})

$('#correct_pi_request_cancel_button').on('click', function() {
    $('#correct_pi_request_cancel_modal').modal()
})
