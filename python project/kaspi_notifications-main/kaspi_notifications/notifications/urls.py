from django.urls import path
from . import views

urlpatterns = [
    path('reply', views.reply, name='reply'),
    path('qr-link-whatsapp/<str:uid>/', views.get_qr_code_green_api_html_render, name='index'),
    path('webhook/<str:uid>/', views.webhook, name='webhook'),

]
