//region функции которые связаны с datetime
function milliSecondsToDays(milliSeconds){
    // convert milliseconds to [days, hours, minutes]
    let oneDay = 1000 * 60 * 60 *24;
    let oneHour = 1000 * 60 * 60;
    let oneMinute = 1000 * 60;
    let days = Math.floor(milliSeconds/oneDay);
    let remainedMilliseconds = (milliSeconds%oneDay);
    let hours = Math.floor(remainedMilliseconds/oneHour);
    remainedMilliseconds = (remainedMilliseconds%oneHour);
    let minutes = Math.floor(remainedMilliseconds/oneMinute);
    return [days, hours, minutes]
}

function date_to_readable_date(val){
    if (val === '' || !val) return ''
    const date = new Date(val);
    const months = ["янв", "фев", "мар", "апр", "мая","июн","июл","авг","сен","окт","ноя","дек"];
    return date.getDate() + " "
        + months[date.getMonth()]
        + " "
        + date.getFullYear()
        + "г. " + ((date.getHours() < 10)?"0":"") + date.getHours()
        + ":" + ((date.getMinutes() < 10)?"0":"") + date.getMinutes()
}
//endregion

//region Проверка есть ли ChangedFlight по этому Booking
async function check_change_flight_exists_by_booking(){
    // Проверяет есть ли ChangedFlight по этому Booking
    return $.ajax({
        type: 'GET',
        url: CHECK_CHANGED_FLIGHT_EXISTS_BY_BOOKING_URL
    });

}
//endregion

//region Выясняет может ли у лега быть Изменения
async function flight_legs_of_booking(){
    /* Выясняет может ли у лега быть Изменения по этим критериям
        1) Reason - АК изменила рейс
        2) стоит галочка на "Вынужденный"
        3) Возврат без удержания штрафов
        4) Возврат по GDS
     */
    return $.ajax({
        type: 'GET',
        url: FLIGHT_LEG_HAS_CHANGE_URL
    });

}
async function check_enable_creating_change_flight_window(){
    // проверяет есть ли change flight по этому booking (Если есть не даем создать новый)
    return check_change_flight_exists_by_booking().then(
        (res) => {
            let changed_flight_exist = res.result;
            if (changed_flight_exist) {
                return false;
            }
            // проверяет есть ли у рейсов Изменения Рейса (Если нет не показываем окно)
            return flight_legs_of_booking().then(
                (res) => {
                    let list_of_flight_legs = res.result;
                    let check_leg_has_change = false;
                    for (let leg in list_of_flight_legs){
                        if (list_of_flight_legs[leg].has_change){
                            check_leg_has_change = true;
                            break
                        }
                    }
                    if (!check_leg_has_change){
                        return false;
                    }

                    // Валидация прошла успешно отправляем true
                    return true
                }
            ).catch(
                () => {
                    return false
                }
    )}
    ).catch(
        () => {
            return false
        }
    )
}
//endregion

