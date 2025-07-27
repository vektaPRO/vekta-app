/**
 * Created with PyCharm.
 * User: lyazka
 * Date: 3/11/15
 * Time: 12:17 PM
 * To change this template use File | Settings | File Templates.
 */
$(document).ready(function () {
    //Script for more detail
    $(document).on('click', '.more-detail', function(){
        var $table = $(".table-flight");
        if(!$(this).hasClass("opened")) {
            $(this).addClass("opened");
            $(".table-booking-detail").show();
            $table.find(".table-passenger").show();
            $table.find(".table-customer").show();
            $table.find(".table-parent").show();
            $table.find(".table-children").show();
            $table.find(".table-refund").show();
            $(this).html("<a href='#'>Свернуть</a>");
        } else {
            $(this).removeClass("opened");
            $(this).html("<a href='#'>Подробнее</a>");
            $(".table-booking-detail").hide();
            $table.find(".table-passenger").hide();
            $table.find(".table-customer").hide();
            $table.find(".table-parent").hide();
            $table.find(".table-children").hide();
            $table.find(".table-refund").hide();
        }
    });

    $('#arrow').click(function () {
        var table = document.getElementById('table_to_show');
        if (table.style.display === 'none') {
            table.style.display = 'block';
        } else {
            table.style.display = 'none';
        }
    });

    // show/hide booking previous refunds
    $('#show-refunds').click(function () {
        let table = document.getElementById('refunds-to-show');
        if (table.style.display === 'none') {
            $('#show-refunds').text('(Свернуть)');
            table.style.display = 'table';
        } else {
            $('#show-refunds').text('(Показать)');
            table.style.display = 'none';
        }
    });

    // show/hide booking previous exchanges
    $('#show-exchanges').click(function () {
        let table = document.getElementById('exchanges-to-show');
        if (table.style.display === 'none') {
            $('#show-exchanges').text('(Свернуть)');
            table.style.display = 'table';
        } else {
            $('#show-exchanges').text('(Показать)');
            table.style.display = 'none';
        }
    });

    // Action on confirm "Deletredactor();e" button in modal form
    var $modalConfirmButton = $('.modal').find('.delete');
    $('.fa-trash-o, .btn-booking-delete, .fa-check-square-o, .fa-share, .fa-check.confirm, .fa-times.cancel').click(function () {
        var $modalConfirmButton = $($(this).data('target')).find('.delete');
        var $element = $(this),
            url = $element.data('flink'),
            success_url = $element.data('success-link'),
            case_id = $element.data('id');
        $modalConfirmButton.on('click', function() {
            window.location.href = url;
            /*$.ajax({
                type: 'GET',
                url: url,
                success: function (data) {
                    if (typeof(success_url) != "undefined"){
                        window.location.href = success_url;
                    }
                    else {
                        $element.closest("tr").hide();
                    }
                }
            });*/
        });
    });
    //---------------------------------------------------------------------------------------/
    // CSRF
    //
    function getCookie(name) {
        var cookieValue = null;
        if (document.cookie && document.cookie != '') {
            var cookies = document.cookie.split(';');
            for (var i = 0; i < cookies.length; i++) {
                var cookie = jQuery.trim(cookies[i]);
                if (cookie.substring(0, name.length + 1) == (name + '=')) {
                    cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                    break;
                }
            }
        }
        return cookieValue;
    }
    var csrftoken = getCookie('csrftoken');

    function csrfSafeMethod(method) {
        return (/^(GET|HEAD|OPTIONS|TRACE)$/.test(method));
    }
    function sameOrigin(url) {
        var host = document.location.host;
        var protocol = document.location.protocol;
        var sr_origin = '//' + host;
        var origin = protocol + sr_origin;
        return (url == origin || url.slice(0, origin.length + 1) == origin + '/') ||
            (url == sr_origin || url.slice(0, sr_origin.length + 1) == sr_origin + '/') ||
            !(/^(\/\/|http:|https:).*/.test(url));
    }
    //---------------------------------------------------------------------------------------/
    // Action to set ChangedBooking as processed independently
    //
    $('.fa-phone-square').click(function () {
        var $element = $(this),
        url = $element.data('flink'),
        success_url = $element.data('success-link'),
        changed_booking_id = $element.data('id');

        var $modalSetProcessedButton = $($(this).data('target')).find('.set_as_processed');
        $modalSetProcessedButton.off('click');
        $modalSetProcessedButton.on('click', function() {
            $.ajaxSetup({
                beforeSend: function(xhr, settings) {
                    if (!csrfSafeMethod(settings.type) && sameOrigin(settings.url)) {
                        xhr.setRequestHeader("X-CSRFToken", csrftoken);
                    }
                }
            });
            $.ajax({
                type: 'POST',
                url: url,
                data: {
                    'set_as_processed': changed_booking_id
                },
                success: function (data) {
                    if (typeof(success_url) != "undefined"){
                        window.location.href = success_url;
                    }
                    else {
                        $element.closest("tr").hide();
                    }
                }
            });
        });
    });
    //---------------------------------------------------------------------------------------/
    // Action to approve sending push-notifications to Bookings based on ChangedFlight
    //
    $('.fa-check, .changed-flight-approve').click(function () {
        var $element = $(this),
        url = $element.data('flink'),
        success_url = $element.data('success-link'),
        changed_flight_id = $element.data('id');

        var $modalApproveButton = $($(this).data('target')).find('.approve');
        $modalApproveButton.off('click');
        $modalApproveButton.on('click', function() {
            $.ajaxSetup({
                beforeSend: function(xhr, settings) {
                    if (!csrfSafeMethod(settings.type) && sameOrigin(settings.url)) {
                        xhr.setRequestHeader("X-CSRFToken", csrftoken);
                    }
                }
            });
            $.ajax({
                type: 'POST',
                url: url,
                data: {
                    'approve': changed_flight_id
                },
                success: function (data) {
                    if (typeof(success_url) != "undefined"){
                        window.location.href = success_url;
                    }
                    else {
                        $element.closest("tr").hide();
                    }
                }
            });
        });
    });
    //---------------------------------------------------------------------------------------/
    // Action to decline sending push-notifications to Bookings based on ChangedFlight
    //
    $('.fa-close, .changed-flight-decline').click(function () {
        var $element = $(this),
        url = $element.data('flink'),
        success_url = $element.data('success-link'),
        changed_flight_id = $element.data('id');
        target =  $element.data('target');
        var $modalDeclineButton = $($(this).data('target')).find('.decline');
        $modalDeclineButton.off('click');
        $modalDeclineButton.on('click', function() {
            var agent_comment_input = $(`${target} #agent_comment_input`).val();
            if (agent_comment_input.length == 0) {
                $(`${target} #empty_comment_warning`).css({visibility : 'visible'});
                return false;  // Preventing closing modal while agent_comment is empty
            } else {
                $.ajaxSetup({
                    beforeSend: function(xhr, settings) {
                        if (!csrfSafeMethod(settings.type) && sameOrigin(settings.url)) {
                            xhr.setRequestHeader("X-CSRFToken", csrftoken);
                        }
                    }
                });
                $.ajax({
                    type: 'POST',
                    url: url,
                    data: {
                        'decline': changed_flight_id,
                        'agent_comment': agent_comment_input
                    },
                    success: function (data) {
                        if (typeof(success_url) != "undefined"){
                            window.location.href = success_url;
                        }
                        else {
                            $element.closest("tr").hide();
                        }
                    }
                });
            }
        });
    });
    
    $('.changed-flight-detail').click(function (e) {
        if(! $(e.target).hasClass("clickable")) {
            window.location = $(this).data("href");
        }
    });    //scroll to top

    //scroll to top
    $(window).scroll(function(){
        if ($(this).scrollTop() > 100) {
            $('.scrollToTop').fadeIn();
        } else {
            $('.scrollToTop').fadeOut();
        }
    });

    $('.scrollToTop').click(function(){
        $('html, body').animate({scrollTop : 0},800);
        return false;
    });

    //Highlight active menu item
    function setNavigation() {
        var path = window.location.pathname;
        path = decodeURIComponent(path);

        $(".nav a").each(function () {
            var href = $(this).attr('href');
            if (href && path.substring(0, href.length) === href) {
                $(this).closest('li').siblings('li').removeClass('active');
                $(this).closest('li').addClass('active');
                if ($(this).closest('ul.nav-second-level')) {
                    $(this).closest('ul.nav-second-level').addClass("collapse in");
                    $(this).closest('ul.nav-second-level').closest('li').addClass('active')
                }
            }
        });
    }
    setNavigation();


    // Филтры

    var queryParameters = {}, queryString = location.search.substring(1),
            re = /([^&=]+)=([^&]*)/g, m;

        while (m = re.exec(queryString)) {
            queryParameters[decodeURIComponent(m[1])] = decodeURIComponent(m[2]);
        }

     setFilterParams();

    //Module for check button
    $('.i-checks').iCheck({
        checkboxClass: 'icheckbox_square-green',
        radioClass: 'iradio_square-green'
    });

    function setFilterParams(){
        var paramStr = queryParameters['filter'],
            $checkboxes = $('.filter-by .i-checks input');
        if(paramStr) {
            var paramArr = paramStr.split(',');
            $checkboxes.each(function(){
                var val = $(this).val();
                if ($.inArray(val, paramArr)>-1){
                    $(this).prop('checked', true);
                }
            });
        }
       /* else {
            // Если нет параметров, значит все
            $($checkboxes[0]).prop('checked', true);
        }*/
        
    }

    function getFilterParams(){
        var $checked = $('.filter-by .i-checks > .checked'),
            $checkedCheckboxes = $checked.find('input'),
            paramArr = [];
        $checkedCheckboxes.each(function() {
            paramArr.push($(this).val());
        });
        return paramArr;
    }
    

    $('.i-checks').on('ifChecked', function(event){
        var paramArr = getFilterParams(),
            currParam = $(this).find('input').val();
        paramArr.push(currParam);
        queryParameters['filter'] = paramArr.join();
        // сбрасываем пагинацию
        queryParameters['page'] = 1;

        location.search = $.param(queryParameters);
        //window.history.pushState("", document.title, '?'+$.param(queryParameters));
    });

    $('.i-checks').on('ifUnchecked', function(event){
        var paramArr = getFilterParams(),
            currParam = $(this).find('input').val(),
            index = paramArr.indexOf(currParam);
        paramArr.splice(index, 1);
        queryParameters['filter'] = paramArr.join();
        // сбросываем пагинацию
        queryParameters['page'] = 1;
        location.search = $.param(queryParameters);
        //window.history.pushState("", document.title, '?'+$.param(queryParameters));
    });

    toastr.options = {
        closeButton: true,
        progressBar: true,
        showMethod: 'slideDown',
        timeOut: 4000
    };
    var $messages = $('#messages .message');
    
    if($messages.length){
        $messages.each(function(){
            var $message = $(this);
             setTimeout(function( ) {
                if ($message.hasClass('success')){
                    toastr.success($message.text(), 'Успех!');
                }
                if ($message.hasClass('error')){
                    toastr.error($message.text(), 'Ошибка!');
                }

            }, 1300);
        });
    }

    initEmailSearch();
    initCustomerSearch();
    initBookingSearch();
    initCompanySearch();
    initDatePickerRange();
    BookingSearch();
    BlockBookingSearch();
    AirlineSearch();

    $('#daterangepicker, .rangepicker').daterangepicker({
        locale: {
            format: 'DD.MM.YYYY',
            applyLabel: 'Применить',
            cancelLabel: 'Отменить',
            weekLabel: 'Н',
            customRangeLabel: 'Другой период',
            daysOfWeek: ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'],
            monthNames: [
                'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
                'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
            ],
        },
        ranges: {
            'Сегодня': [moment(), moment()],
            'Вчера': [moment().subtract(1, 'days'), moment().subtract(1, 'days')],
            'Последние 7 дней': [moment().subtract(6, 'days'), moment()],
            'Последние 30 дней': [moment().subtract(29, 'days'), moment()],
            'В этом месяце': [moment().startOf('month'), moment().endOf('month')],
            'В прошлом месяца': [moment().subtract(1, 'month').startOf('month'), moment().subtract(1, 'month').endOf('month')]
        },
        alwaysShowCalendars: true
    });
    $('#daterangepicker.default-blank, .rangepicker.default-blank').val('')
    var $filterForm = $('#filter-form');
    $filterForm.find('select, input').on('change', function() {
        $filterForm.submit();
    });

});

