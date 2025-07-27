import imaplib
import email
from email.header import decode_header
import re
import os

from parser_kaspi.celery import app

from parser_kaspi_data.models import Merchant
from parser_kaspi_data.service import project_logger
from parser_kaspi_data.service.kaspi.kaspi_methods_with_login import KaspiMerchantCabinetMethods
from parser_kaspi_data.service.project_exceptions import IncorrectLoginException
from dotenv import load_dotenv


load_dotenv()


logger = project_logger.get_logger(__name__)

KASPI_PASSWORD_EMAIL_SUBJECT = 'Kaspi Магазин: Доступ в кабинет партнера'
KASPI_PASSWORD_EMAIL_PASSWORD_REGEX = r"Пароль:&nbsp;(.*)<br\/>"
KASPI_LOGIN_EMAIL_LOGIN_REGEX = r"Логин:&nbsp;(.*)<br/>"


USERNAME = os.getenv('PS_EMAIL_USERNAME')
PASSWORD = os.getenv('PS_EMAIL_PASSWORD')
IMAP_SERVER = os.getenv('IMAP_SERVER')


def find_merchant_password_in_emails(kaspi_merchant_id):
    imap = imaplib.IMAP4_SSL(IMAP_SERVER)
    # authenticate
    imap.login(USERNAME, PASSWORD)
    status, messages = imap.select("INBOX")
    messages = int(messages[0])
    logger.info(f'Messages count :: {messages}')
    if status != 'OK':
        logger.info('Messages were not retrieved, reading emails is impossible')
    else:
        for i in range(messages, 0, -1):
            # fetch the email message by ID
            res, msg = imap.fetch(str(i), "(RFC822)")
            for response in msg:
                password = None
                if isinstance(response, tuple):
                    # parse a bytes email into a message object
                    msg = email.message_from_bytes(response[1])
                    # decode the email subject
                    subject, encoding = decode_header(msg["Subject"])[0]
                    if isinstance(subject, bytes) and encoding is not None:
                        # if it's a bytes, decode to str
                        subject = subject.decode(encoding)
                    subject = subject.strip()
                    if subject != KASPI_PASSWORD_EMAIL_SUBJECT:
                        continue
                    # if the email message is multipart
                    if msg.is_multipart():
                        # iterate over email parts
                        for part in msg.walk():
                            try:
                                body = part.get_payload(decode=True)
                                if body is None:
                                    continue
                                body = body.decode()
                                password_matches = re.findall(KASPI_PASSWORD_EMAIL_PASSWORD_REGEX, body)
                                if password_matches:
                                    password = password_matches[0]
                                login_matches = re.findall(KASPI_LOGIN_EMAIL_LOGIN_REGEX, body)
                                if login_matches:
                                    for login in login_matches:
                                        splitted_string = login.split('@')
                                        splitted_identificators = splitted_string[0].split('+')
                                        splitted_merchant_id = splitted_identificators[1].split('-')[0]
                                        if kaspi_merchant_id == splitted_merchant_id:
                                            logger.info(f'Found password :: merchant_id {splitted_merchant_id}, '
                                                        f'password {password}')

                                            return {'merchant_id': splitted_merchant_id, 'password': password,
                                                    'login': login}
                            except BaseException as e:
                                logger.error(f'Something went wrong while reading emails,'
                                             f' error :: {project_logger.format_exception(e)}')


def check_email_and_try_to_read_its_content(kaspi_merchant_id):
    logger.info(f'Initiating get_password_from_email task')
    email_content = find_merchant_password_in_emails(str(kaspi_merchant_id))
    if email_content is None:
        logger.info('Scheduling get_password_from_email with delay')
        app.signature('parser_kaspi.tasks.get_password_from_email').apply_async((kaspi_merchant_id,), countdown=5)
        return None

    # continue flow - add details to newly created shop
    merchant = Merchant.objects.filter(merchant_id=kaspi_merchant_id).first()
    merchant.password = email_content['password']
    merchant.enabled = True
    merchant.enable_parsing = True
    merchant.save()

    try:
        # try to log in to kaspi with new login and password
        KaspiMerchantCabinetMethods(login=merchant.login, password=merchant.password)
        logger.info(f'New shop for merchant {merchant.name} with login '
                    f'{merchant.login} was successfully created')
        return True
    except IncorrectLoginException:
        return False
