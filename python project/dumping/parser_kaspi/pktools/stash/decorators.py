from pktools.stash.base import wrap
from pktools.stash import utils


__all__ = ('cached_func', 'cached_method', 'cached_property')


def cached_func(timeout, key_prefix=None, key=None, exclude_kwarg_keys=None,
                local_cache=None, cache_alias=utils.get_cache_alias):
    """
    A decorator for caching results of an arbitrary function
    """

    def wrapper(func):
        return wrap(func, timeout, key_prefix, key, exclude_kwarg_keys or [], local_cache, cache_alias)

    return wrapper


def cached_method(timeout, key_prefix=utils.get_method_key_prefix,
                  key=None, exclude_args=['self'],
                  local_cache=utils.get_method_local_cache, cache_alias=utils.get_cache_alias):
    """
    A decorator for caching class methods.
    """
    def wrapper(method):
        return wrap(method, timeout, key_prefix, key, exclude_args,
                    local_cache, cache_alias)
    return wrapper


class cached_property(object):
    def __init__(self, *args, **kwargs):
        self.wrapper = cached_method(*args, **kwargs)

    def __call__(self, func):
        wrapper = self.wrapper(func)

        def fdel(self):
            wrapper.flush(self)

        return property(wrapper, fdel=fdel)
