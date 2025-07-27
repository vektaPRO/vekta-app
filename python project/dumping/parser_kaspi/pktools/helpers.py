import time
import logging
import inspect
from typing import List, Any, Generator
from timeit import default_timer as timer
from functools import wraps
from django.conf import settings
from pktools.models import TaskLocker


logger = logging.getLogger(settings.METRICS_LOGGER_NAME)


def lock_and_log(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        full_task_name = func.__module__ + '.' + func.__name__
        try:
            if TaskLocker.lock(full_task_name) == 0:
                return
        except Exception as err:
            logger.error('lock_and_log: LOCKING %s ERROR: %s', full_task_name, err)
            return

        try:
            func(*args, **kwargs)
        except (Exception, BaseException) as err:
            logger.error('#%s error %s', full_task_name, err)
        finally:
            try:
                # Ждем 5 секунд, так как без этого быстрые таски (меньше секунды) запускаются несколько раз
                time.sleep(5)
                TaskLocker.unlock(full_task_name)
            except Exception as err:
                logger.error('lock_and_log: UNLOCKING %s ERROR: %s', full_task_name, err)
    return wrapper


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

        logger.info(
            '#time_it_and_log',
            extra={
                'status': 'STARTED',
                'metric': 'time_it',
                'func_name': full_func_name,
                'func_args': args,
                'func_kwargs': kwargs,
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
            'func_args': args,
            'func_kwargs': kwargs,
        }

        logger.info('#time_it_and_log', extra=data)
        return func_res
    return wrapper


def model_field_exists(cls, field):
    try:
        cls._meta.get_field(field)
        return True
    except Exception:
        return False


def chunked_data(data: List[Any], chunk_size: int = 200) -> Generator[List[Any], None, None]:
    for i in range(0, len(data), chunk_size):
        yield data[i:i + chunk_size]
