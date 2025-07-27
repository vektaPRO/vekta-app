(function() {
    if (IS_NEW_EXCHANGE_ENABLED) {
        const btn = $("#exchange_request_complete_button");
        btn.removeAttr('data-target')
        // switch off all clicks before it
        btn.off('click');

        // add event click
        $('#exchange_request_complete_button').on('click', function() {
            $("#customChangeModal").modal({
                backdrop: 'static',
                keyboard: false
            });
        }.bind(this));
    }
})()

const filters = {
    install(Vue) {
        Vue.filter('dateFormat', function(val) {
            if (val === '' || !val) return ''
            const date = new Date(val);
            const months = ["янв", "фев", "мар", "апр", "мая","июн","июл","авг","сен","окт","ноя","дек"];
            return date.getDate() + " "
                + months[date.getMonth()]
                + " "
                + date.getFullYear()
                + "г. " + ((date.getHours() < 10)?"0":"") + date.getHours()
                + ":" + ((date.getMinutes() < 10)?"0":"") + date.getMinutes();
        })
    }
}
Vue.use(filters);

Vue.component('autocomplete', {
    props: ['item', 'row', 'col', 'target'],
    data: () => ({}),
    methods: {
        emitClick(search){
            this.$emit('clickSearchItem', search, this.row, this.col, this.target);
        }
    },
    template: `
        <div class="tt-dropdown-menu" 
            style="position: absolute; top: 100%;max-height: 300px;overflow-y: scroll;left: 0px; z-index: 100;width: 100%" 
            v-if="item[row] && item[row][col] && item[row][col][target]">
            <div class="tt-dataset">
                <div v-for="(search, key) in item[row][col][target]" 
                    @click="emitClick(search)"
                    :key="key" 
                    class="tt-dataset__inner autocomplete_item">
                    <span class="autocomplete_item">{{ search.name + (search.code ? '(' + search.code + ')' : '') }}</span>
                </div>
            </div>
        </div>
    `
});

Vue.component('removeIcon', {
    props: ['idx', 'target', 'isAdded', 'i'],
    methods: {
        editEmitter() {
            this.$emit('editCurrent', this.i ,this.idx, this.target);
        }
    },
    template: `
        <i v-if="!isAdded" 
            class="bi bi-trash d-block trashIcon mx-3 trashSegment glyphicon glyphicon-pencil" 
            @click="editEmitter(idx, target)">&#127;</i>  
    `
});

Vue.component('columnComponent', {
    props: [
        'targetField',
        'editFlightLegs',
        'idx',
        'i',
        'leg',
        'flightErrors',
        'editCurrentTr'
    ],
    template: `
        <div>
            <div style="display: flex;" v-if="(idx === 0 && targetField['type'] != 'icon') || (idx > 0)">
                <label 
                    style="width: 100%;display: flex; flex-direction: column" 
                    class="flight" 
                    v-if="!editFlightLegs[i][idx][targetField['type']]"> <!-- !editFlightLegs[idx].origin -->
                    <slot name="forShow">
                        <label :style="(leg[targetField['type']] ? '' : 'color: gray')">{{ leg[targetField['type']] }}</label>
                    </slot>
                </label>
                <div v-else>
                    <slot name="forEdit">
                        <input type="text" class="form-control" v-model="leg[targetField['type']]">
                    </slot>
                </div>
            </div>
            <span style="color: red;display: block"  
                v-if="flightErrors[i] && flightErrors[i][idx] && Array.isArray(targetField['fields'])"
                v-for="(field, id) in targetField['fields']" :key="id ">
                <span v-if="typeof field === 'object' && flightErrors[i][idx][field.key]">{{ field.errorMessage }}</span>
                <span v-else-if="flightErrors[i][idx][field]">Заполните это поле</span>
            </span>
        </div>
    `
});

Vue.component('passengers', {
    props: ['passengerHead',
        'tickets',
        'editPassenger',
        'editOpenedPassenger',
        'extraServices',
        'disabled',
        'passengerErrors',
        'showAlert',
        'oldBooking',
        'removePassenger'],
    methods: {
        focusOn(e){
            e.stopPropagation()
        },
        onValueChange(e, i, field) {
            this.tickets[i][field] = e.target.value.toUpperCase();
        },
        onNewNumberChange(e, idx) {
            const deleteKeyCode = 8;
            if (e.keyCode === deleteKeyCode) {
                return;
            }
            let newVal = e.target.value.split('');
            const currentVal = newVal.filter(x => x !== ' ').join('');
            if (currentVal.length > 21) {
                this.tickets[idx].new_number = e.target.value.substr(0, 21);
            }
            if (currentVal.length > 3) {
                const currentMinus = currentVal[3];
                if (currentMinus != '-') {
                    const firstCut = currentVal.substr(0, 3);
                    const cutTo = currentVal.substr(3, currentVal.length);
                    const ans = firstCut.split("").filter(res => res != '-').join('') + '-' + cutTo.split("").filter(res => res != '-').join('');
                    this.tickets[idx].new_number = ans;
                }
            }
        },
        onCostChange(e, idx, field, extraKey) {
            e.target.value = e.target.value.replaceAll('-', '')
            this.tickets[idx][field] = e.target.value;
            this.$emit('changeTaxWithBase', field);
            this.tickets[idx][extraKey] = (+e.target.value / this.oldBooking.currency).toFixed(0);
        },
        addService(fields) {
            this.$emit('openServiceModal', fields);
        },
        removeRow(i, current) {
            current.splice(i, 1);
        }
    },
    template: `
        <table class="table table-bordered" style="margin-bottom: 0" v-if="oldBooking">
            <thead>
                <tr>
                    <th v-for="(head,i) in passengerHead" :key="i">
                        {{ head }}
                    </th>
                </tr>
            </thead>
            <tbody>
                <tr 
                    v-for="(passenger, idx) in tickets" :key="idx">
                    <td @click="editPassenger(idx, 'passenger')" ref="passengerTd" style="cursor: pointer">
                        <label class="base-fare" v-if="editOpenedPassenger[idx].passenger">
                            <label>
                                Имя:
                                <input type="text" class="form-control" 
                                    v-model="passenger.passenger_name" @click="focusOn" @change="e => onValueChange(e, idx, 'passenger_name')">
                                <span v-if="passengerErrors[idx] && passengerErrors[idx]['passenger_name']" style="color: red">Заполните это поле</span>
                            </label>
                            <label>
                                Фамилия:
                                <input type="text" class="form-control" 
                                    v-model="passenger.passenger_surname" @click="focusOn" @change="e => onValueChange(e, idx, 'passenger_surname')">
                                <span v-if="passengerErrors[idx] && passengerErrors[idx]['passenger_surname']" style="color: red">Заполните это поле</span>
                            </label>
                        </label>
                        <label class="passengerName" v-else>
                            {{ passenger.passenger_name + " " + passenger.passenger_surname }}
                            <label v-if="passengerErrors[idx] && (passengerErrors[idx]['passenger_surname'] || passengerErrors[idx]['passenger_name'])" style="color: red">Заполните эти поля</label>
                        </label>
                    </td>
                    <td>
                        <label>
                            {{ passenger.number }}
                        </label>
                    </td>
                    <td @click="editPassenger(idx, 'new_number')" ref="passengerTd" style="cursor: pointer">
                        <div style="display: flex">
                            <label class="base-fare" v-if="editOpenedPassenger[idx].new_number">
                                <input type="text" class="form-control" 
                                    @keyup="e => onNewNumberChange(e, idx)"
                                    placeholder="XXX-XXXXXX"
                                    v-model="passenger.new_number" 
                                    @click="focusOn">
                                <span v-if="passengerErrors[idx] && passengerErrors[idx]['new_number']" style="color: red">Заполните это поле</span>
                            </label>
                            <label v-else>
                                {{ passenger.new_number }}
                                 <span v-if="passengerErrors[idx] && passengerErrors[idx]['new_number']" style="color: red">Заполните это поле</span>
                            </label>
                        </div>
                    </td>
                    <td @click="editPassenger(idx, 'tax')" ref="passengerTd" style="cursor: pointer">
                        <div style="display: flex;align-items: center;justify-content: center">
                            <label class="base-fare" v-if="editOpenedPassenger[idx].tax">
                                <input type="number" 
                                    min="0" 
                                    class="form-control" 
                                    :value="passenger.tax" 
                                    @input="e => onCostChange(e, idx, 'tax', 'gds_tax')"
                                    @click="focusOn">
                                <div style="display: flex;align-items: center; margin-top: 15px">
                                    <span>{{ oldBooking.gds_currency_alpha_code }}:  </span>
                                    <input type="number"
                                    min="0"
                                    disabled
                                    class="form-control"
                                    v-model="tickets[idx].gds_tax"
                                    @click="focusOn">
                                </div>
                                <span v-if="passengerErrors[idx] && passengerErrors[idx]['tax']" style="color: red">Заполните это поле</span>
                            </label>
                            <label v-else>
                                {{ passenger.tax }}
                                <span v-if="passengerErrors[idx] && passengerErrors[idx]['tax']" style="color: red">Заполните это поле</span>
                            </label>
                        </div>
                    </td>
                    <td @click="editPassenger(idx, 'base_fare')" ref="passengerTd" style="cursor: pointer">
                        <div style="display: flex;align-items: center;justify-content: center">
                            <label class="base-fare" v-if="editOpenedPassenger[idx].base_fare">
                                <input 
                                    type="number" min="0"
                                     class="form-control" 
                                     :value="passenger.base_fare"
                                     @input="e => onCostChange(e, idx, 'base_fare', 'gds_base_fare')"
                                     @click="focusOn">
                                <div style="display: flex;align-items: center; margin-top: 15px">
                                    <span>{{ oldBooking.gds_currency_alpha_code }}:  </span>
                                    <input type="number"
                                    min="0"
                                    disabled
                                    class="form-control"
                                    v-model="tickets[idx].gds_base_fare"
                                    @click="focusOn">
                                </div>
                                <span v-if="passengerErrors[idx] && passengerErrors[idx]['base_fare']" style="color: red">Заполните это поле</span>
                            </label>
                            <label v-else>
                                {{ passenger.base_fare }}
                                <span v-if="passengerErrors[idx] && passengerErrors[idx]['base_fare']" style="color: red">Заполните это поле</span>
                            </label>
                        </div>
                    </td>
                    <td>
                        <label>
                            {{ +passenger.base_fare + +passenger.tax }}
                        </label>
                    </td>
                    <td style="width: 300px">
                        <label v-if="passenger.special_services.length > 0">
                            <div v-for="(item, id) in extraServices.items" :key="id">
                                <h4 style="display: inline-block;">
                                    <span style="border-bottom: 1px solid black;font-size: 12px">{{ item.display }}</span>
                                    <span class="btn" style="font-size: 12px;margin-left: 10px;background-color: lightgrey" @click="addService({...item, id: idx})">
                                        Добавить
                                    </span>
                                </h4>
                                <div style="display: flex;justify-content: space-between;margin-bottom: 5px" 
                                    v-for="(option, i) in passenger.special_services.find(service => service.type == item.type).options" 
                                    :key="i">
                                    <p v-if="item.type === 'XBAG'">
                                        {{ option.origin }} <i class="fa fa-long-arrow-right"></i> 
                                        {{ option.destination }} | {{ option.weight }}{{ option.unit_of_measure }}
                                    </p>
                                    <p v-else-if="item.type === 'SEAT'">
                                        {{ option.origin }} <i class="fa fa-long-arrow-right"></i> 
                                        {{ option.destination }} | {{ option.seat_number }}
                                    </p>
                                    <div class="actions" style="margin-left: 10px">
                                        <i class="fa fa-trash" 
                                            style="cursor: pointer;color: red;font-size: 16px" 
                                            @click="e => removeRow(i, passenger.special_services.find(service => service.type == item.type).options)"></i>
                                    </div>
                                </div>
                            </div>
                        </label>
                    </td>
                    <td>
                        <div style="display: flex; justify-content: center">
                            <button style="color: red; border: 1px solid red;background-color: white;display: none" @click="removePassenger(idx)">
                                Удалить
                                <i class="fa fa-trash" style="cursor: pointer;color: red;font-size: 16px"></i>
                            </button>
                        </div>
                    </td>
                </tr>
            </tbody>
        </table>
    `
});