function initDatePickerRange(){
    $('.input-daterange').datepicker({
        format: "yyyy-mm-dd" ,
        keyboardNavigation: false,
        forceParse: false,
        autoclose: true,
        language:"ru"
    });

    $('#report-datepicker').datepicker({
        format:'dd/mm/yyyy',
        todayBtn: "linked",
        keyboardNavigation: false,
        forceParse: false,
        autoclose: true,
        todayHighlight:true,
        defaultDate: new Date(),
        language:"ru"
    });
}


function initEmailSearch() {
    var
        emails = new Bloodhound({
            datumTokenizer: function(d) {
                return Bloodhound.tokenizers.whitespace(d.value);
            },
            queryTokenizer: Bloodhound.tokenizers.whitespace,
            remote: {
                url: '?balance_q=%QUERY',
                filter: function(list) {
                    return $.map(list, function(user) {
                        return {
                            id: user['id'],
                            value: user['email'],
                            currency: user['currency'],
                            fio: user['fio']};
                    });
                }
            },
        }),

        $emailInput = $('#email_search')
        $emailLabelCurrency = $('#email_label_currency'),
        $emailInputAmount = $('#email_add_balance_input');

    emails.initialize();

    $emailInput.typeahead({
        highlight: true,
    },
    {
        source: emails.ttAdapter(),
        templates: {
            suggestion: Handlebars.compile('<a href="#">{{id}} {{currency}} {{value}} {{fio}}</a>'),
        }
    })
    .bind('typeahead:selected', function(e, obj){
        $emailInput.val(obj.value);
        $emailLabelCurrency.html(obj.currency);
        $emailInputAmount.attr("placeholder", "Валюта " + obj.currency)
    });
}
function initBookingSearch() {
    var $searchForm = $('#manager-search');
    var $dropdown = $searchForm.find('.tt-dropdown-menu');
    var $dataset = $dropdown.find('.tt-dataset-0');
    $(document).click(function (event) {
        var target = $(event.target);
        if (!target.hasClass('main-search')) {
            $dropdown.hide();
        }
    });

    $searchForm.on('submit', function(e) {
        e.preventDefault();
        var q = $(this).serializeArray().find(function(e) {return e.name === "q"}).value;
        if (q) {
          $.ajax({
                url: '?' + $(this).serialize(),
                type: 'GET',
                success: function(list) {
                    $dropdown.show();
                    $dataset.empty();
                    if (list.length > 0) {
                        $.each(list, function(index, booking) {
                            var icon;
                            if (booking['trip_type']==1)
                                icon = 'fa-exchange';
                            else icon = 'fa-long-arrow-right';
                            $dataset.append(
                                '<div class="tt-suggestion tt-m-cursor"><a href="'+booking['url']+'">'+booking['id']+':' + booking['origin'] +
                                '<i class="fa ' + icon + '"></i>' +
                                booking['destination'] + ' - '+booking['customer']+ ' - '+booking['status']+' - '+booking['create_date'].slice(0, 19).replace('T', ' ')+' </a></div>'
                            );
                        });
                    } else {
                        $dataset.append('<div class="tt-suggestion">Нет результатов</div>');
                    }
                }
            });
        } else {
            $dropdown.show();
            $dataset.empty();
            $dataset.append('<div class="tt-suggestion">Пустая строка поиска</div>');
        }
    });
}


