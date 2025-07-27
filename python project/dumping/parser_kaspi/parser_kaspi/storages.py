from storages.backends.s3boto3 import S3Boto3Storage


class PublicMediaStorage(S3Boto3Storage):
    def url(self, *args, **kwargs):
        url = super().url(*args, **kwargs)
        if '?' in url:
            url = url.split('?')[0]
        return url
