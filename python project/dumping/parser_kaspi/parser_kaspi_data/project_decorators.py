import asyncio

from parser_kaspi_data.service import project_logger
from parser_kaspi_data.service.project_exceptions import RetryableHttpClientException

logger = project_logger.get_logger(__name__)

REQUESTS_RETRY_TIMEOUT_SECONDS = 2


def http_retry_decorator(retries):
    def decorator(func_to_decorate):
        async def wrapper(*args, **kwargs):
            for _ in range(retries):
                try:
                    return await func_to_decorate(*args, **kwargs)
                except RetryableHttpClientException:
                    if _ == retries - 1:
                        logger.info(f'Num retries exceeded for {func_to_decorate.__name__} for func args: {args, kwargs}')
                        raise
                    else:
                        logger.error(
                            f'Retryable error during {func_to_decorate.__name__}. Retrying after timeout for func args: {args, kwargs}')
                        await asyncio.sleep(REQUESTS_RETRY_TIMEOUT_SECONDS)

                except BaseException as e:
                    logger.error(f'Unretryable error occurred during {func_to_decorate.__name__} request for func args: {args, kwargs}')
                    logger.error(project_logger.format_exception(e))
                    raise e
            return None
        return wrapper
    return decorator