Vue.component('divider', {
    template: `
        <span style="height: 1px;width: 100%;display: block;background-color: #e6e6e6"></span>
    `
});

// hint
Vue.component('hint', {
    props: ['message', 'refs'],
    methods: {
        searchProps(parentRef, refs, counter = 0) {
            let curProps = refs;
            if (!parentRef[curProps] && Array.isArray(curProps)) {
                parentRef = parentRef[curProps[counter]].$refs;
                curProps = curProps[++counter];
                this.searchProps(parentRef, curProps, counter);
            }
            return [parentRef, curProps];
        },
        hintMouseOver(e) {
            const [ref, curProp] = this.searchProps(this.$parent.$refs, this.refs);
            for (let x = 0;x < ref[curProp].length;x++) {
                const cur = ref[curProp][x];
                cur.style.animation = 'animationWithOpacity 1s infinite'
            }
        },
        hintMouseOut(e) {
            const [ref, curProp] = this.searchProps(this.$parent.$refs, this.refs);
            for (let x = 0;x < ref[curProp].length;x++) {
                const cur = ref[curProp][x];
                cur.style.animation = 'unset'
            }
        },
    },
    template: `
        <span>
            <span style="margin-left: 10px" 
                @mouseover="e => hintMouseOver(e)" 
                @mouseout="hintMouseOut" 
                class="show-tooltip">
                <i class="fa fa-question-circle"></i>
            </span>
            <span class="tooltips">{{ message }}</span>
        </span>
    `
})

// compare tables
Vue.component('oldNewInfo', {
    props: ['show', 'oldBooking', 'newBooking', 'externalHintText', 'isAllFilled', 'extraServices'],
    methods: {
        styleCondition(i, x, ...fields) {
            let oldLeg = this.oldBooking.itinerary.flights[i].legs[x]
            let newLeg = this.newBooking.itinerary.flights[i].legs[x]
            if (!oldLeg || !newLeg) return false;

            const findValueByFields = (field) => {
              oldLeg = oldLeg[field];
              newLeg = newLeg[field];
              if (!fields.length) {
                  return;
              }
              return findValueByFields(fields.shift());
            }
            findValueByFields(fields.shift());
            return oldLeg === newLeg;
        }
    },
    template: `
        <div id="infoForm" v-if="show && oldBooking && newBooking">
            <hintText :text="externalHintText" v-if="isAllFilled" />
            <h3 class="mb-3">Проверьте данные обмена</h3>
            <table class="table table-bordered">
                <thead>
                    <tr>
                        <th>Бронь</th>
                        <th>Код авиакомпании</th>
                        <th colspan="2">Направления</th>
                        <th>Рейс</th>
                        <th>Багаж</th>
                        <th>Тариф</th>
                        <th>Класс</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>{{ oldBooking.booking_reference_id }}</td>
                        <td>
                            <p v-for="(item,i) in Object.keys(oldBooking.itinerary.supplier_code)" :key="i">
                                {{ item }}: {{ oldBooking.itinerary.supplier_code[item] }}
                            </p>
                        </td>
                        <td>Текущий маршрут</td>
                        <td>
                            <span v-for="(flight, i) in oldBooking.itinerary.flights" :key="i">
                                <span v-for="(leg, x) in flight.legs" :key="x">
                                    <span class="date-from">{{ leg.departure_local | dateFormat }}</span>
                                    {{ leg.origin.code }}
                                    <i class="fa fa-long-arrow-right"></i>
                                    {{ leg.destination.code }}
                                    <span class="date-from">{{ leg.arrival_local | dateFormat }}</span>
                                    <divider />
                                    <br>
                                </span>
                                <br/><br/>
                            </span>
                        </td>
                        <td>
                            <span v-for="(flight, i) in oldBooking.itinerary.flights" :key="i">
                                <span v-for="(leg, x) in flight.legs" :key="x">
                                    {{ leg.airline ? leg.airline.code + '-' : '' }} {{ leg.flight_number }}
                                    <divider />
                                    <br>
                                </span>
                                <br><br>
                            </span>
                        </td>
                        <td>
                            <span v-for="(flight, i) in oldBooking.itinerary.flights" :key="i">
                                <span v-for="(leg, x) in flight.legs" :key="x">
                                    ({{ leg.baggage_raw.count + "*" + leg.baggage_raw.weight }}){{ leg.baggage_raw.unit }}
                                    <divider />
                                    <br>
                                </span>
                                <br><br>
                            </span>
                        </td>
                        <td>
                            <span v-for="(flight, i) in oldBooking.itinerary.flights" :key="i">
                                <span v-for="(leg, x) in flight.legs" :key="x">
                                    {{ leg.fare_basis }}
                                    <divider />
                                    <br>
                                </span>
                                <br><br>
                            </span>
                        </td>
                        <td>
                            <span v-for="(flight, i) in oldBooking.itinerary.flights" :key="i">
                                <span v-for="(leg, x) in flight.legs" :key="x">
                                    {{ leg.service_class }}
                                    <divider />
                                    <br>
                                </span>
                                <br><br>
                            </span>
                        </td>
                    </tr>
                    <tr>
                        <td :style="newBooking.new_booking_reference_id == newBooking.booking_reference_id ? '' : 'color: green'">
                            {{ newBooking.new_booking_reference_id }}
                        </td>
                        <td>
                            <p v-for="(item,i) in Object.keys(newBooking.itinerary.supplier_code)" :key="i">
                                {{ item }}: <span :style="newBooking.itinerary.supplier_code[item] == oldBooking.itinerary.supplier_code[item] ? '' : 'color: green'">{{ newBooking.itinerary.supplier_code[item] }}</span>
                            </p>
                        </td>
                        <td>Новый маршрут</td>
                        <td>
                            <span v-for="(flight, i) in newBooking.itinerary.flights" :key="i">
                                <span v-for="(leg, x) in flight.legs" :key="x">
                                    <span class="date-from" 
                                        :style="!leg.changed ? '' : 'color: green'">
                                        {{ leg.departure_local | dateFormat }}
                                    </span>
                                    <span :style="!leg.changed ? '' : 'color: lightseagreen'">{{ leg.origin.code }}</span>
                                    <i class="fa fa-long-arrow-right"></i>
                                    <span :style="!leg.changed ? '' : 'color: lightseagreen'">{{ leg.destination.code }}</span>
                                    <span class="date-from" 
                                        :style="!leg.changed ? '' : 'color: green'">
                                        {{ leg.arrival_local | dateFormat }}
                                    </span>
                                    <divider />
                                    <br>
                                </span>
                                <br/><br/>
                            </span>
                        </td>
                        <td>
                            <span v-for="(flight, i) in newBooking.itinerary.flights" :key="i">
                                <span v-for="(leg, x) in flight.legs" :key="x">
                                    {{ leg.airline ? leg.airline.code + '-' : '' }} {{ leg.flight_number }}
                                    <divider />
                                    <br>
                                </span>
                                <br><br>
                            </span>
                        </td>
                        <td>
                            <span v-for="(flight, i) in newBooking.itinerary.flights" :key="i">
                                <span v-for="(leg, x) in flight.legs" :key="x">
                                    ({{ leg.baggage_raw.count + "*" + leg.baggage_raw.weight }}){{ leg.baggage_raw.unit }}
                                    <divider />
                                    <br>
                                </span>
                                <br><br>
                            </span>
                        </td>
                        <td>
                            <span v-for="(flight, i) in newBooking.itinerary.flights" :key="i">
                                <span v-for="(leg, x) in flight.legs" :key="x">
                                    {{ leg.fare_basis }}
                                    <divider />
                                    <br>
                                </span>
                                <br><br>
                            </span>
                        </td>
                        <td>
                            <span v-for="(flight, i) in newBooking.itinerary.flights" :key="i">
                                <span v-for="(leg, x) in flight.legs" :key="x">
                                    {{ leg.service_class }}
                                    <divider />
                                    <br>
                                </span>
                                <br><br>
                            </span>
                        </td>
                    </tr>
                </tbody>
            </table>
            <div style="display: flex;justify-content: space-between">
                <div :style="oldBooking.branded_fare && Object.keys(oldBooking.branded_fare).length > 0 ? 'width: 47%' : 'width: 100%'">
                    <h3><b>Билеты</b></h3>
                    <table class="table table-bordered">
                        <thead>
                        <tr>
                            <th>Пассажир</th>
                            <th>Старый билет</th>
                            <th>Новый билет</th>
                            <th>Новая стоимость билета</th>
                            <th>Доп.Сервисы</th>
                        </tr>
                        </thead>
                        <tbody>
                            <tr v-for="(passenger, i) in newBooking.tickets">
                                <td class="info">{{ passenger.passenger_name + " " + passenger.passenger_surname }} </td>
                                <td class="info">{{ passenger.number }}</td>
                                <td class="info">{{ passenger.new_number }}</td>
                                <td class="info">{{  (+passenger.tax + +passenger.base_fare) }}</td>
                                <td class="info">
                                    <label v-if="passenger.special_services.length > 0">
                                        <div v-for="(item, id) in extraServices.items" :key="id">
                                            <h4 style="display: inline-block;">
                                                <span style="border-bottom: 1px solid black;font-size: 12px">{{ item.display }}</span>
                                            </h4>
                                            <div style="display: flex;justify-content: space-between;margin-bottom: 5px" 
                                                v-for="(option, i) in passenger.special_services.find(service => service.type == item.type).options" 
                                                :key="i">
                                                <p v-if="item.type === 'XBAG'">
                                                    {{ option.origin }} <i class="fa fa-long-arrow-right"></i> 
                                                    {{ option.destination }} | {{ option.weight }}{{ option.unit_of_measure }}
                                                </p>
                                                <p v-else-if="item.type === 'SEAT'">
                                                    {{ option.origin }} <i class="fa fa-long-arrow-right"></i> 
                                                    {{ option.destination }} | {{ option.seat_number }}
                                                </p>
                                            </div>
                                        </div>
                                    </label>
                                    <label v-else>
                                        <span>-</span>
                                    </label>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                <div style="width: 47%" v-if="oldBooking.branded_fare && Object.keys(oldBooking.branded_fare).length > 0">
                    <h3><b>Брендированный тариф</b></h3>
                    <table class="table table-bordered">
                        <thead>
                            <tr>
                                <th></th>
                                <th>Ручная кладь</th>
                                <th>Обмен</th>
                                <th>Возврат</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                <td>Текущий тариф</td>
                                <td>{{ oldBooking.branded_fare['carryon_text'] }}</td>
                                <td>
                                    {{ oldBooking.branded_fare['change_text'] }}
                                </td>
                                <td>{{ oldBooking.branded_fare['refund_text'] }}</td>
                            </tr>
                            <tr>
                                <td style="color: darkgreen">Новый тариф</td>
                                <td :style="oldBooking.branded_fare['carryon_text'] == newBooking.branded_fare['carryon_text'] ? '' : 'color: green'">
                                    {{ newBooking.branded_fare['carryon_text'] }}
                                </td>
                                <td :style="oldBooking.branded_fare['change_text'] == newBooking.branded_fare['change_text'] ? '' : 'color: green'">
                                    {{ newBooking.branded_fare['change_text'] }}
                                </td>
                                <td :style="oldBooking.branded_fare['refund_text'] == newBooking.branded_fare['refund_text'] ? '' : 'color: green'">
                                    {{ newBooking.branded_fare['refund_text'] }}
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    `
});

