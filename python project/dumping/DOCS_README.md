## Create new shop via phone_number

# Create new shop by phone number - send security code
</merchants/get-login-security-code/>

**Method: POST**

Request Body
```
{
    "phone_number": "77073395292"
}
```
Response

**20O OK**


# Create new shop by phone number - verify security code
</merchants/verify-login-security-code/>

**Method: POST**

Request Body
```
{
    "phone_number": "77073395292",
    "security_code": "0737"
}
```
Response

**20O OK**

```
{
    "merchant_name": "Sanira"
}
```
