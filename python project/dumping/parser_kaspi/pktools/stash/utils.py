import inspect
import hashlib
from django.utils.encoding import force_str
from pktools.stash.constants import NO_CACHE


def make_callable(obj):
    if callable(obj):
        return obj

    return lambda *args, **kwargs: obj


def assert_key_is_valid(key, func, prefix):
    """
    Validates key or key prefix coming from key/key_prefix callbacks
    passed to decorators
    """
    is_valid = isinstance(key, str) or key is NO_CACHE
    assert is_valid, 'Resulting cache %s for %s must be a string or '\
        'NO_CACHE object (%s instance for now).' % (prefix, func,
                                                    key.__class__.__name__)


def append_postfix(key,  exclude_kwarg_keys, func, *args, **kwargs):
    """
    Finalizes cache key creation by appending postfix to key.
    Postfix is constructed from hashed func args.
    """
    callargs = inspect.getcallargs(func, *args, **kwargs)

    if callargs:
        # Since unicode and byte strings can be equal while not being
        # identical, coerce callargs dict to unicode to keep resulting
        # postfix from varying from such a thing.
        uniargs = dict((force_str(k), force_str(v)) for k, v in list(callargs.items()))

        for k in exclude_kwarg_keys or []:
            uniargs.pop(k)

        postfix = hashlib.md5(str(uniargs).encode()).hexdigest()
        return ':'.join([key, postfix])

    return key


def make_key(func, get_key, get_key_prefix, exclude_kwarg_keys, *args, **kwargs):
    key = get_key(*args, **kwargs)
    if key is not None:
        assert_key_is_valid(key, func, 'key')
        return key

    key_prefix = get_key_prefix(*args, **kwargs)
    if key_prefix is not None:
        assert_key_is_valid(key_prefix, func, 'key_prefix')
        if key_prefix is NO_CACHE:
            return key_prefix
        return append_postfix(':'.join([key_prefix, func.__name__]), exclude_kwarg_keys,
                              func, *args, **kwargs)
    key = ':'.join([func.__module__ or 'root', func.__name__])
    return append_postfix(key, exclude_kwarg_keys,
                          func, *args, **kwargs)


def get_method_key_prefix(ctx, *args, **kwargs):
    """
    Get default key for class or instance method.
    Ctx is context object, could be either class or instance
    """
    if hasattr(ctx, 'cache'):
        return ctx.cache.key

    if isinstance(ctx, type):
        return ':'.join([ctx.__module__, ctx.__name__])

    return ':'.join([ctx.__module__, ctx.__class__.__name__])


def get_method_local_cache(ctx, *args, **kwargs):
    if hasattr(ctx, '_local_stash'):
        return ctx._local_stash
    return None


def get_cache_alias(ctx, *args, **kwargs):
    if hasattr(ctx, 'cache_alias'):
        return ctx.cache_alias
    return 'default'