Vue.component('alert', {
    props: ['alertProp'],
    methods: {
        closePopup(isOk) {
            this.alertProp.isOpened = false;
            this.$emit('alertInfo', {
                ...this.alertProp,
                ok: isOk
            });
        }
    },
    template: `
        <div v-if="alertProp.isOpened" class="overlay alert-overlay">
            <div class="popup alert-popup">
                <h3><i class="fa fa-exclamation-triangle" style="color: #bd9c5b"></i><span style="margin-left: 20px;">{{ alertProp.title }}</span></h3>
                <div style="display: flex;margin-top: 30px">
                    <button class="btn" style="width: 30%" @click="closePopup(false)">Отмена</button>
                    <button class="btn btn-danger" style="width: 30%;margin-left: 20px" @click="closePopup(true)">{{ alertProp.btnOkText || 'Ок' }}</button>
                </div>
            </div>
        </div>
    `
});

Vue.component('hintText', {
    props: ['text'],
    template: `
        <div class="warnings" style="display: flex; align-items: center;margin-bottom: 20px" v-if="text && text.length > 0">
            <i class="fa fa-warning" style="color: red"></i>
            <h3 style="margin: 0;margin-left: 20px;color: red">{{ text }}</h3>
        </div>
    `
})

Vue.component('extraServices', {
    props: ['options', 'serviceProps'],
    data() {
        return {
            item: {},
            error: {}
        }
    },
    methods: {
        add() {
            if (this.validate()) {
                return;
            }
            this.$emit('addService', this.serviceProps, this.item);
            this.item = {};
            this.serviceProps.open = false;
        },
        validate() {
            const keys = Object.keys(this.item);
            const fields = Object.keys(this.serviceProps.fields.fields);
            this.error = {};
            // if it is declared and has empty items
            for (let x = 0;x < keys.length;x++) {
                if (this.item[keys[x]] === '') {
                    this.error[keys[x]] = true;
                }
            }
            // field length is not equal to keys
            if (keys.length !== fields.length) {
                this.error = fields.filter(key => !keys.includes(key))
                                    .reduce((a, v) => ({ ...a, [v]: v}), {});
            }
            // get input refs
            [...this.$refs.inputRef].forEach(ref => {
                if (Object.keys(this.error).includes(ref.name)) {
                    ref.style = 'border: 1px solid red'
                }else {
                    ref.style = ''
                }
            })
            return Object.keys(this.error).length > 0;
        }
    },
    template: `
        <div class="overlay alert-overlay" v-if="serviceProps.open">
            <div class="popup alert-popup">
                <div v-if="serviceProps.fields">
                    <p v-for="(field, i) in Object.keys(serviceProps.fields.fields)" :key="i">
                        <label for="origin">{{ serviceProps.fields.fields[field] }}</label>
                        <input type="text" 
                            id="origin" 
                            class="form-control" 
                            ref="inputRef"
                            :name="field"
                            v-model="item[field]" />
                    </p>
                    <span style="color: red;display: block" v-if="Object.keys(error).length > 0">Заполните все поля</span>
                    <div style="margin-top: 20px;">
                        <button class="btn btn-danger" style="font-size: 12px" @click="() => serviceProps.open = false">Закрыть</button>
                        <button class="btn btn-success" style="font-size: 12px" @click="add">Добавить</button>
                    </div>
                </div>
            </div>
        </div>
    `
})

