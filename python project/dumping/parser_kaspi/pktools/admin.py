from django.contrib import admin
from pktools.models import TaskLocker

class TaskLockerAdmin(admin.ModelAdmin):
    list_display = ('periodic_task', 'status', 'last_lock_date', 'last_unlock_date', 'last_task_duration')


admin.site.register(TaskLocker, TaskLockerAdmin)
