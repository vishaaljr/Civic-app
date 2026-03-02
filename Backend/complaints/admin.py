from django.contrib import admin
from django.db.models import Count
from .models import Complaint, ComplaintImage, ComplaintUpvote, Notification

class ComplaintImageInline(admin.TabularInline):
    model = ComplaintImage
    extra = 1

@admin.register(Complaint)
class ComplaintAdmin(admin.ModelAdmin):
    list_display = (
        'complaint_number', 'user', 'issue_type', 'status', 
        'severity', 'severity_score', 'latitude', 'longitude', 
        'upvote_count', 'submitted_at'
    )
    list_filter = ('status', 'issue_type', 'severity', 'is_emergency', 'is_duplicate')
    search_fields = ('complaint_number', 'description', 'address', 'user__username')
    readonly_fields = ('complaint_number', 'submitted_at', 'severity_score', 'upvote_count')
    inlines = [ComplaintImageInline]

    # Added custom action or display based on user request. 
    # To truly "group by" in standard Django admin, we can add a custom view or use a custom queryset,
    # but the simplest way to see grouped issues in Admin is to filter by them.
    # We will override the changelist view to show a summary OR just add a special method to list_display.
    
    # Another approach: create a proxy model for the grouped view.

class ComplaintLocationGroupProxy(Complaint):
    class Meta:
        proxy = True
        verbose_name = 'Complaint Grouped By Location & Type'
        verbose_name_plural = 'Complaints Grouped By Location & Type'

@admin.register(ComplaintLocationGroupProxy)
class ComplaintLocationGroupAdmin(admin.ModelAdmin):
    change_list_template = 'admin/complaints_grouped_change_list.html'
    
    def changelist_view(self, request, extra_context=None):
        response = super().changelist_view(
            request,
            extra_context=extra_context,
        )

        try:
            qs = response.context_data['cl'].queryset
        except (AttributeError, KeyError):
            return response
            
        # Group by approximate location (e.g., rounding lat/lng) and issue_type
        # In a real app with geopy, we'd use spatial queries. For SQLite, grouping by rounded lat/lng works for a prototype.
        metrics = {
            'groups': qs.values('issue_type', 'latitude', 'longitude').annotate(total=Count('id')).order_by('-total')
        }
        
        response.context_data['summary'] = metrics
        return response

admin.site.register(ComplaintImage)
admin.site.register(ComplaintUpvote)
admin.site.register(Notification)
