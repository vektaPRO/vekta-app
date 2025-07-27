from django.urls import path

from api.views import UserView

urlpatterns = [
    path('user/', UserView.as_view(), name='user-info'),
]
