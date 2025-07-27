from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import KaspiNewOrder, Merchant, OrderProduct, CustomUser, Invoice, Manager, ResendMessage


admin.site.site_header = 'Администрация KASPI notification'              # default: "Django Administration"
admin.site.index_title = 'KASPI notification'                 # default: "Site administration"
# admin.site.site_title = 'HTML title from administration'   # default: "Django site admin"


class OrderProductInline(admin.TabularInline):
    model = OrderProduct


class KaspiNewOrderAdmin(admin.ModelAdmin):
    list_display = ('kaspi_order_id', 'kaspi_order_code', 'order_date',
                    'notification_time', 'phone_number', 'full_name', 'client_answer', 'first_message_delivery_status',
                    'second_message_delivery_status', 'merchant', 'first_message_sending_time', 'auto_accepted',
                    'api_order_status', 'api_order_state')
    empty_value_display = '-пусто-'
    list_filter = ('notification_status', 'first_message_delivery_status', 'merchant', 'api_order_status')
    search_fields = ['order_date', 'order_status', 'notification_status', 'kaspi_order_code']
    exclude = ('is_kaspi_postamat',)
    inlines = [OrderProductInline]

    def get_queryset(self, request):
        qs = super(KaspiNewOrderAdmin, self).get_queryset(request)
        if request.user.has_group('Manager'):
            return qs.filter(merchant=request.user.user_company)
        return qs


class MerchantAdmin(admin.ModelAdmin):
    list_display = (
        'name', 'communication_type', 'enabled', 'readable_subscription_days_left', 'creation_date',
        'contact_number', 'manager', 'todays_message_count', 'template_type',
        'message_template_name_new_order', 'message_template_name_ask_for_comment', 'auto_accepting',
        'subscription_days', 'subscription_date_start', 'subscription_date_end', 'merchant_shop_link',
        'message_language',
        'chat_id', 'membership_status', 'telegram_mode')
    empty_value_display = '-пусто-'
    list_filter = ('creation_date', 'manager', 'enabled', 'type_of_subscription')
    readonly_fields = ('subscription_date_end', 'uid', 'webhook_url')
    search_fields = ('name', 'green_api_instance_id',)
    exclude = ('daily_message_counts',)

    def get_readonly_fields(self, request, obj=None):
        readonly_fields = super().get_readonly_fields(request, obj)
        return readonly_fields + ('formatted_daily_message_counts',)
    # inlines = [KaspiOrderInline]


class ManagerAdmin(admin.ModelAdmin):
    list_display = ('name', 'phone_number')
    list_filter = ('name',)


class OrderProductAdmin(admin.ModelAdmin):
    list_display = ('order', 'name', 'product_code', 'product_mastercode', 'category', 'quantity', 'price',)
    empty_value_display = '-пусто-'
    list_filter = ('category', )

    def get_queryset(self, request):
        qs = super(OrderProductAdmin, self).get_queryset(request)
        if request.user.has_group('Manager'):
            return qs.filter(order__merchant=request.user.user_company)
        return qs


class CustomUserAdmin(UserAdmin):
    list_display = UserAdmin.list_display + ('user_company', 'core_id')
    fieldsets = UserAdmin.fieldsets + ((None, {'fields': ('user_company', 'core_id')}),)


class InvoiceAdmin(admin.ModelAdmin):
    list_display = [field.name for field in Invoice._meta.get_fields()]
    list_filter = ('creation_date', 'type', 'status', 'merchant')
    empty_value_display = '-пусто-'


@admin.register(ResendMessage)
class ResendMessageAdmin(admin.ModelAdmin):
    list_display = ('merchant', 'start_date', 'first_message_delivery_status', 'status')
    readonly_fields = ('status',)


# class PromoCodeAdmin(admin.ModelAdmin):
#     list_display = ('code', 'merchant', 'cashback_days', 'created_at')
#     empty_value_display = '-пусто-'


# @admin.register(Mailing)
# class MailingAdmin(admin.ModelAdmin):
#     list_display = ('name', 'notification_status', 'message_id', 'status_message')
#     list_filter = ('kaspi_token', 'notification_status')
#     search_fields = ['kaspi_token', 'message_id']


admin.site.register(Invoice, InvoiceAdmin)
admin.site.register(KaspiNewOrder, KaspiNewOrderAdmin)
admin.site.register(Merchant, MerchantAdmin)
admin.site.register(Manager, ManagerAdmin)
admin.site.register(OrderProduct, OrderProductAdmin)
admin.site.register(CustomUser, CustomUserAdmin)
# admin.site.register(PromoCode, PromoCodeAdmin)
# admin.site.register(Cashback)
