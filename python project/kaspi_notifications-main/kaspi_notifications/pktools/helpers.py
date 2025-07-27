import inspect
import logging
import random
import datetime
import time
from functools import wraps
from timeit import default_timer as timer
from django.db import models
from django.conf import settings
from pktools.models import TaskLocker
from django.db import close_old_connections

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


def time_it_and_log(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        is_method = False

        try:
            is_method = inspect.getfullargspec(func).args[0] == 'self'
        except: # noqa
            pass

        if is_method:
            full_func_name = '%s.%s.%s' % (func.__module__, args[0].__class__.__name__, func.__name__)
        else:
            full_func_name = '%s.%s' % (func.__module__, func.__name__)

        args_for_log = []
        for arg in args:
            if isinstance(arg, models.Model):
                args_for_log.append(f'{arg.__class__}-{arg.id}')
            else:
                args_for_log.append(arg)

        kwargs_for_log = {}
        for k, v in kwargs.items():
            if isinstance(v, models.Model):
                kwargs_for_log[k] = f'{v.__class__}-{v.id}'
            else:
                kwargs_for_log[k] = v

        logger.info(
            '#time_it_and_log',
            extra={
                'status': 'STARTED',
                'metric': 'time_it',
                'func_name': full_func_name,
                'func_args': args_for_log,
                'func_kwargs': kwargs_for_log,
            }
        )
        start = timer()
        func_res = func(*args, **kwargs)
        end = timer()

        data = {
            'status': 'COMPLETED',
            'metric': 'time_it',
            'func_name': full_func_name,
            'duration': end - start,
            'func_args': args_for_log,
            'func_kwargs': kwargs_for_log,
        }

        logger.info('#time_it_and_log', extra=data)
        return func_res
    return wrapper


def lock_and_log(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        full_task_name = func.__module__ + '.' + func.__name__
        close_old_connections()
        try:
            if not TaskLocker.lock(full_task_name):
                return
        except BaseException as err:
            logger.error('lock_and_log: LOCKING %s ERROR: %s', full_task_name, err)
            return

        close_old_connections()
        try:
            func(*args, **kwargs)
        except BaseException as err:
            logger.error('#%s error %s', full_task_name, err)
        finally:
            try:
                time.sleep(5)
                close_old_connections()
                TaskLocker.unlock(full_task_name)
            except BaseException as err:
                logger.error('lock_and_log: UNLOCKING %s ERROR: %s', full_task_name, err)
    return wrapper


def get_current_timestamp() -> int:
    return int(datetime.datetime.now().timestamp())


def get_uniqid() -> str:
    id = get_current_timestamp()
    r = random.randint(0, 1000000)
    return f'{id}:{r}'


def try_acquire_lock(process: str, minutes: int) -> bool:
    current_time = get_current_timestamp()
    last_lock_time = 0
    lock_filename = f'{process}.lock'
    try:
        with open(lock_filename, mode='r') as f:
            r = f.read()
            if r:
                last_lock_time = int(r)
    except FileNotFoundError:
        pass

    diff = current_time - last_lock_time

    if last_lock_time == 0:
        logger.info(f'#try_acquire_lock :: No {process} lock file')
    else:
        logger.info(f'#try_acquire_lock :: Locked {process} {diff} seconds ago')

    if last_lock_time == 0:
        logger.info(f'#try_acquire_lock :: Locking {process} for the first time')
        with open(lock_filename, mode='w') as f:
            f.write(str(current_time))
    elif diff > minutes * 60:
        logger.info(f'#try_acquire_lock :: RE-Locking {process}')
        with open(lock_filename, mode='w') as f:
            f.write(str(current_time))
    else:
        logger.error(f'#try_acquire_lock :: Unable acquire {process} lock')
        return False

    return True


def model_field_exists(cls, field):
    try:
        cls._meta.get_field(field)
        return True
    except Exception:
        return False
