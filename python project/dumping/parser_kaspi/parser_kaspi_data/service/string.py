def filter_phone_number(phone_number: str, forced_country_code='7') -> str:
    nums = list(phone_number)
    if nums[0] == '+':
        nums.pop(0)
    if nums[0] != forced_country_code:
        nums[0] = forced_country_code

    return ''.join(nums)
