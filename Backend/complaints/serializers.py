from rest_framework import serializers
from .models import Complaint, ComplaintImage

class ComplaintImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ComplaintImage
        fields = ['image', 'is_primary']

class ComplaintSerializer(serializers.ModelSerializer):
    primary_image = serializers.SerializerMethodField()

    class Meta:
        model = Complaint
        fields = [
            'id', 'complaint_number', 'issue_type', 'severity',
            'severity_score', 'status', 'latitude', 'longitude',
            'upvote_count', 'submitted_at', 'is_emergency',
            'is_duplicate', 'primary_image'
        ]

    def get_primary_image(self, obj):
        primary = obj.images.filter(is_primary=True).first()
        if primary and primary.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(primary.image.url)
            return primary.image.url
        return None

class ComplaintDetailSerializer(ComplaintSerializer):
    images = serializers.SerializerMethodField()
    history = serializers.SerializerMethodField()
    user_info = serializers.SerializerMethodField()

    class Meta(ComplaintSerializer.Meta):
        fields = ComplaintSerializer.Meta.fields + ['description', 'address', 'resolved_at', 'images', 'history', 'user_info']

    def get_user_info(self, obj):
        return {
            "username": obj.user.username,
            "role": obj.user.role
        }

    def get_images(self, obj):
        request = self.context.get('request')
        images = []
        for img in obj.images.all():
            if img.image:
                if request:
                    images.append(request.build_absolute_uri(img.image.url))
                else:
                    images.append(img.image.url)
        return images

    def get_history(self, obj):
        hist = []
        hist.append({
            'status': 'submitted',
            'timestamp': obj.submitted_at
        })
        if obj.status != 'submitted':
            hist.append({
                'status': obj.status,
                'timestamp': obj.resolved_at if obj.resolved_at else obj.submitted_at
            })
        return hist
