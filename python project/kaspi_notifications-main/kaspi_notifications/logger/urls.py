from django.conf import settings
from django.urls import path
from logger.views import CabinetLogView, CabinetLogsTable
from django.conf.urls.static import static


urlpatterns = [
    path('cabinetlog/', CabinetLogsTable.as_view(), name='cabinetlog_list'),
    path('cabinetlog/<int:pk>/', CabinetLogView.as_view(), name='cabinetlog_view'),
] + static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)

