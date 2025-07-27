import asyncio
import contextvars
import functools


async def to_thread(func, /, *args, **kwargs):
    loop = asyncio.get_running_loop()
    ctx = contextvars.copy_context()
    func_call = functools.partial(ctx.run, func, *args, **kwargs)
    return await loop.run_in_executor(None, func_call)


def chunked_data(data: list, chunk_size: int = 200):
    for i in range(0, len(data), chunk_size):
        yield data[i:i + chunk_size]

