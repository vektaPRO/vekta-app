from django.db import models


class DBLogEntry(models.Model):
    time = models.DateTimeField(auto_now_add=True)
    level = models.CharField(max_length=11)
    message = models.TextField()

    class Meta:
        abstract = True


class GeneralLog(DBLogEntry):
    pass


class CabinetLog(DBLogEntry):
    """
    Cabinet log Model
    """

    STATUS_SUCCESS, STATUS_WARNING, STATUS_ERROR = list(range(1, 4))
    STATUSES = (
        (STATUS_SUCCESS, 'success'),
        (STATUS_WARNING, 'warning'),
        (STATUS_ERROR, 'error')
    )

    id = models.BigAutoField(primary_key=True)
    uid = models.CharField(max_length=32, blank=True, null=True, db_index=True)
    conversation_id = models.CharField(max_length=32, blank=True, null=True)
    url = models.URLField(blank=True, null=True)
    cabinet_cookie = models.TextField(blank=True, null=True)
    method = models.CharField(max_length=128, db_index=True)
    merchant_reference = models.CharField(max_length=128, blank=True, null=True, db_index=True)
    status = models.IntegerField(choices=STATUSES, default=STATUS_SUCCESS)
    response_code = models.IntegerField(blank=True, null=True)

    class Meta:
        ordering = ['-pk']
        indexes = [
            models.Index(fields=['time']),
        ]

    def get_db_name(self):
        return self._state.db
