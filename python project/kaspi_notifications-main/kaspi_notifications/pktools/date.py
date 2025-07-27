from datetime import datetime, time, timedelta

from notifications.utils import convert_datetime_to_milliseconds


def get_default_date_range():
    """
        Returns a tuple with the start and end of the date range.
         The default date range starts two days before midnight of
    """
    midnight = datetime.combine(datetime.today(), time.min)
    orders_from_date = midnight - timedelta(days=2)
    orders_to_date = midnight + timedelta(days=2) - timedelta(seconds=1)
    return orders_from_date, orders_to_date


def get_date_range_in_ms(start_date=None, finish_date=None):
    """
         Converts provided dates to milliseconds; uses default range if not provided.
         default: today_begin - 2 days <= today_begin < today_begin + 2 days
    """
    if start_date is None or finish_date is None:
        start_date, finish_date = get_default_date_range()

    start_date_ms = convert_datetime_to_milliseconds(start_date)
    finish_date_ms = convert_datetime_to_milliseconds(finish_date)

    return start_date_ms, finish_date_ms
