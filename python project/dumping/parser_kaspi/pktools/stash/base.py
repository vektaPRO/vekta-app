import asyncio
import logging
import functools
from django.conf import settings
from django.core.cache import caches
from pktools.stash import utils
from pktools.stash.constants import NO_CACHE, CACHE_MISS


logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME)


def wrap(func, timeout, key_prefix, key, exclude_kwarg_keys, local_cache, cache_alias):
    """
    Core for cached function decorator
    """
    get_key_prefix = utils.make_callable(key_prefix)
    get_cache_alias = utils.make_callable(cache_alias)

    get_key = utils.make_callable(key)
    get_local_cache = utils.make_callable(local_cache)

    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        cache_key = utils.make_key(func, get_key, get_key_prefix, exclude_kwarg_keys, *args, **kwargs)
        alias = get_cache_alias(*args, **kwargs)

        if cache_key is NO_CACHE:
            return func(*args, **kwargs)
        else:
            local_cache = get_local_cache(*args, **kwargs)
            local_cache_available = isinstance(local_cache, dict)

            if local_cache_available and cache_key in local_cache:
                return local_cache[cache_key]
            try:
                value = caches[alias].get(cache_key, CACHE_MISS)
            except Exception as e:
                caches[alias].delete(cache_key)
                value = CACHE_MISS
                logger.exception(e)

            if value is CACHE_MISS:
                value = func(*args, **kwargs)
                if value is not NO_CACHE:
                    caches[alias].set(cache_key, value, timeout=timeout)
            else:
                pass

            if local_cache_available and value is not NO_CACHE:
                local_cache[cache_key] = value

        return value

    @functools.wraps(func)
    async def awrapper(*args, **kwargs):
        cache_key = utils.make_key(func, get_key, get_key_prefix, exclude_kwarg_keys, *args, **kwargs)
        alias = get_cache_alias(*args, **kwargs)

        if cache_key is NO_CACHE:
            return await func(*args, **kwargs)
        else:
            local_cache = get_local_cache(*args, **kwargs)
            local_cache_available = isinstance(local_cache, dict)

            if local_cache_available and cache_key in local_cache:
                return local_cache[cache_key]
            try:
                value = caches[alias].get(cache_key, CACHE_MISS)
            except Exception as e:
                caches[alias].delete(cache_key)
                value = CACHE_MISS
                logger.exception(e)
            if value is CACHE_MISS:
                value = await func(*args, **kwargs)
                if value is not NO_CACHE:
                    caches[alias].set(cache_key, value, timeout=timeout)
            else:
                pass

            if local_cache_available and value is not NO_CACHE:
                local_cache[cache_key] = value

        return value

    # Make function available via `apply` attribute of wrapper.
    wrapper.apply = func

    def flush(*args, **kwargs):
        cache_key = utils.make_key(func, get_key, get_key_prefix,
                                   exclude_kwarg_keys, *args, **kwargs)
        alias = get_cache_alias(*args, **kwargs)
        local_cache = get_local_cache(*args, **kwargs)
        local_cache_available = isinstance(local_cache, dict)
        caches[alias].delete(cache_key)

        if local_cache_available and cache_key in local_cache:
            del local_cache[cache_key]

    # Make `flush` method available for flushing result of this function
    # with specified arguments.
    wrapper.flush = flush

    if asyncio.iscoroutinefunction(func):
        awrapper.flush = flush
        return awrapper

    return wrapper
