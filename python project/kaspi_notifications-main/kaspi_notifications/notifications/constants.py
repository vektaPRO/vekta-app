# order status
STATUS_ORDER_WAS_CONFIRMED = 'order_was_confirmed_by_client'
STATUS_WAS_CANCELLED = 'order_was_canceled_by_client'
STATUS_ORDER_WAS_AUTO_ACCEPTED_IN_KASPI = 'order_was_auto_accepted_by_bot_in_kaspi'
STATUS_ORDER_WAS_NOT_AUTO_ACCEPTED_IN_KASPI = 'order_was_not_auto_accepted_by_bot_in_kaspi'

IN_PROGRESS = 'IN_PROGRESS'
CREATED = 'CREATED'
DONE = 'DONE'
IS_ERROR = 'IS_ERROR'
IS_NULL_OR_0 = 'IS_NULL_OR_0'
STOPPED = 'FORCE_STOP'

# order notification status
STATUS_CLIENT_TO_BE_NOTIFIED = 'client_must_be_notified'
STATUS_CLIENT_ASKED_TO_LEAVE_COMMENT = 'client_was_notified_to_leave_comment_about_order'
STATUS_CLIENT_NOT_TO_BE_NOTIFIED = 'client_must_not_be_notified'  # with api status CANCELLED
STATUS_CLIENT_NEED_ANSWER = 'need_client_to_answer'
STATUS_CLIENT_WITH_DELAY = 'client_with_delay'

# message delivery statuses
CLIENT_WITHOUT_WHATSAPP = 'нет ватсапа'
ERROR_WHILE_DELIVERING_MESSAGE = 'ошибка при доставке сообщения'
MESSAGE_IS_DELIVERED = 'сообщение доставлено'
MESSAGE_IS_NOT_DELIVERED = 'сообщение не доставлено'
MESSAGE_IS_SENT = 'сообщение отправлено'
MESSAGE_IS_READ = 'сообщение прочитано'

# statuses for robokassa
INVOICE_TYPE_REGISTRATION = 'registration'
INVOICE_STATUS_PAID = 'paid'
TELEGRAM_MODE_COMPLETE_REGISTRATION = 'tg_complete_registration_mode'
TELEGRAM_MODE_CREATE_GREEN_API_INSTANCE = 'create_green_api_instance_mode'
TELEGRAM_MODE_GREEN_API_INSTANCE_CREATED = 'green_api_instance_created_mode'
GREEN_API_STATUS_STARTING = 'starting'
GREEN_API_STATUS_NOT_AUTHORIZED = 'notAuthorized'
COMMUNICATION_TYPE_GREEN_API = 'GREEN_API'
MEMBERSHIP_STATUS_DRAFT = 'draft'
MEMBERSHIP_STATUS_INITIAL_INVOICE_PAID = 'initial_invoice_paid'

# model constants
MERCHANT_HELP_TEXT_GREEN_API = (
    'Пример: <br>'
    '{hello_rus}, {client_name}!<br>'
    'Спасибо за заказ в магазине {merchant_name}<br>'
    'Вы заказали: {product_names}<br>'
    'Плановая дата доставки: {planned_delivery_date}.<br>'
    'Доставка будет осуществлена в указанную дату.<br>'
    'Номер заказа: {kaspi_order_code}<br>'
    'В ближайшее время мы соберём заказ и отправим вам.<br>'
    'Хороших покупок!<br><br><br>'
    '{hello_kaz} - Қайырлы таң, Қайырлы күн, Қайырлы кеш, Қайырлы түн (не обязательно)<br>'
    '{hello_rus} - Доброе утро, Добрый день, Добрый вечер, Доброй ночи (не обязательно)<br>'
    '{client_name} - имя покупателя (обязательно)<br>'
    '{merchant_name} - название вашего магазина (обязательно)<br>'
    '{product_names} - название купленных продуктов (обязательно)<br>'
    '{planned_delivery_date} - планируемая дата доставка (обязательно)<br>'
    '{kaspi_order_code} - код заказа каспи (обязательно)<br><br>'
    'Каждый магазин может формировать свои шаблон для отправки своих клиентах.<br>'
    'Если шаблон пустой или где то будет ошибка, используется шаблон как в примере.<br>'
)