//region Создание ChangedFlight
function flightCheckboxChanged(x) {
     /*
       Функция для выборки полетов
      */
    return function (e) {
        const flight_leg_info = $($(".flight_leg_name")[x])
        const flightName = flight_leg_info.text();
        const flight_leg_id = flight_leg_info.attr('id');
        const departure = flight_leg_info.attr('departure');
        const arrival = flight_leg_info.attr('arrival');
        const departure_date = new Date(departure).toISOString().split("T")[0];
        const arrival_date = new Date(arrival).toISOString().split("T")[0];

        if (e.target.checked) {
            // если выбрали рейс то создаем формучку для создание ChangedFlight
            $("#template_flight_checked .leg_name").html('Рейс: ' + flightName);
            $("#template_flight_checked .leg_name").attr("attr-value", flight_leg_id);
            $("#template_flight_checked .type_changed_flight select").attr({
                "id": "typeOfFlight" + flight_leg_id
            })
            $("#template_flight_checked .postponed_changed_flight").attr({
                "id": "postponedChangedFlight" + flight_leg_id
            })
            $("#template_flight_checked .departureZone .oldTime").text(
                date_to_readable_date(departure)
            )
            $("#template_flight_checked .arrivalZone .oldTime").text(
                date_to_readable_date(arrival)
            )
            const templateFlightBlock = $(`#template_flight_checked`).html();
            $("#checked_flights").append(`
                <div class="block_checked_${flight_leg_id}">${templateFlightBlock}</div>
            `);

            $(`#postponedChangedFlight${flight_leg_id} .departureZone input[name=date_name]`).on(
                'change', onChangeMethod('departure'))
            $(`#postponedChangedFlight${flight_leg_id} .departureZone input[name=time_name]`).on(
                'change', onChangeMethod('departure'))
            $(`#postponedChangedFlight${flight_leg_id} .departureZone input[name=date_name]`).val(departure_date);

            $(`#postponedChangedFlight${flight_leg_id} .arrivalZone input[name=date_name]`).on(
                'change', onChangeMethod('arrival'))
            $(`#postponedChangedFlight${flight_leg_id} .arrivalZone input[name=time_name]`).on(
                'change', onChangeMethod('arrival'))
            $(`#postponedChangedFlight${flight_leg_id} .arrivalZone input[name=date_name]`).val(arrival_date);

            function onChangeMethod(type) {
                return (e) => {
                    const _date = $(e.target).parent().find(`input[name=date_name_hidden]`);
                    const _time = $(e.target).parent().find(`input[name=time_name]`);
                    const crt_date = $(e.target).parent().find(`input[name=date_name]`);
                    const value = crt_date.val() + "T" + _time.val();
                    _date.val(value);
                    // Вычисляем на сколько дней рейс изменится
                    if (type === 'departure'){
                        const departure_date = new Date(departure);
                        const new_departure_date = new Date(value);
                        const diff = new_departure_date - departure_date;
                        let after_or_past = diff<=0 ? 'раньше': 'позже';
                        let arr_date = milliSecondsToDays(Math.abs(diff));

                        $(`#postponedChangedFlight${flight_leg_id} .departureZone .changed_time_diff`).text(`Вы изменяете дату вылета на
                            ${arr_date[0]} дней ${arr_date[1]} часов ${arr_date[2]} мин ${after_or_past}`
                        );
                        $(`#postponedChangedFlight${flight_leg_id} .departureZone .date_error`).css("display", "none");
                    }
                    else if(type === 'arrival'){
                        const arrival_date = new Date(arrival);
                        const new_arrival_date = new Date(value);
                        const diff = new_arrival_date - arrival_date;
                        let after_or_past = diff<=0 ? 'раньше': 'позже';
                        let arr_date = milliSecondsToDays(Math.abs(diff));

                        $(`#postponedChangedFlight${flight_leg_id} .arrivalZone .changed_time_diff`).text(
                            `Вы изменяете дату прилета на ${arr_date[0]} дней ${arr_date[1]} часов ${arr_date[2]} мин ${after_or_past}`
                        );
                        $(`#postponedChangedFlight${flight_leg_id} .arrivalZone .date_error`).css("display", "none");

                    }
                }
            }


            // Если выбралы перенос рейса то показываем окно с переносом рейса
            $("#typeOfFlight" + flight_leg_id).on('change', function (e) {
                if (e.target.value == 1) {
                    $("#postponedChangedFlight" + flight_leg_id).css("display", "block");
                } else {
                    $("#postponedChangedFlight" + flight_leg_id).css("display", "none");
                }
            })

        } else {
            $(`#checked_flights .block_checked_${flight_leg_id}`).remove()
        }
    }
}
function on_change_call() {
    const ar = $(".flight_checkbox");
    for (let x = 0;x < ar.length;x++) {
        $(ar[x]).off();
        $(ar[x]).on('change', flightCheckboxChanged(x));
    }
}