new Vue({
    data: () => ({
        alertProp: {
            isOpened: false,
            title: '',
        },
        defaultSegment: {
            origin_terminal: "",
            destination_terminal: "",
            airplane_name: '',
            airline: {
                name: ''
            },
            fare_basis: '',
            fare_class: '',
            airplane_id: null,
            baggage_raw: {
                count: 0,
                weight: 0,
                unit: 'kg'
            },
            origin: {
                city: {
                    name: ''
                },
                name: ''
            },
            destination: {
                name: ''
            }
        },
        defaultSegmentType: {
            origin: true,
            destination: true,
            flight_number: true,
            fare_basis: true,
            airline: true,
            service_class: true,
            airplane_name: true,
            baggage: true,
            baggage_raw: true,
            isAdded: true,
        },
        defaultPassengerType: {
            base_fare: 0,
            number: "",
            passenger: "",
            new_number: "",
            changed: true,
            passenger_id: null,
            passenger_name: "",
            passenger_surname: "",
            tax: 0
        },
        searchForms: {},
        editFlightLegs: [],
        editOpenedPassenger: [],
        table: {
            thead: [
                {
                    type: 'origin',
                    fields: [{
                        errorMessage: 'Выберите город',
                        key: 'origin'
                    },{
                        errorMessage: 'Выберите время',
                        key: 'departure_local'
                    }],
                    name: 'Вылет'
                },
                {
                    type: 'destination',
                    fields: [{
                        errorMessage: 'Выберите город',
                        key: 'destination'
                    },{
                        errorMessage: 'Выберите время',
                        key: 'arrival_local'
                    }],
                    name: 'Прилет'
                },
                {
                    type: 'airline',
                    fields: ['airline'],
                    name: 'Авиалиния'
                },
                {
                    type: 'flight_number',
                    fields: [{
                        errorMessage: 'Заполните это поле',
                        key: 'flight_number'
                    }],
                    name: 'Рейс'
                },
                {
                    type: 'fare_basis',
                    fields: [{
                        errorMessage: 'Заполните это поле',
                        key: 'fare_basis'
                    }],
                    name: 'Тариф'
                },
                {
                    type: 'service_class',
                    fields: ['service_class'],
                    name: 'Класс'
                },
                {
                    type: 'airplane_name',
                    fields: ['airplane_id'],
                    name: 'Самолет'
                },
                {
                    type: 'baggage_raw',
                    fields: [{
                        errorMessage: 'Введены неверные данные',
                        key: 'baggage_raw'
                    }],
                    name: 'Багаж'
                },
                {
                    type: 'icon',
                    fields: ['icon'],
                    name: '',
                    disabledEdit: true
                }
            ],
            passengerHead: [
                'Покупатель',
                'Старый номер билета',
                'Новый номер билета',
                'Штраф за обмен',
                'Разница в стоимости билетов',
                'Сумма',
                'Доп. сервисы',
                ''
            ]
        },
        URLS: {
            SEARCH_AIRPORTS_URL,
            SEARCH_AIRPLANES_URL,
            SEARCH_AIRLINES_URL
        },
        requiredFlightFields: [
            'airplane_id',
            {
              'destination': [
                  'code',
                  'name',
                  'id'
              ]
            },
            {
                'origin': [
                    'code',
                    'name',
                    'id'
                ]
            },
            {
                'baggage_raw': [
                    'count',
                    'unit',
                    'weight'
                ]
            },
            {
                'airline': [
                    'name'
                ]
            },
            'airplane_name',
            'arrival_local',
            'departure_local',
            'fare_basis',
            'flight_number',
            'service_class'
        ],
        requiredPassengerFields: [
            'base_fare',
            'new_number',
            'passenger_name',
            'passenger_surname',
            'tax'
        ],
        newBooking: {
            reference_id: ''
        },
        branded_fare: {
            table: ['Ручная кладь', 'Обмен', 'Возврат'],
            info: {
                carryon_text: ['Ручная кладь 1x5 кг', 'Ручная кладь 1x7 кг', 'Ручная кладь 1x10 кг', 'Ручная кладь 1x9 кг',
                            'Ручная кладь 1x12 кг',
                            'Ручная кладь 1x15 кг',
                            'Ручная кладь 2х9 кг',
                            'Ручная кладь 2х8 кг',
                            'Ручная кладь 2х18 кг'],
                change_text: ['Обмен платный', 'Обмен недоступен', 'Обмен без штрафа'],
                refund_text: ['Возврат со штрафом', 'Невозвратный', 'Возврат без штрафа']
            },
            types: [
                'CHARGABLE',
                'NOT_OFFER',
                'INCLUDE'
            ]
        },
        mergedBookings: {},
        disabled: {},
        pdf: false,
        oldBooking: null,
        showAllInfo: false,
        booking_reference: false,
        loading: true,
        isDisabled: false,
        externalHintText: "",
        getFlightInfo: null,
        isAllFilled: false,
        extraErrors: {},
        isAgreedForSameCache: true,
        passengerErrors: [],
        error: false,
        flightErrors: [],
        extraServices: {
            serviceProps: {},
            open: false,
            items: []
        }
    }),
    template: `
        <div class="modal-content">
            <!-- modal -->
            <alert :alertProp="alertProp" @alertInfo="alertInfo"></alert>
            <div class="modal-header">
                <h5 class="modal-title" id="exampleModalLabel">Создать обмен</h5>
            </div>
            <extraServices :serviceProps="extraServices" @addService="addService" />
            <div class="modal-body">
                <div class="loader" v-if="loading"><div class="lds-ring"><div></div><div></div><div></div><div></div></div></div>
                <div v-else-if="pdf">
                    <hintText :text="externalHintText" />
                    <input type="file" @change="downloadPdf" style="margin-top: 20px;">Загрузить pdf</input>
                </div>
                <div v-else-if="booking_reference">
                    <hintText :text="externalHintText" />
                    <input v-model="newBooking.reference_id" @change="onReferenceIdChange" type="text" class="form-control" style="width: 150px">
                </div>
                <div v-else-if="getFlightInfo && !showAllInfo">
                    <hintText :text="externalHintText" />
                    <h3 class="tooltips-root">Перелеты
                        <hint message="Для редактирования перелета нажмите на поле" refs="segmentTd"/>
                     </h3>
                    <!-- flights table -->
                    <div v-for="(flightInfo, i) in getFlightInfo.itinerary.flights" :key="i">
                        <h4 v-if="flightInfo.legs.length > 0">
                            {{ flightInfo.legs.length > 0 && flightInfo.legs[0].origin.city ? 
                                flightInfo.legs[0].origin.city.name : 
                                flightInfo.legs[0].origin.name }} 
                            <i class="fa fa-long-arrow-right"></i>
                            {{ flightInfo.legs.length > 0 && flightInfo.legs[flightInfo.legs.length - 1].destination.city ? 
                                    flightInfo.legs[flightInfo.legs.length - 1].destination.city.name : 
                                    flightInfo.legs[flightInfo.legs.length - 1].destination.name }}
                            <button style="color: black; border: none;background-color: white" @click="removeFlight(i)">
                                <i class="fa fa-trash" style="cursor: pointer;font-size: 16px"></i>
                            </button>
                        </h4>
                        <table class="table table-bordered table-hover flightExchangeTable" style="margin-bottom: 0">
                            <thead>
                                <tr>
                                    <th v-for="(head, i) in table.thead" :key="i">
                                        {{ head.name }}
                                    </th>
                                </tr>
                            </thead>
                            <tbody class="segmentBody" ref="segmentBody">
                                <tr v-for="(leg, idx) in flightInfo.legs" :key="idx" class="vertical-align" >
                                    <td style="cursor: pointer" 
                                        disabled="true"
                                        v-for="(head, index) in table.thead" 
                                        ref="segmentTd"
                                        :key="index" 
                                        :style="!(editFlightLegs[i] && editFlightLegs[i][idx] && editFlightLegs[i][idx].isAdded) && 
                                            !disabled[i +'' + idx] && !leg.changed ? 'background-color: lightgrey' : ''"
                                        v-on=" { 
                                                click: (e) => {
                                                    if (!disabled[i + '' + idx] && !leg.changed) {
                                                        showAlert(i +'' + idx, 'Вы хотите поменять сегмент который клиент не запрашивал на обмен?');
                                                        return;
                                                    }
                                                    editCurrentTr(i, idx, head['type'], e) 
                                                }
                                            }">
                                        <columnComponent 
                                            :targetField="head" 
                                            :editFlightLegs="editFlightLegs"
                                            :flightErrors="flightErrors" 
                                            :idx="idx" 
                                            :i="i"
                                            :leg="leg"
                                            :editCurrentTr="editCurrentTr"
                                        >
                                            <template #forShow 
                                                v-if="head.type == 'origin'">
                                                <span class="date-from" style="width: 40%">
                                                        {{ leg['departure_local'] | dateFormat }}
                                                </span>
                                                <label>{{ leg[head.type] | formatCity }}</label>
                                            </template>
                                            <template #forShow 
                                                v-else-if="head.type == 'destination'">
                                                <span class="date-from" style="width: 40%" v-if="leg.arrival_local">
                                                    {{ leg['arrival_local'] | dateFormat }}
                                                </span>
                                                <label>{{ leg[head.type] | formatCity }}</label>
                                            </template>
                                            <template #forShow v-else-if="head.type == 'baggage_raw'">
                                                <label>({{ leg.baggage_raw.count }} * {{ leg.baggage_raw.weight }}) {{ leg.baggage_raw.unit }}</label>
                                            </template>
                                            <template #forShow v-else-if="head.type == 'airline'">
                                                <label>{{ leg.airline.code }}</label>
                                            </template>
                                            <template #forShow v-else-if="head.type == 'icon'">
                                                <div style="display: flex;justify-content: center;align-items: center">
                                                    <i class="bi bi-trash d-block trashIcon mx-3 trashSegment glyphicon glyphicon-trash" 
                                                        @click="deleteSegment(i, idx)"> &#127;</i>
                                                </div>
                                            </template>
                                            <template #forEdit 
                                                v-if="head.type == 'origin' 
                                                    || head.type == 'destination'">
                                                <label class="dynamicInfo destination" style="width: 100%;position: relative">
                                                    <input type="text" class="form-control main-search" 
                                                        v-model="leg[head.type].name"
                                                        @input="e => debouncer(e, i, idx, head.type, URLS['SEARCH_AIRPORTS_URL'])">
                                                    <autocomplete 
                                                        @clickSearchItem="clickSearchItem" 
                                                        :item="searchForms" 
                                                        :row="i" 
                                                        :col="idx"
                                                        :target="head.type" />
                                                </label>
                                                <label class="dynamicInfo">
                                                    <input name="departure-1"
                                                            v-if="head.type == 'destination'"
                                                           type="datetime-local"
                                                           :min="leg.departure_local"
                                                           v-model="leg.arrival_local"
                                                           class="form-control dateDeparture main-search">
                                                     <input name="departure-1"
                                                           type="datetime-local"
                                                           v-else
                                                           v-model="leg.departure_local"
                                                           v-on="idx > 0 ? {
                                                                input: (e) => {
                                                                    onDepartureChange(e, flightInfo.legs, idx);
                                                                }
                                                           } : {}"
                                                           :min="idx > 0 ? flightInfo.legs[idx-1].arrival_local : ''"
                                                           class="form-control dateDeparture">
                                                </label>
                                            </template>
                                            <template #forEdit v-else-if="head.type == 'icon'">
                                                <div style="display: flex;justify-content: center;align-items: center">
                                                    <i class="bi bi-trash d-block trashIcon mx-3 trashSegment glyphicon glyphicon-trash" 
                                                        @click="deleteSegment(i, idx)"> &#127;</i>
                                                </div>
                                            </template>
                                            <template #forEdit v-else-if="head.type == 'service_class'">
                                                <label>
                                                    <select name="" v-model="leg.service_class" style="padding: 5px 20px">
                                                        <option value="ECNM">ECNM</option>
                                                        <option value="BSNS">BSNS</option>
                                                    </select>
                                                </label>
                                            </template>
                                            <template #forEdit v-else-if="head.type == 'fare_basis'">
                                                <label>
                                                    <input type="text" 
                                                        class="form-control" 
                                                        v-model="leg.fare_basis" 
                                                        @keyup="onTarifMask" 
                                                        @change="e => onValuesChange(e.target.value, i, idx,'fare_basis')" />
                                                </label>
                                            </template>
                                            <template #forEdit v-else-if="head.type == 'flight_number'">
                                                <label>
                                                    <input type="text" 
                                                        class="form-control" 
                                                        v-model="leg.flight_number" 
                                                        @keyup="e => onTarifMask(e, 7)" 
                                                        @change="e => onValuesChange(e.target.value, i, idx,'flight_number')" />
                                                </label>
                                            </template>
                                            <template #forEdit 
                                                v-else-if="head.type == 'airplane_name'">
                                                <label style="position:relative;">
                                                    <input type="text"
                                                            class="form-control" 
                                                            @input="e => debounce(search, 200)(e, i, idx, head.type, URLS['SEARCH_AIRPLANES_URL'])"
                                                            v-model="leg.airplane_name" />
                                                    <autocomplete 
                                                            @clickSearchItem="chooseAirplane" 
                                                            :item="searchForms" 
                                                            :row="i" 
                                                            :col="idx"
                                                            :target="head.type" />
                                                </label>
                                            </template>
                                            <template #forEdit 
                                                v-else-if="head.type == 'airline'">
                                                <label style="position:relative;">
                                                    <input type="text"
                                                            class="form-control" 
                                                            @input="e => debouncer(e, i, idx, head.type, URLS['SEARCH_AIRLINES_URL'])"
                                                            v-model="leg.airline.name">
                                                    <autocomplete 
                                                            @clickSearchItem="chooseAirline" 
                                                            :item="searchForms" 
                                                            :row="i" 
                                                            :col="idx"
                                                            :target="head.type" />
                                                </label>
                                            </template>
                                            <template #forEdit 
                                                v-else-if="head.type == 'baggage_raw'">
                                                <label>
                                                    <span>Количество</span>
                                                    <input 
                                                        type="number" 
                                                        class="form-control" 
                                                        @keyup="e => onLengthChangeMask(e, i , idx, 2, 'baggage_raw', 'count')"
                                                        @click="e => onLengthChangeMask(e, i , idx, 2, 'baggage_raw', 'count')" 
                                                        v-model="leg.baggage_raw.count" 
                                                        maxlength="10"
                                                        min="0" 
                                                        max="10">
                                                </label>
                                                <label>
                                                    <span>Вес</span>
                                                    <input 
                                                        type="number" 
                                                        class="form-control" 
                                                        @keyup="e => onLengthChangeMask(e, i, idx, 2, 'baggage_raw', 'weight')" 
                                                        v-model="leg.baggage_raw.weight" 
                                                        @click="e => onLengthChangeMask(e, i , idx, 2, 'baggage_raw', 'count')" 
                                                        min="0" 
                                                        max="100">
                                                </label>
                                                <label>
                                                    <span>Ед.изм.</span>
                                                    <select name="" v-model="leg.baggage_raw.unit" style="padding: 5px 20px">
                                                        <option value="kg">kg</option>
                                                        <option value="pc">pc</option>
                                                    </select>
                                                </label>
                                            </template>
                                        </columnComponent>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                        <button class="btn btn-secondary addSegment" @click="addSegment(i)" style="margin-bottom: 20px;border: 1px solid black">
                            <i class="bi bi-plus"></i>Добавить сегмент
                        </button>   
                    </div>
                    <button class="btn btn-secondary addSegment" @click="addFlight" style="margin-bottom: 20px;border: 1px solid black">
                        <i class="bi bi-plus"></i>Добавить перелет
                    </button>  
                    <!-- change booking reference id -->
                    <div style="margin-bottom: 15px;display: flex">
                        <label @click="getFlightInfo.new_booking_reference_id.length > 0 ? showAlert('reference_id'): null">
                            <h3>Новый номер брони</h3>
                            <input :disabled="!disabled.reference_id && getFlightInfo.new_booking_reference_id.length > 0" 
                                type="text" 
                                @change="onNumberBookingChange"
                                :style="!disabled.reference_id ? 'cursor:pointer;' : ''"
                                
                                class="form-control"
                                 v-model="getFlightInfo.new_booking_reference_id">
                            <span class="err" style="color: red" v-if="extraErrors.reference_id">{{ extraErrors.reference_id }}</span>
                        </label>
                        <label style="margin-left: 20px">
                            <h3>Код авиакомпании</h3>
                            <div>
                                <div v-for="(item, i) in Object.keys(getFlightInfo.itinerary.supplier_code)" :key="i" style="display: flex; align-items: center">
                                    <span>{{ item }}: </span>
                                    <input
                                        type="text" 
                                        class="form-control"
                                        @change="e => onFlightCodeChange(e, item)"
                                        v-model="getFlightInfo.itinerary.supplier_code[item]">
                                    <span class="err" style="color: red" v-if="extraErrors.reference_id">{{ extraErrors.reference_id }}</span>
                                </div>
                            </div>
                        </label>
                        <label style="margin-left: 20px; border-left: 1px solid lightgrey;padding-left: 20px" v-if="getFlightInfo.branded_fare && Object.keys(getFlightInfo.branded_fare).length > 0">
                            <h3>Брендированный тариф</h3>
                            <table class="table table-bordered">
                                <thead>
                                    <tr>
                                        <th v-for="(info, i) in branded_fare.table" :key="i">
                                            {{ info }}
                                        </th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td>
                                            <label>
                                                <select name="" style="padding: 5px 20px;" @change="e => onBrandedFareChange(e, 'carryon_text')">
                                                    <option v-for="(value, i) in (
                                                                branded_fare.info['carryon_text'].includes(brandedFare['carryon_text']) ? 
                                                                        branded_fare.info['carryon_text'] : 
                                                                        [...branded_fare.info['carryon_text'], brandedFare['carryon_text'] ])" 
                                                            :value="value"
                                                            :selected="value == getFlightInfo.branded_fare['carryon_text']">
                                                        {{ value }}
                                                    </option>
                                                </select>
                                            </label>
                                        </td>
                                        <td>
                                            <label>
                                                <select name="" style="padding: 5px 20px;" @change="e => onBrandedFareChange(e, 'change_text', 'change_payment_type')">
                                                    <option v-for="(value, i) in (
                                                                branded_fare.info['change_text'].includes(brandedFare['change_text']) ? 
                                                                        branded_fare.info['change_text'] : 
                                                                        [...branded_fare.info['change_text'], brandedFare['change_text'] ])" 
                                                            :value="value"
                                                            :selected="value == getFlightInfo.branded_fare['change_text']">
                                                        {{ value }}
                                                    </option>
                                                </select>
                                            </label>
                                        </td>
                                        <td>
                                            <label>
                                                <select name="" style="padding: 5px 20px;" @change="e => onBrandedFareChange(e, 'refund_text', 'refund_payment_type')">
                                                    <option v-for="(value, i) in (
                                                                branded_fare.info['refund_text'].includes(brandedFare['refund_text']) ? 
                                                                        branded_fare.info['refund_text'] : 
                                                                        [...branded_fare.info['refund_text'], brandedFare['refund_text'] ])" 
                                                            :value="value"
                                                            :selected="value == getFlightInfo.branded_fare['refund_text']">
                                                        {{ value }}
                                                    </option>
                                                </select>
                                            </label>
                                        </td>
                                    </tr>
                                </tbody>
                            </table>
                        </label>
                    </div>
                    <!-- passengers table -->
                    <div id="flightPassengersExample">
                        <h3 class="mt-4 tooltips-root">Пассажиры
                            <hint 
                                message="Для редактирования пассажира нажмите на поле" 
                                :refs="['passengers', 'passengerTd']"/>
                        </h3>
                        <passengers 
                            :passengerHead="table.passengerHead" 
                            :disabled="disabled"
                            ref="passengers"
                            :showAlert="showAlert"
                            :passengerErrors="passengerErrors"
                            :oldBooking="getFlightInfo"
                            :extraServices="extraServices"
                            :tickets="getFlightInfo.tickets" 
                            :removePassenger="removePassenger"
                            :editPassenger="editPassenger" 
                            :editOpenedPassenger="editOpenedPassenger"
                            @changeTaxWithBase="updateFieldAfterChange"
                            @openServiceModal="openServiceModal"
                             />
                        <button 
                            class="btn btn-primary addSegment" 
                            @click="addPassenger" 
                            style="margin-bottom: 20px;display: none"> # временно отключим добавление пассажира
                            <i class="bi bi-plus"></i>Добавить пассажира
                        </button>  
                        <div class="d-flex justify-content-end">
                            Общая сумма:
                            <label class="mx-2 font-bold" id="totalSum">
                                {{ getCurrentSum }}
                            </label>
                        </div>
                        <div class="d-flex justify-content-end">
                            Общая сумма в {{ getFlightInfo.gds_currency_alpha_code }}:
                            <label class="mx-2 font-bold" id="totalSum">
                                {{ +(getCurrentSum / getFlightInfo.currency).toFixed(0) }}
                            </label>
                        </div>
                        <div>
                            <h4  class="mx-2 font-bold">Оплачено клиентом: 
                            {{ getFlightInfo.paid_by_client }}</h4>
                        </div>
                    </div>
                </div>
                <oldNewInfo 
                    :show="showAllInfo" 
                    :oldBooking="oldBooking" 
                    :externalHintText="externalHintText"
                    :isAllFilled="isAllFilled"
                    :extraServices="extraServices"
                    :newBooking="mergedBookings"/>
                <div v-if="error" style="color: red;font-size: 16px">
                    <span>{{ typeof error === 'object' ? error.text : 'Заполните все поля' }}</span>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn-secondary btn" v-if="!pdf" @click="downloadAgain">Сбросить</button>
                <button type="button" 
                        class="btn btn-primary" 
                        data-dismiss="modal" 
                        @click="previousPage" 
                        ref="modalFooterBtnRef"
                        :disabled="isDisabled">
                    {{ showAllInfo ? 'Редактировать' : 'Закрыть' }}
                </button>
                <button 
                    type="button" 
                    class="btn btn-danger" 
                    @click="nextPage" 
                    :disabled="isDisabled">
                    {{ showAllInfo ? 'Сохранить' : 'Продолжить' }}
                </button>
            </div>
        </div>
    `,
    created() {
        // custom fetch method
        this.abortController = new AbortController();
        this.customFetch = (url) => fetch(url, {signal: this.abortController.signal}).then(res => res.json());
        // start wrapped to function to use in future (remove, add events)
        this.functionInstance = function() {
            if (IS_NEW_EXCHANGE_ENABLED) {
                this.start();
            }
        }
        // adding click event for modal form
        document.querySelector('#exchange_request_complete_button')
            .addEventListener('click', this.functionInstance.bind(this));
        // create debouncer for searches
        this.debouncer = this.debounce(this.search, 300);
        // add click document event to close dropdowns
        $(document).click(function (event) {
            const target = $(event.target);
            if (!target.hasClass('main-search')) {
                this.searchForms = {}
            }
        }.bind(this));
    },
    beforeDestroy() {
        document.querySelector('#exchange_request_complete_button')
            .removeEventListener('click', this.functionInstance);
    },
    computed: {
        getCurrentSum:{
            get() {
                if (!this.getFlightInfo) return;
                return this.getFlightInfo.tickets.reduce(
                    (prev, current) =>
                        (+current.tax + +current.base_fare) + prev,
                    0);
            }
        }
    },
    watch: {
        getCurrentSum(value) {
            this.getFlightInfo.price = value;
        }
    },
    methods: {
        updateFieldAfterChange(field) {
            this.getFlightInfo[field === 'tax' ? 'tax' : field] = this.getFlightInfo.tickets.reduce((prev, cur) => {
                return prev + +cur[field]
            }, 0);
        },
        openServiceModal(fields) {
            this.extraServices.fields = fields;
            this.extraServices.open = true;
        },
        onBrandedFareChange(e, target, field) {
            this.getFlightInfo.branded_fare[target] = e.target.value;
            if (field) {
                this.getFlightInfo.branded_fare[field] = this.branded_fare.types[this.branded_fare.info[target].findIndex(res => res === e.target.value)];
            }
        },
        addService(field, item) {
            const currentTicket = this.getFlightInfo.tickets[field.fields.id];
            const currentService = currentTicket.special_services.find(res => res.type === field.fields.type);
            currentService.options.push(item);
        },
        addPassenger() {
            const keys = Object.keys(this.defaultPassengerType);
            const new_ticket = {};
            for (const key of keys) {
                new_ticket[key] = true;
            }
            this.getFlightInfo.tickets.push({...this.defaultPassengerType})
            this.editOpenedPassenger.push(new_ticket);
        },
        onNumberBookingChange(e) {
            this.getFlightInfo.new_booking_reference_id = e.target.value.toUpperCase();
        },
        onFlightCodeChange(e, key) {
            this.getFlightInfo.itinerary.supplier_code[key] = e.target.value.toUpperCase()
        },
        onReferenceIdChange(e) {
            this.newBooking.reference_id = e.target.value.toUpperCase();
        },
        onDepartureChange(e, legs, idx) {
            const arrival_local = legs[idx - 1].arrival_local;
            if (new Date(arrival_local) >= new Date(e.target.value)) {
                e.target.style = 'border: 1px solid red'
            }else {
                e.target.style = ''
            }
        },
        addFlight() {
            const deepClone = JSON.parse(JSON.stringify(this.defaultSegment));
            this.getFlightInfo.itinerary.flights.push({
                legs: [{...deepClone, changed: true}]
            });

            const keys = Object.keys(deepClone);
            const result = {}
            for (let k in keys) {
                result[keys[k]] = true
            }
            this.editFlightLegs.push([{...this.defaultSegmentType, isAdded: true, changed: true}]);
        },
        alertInfo(obj) {
            if (!obj.ok) {
                return;
            }
            switch (obj.extraInfo.type) {
                case 'inputChange':
                    this.disabled = {
                        ...this.disabled,
                        [obj.extraInfo.field]: true
                    }
                    break;
                case 'flightRemove':
                    const flights = this.getFlightInfo.itinerary.flights;
                    this.getFlightInfo.itinerary.flights = flights.filter((_, x) => x !== obj.extraInfo.field);
                    break;
                case 'addSegment':
                    const deepClone = JSON.parse(JSON.stringify(this.defaultSegment));
                    this.getFlightInfo.itinerary.flights[obj.extraInfo['id']].legs.push({...deepClone, changed: true});
                    this.editFlightLegs[obj.extraInfo['id']].push(this.defaultSegmentType);
                    break;
                case 'removePassenger':
                    this.getFlightInfo.tickets = this.getFlightInfo.tickets.filter((_, x) => x !== obj.extraInfo.field);
                    break
                case 'isNext':
                    this.isAgreedForSameCache = true;
                    this.getOldBooking();
                    break
            }
        },
        showAlert(field, message = 'Вы хотите изменить номер брони?', type='inputChange') {
            if (this.disabled[field]) return false;
            this.alertProp = {
                isOpened: true,
                title: message,
                extraInfo: {
                    type: type,
                    field: field
                }
            }
        },
        removePassenger(idx) {
            this.alertProp = {
                isOpened: true,
                title: 'Вы уверены что хотите удалить сегмент?',
                extraInfo: {
                    type: 'removePassenger',
                    field: idx
                }
            }
        },
        removeFlight(i) {
            this.alertProp = {
                isOpened: true,
                title: 'Вы уверены что хотите удалить сегмент?',
                extraInfo: {
                    type: 'flightRemove',
                    field: i
                }
            }
        },
        downloadAgain() {
            this.pdf = false;
            this.booking_reference = false;
            this.showAllInfo = false;
            this.error = false;
            this.start();
        },
        start() {
            this.loading = true;
            this.customFetch(EXCHANGE_INFO_URL).then(res => {
                this.isAllFilled = res.filled;
                if (res.filled) {
                    this.assignFlightInfo(res);
                    this.loading = false;
                    this.pdf = false;
                    this.nextPage(true);
                    this.booking_reference = false;
                    return;
                }
                if (res.required) {
                    if (res.required.includes('pdf_file')){
                        this.pdf = true;
                    }else if (res.required.includes('booking_reference_id')) {
                        this.pdf = false;
                        this.booking_reference = true;
                    }
                    this.showAllInfo = false;
                }
                else {
                    this.showAllInfo = false;
                    this.pdf = false;
                    this.assignFlightInfo(res);
                }
                this.externalHintText = res.hint;
                this.loading = false;
            });
            this.customFetch(EXTRA_SERVICES).then(res => {
                this.extraServices.items = res;
            })
        },
        downloadPdf(e) {
            this.isDisabled = true;
            const form = new FormData();
            form.append('pdf_file', e.target.files[0]);
            form.append('booking_reference_id', ID);
            fetch(EXTERNAL_EXCHANGE_INFO_URL, {
                method: 'POST',
                body: form
            }).then(res => res.json())
                .then(flightInfo => {
                flightInfo.itinerary.flights = flightInfo.itinerary.flights.map(response => {
                    return {
                        ...response,
                        legs: response.legs.map(leg => {
                            return {...leg, fare_class: leg.fare_basis ? leg.fare_basis[0] : ''}
                        })
                    }
                });
                this.isAllFilled = flightInfo.filled;
                this.assignFlightInfo(flightInfo);
                this.nextPage(flightInfo.filled);
                this.pdf = false;
                this.isDisabled = false;
                this.externalHintText = flightInfo.hint;
            }).catch(err => {
                this.error = err.response;
                this.isDisabled = false;
            });
        },
        checkFlightDates() {
            const flights = this.getFlightInfo.itinerary.flights;
            // change invalid departure local
            flights.forEach((flight, i) => {
                flight.legs.forEach((leg, idx) => {
                    const departure = leg.departure_local.split("T")[1];
                    const arrival = leg.arrival_local.split("T")[1];
                    if (departure.split(":").length === 2) {
                        this.getFlightInfo.itinerary.flights[i].legs[idx].departure_local = leg.departure_local + ":00";
                    }
                    if (arrival.split(":").length === 2) {
                        this.getFlightInfo.itinerary.flights[i].legs[idx].arrival_local = leg.arrival_local + ":00";
                    }
                })
            });
            this.getFlightInfo.tickets = this.getFlightInfo.tickets.map(res => {
                res.gds_base_fare = +(+res.gds_base_fare).toFixed(0);
                res.base_fare = +res.base_fare;
                res.gds_tax = +(+res.gds_tax).toFixed(0);
                res.tax = +res.tax;
                return res;
            })
            this.getFlightInfo.gds_base_fare = +(+this.getFlightInfo.tickets.reduce((prev, current) => prev + current.gds_base_fare, 0)).toFixed(0);
            this.getFlightInfo.gds_tax = +(+this.getFlightInfo.tickets.reduce((prev, current) => prev + current.gds_tax, 0)).toFixed(0);
            this.getFlightInfo.gds_price = this.getFlightInfo.gds_tax + this.getFlightInfo.gds_base_fare;
            this.getFlightInfo.tax = +(+this.getFlightInfo.tax).toFixed(0);
            this.getFlightInfo.base_fare = +(+this.getFlightInfo.base_fare).toFixed(0);
        },
        onLengthChangeMask(e, i, idx, targetLength ,...types) {
            // disable '-' sign in baggage (key code == '-')
            if (e.keyCode === 189) {
                let copyLeg = this.getFlightInfo.itinerary.flights[i].legs[idx];
                if (types.length === 2) {
                    copyLeg[types[0]][types[1]] = 0;
                }
                else if (types.length === 1) {
                    copyLeg[types[0]] = 0;
                }
                this.getFlightInfo.itinerary.flights[i].legs[idx] = {...copyLeg}
                return;
            }
            // trigger border red color for invalid legs
            let copyLeg = this.getFlightInfo.itinerary.flights[i].legs[idx];
            if (e.target.value.length > targetLength || e.target.value === '') {
                e.target.style = 'border-color: red'
            }
            else {
                e.target.style = 'border-color: #e5e6e7'
            }
            // reactive flight legs to trigger html
            this.getFlightInfo.itinerary.flights[i].legs[idx] = {...copyLeg};
        },
        onTarifMask(e, len = 15) {
            let val = e.target.value;
            let exist = false;
            for (let x = 0;x < val.length;x++) {
                if (val.charCodeAt(x) >= 1000) {
                    exist = true;
                    break;
                }
            }
            if (exist || e.target.value.length > len) {
                e.target.style = 'border-color: red'
            }
            else {
                e.target.style = '';
            }
        },
        save() {
            this.isDisabled = true;
            this.checkFlightDates();
            this.showAllInfo = true;
            fetch(EXCHANGE_INFO_URL, {
                method: 'PUT',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(this.getFlightInfo)
            })
            .then(res => {
                if (res.status === 404 || res.status === 200)
                    window.location.reload();
                this.error = {
                    text: res.statusText
                }
                this.isDisabled = false;
                return Promise.reject(res.json())
            }).catch(error => {
                error.then(er => {
                    const getErrorText = (er) => {
                        const keys = Object.keys(er);
                        for (const key of keys) {
                            if(Array.isArray(er[key])) {
                                if (typeof er[key][0] === 'object') {
                                    getErrorText(er[key][0]);
                                    return;
                                }
                                this.error = {
                                    text: key + ' ' + er[key][0]
                                }
                                return;
                            }
                            else if (typeof er[key] == 'string') {
                                this.error = {
                                    text: key + ' ' + er[key]
                                }
                                return;
                            }
                            else if(typeof er[key] === 'object'){
                                getErrorText(er[key]);
                                return;
                            }
                        }
                    }
                    this.error = {
                        text: er.message
                    }
                    getErrorText(er);
                })
            })
        },
        editCurrentTr(flight, leg, target, e) {
            if (e.target.type ||
                e.target.classList.contains('autocomplete_item') ||
                target === 'icon') return;
            const copyAr = [...this.editFlightLegs];
            copyAr[flight][leg] = { ...copyAr[flight][leg],[target]: !copyAr[flight][leg][target] };
            this.editFlightLegs = [...copyAr];
        },
        addSegment(idx) {
            // alert message when click add new segment to flight
            const isChangedFlight = this.getFlightInfo.itinerary.flights[idx].legs.find(leg => leg.changed);
            if (!isChangedFlight && !this.disabled[idx + 'isSegment']) {
                this.alertProp = {
                    isOpened: true,
                    title: 'Вы хотите поменять сегмент который клиент не запрашивал на обмен?',
                    extraInfo: {
                        type: 'addSegment',
                        field: idx + 'isSegment',
                        id: idx
                    }
                }
                return;
            }

            const deepClone = JSON.parse(JSON.stringify(this.defaultSegment));
            this.getFlightInfo.itinerary.flights[idx].legs.push({...deepClone, changed: true});
            this.editFlightLegs[idx].push(this.defaultSegmentType);
        },
        nextPage(filled = false) {
            // when click nextPage is showAllInfo
            if (this.showAllInfo) {
                this.save();
                return;
            }
            // when it is after booking_reference filled
            if (this.booking_reference) {
                this.externalExchange();
                return;
            }
            // validate before getOldBooking
            if (this.validate() && filled) {
                if (this.getFlightInfo.emd_hint && this.getFlightInfo.emd_hint.length > 0) {
                    if (this.showAlert('emd_hint', this.getFlightInfo.emd_hint) === undefined) {
                        return;
                    }
                }
                if (this.validatePaidCash()) {
                    this.getOldBooking();
                    this.error = false;
                }
            }
            this.error = !this.error ? !this.validate() : this.error;
        },
        getOldBooking() {
            this.customFetch(OLD_BOOKING_INFO_URL).then(old => {
                this.oldBooking = old;
                // by default assign merged booking to old
                this.mergedBookings = JSON.parse(JSON.stringify(this.getFlightInfo));
                // sign old tickets to new booking to show differences
                this.getFlightInfo.tickets.forEach((ticket, i) => {
                    this.mergedBookings.tickets[i] = {
                        ...ticket,
                        price: +ticket.tax + +ticket.base_fare,
                        changed: true
                    }
                });
                // remove dismiss attribute for modal button
                this.$refs.modalFooterBtnRef.setAttribute('data-dismiss', 'none'); // disable close modal in page changes
                // show all info
                this.showAllInfo = !this.showAllInfo;

                this.passengerErrors = this.passengerErrors.map(() => {});
                // this.mergedBookings.new_booking_reference_id = this.getFlightInfo.new_booking_reference_id
            });
        },
        assignFlightInfo(flightInfo) {
            // assign editFlightLegs to detect open edit field in html
            this.editFlightLegs = flightInfo.itinerary.flights.map((res) => res.legs.map(leg => {
                const keys = Object.keys(leg);
                const result = {}
                for (let k in keys) {
                    result[keys[k]] = leg[keys[k]] == null
                }
                return result;
            }));
            // assign edit opened passenger to detect open edit field in html
            this.editOpenedPassenger = flightInfo.tickets.map((passenger) => {
                const result = {}
                this.passengerErrors.push({});
                const keys = Object.keys(passenger);
                for (let x = 0;x < keys.length;x++) {
                    result[keys[x]] = passenger[keys[x]] == null || passenger[keys[x]] === ''
                }
                return result;
            });
            // assign current flightinfo to getFlightInfo
            this.getFlightInfo = flightInfo;
            // assign number to new_number property
            this.getFlightInfo.tickets = flightInfo.tickets.map(ticket => {
                ticket.gds_tax = (+ticket.tax / +this.getFlightInfo.currency).toFixed(0);
                ticket.gds_base_fare = (+ticket.base_fare / +this.getFlightInfo.currency).toFixed(0);
                if (!ticket.new_number) {
                    return {
                        ...ticket
                    }
                }
                return ticket;
            });
            this.booking_reference = false;
            if (this.getFlightInfo.new_booking_reference_id.length === 0) this.disabled['reference_id'] = true;

            this.brandedFare = JSON.parse(JSON.stringify(this.getFlightInfo.branded_fare));
            if (flightInfo.itinerary.flights.length === 0) {
                this.addFlight();
            }
        },
        externalExchange() {
            const form = new FormData();
            form.append('booking_reference_id', this.newBooking.reference_id);
            fetch(EXTERNAL_EXCHANGE_INFO_URL, {
                method: 'POST',
                body: form
            }).then(res => res.json()).then(flightInfo => {
                this.getFlightInfo = flightInfo;
                this.externalHintText = flightInfo.hint;
                flightInfo.itinerary.flights = flightInfo.itinerary.flights.map(response => {
                    return {
                        ...response,
                        legs: response.legs.map(leg => {
                            return {...leg, fare_class: leg.fare_basis ? leg.fare_basis[0] : ''}
                        })
                    }
                });
                this.assignFlightInfo(flightInfo);
                this.pdf = false;
                this.isAllFilled = flightInfo.filled;
                if (!flightInfo.filled) {
                    this.showAllInfo = false;
                }
                else if(flightInfo.filled) {
                    this.nextPage(true);
                }
                this.booking_reference = false;
            });
        },
        validatePaidCash() {
            if (this.getFlightInfo.base_fare + this.getFlightInfo.tax !== this.getFlightInfo.paid_by_client &&
                this.isAgreedForSameCache) {
                this.alertProp = {
                    isOpened: true,
                    title: `Сумма за все билеты: ${this.getFlightInfo.base_fare + this.getFlightInfo.tax} тг не совпадает с суммой оплаченной клиентом: ${this.getFlightInfo.paid_by_client} тг. Вы уверены что хотите продолжить?`,
                    btnOkText: 'Продолжить',
                    extraInfo: {
                        type: 'isNext'
                    }
                }
                return false;
            }
            return true;
        },
        validate() {
            const passengers = this.getFlightInfo.tickets;
            const flights = this.getFlightInfo.itinerary.flights;
            const supplier_codes = Object.keys(this.getFlightInfo.itinerary.supplier_code);
            let isError = false;
            let isSameNumber = false;
            let fieldError = false;
            let previous = null;
            for (let x = 0;x < flights.length;x++) {
                if (flights[x].legs) {
                    const legs = flights[x].legs;
                    this.flightErrors[x] = {};
                    for (let leg = 0;leg < legs.length;leg++) {
                        const current = legs[leg];
                        this.flightErrors[x][leg] = {};
                        const isCheckedError = this.checkFilledFields(this.requiredFlightFields, current, x, leg);
                        if (!isError) {
                            isError = isCheckedError;
                        }
                    }
                }
            }
            for (let passenger = 0;passenger < passengers.length;passenger++) {
                const copy = [...this.passengerErrors];
                copy[passenger] = {};
                this.passengerErrors = copy;
                if (passengers[passenger].new_number === previous && previous != null) {
                    isSameNumber = true;
                    break;
                }
                for (let x = 0;x < this.requiredPassengerFields.length;x++) {
                    const field = passengers[passenger][this.requiredPassengerFields[x]];
                    if (field === '' || field === null) {
                        this.passengerErrors[passenger] = {
                            [this.requiredPassengerFields[x]]: true
                        }
                        // trigger error with copying and creating new link for passenger array object
                        this.passengerErrors = [...this.passengerErrors];
                        // copy it to further triggering error
                        const passengers = [...this.editOpenedPassenger];
                        passengers[passenger] = {
                            ...passengers[passenger],
                            [this.requiredPassengerFields[x]]: !passengers[passenger][field]
                        }
                        // assign it to itself
                        this.editOpenedPassenger = passengers;
                        // set error true
                        isError = true;
                    }
                }
                previous = passengers[passenger].new_number;
            }
            // func
            const triggerError = (text) => {
                this.error = {
                    text: text
                }
                fieldError = true;
            }
            // check flight number
            if (this.getFlightInfo.new_booking_reference_id.length > 10 || this.getFlightInfo.new_booking_reference_id.trim().length === 0) {
                triggerError('Введены неверные данные');
                this.extraErrors.reference_id = "Заполните это поле";
            }
            if (supplier_codes.length) {
                if (!/^[A-ZА-ЯёЁ0-9]*$/.test(this.getFlightInfo.itinerary.supplier_code[supplier_codes[0]])) {
                    triggerError('Введены неверные данные номера кода авиакомпании');
                }
            }
            if (!/^[A-ZА-ЯёЁ0-9]*$/.test(this.getFlightInfo.new_booking_reference_id)) {
                triggerError('Введены неверные данные номера брони');
            }
            if (isSameNumber) {
                triggerError('Новые номера билетов должны быть разными')
            }
            if (flights.length === 0) {
                triggerError('Добавьте сегмент')
            }
            if (passengers.length === 0) {
                triggerError('Добавьте пассажира')
            }

            if (!fieldError) {
                this.error = false;
                this.extraErrors = {}
            }
            return !isError && !fieldError;
        },
        checkFilledFields(requiredFields,current, x, leg){
            let isExistError = false;
            for(let field of requiredFields){
                // validation for object baggage(count) and origin, departure objects
                if(typeof field == 'object') {
                    const keys = Object.keys(field);
                    for (let y = 0;y < keys.length;y++) {
                        for (let fields of field[keys[y]]){
                            if (current[keys[y]][fields] === '' || current[keys[y]][fields] == null) {
                                this.flightErrors[x][leg][keys[y]] = true;
                                this.editFlightLegs[x][leg][keys[y]] = true;
                                isExistError = true;
                            }
                        }
                    }
                }
                else if (current[field] === '' || current[field] == null) {
                    // search field for trigger error
                    const getKey = this.table.thead.filter((value) => {
                        return value.fields.filter(targetField => {
                            return typeof targetField === 'object' ? targetField.key === field : targetField === field
                        }).length > 0
                    })[0];
                    if (field === 'airplane_name') {
                        this.flightErrors[x][leg]['airplane_id'] = true;
                    }
                    this.flightErrors[x][leg][field] = true;
                    if (getKey) this.editFlightLegs[x][leg][getKey['type']] = true;
                    this.flightErrors = JSON.parse(JSON.stringify(this.flightErrors));
                    isExistError = true;
                }
            }
            const departure = new Date(current.departure_local);
            const arrival = new Date(current.arrival_local);
            const tarrif = current.fare_basis;
            const reis = current.flight_number;
            const baggage_count = current.baggage_raw.count;
            const baggage_weight = current.baggage_raw.weight;
            const copy = JSON.parse(JSON.stringify(this.table));
            // trigger error function
            const triggerError = (field) => {
                this.editFlightLegs[x][leg][field]= true;
                this.flightErrors[x][leg][field]= true;
                isExistError = true;
            }
            // is kirilica exist in word
            const isLatin = (val) => val && val.split("").find((v,i) => val.charAt(i) > 1000);
            // checks departure greater than arrival
            arrival.setHours(arrival.getHours() + 2)
            if (departure >= arrival) {
                triggerError('departure_local');
                this.table.thead[0].fields[1].errorMessage = 'Время вылета не может быть больше времени прилета'
            }
            // checks tarrif validation
            if ((tarrif && tarrif.length > 15) || isLatin(tarrif)) {
                triggerError('fare_basis');
                // thead[4] and fields[0] means setting value for those fields (static array)
                copy.thead[4].fields[0] = {
                    ...this.table.thead[4].fields[0],
                    errorMessage: 'Введены неверные данные'
                };
                this.table = copy;
            }
            // checks reis validation
            if ((reis && reis.length > 7) || isLatin(reis)) {
                triggerError('flight_number')
                copy.thead[3].fields[0] = {
                    ...copy.thead[3].fields[0],
                    errorMessage: 'Введены неверные данные'
                };
                this.table = copy;
            }
            // checks baggage validation
            if ((baggage_count && baggage_count > 100) ||
                (baggage_weight && baggage_weight > 100)) {
                triggerError('baggage_raw')
            }
            // checks arrival should be greater than leg's departure
            if (leg > 0) {
                const prevLeg = this.getFlightInfo.itinerary.flights[x].legs[leg - 1].arrival_local;
                if (new Date(current.departure_local) <= new Date(prevLeg)) {
                    triggerError('departure_local');
                    this.table.thead[0].fields[1].errorMessage = 'Введены вылета не может быть меньше времени прилета'
                }
            }
            return isExistError;
        },
        previousPage() {
            if (this.showAllInfo) {
                this.showAllInfo = !this.showAllInfo;
            }
            else {
                this.$refs.modalFooterBtnRef.setAttribute('data-dismiss', 'modal'); // enable modal dismiss
            }
        },
        deleteSegment(idx, legIndex) {
            const currentFlight = this.getFlightInfo.itinerary.flights[idx];
            currentFlight.legs.splice(legIndex, 1);
            if (this.flightErrors[idx]) {
                delete this.flightErrors[idx][legIndex];
            }
            // this.flightErrors[idx] = [...this.flightErrors][idx].filter((_, i) => i !== legIndex);
            this.editFlightLegs[idx] = [...this.editFlightLegs][idx].filter((_, i) => i !== legIndex);
        },
        editPassenger(idx, field) {
            const passengers = [...this.editOpenedPassenger];
            passengers[idx] = {
                ...passengers[idx],
                [field]: !passengers[idx][field]
            }
            this.editOpenedPassenger = passengers;
        },
        focusOn(e){
            e.stopPropagation()
        },
        search(e, i, idx, targetKey, url) {
            const currentVal = e.target.value;
            if (currentVal === '') {
                this.searchForms = {[i]: null}
                return;
            }
            if (targetKey === 'airplane_name') {
                this.getFlightInfo.itinerary.flights[i].legs[idx].airplane_id = "";
            }
            // remove code when typing
            this.getFlightInfo.itinerary.flights[i].legs[idx][targetKey].code = "";
            this.abortController.abort(); // отменяем предыдущий запрос
            this.abortController = new AbortController(); // создаем новый аборт контроллер на каждый новый запрос
            this.customFetch(url + currentVal) // SEARCH_AIRPORTS_URL, SEARCH_AIRPLANES_URL, SEARCH_AIRLINE_URL
                .then(res => {
                    this.searchForms = {
                        [i]: {
                            [idx]: {
                                [targetKey]: res
                            }
                        }
                    }
                })
        },
        chooseAirplane(value, i ,idx, target) {
            this.getFlightInfo.itinerary.flights[i].legs[idx].airplane_name = value.name;
            this.getFlightInfo.itinerary.flights[i].legs[idx].airplane_id = value.id;
            this.searchForms = {};
        },
        chooseAirline(value, i, idx,  target) {
            this.getFlightInfo.itinerary.flights[i].legs[idx].airline.name = value.name;
            this.getFlightInfo.itinerary.flights[i].legs[idx].airline.code = value.code;
            this.getFlightInfo.itinerary.flights[i].legs[idx].airline.id = value.id;
            this.searchForms = {};
        },
        clickSearchItem(value, i, idx, target) {
            this.getFlightInfo.itinerary.flights[i].legs[idx][target] = value;
            this.searchForms = {};
        },
        debounce(func, delay = 200) {
            let timer;
            return (...args) => {
                clearTimeout(timer);
                timer = setTimeout(() => {
                    func.apply(this, args);
                }, delay);
            }
        },
        onValuesChange(val, i, idx, field) {
            this.getFlightInfo.itinerary.flights[i].legs[idx][field] = val.toUpperCase();
        }
    },
    filters: {
        formatCity: function(val) {
            if (!val.name || !val.code) return 'Пусто'
            return (val.name + `(${val.code})`);
        }
    }
}).$mount('#flightContainer');
