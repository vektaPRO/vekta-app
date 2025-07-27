from pktools.stash import constants
from pktools.stash import decorators

FOREVER = constants.FOREVER
NO_CACHE = constants.NO_CACHE
CACHE_MISS = constants.CACHE_MISS

func = decorators.cached_func
method = decorators.cached_method
property = decorators.cached_property