function isValidTime(old_time, new_time){
    /*
        1) Новая время вылета и новая время прилета не должна превышать 14 дней до и после
        2) Новая время вылета и новая время прилета не должна быть в прошлом
    */
    const two_weeks_in_milliseconds = 1209600000;
    const error_codes = {
        newTimeInPast: 'newTimeInPast',
        newTimeLaterThanTwoWeeks: 'newTimeLaterThanTwoWeeks',
        newTimeEarlierThanTwoWeeks: 'newTimeEarlierThanTwoWeeks'
    }
    let now = new Date();
    let diff = new_time - old_time;

    if (new_time<now){
        return {
            is_valid: false,
            valid_text: error_codes.newTimeInPast
        }
    }
    if (diff>=two_weeks_in_milliseconds){
        return {
            is_valid: false,
            valid_text: error_codes.newTimeLaterThanTwoWeeks
        }
    }
    else if(diff<= -two_weeks_in_milliseconds){
        return {
            is_valid: false,
            valid_text: error_codes.newTimeEarlierThanTwoWeeks
        }
    }

    return {
            is_valid: true,
            valid_text: ''
        }
}
function isChangedFlightValid(){
    /* Проверяем валидные ли данные
            1) Тип не должен быть пустым
            2) Если тип Postponed то должно быть обязательно новая время вылета и новая время прилета
            3) новая время вылета < новая время прилета
     */
    const error_codes = {
        newTimeInPast: 'newTimeInPast',
        newTimeLaterThanTwoWeeks: 'newTimeLaterThanTwoWeeks',
        newTimeEarlierThanTwoWeeks: 'newTimeEarlierThanTwoWeeks'
    }
    let is_changed_flight_date_valid = true;
    let is_changed_flight_exists = false;
    $('#checked_flights').children('div').each(function () {
        is_changed_flight_exists=true;
        let flight_leg_id = $(this).children().eq(0).attr('attr-value');
        let type = $('#typeOfFlight'+flight_leg_id).val();

        let new_departure = null;
        let new_arrival = null;

        if (type === '1') {
            // Валидация departure time
            let departure_date_error_query =  $(`#postponedChangedFlight${flight_leg_id} .departureZone .date_error`)
            new_departure = $(`#postponedChangedFlight${flight_leg_id} .departureZone .new_changed_date`).val();
            if (new_departure === 'null') {
                departure_date_error_query.text("Необходимо выбрать дату")
                departure_date_error_query.css("display", "block");
                is_changed_flight_date_valid = false
                return;
            }
            const departure = $(`#${flight_leg_id}`).attr('departure');
            let departure_date = new Date(departure);
            let new_departure_date = new Date(new_departure);
            if (new_departure_date.getTime() === departure_date.getTime()){
                departure_date_error_query.text("Вы указали старую дату вылета")
                departure_date_error_query.css("display", "block");
                is_changed_flight_date_valid = false
                return;
            }
            let time_valid = isValidTime(departure_date, new_departure_date);
            if (!time_valid.is_valid){
                if (time_valid.valid_text === error_codes.newTimeInPast){
                    departure_date_error_query.text("Новая время вылета не должна быть в прошлом")
                    departure_date_error_query.css("display", "block");
                }
                else if(time_valid.valid_text === error_codes.newTimeLaterThanTwoWeeks){
                    departure_date_error_query.text("Новая время вылета не должна превышать 14 дней")
                    departure_date_error_query.css("display", "block");
                }
                else if(time_valid.valid_text === error_codes.newTimeEarlierThanTwoWeeks){
                    departure_date_error_query.text("Новая время вылета не должна быть меньше чем на 14 дней")
                    departure_date_error_query.css("display", "block");
                }
                is_changed_flight_date_valid = false
                return;
            }

            // Валидация arrival time
            let arrival_date_error_query =  $(`#postponedChangedFlight${flight_leg_id} .arrivalZone .date_error`)
            new_arrival = $(`#postponedChangedFlight${flight_leg_id} .arrivalZone .new_changed_date`).val();
            if (new_arrival === 'null'){
                arrival_date_error_query.text("Необходимо выбрать дату")
                arrival_date_error_query.css("display", "block");
                is_changed_flight_date_valid = false
                return;
            }
            const arrival = $(`#${flight_leg_id}`).attr('arrival');
            let arrival_date = new Date(arrival);
            let new_arrival_date = new Date(new_arrival)
            if (new_arrival_date.getTime() === arrival_date.getTime()){
                arrival_date_error_query.text("Вы указали старую дату прилета")
                arrival_date_error_query.css("display", "block");
                is_changed_flight_date_valid = false
                return;
            }
            let arrival_time_valid = isValidTime(arrival_date, new_arrival_date);
            if (!arrival_time_valid.is_valid){
                if (arrival_time_valid.valid_text === error_codes.newTimeInPast){
                    arrival_date_error_query.text("Новая время прилета не должна быть в прошлом")
                    arrival_date_error_query.css("display", "block");
                }
                else if(arrival_time_valid.valid_text === error_codes.newTimeLaterThanTwoWeeks){
                    arrival_date_error_query.text("Новая время прилета не должна превышать 14 дней")
                    arrival_date_error_query.css("display", "block");
                }
                else if(arrival_time_valid.valid_text === error_codes.newTimeEarlierThanTwoWeeks){
                    arrival_date_error_query.text("Новая время прилета не должна быть меньше чем на 14 дней")
                    arrival_date_error_query.css("display", "block");
                }
                is_changed_flight_date_valid = false
                return;
            }

            if (new_departure_date>=new_arrival_date){
                departure_date_error_query.text("Новое время даты вылета не должно быть позже нового времени даты прилета")
                departure_date_error_query.css("display", "block");
                arrival_date_error_query.text("Новое время даты прилета не должно быть раньше нового времени даты вылета")
                arrival_date_error_query.css("display", "block");
                is_changed_flight_date_valid = false;
                return;
            }
        }
        else if(type === ''){
            is_changed_flight_date_valid = false
            return;
        }
    });

    return is_changed_flight_date_valid && is_changed_flight_exists;
}
function isConfirmed() {
    // Ecли данные все валидные то показываем Confirm Dialog
    if (!isChangedFlightValid()){
        return
    }
    $("#confirm-dialog").modal("show")
}