function initCustomerSearch() {
    var
        emails = new Bloodhound({
            datumTokenizer: function(d) {
                return Bloodhound.tokenizers.whitespace(d.value);
            },
            queryTokenizer: Bloodhound.tokenizers.whitespace,
            remote: {
                url: '?balance_q=%QUERY',
                filter: function(list) {
                    return $.map(list, function(user) {
                        return {
                            id: user['id'],
                            value: user['id'],
                            fio: user['fio']};
                    });
                }
            },
        }),

        $emailInput = $('#customer_search');

    emails.initialize();

    $emailInput.typeahead({
        highlight: true,
    },
    {
        source: emails.ttAdapter(),
        templates: {
            suggestion: Handlebars.compile('<a href="#">{{id}} {{value}} {{fio}}</a>'),
        }
    })
    .bind('typeahead:selected', function(e, obj){
        $emailInput.val(obj.id);
    });
}

function initCompanySearch() {
        var
            companies = new Bloodhound({
                datumTokenizer: function(d) {
                    return Bloodhound.tokenizers.whitespace(d.value);
                },
                queryTokenizer: Bloodhound.tokenizers.whitespace,
                remote: {
                    url: '?company_balance_q=%QUERY',
                    filter: function(list) {
                        return $.map(list, function(company) {
                            return {
                                id: company['id'],
                                value: company['id'] + ' '+ company['name'],
                                currency: company['currency'],
                                name: company['name']};
                        });
                    }
                },
            }),

            $companyInput = $('#company_search, #company_subtract_search'),
            $companyInputId = $('#company_search_id'),
            $companyLabelCurrency = $('#company_label_currency'),
            $companyInputAmount = $('#company_add_balance_input');

        companies.initialize();

        $companyInput.typeahead({
            highlight: true,
        },
        {
            source: companies.ttAdapter(),
            templates: {
                suggestion: Handlebars.compile('<a href="#">{{currency}} {{id}} {{name}}</a>'),
            }
        })
        .bind('typeahead:selected', function(e, obj){
            $companyInput.val(obj.value);
            $companyInputId.val(obj.id);
            $companyLabelCurrency.html(obj.currency);
            $companyInputAmount.attr("placeholder", "Валюта " + obj.currency)
        });
    }

