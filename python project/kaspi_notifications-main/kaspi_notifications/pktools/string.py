import uuid


def generate_string():
    return str(uuid.uuid4().hex)


def prettify_phone_number(phone_number: str):
    """
    Phone number formatting
    """
    if len(phone_number) == 10 and phone_number[0] == '7':
        phone_number = '7' + phone_number
    if phone_number[0] == '+':
        phone_number = phone_number[1:]
    if len(phone_number) == 11 and phone_number[0] == '8':
        phone_number = '7' + phone_number[1:]
    return phone_number
