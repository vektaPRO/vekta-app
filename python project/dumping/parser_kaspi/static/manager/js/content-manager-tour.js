$(document).ready(function () {
    initHotelSearch();
    HotelSearch()
    let parent_id = null;
    let parent_model = null;
    const params = new Proxy(new URLSearchParams(window.location.search), {
        get: (searchParams, prop) => searchParams.get(prop),
    });
    if (params.parent_id && params.parent_model) {
        parent_id = Number(params.parent_id);
        parent_model = params.parent_model;
    } else {
        let url = window.location.href.split('/');
        parent_id = Number(url[url.length - 3]);
    }
    if (Number.isInteger(parent_id)) {
        $('a.add-another').each(function () {
            var oldUrl = $(this).attr("href");
            var newUrl;
            if (parent_model) {
                newUrl = oldUrl + `?parent_model=${parent_model}&parent_id=${parent_id}`;
            } else {
                newUrl = oldUrl + `parent_id=${parent_id}`;
            }
            $(this).attr("href", newUrl);
        });
    }
});

function initHotelSearch() {
    var $searchForm = $('#hotel-search');
    var $dropdown = $searchForm.find('.tt-dropdown-menu');
    var $dataset = $dropdown.find('.tt-dataset-0');
    $(document).click(function (event) {
        var target = $(event.target);
        if (!target.hasClass('main-search')) {
            $dropdown.hide();
        }
    });

    $searchForm.on('submit', function (e) {
        e.preventDefault();
        var q = $(this).serializeArray().find(function (e) {
            return e.name === "q"
        }).value;
        if (q) {
            $.ajax({
                url: '?' + $(this).serialize(),
                type: 'GET',
                success: function (list) {
                    $dropdown.show();
                    $dataset.empty();
                    if (list.length > 0) {
                        $.each(list, function (index, hotel) {
                            $dataset.append(
                                '<div class="tt-suggestion tt-m-cursor"><a href="' + hotel['url'] + '">' + hotel['name'] + ' ' + hotel['type'] +
                                ': ' +  hotel['country'] + ' - ' + hotel['region'] + ' - ' + hotel['status'] + '</a></div>'
                            )
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

function HotelSearch() {
    var
        hotels = new Bloodhound({
            datumTokenizer: function(d) {
                return Bloodhound.tokenizers.whitespace(d.value);
            },
            queryTokenizer: Bloodhound.tokenizers.whitespace,
            remote: {
                url: '?q=%QUERY',
                filter: function(list) {
                    return $.map(list, function(hotel) {
                        return {
                            id: hotel['org_id'],
                            name: hotel['name'],
                            type: hotel['type'],
                            url: hotel['url'],
                            region: hotel['region'],
                            country: hotel['country'],
                            update_required: hotel['update_required']
                        };
                    });
                }
            },
        }),

        $searchInput = $('.booking_search_exchange'),
        $searchInputVal = $('.booking_id');
    hotels.initialize();
    $searchInput.typeahead({
        highlight: true,
    },
    {
        source: hotels.ttAdapter(),
        templates: {
            suggestion: Handlebars.compile('<a href="#">{{name}}: '+
                '{{type}} {{country}} - '+
                '{{region}} - {{status}}</a>'),
        }
    })
    .bind('typeahead:selected', function(e, obj){
        $searchInput.val(obj.value);
        $searchInputVal.val(obj.id);
    });
}