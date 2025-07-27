import uuid


def generate_string(size: int = 32) -> str:
    if size == 32:
        return uuid.uuid4().hex
    return uuid.uuid4().hex[:size]
