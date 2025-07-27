import logging

from django.conf import settings
from django.db import models
from django.utils import timezone
from django_celery_beat.models import PeriodicTask

logger = logging.getLogger(settings.DEFAULT_LOGGER_NAME + '.' + __name__)


class TaskLocker(models.Model):
    STATUS_LOCKED, STATUS_UNLOCKED = list(range(2))
    STATUS_CHOICES = (
        (STATUS_LOCKED, 'LOCKED'),
        (STATUS_UNLOCKED, 'UNLOCKED')
    )

    periodic_task = models.OneToOneField(PeriodicTask, on_delete=models.CASCADE)
    status = models.SmallIntegerField(choices=STATUS_CHOICES, default=STATUS_UNLOCKED)
    last_lock_date = models.DateTimeField(null=True, blank=True)
    last_unlock_date = models.DateTimeField(null=True, blank=True)
    last_task_duration = models.DurationField(null=True, blank=True)

    @staticmethod
    def lock(full_task_name: str) -> int:
        task = PeriodicTask.objects.get(task=full_task_name)
        locker, _ = TaskLocker.objects.get_or_create(periodic_task=task)
        tsk_cnt = TaskLocker.objects.filter(
            id=locker.id,
            status=TaskLocker.STATUS_UNLOCKED
        ).update(
            status=TaskLocker.STATUS_LOCKED,
            last_lock_date=timezone.now()
        )

        logger.info("Locked the task: %s , status: %s", full_task_name, locker.status)

        return tsk_cnt

    @staticmethod
    def unlock(full_task_name: str) -> int:
        task = PeriodicTask.objects.get(task=full_task_name)
        locker, _ = TaskLocker.objects.get_or_create(periodic_task=task)
        now = timezone.now()
        tsk_cnt = TaskLocker.objects.filter(
            id=locker.id,
            status=TaskLocker.STATUS_LOCKED
        ).update(
            status=TaskLocker.STATUS_UNLOCKED,
            last_unlock_date=now,
            last_task_duration=(now - locker.last_lock_date) if locker.last_lock_date else None
        )

        logger.info("Unlocked the task: %s , status: %s", full_task_name, locker.status)

        return tsk_cnt
