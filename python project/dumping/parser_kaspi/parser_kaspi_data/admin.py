from django.contrib import admin

from .models import KaspiProduct, ProductPrice, KaspiOrder, KaspiOrderProduct, Merchant, CustomUser, Comment, \
    UserNotification

from import_export.admin import ExportActionMixin


class ProductPriceInline(admin.TabularInline):
    model = ProductPrice


class KaspiOrderProductInline(admin.TabularInline):
    model = KaspiOrderProduct


class KaspiProductAdmin(ExportActionMixin, admin.ModelAdmin):
    list_display = ('merchant', 'num_checks_to_skip', 'num_checks_without_changed_price', 'product_flag',
                    'hyperlinked_product_image', 'hyperlinked_product_link', 'title', 'code', 'master_sku',
                    'price', 'current_price_place', 'first_place_price', 'second_place_price',
                    'third_place_price', 'target_price_place', 'price_difference', 'price_auto_change',
                    'date_of_parsing',  'recently_parsed', )
    list_filter = ('price_auto_change', 'merchant', 'code')
    readonly_fields = ('merchant', 'title', 'code', 'master_sku',  'price', 'date_of_parsing', 'availabilities')
    empty_value_display = '-пусто-'
    inlines = [ProductPriceInline]


class ProductPriceAdmin(admin.ModelAdmin):
    list_display = [field.name for field in ProductPrice._meta.get_fields()]
    list_filter = ('date_of_changing', 'product', )
    empty_value_display = '-пусто-'


class CustomUserAdmin(admin.ModelAdmin):
    list_display = ('get_full_name', 'email', 'phone_number', 'company_name', 'used_trial', 'informed_about_login_problems')
    list_filter = ('company_name', 'email', )
    readonly_fields = ('informed_about_login_problems', )
    empty_value_display = '-пусто-'


class KaspiOrderAdmin(admin.ModelAdmin):
    list_display = ('order_id', 'order_date', 'order_type', 'order_status')
    list_filter = ('order_date', 'order_type', 'order_status', )
    empty_value_display = '-пусто-'
    inlines = [KaspiOrderProductInline]


class KaspiOrderProductAdmin(admin.ModelAdmin):
    list_display = [field.name for field in KaspiOrderProduct._meta.get_fields()]
    list_filter = ('order', 'product', )
    empty_value_display = '-пусто-'


class MerchantAdmin(admin.ModelAdmin):
    list_display = ('name', 'execution_type',
                    'merchant_id', 'enabled', 'created_date','subscription_date_start', 'readable_subscription_days_left',
                    'subscription_days', 'subscription_date_end', 'price_place', 'price_difference', 'price_auto_change',
                    'allowed_number_of_products_with_price_change', 'readable_count_products_with_auto_price_change',
                    'readable_count_products_with_remainders', 'enable_parsing', 'competitors_to_exclude', 'hyperlinked_xml_file_path')
    exclude = ('xml_file_path', 'allowed_number_of_products_with_remainders', )
    list_filter = ('name',)
    empty_value_display = '-пусто-'
    readonly_fields = ('subscription_date_end', 'execution_type')


class CommentAdmin(admin.ModelAdmin):
    list_display = [field.name for field in Comment._meta.get_fields()]
    list_filter = ('user', 'rating', 'text', )
    empty_value_display = '-пусто-'


class UserNotificationAdmin(admin.ModelAdmin):
    list_display = [field.name for field in UserNotification._meta.get_fields()]
    list_filter = ('user', 'message_type', )
    empty_value_display = '-пусто-'


admin.site.register(KaspiProduct, KaspiProductAdmin)
admin.site.register(ProductPrice, ProductPriceAdmin)
admin.site.register(CustomUser, CustomUserAdmin)
admin.site.register(KaspiOrder, KaspiOrderAdmin)
admin.site.register(KaspiOrderProduct, KaspiOrderProductAdmin)
admin.site.register(Merchant, MerchantAdmin)
admin.site.register(Comment, CommentAdmin)
admin.site.register(UserNotification, UserNotificationAdmin)