MERCHANT_HELP_TEXT_GREEN_API_REVIEW = (
    'Пример:<br>'
    '{hello_rus}, {client_name}!<br>'
    'Поздравляем с покупкой!<br>'
    'Мы надеемся, что вам все понравилось.<br>'
    'Если вам не сложно, то оставьте отзыв здесь:<br>'
    '{products_urls}<br><br><br>'
    '{hello_kaz} - Қайырлы таң, Қайырлы күн, Қайырлы кеш, Қайырлы түн (не обязательно)<br>'
    '{hello_rus} - Доброе утро, Добрый день, Добрый вечер, Доброй ночи (не обязательно)<br>'
    '{client_name} - имя покупателя (обязательно)<br>'
    '{products_urls} - ссылка отзыва (обязательно)<br>'
    'Если шаблон пустой или где то будет ошибка, используется шаблон как в примере.<br>'
)

MERCHANT_HELP_TEXT_GREEN_API_POSTAMAT_ORDER = (
    'Пример:<br>'
    '{hello_rus}, {client_name}!<br>'
    'Ваш заказ с номером {kaspi_order_code} был успешно доставлен в Kaspi постомат.<br>'
    'Ваш товар: {product_names}<br>Не забудьте забрать его до '
    'автоматической отмены заказа.<br>Спасибо за покупку!<br><br><br>'
    '{hello_kaz} - Қайырлы таң, Қайырлы күн, Қайырлы кеш, Қайырлы түн (не обязательно)<br>'
    '{hello_rus} - Доброе утро, Добрый день, Добрый вечер, Доброй ночи (не обязательно)<br>'
    '{client_name} - имя покупателя (обязательно)<br>'
    '{kaspi_order_code} - код заказа каспи (обязательно)<br>'
    '{product_names} - название продуктов (обязательно)<br>'
    'Если шаблон пустой или где то будет ошибка, используется шаблон как в примере.<br>'
)

MERCHANT_HELP_TEXT_GREEN_API_NEGATIVE_REVIEW = (
    'Пример (этот шаблон используется по умолчанию, если указан оба языка):<br>'
    'Кешіріңіз, {client_name}!<br>'
    'Сізге ұнамағаны біз үшін өкінішті.<br>'
    'Бізге не ұнамағанын жазсаңыз, біз оны түзетуге тырысамыз.<br>'
    'Сіздің пікіріңіз біз үшін маңызды.<br>'
    '🔸🔸🔸<br>'
    'Извините, {client_name}!<br>'
    'Нам жаль, что вам не понравилось.<br>'
    'Пожалуйста, сообщите нам, что именно не так, чтобы мы могли это исправить.<br>'
    'Ваше мнение очень важно для нас.<br><br><br>'
    '<br'
    '<i>Следующие поля являются необязательными, их можно не указывать:</i><br>'
    '{kaspi_order_code} - код заказа каспи<br>'
    '{client_name} - Имя покупателя<br><br>'
    '<br>'
    'Если шаблон пустой или содержит ошибку, будет использован этот шаблон по умолчанию.<br>'
)

MERCHANT_HELP_TEXT_GREEN_API_CONFIRM_REVIEW = (
    'Пример (этот шаблон используется по умолчанию, если указан оба языка):<br>'
    '{hello_kaz}, {client_name}!<br>'
    'Сатып алуыңызбен құттықтаймыз!<br>'
    'Сізге барлығы ұнады ма?<br>'
    '1 - Иә, барлығы жақсы.<br>'
    '2 - Жоқ, маған ұнамады.<br>'
    'Өтініш, тек 1 немесе 2 санын жіберіңіз.<br>'
    '🔸🔸🔸<br>'
    '{hello_rus}, {client_name}!<br>'
    'Поздравляем с покупкой!<br>'
    'Всё ли вам понравилось?<br>'
    '1 - Да, всё хорошо.<br>'
    '2 - Нет, мне не понравилось.<br>'
    'Пожалуйста, отправьте только цифру (1 или 2).<br>'
    '<br><br>'
    '{hello_kaz} - Қайырлы таң, Қайырлы күн, Қайырлы кеш, Қайырлы түн (необязательно)<br>'
    '{hello_rus} - Доброе утро, Добрый день, Добрый вечер, Доброй ночи (необязательно)<br>'
    '{client_name} - Имя покупателя (необязательно)<br>'
    '{kaspi_order_code} - код заказа каспи (необязательно)<br>'
    '{only_products_name} - название купленных продуктов (необязательно)<br>'
    '<br>'
    'Если шаблон пустой или содержит ошибку, будет использован этот шаблон по умолчанию.<br>'
)


KASPI_ORDER_CANCELLED = 'CANCELLED'
KASPI_ORDER_COMPLETED = 'COMPLETED'
