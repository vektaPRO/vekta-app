from django.urls import path
from logger.views import CabinetLogView, CabinetLogsTable


urlpatterns = [
    path('cabinetlog/', CabinetLogsTable.as_view(), name='cabinetlog_list'),
    path('cabinetlog/<int:pk>/', CabinetLogView.as_view(), name='cabinetlog_view'),
]
