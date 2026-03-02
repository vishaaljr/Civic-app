from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    ROLES = [('citizen','Citizen'),('authority','Authority'),('admin','Admin')]
    phone = models.CharField(max_length=15, blank=True)
    role = models.CharField(max_length=20, choices=ROLES, default='citizen')
    civic_points = models.IntegerField(default=0)

    def __str__(self):
        return f"{self.username} ({self.role})"
