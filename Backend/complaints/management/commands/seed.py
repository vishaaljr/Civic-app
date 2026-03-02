from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from complaints.models import Complaint
from complaints.utils import compute_severity_score
import random

User = get_user_model()

class Command(BaseCommand):
    help = 'Seed database with users and complaints'

    def handle(self, *args, **kwargs):
        # 1. Create Users
        if not User.objects.filter(username='admin').exists():
            User.objects.create_superuser('admin', email='', password='admin123', role='admin')
        
        users_data = [
            ('authority1', 'auth123', 'authority'),
            ('citizen1', 'pass123', 'citizen'),
            ('citizen2', 'pass123', 'citizen'),
            ('citizen3', 'pass123', 'citizen'),
        ]
        
        created_users = []
        for username, password, role in users_data:
            user, created = User.objects.get_or_create(username=username, defaults={'role': role})
            if created:
                user.set_password(password)
                user.save()
            if role == 'citizen':
                created_users.append(user)

        # 2. Create Complaints
        if Complaint.objects.count() == 0:
            issue_types = ['pothole', 'garbage', 'streetlight', 'water_leak', 'drain', 'other']
            severities = ['low', 'moderate', 'critical']
            
            # We need 8 complaints: 3 resolved, 3 in_progress, 2 submitted
            statuses = ['resolved']*3 + ['in_progress']*3 + ['submitted']*2
            
            for i in range(8):
                lat = round(random.uniform(17.3, 17.5), 6)
                lng = round(random.uniform(78.3, 78.6), 6)
                upvotes = random.randint(0, 15)
                severity = random.choice(severities)
                is_emergency = random.choice([True, False])
                status = statuses[i]
                
                severity_score = compute_severity_score(upvotes, severity, is_emergency)
                
                complaint = Complaint.objects.create(
                    complaint_number=f"CMP-{i+1:05d}",
                    user=random.choice(created_users),
                    latitude=lat,
                    longitude=lng,
                    address=f"Random Block {i}, MG Road, Hyderabad",
                    issue_type=random.choice(issue_types),
                    description=f"Sample issue description for complaint {i+1}",
                    severity=severity,
                    severity_score=severity_score,
                    image_hash="dummyhash123", # mock hash for seed
                    status=status,
                    upvote_count=upvotes,
                    is_emergency=is_emergency
                )
        
        self.stdout.write(self.style.SUCCESS("Seed complete!"))
        self.stdout.write("Users: admin, authority1, citizen1, citizen2, citizen3")
        self.stdout.write(f"Complaints created: {Complaint.objects.count()}")
