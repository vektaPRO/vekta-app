from rest_framework import permissions

from parser_kaspi_data.models import Merchant, CustomUser, KaspiProduct


class IsOwnerOrReadOnly(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True

        if request.user.has_group('Manager'):
            return True

        return (isinstance(obj, Merchant) and obj.user == request.user) or \
            (isinstance(obj, KaspiProduct) and obj.merchant.user == request.user) \
            or obj == request.user


class ReadOnly(permissions.BasePermission):

    def has_permission(self, request, view):
        return request.method in permissions.SAFE_METHODS
