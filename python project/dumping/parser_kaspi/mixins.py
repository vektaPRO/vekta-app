from rest_framework import mixins, viewsets


class CustomViewSet(mixins.ListModelMixin,
              mixins.RetrieveModelMixin,
              mixins.UpdateModelMixin,
              mixins.DestroyModelMixin,
              viewsets.GenericViewSet):
    pass
