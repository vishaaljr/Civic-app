from django.urls import path
from .views import (
    ComplaintListView, SubmitComplaintView, MyComplaintsView,
    ComplaintDetailView, UpdateStatusView, UpvoteView,
    DashboardView, NotificationsView
)

urlpatterns = [
    path('complaints/', ComplaintListView.as_view()),
    path('complaints/submit/', SubmitComplaintView.as_view()),
    path('complaints/mine/', MyComplaintsView.as_view()),
    path('complaints/<uuid:pk>/', ComplaintDetailView.as_view()),
    path('complaints/<uuid:pk>/status/', UpdateStatusView.as_view()),
    path('complaints/<uuid:pk>/upvote/', UpvoteView.as_view()),
    path('dashboard/', DashboardView.as_view()),
    path('notifications/', NotificationsView.as_view()),
]
