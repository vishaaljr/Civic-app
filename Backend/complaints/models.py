import uuid
from django.db import models
from django.conf import settings

class Complaint(models.Model):
    ISSUE_TYPES = [
        ('pothole', 'Pothole'),
        ('garbage', 'Garbage'),
        ('streetlight', 'Streetlight'),
        ('water_leakage', 'Water Leakage'),
        ('drain', 'Drain'),
        ('other', 'Other')
    ]
    SEVERITY_CHOICES = [
        ('low', 'Low'),
        ('moderate', 'Moderate'),
        ('critical', 'Critical')
    ]
    STATUS_CHOICES = [
        ('submitted', 'Submitted'),
        ('in_progress', 'In Progress'),
        ('resolved', 'Resolved'),
        ('rejected', 'Rejected')
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    complaint_number = models.CharField(max_length=20, unique=True)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    latitude = models.DecimalField(max_digits=10, decimal_places=6)
    longitude = models.DecimalField(max_digits=10, decimal_places=6)
    address = models.CharField(max_length=300, blank=True)
    issue_type = models.CharField(max_length=20, choices=ISSUE_TYPES)
    description = models.TextField(blank=True)
    severity = models.CharField(max_length=20, choices=SEVERITY_CHOICES, default='low')
    severity_score = models.FloatField(default=0.0)
    # AI fields
    predicted_class = models.CharField(max_length=50, blank=True)
    ai_confidence = models.FloatField(default=0.0)
    image_embedding = models.JSONField(null=True, blank=True)   # 1280-dim vector stored as JSON list
    # Duplicate detection
    is_duplicate = models.BooleanField(default=False)
    parent_complaint = models.ForeignKey('self', null=True, blank=True, on_delete=models.SET_NULL)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='submitted')
    upvote_count = models.IntegerField(default=0)
    is_emergency = models.BooleanField(default=False)
    submitted_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.complaint_number} - {self.issue_type}"

class ComplaintImage(models.Model):
    complaint = models.ForeignKey(Complaint, related_name='images', on_delete=models.CASCADE)
    image = models.ImageField(upload_to='complaints/')
    is_primary = models.BooleanField(default=False)

    def __str__(self):
        return f"Image for {self.complaint.complaint_number}"

class ComplaintUpvote(models.Model):
    complaint = models.ForeignKey(Complaint, on_delete=models.CASCADE)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)

    class Meta:
        unique_together = ('complaint', 'user')

class Notification(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    complaint = models.ForeignKey(Complaint, null=True, blank=True, on_delete=models.SET_NULL)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Notification for {self.user.username}"