function BookingSearch() {
    var
        bookings = new Bloodhound({
            datumTokenizer: function(d) {
                return Bloodhound.tokenizers.whitespace(d.value);
            },
            queryTokenizer: Bloodhound.tokenizers.whitespace,
            remote: {
                url: '?q=%QUERY',
                filter: function(list) {
                    return $.map(list, function(booking) {
                        var icon;
                        if (booking['trip_type']==1)
                            icon = 'fa-exchange';
                        else icon = 'fa-long-arrow-right';
                        return {
                            id: booking['org_id'],
                            value: booking['id'],
                            status: booking['status'],
                            url: booking['url'],
                            customer: booking['customer'],
                            origin: booking['origin'],
                            destination: booking['destination'],
                            create_date: (booking['create_date']).toString().slice(0, 19).replace('T', ' '),
                            icon: icon};
                    });
                }
            },
        }),

        $searchInput = $('.booking_search_exchange'),
        $searchInputVal = $('.booking_id');
    bookings.initialize();
    $searchInput.typeahead({
        highlight: true,
    },
    {
        source: bookings.ttAdapter(),
        templates: {
            suggestion: Handlebars.compile('<a href="#">{{ id }} -{{value}}: '+
                '{{origin}} <i class="fa {{icon}}"></i>  {{destination}} - '+
                '{{customer}} - {{status}} - {{ create_date }} </a>'),
        }
    })
    .bind('typeahead:selected', function(e, obj){
        $searchInput.val(obj.value);
        $searchInputVal.val(obj.id);
    });
}

