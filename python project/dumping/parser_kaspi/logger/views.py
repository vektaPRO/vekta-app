import re
import xml
import json
from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from django.db.models import Q
from django.core.exceptions import PermissionDenied
from django.views.generic.base import View, TemplateView
from django.views.generic import ListView
from pktools.helpers import model_field_exists
from logger.models import CabinetLog


class CabinetLogCommon(View):
    def dispatch(self, request, *args, **kwargs):
        if not (request.user.is_authenticated and request.user.is_superuser):
            raise PermissionDenied()
        return super().dispatch(request, *args, **kwargs)


class CabinetLogsTable(CabinetLogCommon, ListView):
    template_name = 'logger/table.html'
    paginate_by = 20
    default_show_pages = 20
    order_by = '-time'
    search_fields = ['uid', 'merchant_reference']
    search_queries = ['startswith', 'istartswith', 'exact', 'iexact', 'endswith', 'iendswith']

    def get_queryset(self):
        qs = CabinetLog.objects.order_by(self.order_by).defer('message')
        search_conditions = Q()
        for k, v in list(self.request.GET.items()):
            if k == 'q':
                temp_search_fields = self.search_fields
                is_extended_search = False
                search_query = 'exact'
                field_value = v
                prepared_string_array = [x for x in v.split(',') if bool(x)]
                if len(prepared_string_array) and prepared_string_array[-1] in self.search_queries:
                    field_value = ''.join(prepared_string_array[:-1])
                    search_query = prepared_string_array[-1]
                    temp_search_fields.append('method')
                    is_extended_search = True
                for f in temp_search_fields:
                    search_conditions |= Q(**{'%s__exact' % f: v})
                    if is_extended_search:
                        search_conditions |= Q(**{'__'.join([f, search_query]): field_value})
            elif model_field_exists(CabinetLog, k):
                search_conditions &= Q(**{k: v})
            elif k == 'page':
                page = int(v)
                if page >= self.default_show_pages:
                    self.default_show_pages = page + 20

        all_logs = []
        for logger_db_name in settings.LOGGER_DATABASES:
            if search_conditions:
                all_logs.extend(
                    list(
                        qs.filter(
                            search_conditions
                        ).order_by(
                            self.order_by
                        ).using(
                            logger_db_name
                        )[:self.default_show_pages * self.paginate_by]
                    )
                )
            else:
                all_logs.extend(
                    list(
                        qs.order_by(
                            self.order_by
                        ).using(
                            logger_db_name
                        )[:self.default_show_pages * self.paginate_by]
                    )
                )
        all_logs.sort(key=lambda x: -x.time.timestamp())
        return all_logs

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['url_params'] = '&' + '&'.join(['%s=%s' % (k, v) for k, v in list(self.request.GET.items()) if k != 'page'])
        context['search_query'] = self.request.GET.get('q', '')
        context['with_tours'] = self.request.GET.get('with_tours')
        context['object_count'] = len(context['object_list'])
        return context


class CabinetLogView(CabinetLogCommon, TemplateView):
    template_name = 'logger/view.html'
    db_name = 'logger'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        current_log = CabinetLog.objects.using(self.db_name).get(pk=kwargs['pk'])
        logs = []

        for logger_db_name in settings.LOGGER_DATABASES:
            if current_log.uid:
                logs.extend(list(
                    CabinetLog.objects.using(
                        logger_db_name
                    ).filter(
                        uid=current_log.uid
                    ).order_by('pk')))
            elif current_log.conversation_id:
                logs.extend(list(
                    CabinetLog.objects.using(
                        logger_db_name
                    ).filter(
                        conversation_id=current_log.conversation_id
                    ).order_by('pk')))
        for log in logs:
            try:
                message = re.sub(r'>[\n\t\r ]+<', '><', log.message)
                message = xml.dom.minidom.parseString(message.encode('utf-8')).toprettyxml(indent='    ')
            except Exception as e:
                try:
                    message = json.loads(log.message.replace('@', ''))
                    message = json.dumps(message, indent=4, ensure_ascii=False, sort_keys=True)
                except Exception as e:
                    message = log.message
            log.pretty_message = message

        context['current_log'] = current_log
        context['logs'] = logs
        context['logs_count'] = len(logs)
        return context
