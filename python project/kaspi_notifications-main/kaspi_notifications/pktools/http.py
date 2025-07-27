from enum import Enum


class RequestMethod(str, Enum):
    GET = 'GET'
    POST = 'POST'


def get_url(host, path, *ids, **params):
    if path[0] == '/':
        path = path[1:]
    if host[-1] != '/':
        host += '/'
    if ids:
        path = path % ids

    url = host + path
    if params:
        url += '?'
        data = ''
        for k, v in params.items():
            data += f'{k}={v}&'
        url += data[:-1]

    return url