function BlockBookingSearch() {
    var
        bookings = new Bloodhound({
            datumTokenizer: function(d) {
                return Bloodhound.tokenizers.whitespace(d.value);
            },
            queryTokenizer: Bloodhound.tokenizers.whitespace,
            remote: {
                url: '?q=%QUERY',
                filter: function(list) {
                    return $.map(list, function(booking) {
                        var icon;
                        if (booking['trip_type']==1)
                            icon = 'fa-exchange';
                        else icon = 'fa-long-arrow-right';
                        return {
                            id: booking['org_id'],
                            value: booking['id'],
                            status: booking['status'],
                            url: booking['url'],
                            customer: booking['customer'],
                            origin: booking['origin'],
                            destination: booking['destination'],
                            create_date: (booking['create_date']).toString().slice(0, 19).replace('T', ' '),
                            icon: icon};
                    });
                }
            },
        }),

        $searchInput = $('.block_search_booking'),
        $searchInputVal = $('.block_booking_id'),
        $searchSpanElem = $('#block_booking_id_span'),
        $idTicketInfoElem = $('#div_id_ticket_info');
    if($searchInputVal.val() && $searchInputVal.val() !== 'None') {
        $searchSpanElem.html('ССЫЛКА НА БРОНЬ');
        $searchSpanElem.attr('href', `/accountant/bookings/${$searchInputVal.val()}/`);
        $idTicketInfoElem.attr('style', 'display: none');
    }
    bookings.initialize();
    $searchInput.typeahead({
        highlight: true,
    },
    {
        source: bookings.ttAdapter(),
        templates: {
            suggestion: Handlebars.compile('<a href="#">{{ id }} -{{value}}: '+
                '{{origin}} <i class="fa {{icon}}"></i>  {{destination}} - '+
                '{{customer}} - {{status}} - {{ create_date }} </a>'),
        }
    })
    .bind('typeahead:selected', function(e, obj){
        $searchInput.val(obj.value);
        $searchInputVal.val(obj.id);
        $searchSpanElem.html('ССЫЛКА НА БРОНЬ');
        $searchSpanElem.attr('href', `/accountant/bookings/${obj.id}/`);
        $idTicketInfoElem.attr('style', 'display: none');
        $searchSpanElem.attr('is_search', 'false');
    });
}