$(document).on('ready', () => {
    $("#confirm-dialog input[name='accept']").on('click', function(){
        createChangeFlight();
        $(this).off();

    });
    $("#confirm-dialog input[name='decline']").on('click', function() {
        $("#confirm-dialog").modal("hide")
    })
})

function createChangeFlight() {
    /*
    Складываем данные и отправляем на бэк
     */
    let changed_flights = [];
    $('#checked_flights').children('div').each(function () {
        let flight_leg_id = $(this).children().eq(0).attr('attr-value');
        let type = $('#typeOfFlight'+flight_leg_id).val();
        let new_departure = type === '1' ? $(`#postponedChangedFlight${flight_leg_id} .departureZone .new_changed_date`).val(): null;
        let new_arrival = type === '1' ? $(`#postponedChangedFlight${flight_leg_id} .arrivalZone .new_changed_date`).val(): null;
        changed_flights.push({
            "flight_leg": flight_leg_id, "type": type, "new_departure": new_departure, "new_arrival": new_arrival
        })
    });
    $.ajax({
        type: 'POST',
        url: CREATE_CHANGED_FLIGHT_URL,
        dataType:'json',
        data: JSON.stringify({
            "changed_flights": changed_flights,
            "refund_request_id" : REFUND_REQUEST_ID
        }),
        contentType: 'application/json;',
        success: function (data) {
            enable_creating_change_flight_window().then(res => {
                if (!res) {
                    $('#change_flight').css({display: 'none'});
                }
            })
            $("#confirm-dialog").modal("hide")
        },
        error: function (data) {
            $("#confirm-dialog").modal("hide")
        },
    });
}