function setIsSearch() {
    $('#block_booking_id_span').attr('is_search', 'true');
}

function onChangeBookingId() {
    $searchInputVal = $('#block_booking_id');
    $searchSpanElem = $('#block_booking_id_span');
    $idTicketInfoElem = $('#div_id_ticket_info');
    if ($searchSpanElem.attr('is_search') === 'true') {
        $searchInputVal.val('');
        $searchSpanElem.html('');
        $idTicketInfoElem.attr('style', 'display: block');
    }
}

function AirlineSearch() {
    var
        airlines = new Bloodhound({
            datumTokenizer: function(d) {
                return Bloodhound.tokenizers.whitespace(d.value);
            },
            queryTokenizer: Bloodhound.tokenizers.whitespace,
            remote: {
                url: '?q=%QUERY',
                filter: function(list) {
                    return $.map(list, function(airline) {
                        return {
                            id: airline['id'],
                            value: airline['code']+ ' ' + airline['name']
                        };
                    });
                }
            },
        }),

        $searchInput = $('#airline_search'),
        $searchInputVal = $('#airline_id');
    airlines.initialize();
    $searchInput.typeahead({
        highlight: true,
    },
    {
        source: airlines.ttAdapter(),
        templates: {
            suggestion: Handlebars.compile('<a href="#">{{value}} </a>'),
        }
    })
    .bind('typeahead:selected', function(e, obj){
        $searchInput.val(obj.value);
        $searchInputVal.val(obj.id);
    });
}