function construct_changed_flight_component(){
    new Vue({
        data(){
            return {
                flight_list: [],
            }
        },
        created(){
            fetch(BOOKING_FLIGHT_INFO_URL).then(res => res.json()).then(
                res => {
                    let flight_list = res;
                    fetch(FLIGHT_LEG_HAS_CHANGE_URL).then(res => res.json()).then(
                        res => {
                            let change_flight_info_by_leg = res.result; // [{"flight_leg_id": 1, "has_change": True}, ..]
                            for (const ind in flight_list){
                                let flight_legs = flight_list[ind][['flight_legs']]
                                let has_leg_with_change = false;
                                for (const leg in flight_legs) {
                                    for (const index in change_flight_info_by_leg){
                                        if (change_flight_info_by_leg[index].flight_leg_id == flight_legs[leg].id){
                                            flight_legs[leg].has_change = change_flight_info_by_leg[index].has_change;
                                            if (flight_legs[leg].has_change){
                                                has_leg_with_change = true;
                                            }

                                        }
                                    }

                                }
                                flight_list[ind].has_leg_with_change = has_leg_with_change;
                            }
                            this.flight_list = flight_list;
                        }


                    );
                }
            );
        },
        mounted(){
            this.$nextTick(()=>{
                setTimeout(()=>{
                    on_change_call();
                }, 1000);
            })
        },
        template: `         
         <div>
         <table class="table table-bordered table-booking-detail" style="display:table;" v-for="(flight, i) in flight_list" :key="i"
          v-if="flight.has_leg_with_change">
                <tr>
                    <td colspan="7" style="text-align:left">
                        <span class='directions'>{{flight.origin}}
                            <i class='fa fa-long-arrow-right'></i>
                            {{flight.destination}}
                        </span>,
                        {{flight.departure|date_format}}
                    </td>
                </tr>
                <tr>
                    <th>Рейс</th>
                    <th>Вылет</th>
                    <th>Прилет</th>
                    <th>Перевозчик</th>
                    <th></th>
                </tr>
                <tr v-for="(leg, x) in flight.flight_legs" :key="x" v-if="leg.has_change">
                    <td class="flight_leg_name" :id="leg.id" :departure="leg.departure_date" :arrival="leg.arrival_date">
                        {{ leg.flight_name}}
                    </td>
                    <td>{{leg.departure_date | hour_format}} {{leg.origin_city}}
                        <span class="grey">{{leg.origin_terminal}}</span></td>
                    <td>{{leg.arrival_date| hour_format}} {{leg.destination_city}}
                        <span class="grey">{{leg.destination_terminal}}</span></td>
                    <td>{{ leg.airline_name }}</td>
                    <td><input type="checkbox" class="flight_checkbox" /></td>
                </tr>
         </table>
        </div>
          `,
        filters:{
            date_format(val){
                if (val === '' || !val) return ''
                const date = new Date(val);
                const months = ["янв", "фев", "мар", "апр", "мая","июн","июл","авг","сен","окт","ноя","дек"];
                return date.getDate() + " "
                    + months[date.getMonth()]
                    + " "
                    + date.getFullYear()
                    + "г. " + ((date.getHours() < 10)?"0":"") + date.getHours()
                    + ":" + ((date.getMinutes() < 10)?"0":"") + date.getMinutes()
            },
            hour_format(val){
                if (val === '' || !val) return ''
                const date = new Date(val);
                return " "
                    + ((date.getHours() < 10)?"0":"") + date.getHours()
                    + ":" + ((date.getMinutes() < 10)?"0":"") + date.getMinutes()
            }
        }
    }).$mount('#booking_flight_list');
}
//endregion