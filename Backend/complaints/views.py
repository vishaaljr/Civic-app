"""
Complaint views — AI-powered submission, duplicate detection, and management.
"""

import os
import tempfile

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from django.db.models import Count
from django.utils import timezone

from .models import Complaint, ComplaintImage, ComplaintUpvote, Notification
from .serializers import ComplaintSerializer, ComplaintDetailSerializer
from .utils import find_duplicate, compute_severity_score
from .ai_pipeline import analyze_image


class SubmitComplaintView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        images = request.FILES.getlist('images')
        if not images:
            return Response(
                {'error': 'At least one image is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ── Parse form fields ────────────────────────────────────────────────
        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        address = request.data.get('address', '')
        description = request.data.get('description', '')
        severity = request.data.get('severity', 'low')
        is_emergency = request.data.get('is_emergency', 'false').lower() == 'true'

        try:
            lat = float(lat)
            lng = float(lng)
        except (TypeError, ValueError):
            return Response(
                {'error': 'Invalid latitude or longitude'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ── Stage 1: AI Classification ───────────────────────────────────────
        first_image = images[0]
        tmp_path = None
        try:
            suffix = os.path.splitext(first_image.name)[-1] or '.jpg'
            with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
                for chunk in first_image.chunks():
                    tmp.write(chunk)
                tmp_path = tmp.name

            ai_result = analyze_image(tmp_path)
        except Exception as exc:
            return Response(
                {'error': f'AI analysis failed: {exc}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        finally:
            if tmp_path and os.path.exists(tmp_path):
                os.remove(tmp_path)

        # Reset file pointer so it can be saved again later
        first_image.seek(0)

        predicted_class = ai_result['predicted_class']
        confidence = ai_result['confidence']
        embedding = ai_result['embedding']

        # Reject clearly non-issue images
        if predicted_class == 'no_issue':
            return Response(
                {
                    'status': 'rejected',
                    'reason': 'no_issue',
                    'confidence': confidence,
                    'message': 'The uploaded image does not appear to show a civic issue.',
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Use AI-detected class as the complaint issue_type
        issue_type = request.data.get('issue_type') or predicted_class

        # ── Stage 2: Duplicate Detection ─────────────────────────────────────
        embedding_list = embedding.tolist() if embedding is not None else None
        duplicate = find_duplicate(lat, lng, embedding_list)

        if duplicate:
            duplicate.upvote_count += 1
            duplicate.severity_score = compute_severity_score(
                duplicate.upvote_count, duplicate.severity, duplicate.is_emergency
            )
            duplicate.save()
            return Response(
                {
                    'status': 'duplicate',
                    'complaint_id': str(duplicate.id),
                    'complaint_number': duplicate.complaint_number,
                    'confidence': confidence,
                    'predicted_class': predicted_class,
                    'upvote_count': duplicate.upvote_count,
                    'message': 'Duplicate detected. Your report boosted its priority.',
                },
                status=status.HTTP_200_OK,
            )

        # ── Stage 3: Create new complaint ────────────────────────────────────
        complaint_number = f"CMP-{Complaint.objects.count() + 1:05d}"
        severity_score = compute_severity_score(0, severity, is_emergency)

        complaint = Complaint.objects.create(
            complaint_number=complaint_number,
            user=request.user,
            latitude=lat,
            longitude=lng,
            address=address,
            issue_type=issue_type,
            description=description,
            severity=severity,
            severity_score=severity_score,
            predicted_class=predicted_class,
            ai_confidence=confidence,
            image_embedding=embedding_list,
            is_emergency=is_emergency,
        )

        # Save uploaded images
        for i, img in enumerate(images):
            if i != 0:
                img.seek(0)
            ComplaintImage.objects.create(
                complaint=complaint,
                image=img,
                is_primary=(i == 0),
            )

        # Reward civic points
        user = request.user
        user.civic_points += 10
        user.save()

        return Response(
            {
                'status': 'created',
                'complaint_id': str(complaint.id),
                'complaint_number': complaint.complaint_number,
                'confidence': confidence,
                'predicted_class': predicted_class,
                'severity_score': complaint.severity_score,
                'message': 'Complaint submitted successfully',
            },
            status=status.HTTP_201_CREATED,
        )


class ComplaintListView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ComplaintSerializer

    def get_queryset(self):
        queryset = Complaint.objects.all().order_by('-submitted_at')
        status_filter = self.request.query_params.get('status')
        issue_type = self.request.query_params.get('issue_type')
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        if issue_type:
            queryset = queryset.filter(issue_type=issue_type)
        return queryset


class MyComplaintsView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ComplaintSerializer

    def get_queryset(self):
        return Complaint.objects.filter(user=self.request.user).order_by('-submitted_at')


class ComplaintDetailView(generics.RetrieveAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ComplaintDetailSerializer
    queryset = Complaint.objects.all()


class UpdateStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        if request.user.role not in ['authority', 'admin']:
            return Response({'error': 'Forbidden'}, status=status.HTTP_403_FORBIDDEN)

        try:
            complaint = Complaint.objects.get(pk=pk)
        except Complaint.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get('status')
        if not new_status:
            return Response({'error': 'Status required'}, status=status.HTTP_400_BAD_REQUEST)

        complaint.status = new_status
        if new_status == 'resolved':
            complaint.resolved_at = timezone.now()
        complaint.save()

        Notification.objects.create(
            user=complaint.user,
            complaint=complaint,
            message=f"Your complaint {complaint.complaint_number} is now {new_status}",
        )

        return Response({'message': 'Status updated', 'status': new_status}, status=status.HTTP_200_OK)


class UpvoteView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            complaint = Complaint.objects.get(pk=pk)
        except Complaint.DoesNotExist:
            return Response({'error': 'Not found'}, status=status.HTTP_404_NOT_FOUND)

        upvote, created = ComplaintUpvote.objects.get_or_create(
            complaint=complaint,
            user=request.user,
        )

        if created:
            complaint.upvote_count += 1
            complaint.severity_score = compute_severity_score(
                complaint.upvote_count, complaint.severity, complaint.is_emergency
            )
            complaint.save()
            return Response(
                {'message': 'Upvoted', 'upvote_count': complaint.upvote_count, 'severity_score': complaint.severity_score},
                status=status.HTTP_200_OK,
            )
        return Response({'message': 'Already upvoted'}, status=status.HTTP_400_BAD_REQUEST)


class DashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user

        if user.role in ['authority', 'admin']:
            total = Complaint.objects.count()
            resolved = Complaint.objects.filter(status='resolved').count()
            pending = Complaint.objects.exclude(status='resolved').count()
            critical = Complaint.objects.filter(severity='critical').count()
            resolution_rate = f"{(resolved / total * 100):.1f}%" if total > 0 else "0.0%"

            issue_counts = Complaint.objects.values('issue_type').annotate(count=Count('id'))
            by_issue_type = {item['issue_type']: item['count'] for item in issue_counts}

            unresolved = Complaint.objects.exclude(status='resolved')
            heatmap = [
                {
                    'lat': float(c.latitude),
                    'lng': float(c.longitude),
                    'severity_score': c.severity_score,
                    'issue_type': c.issue_type,
                }
                for c in unresolved
            ]

            return Response(
                {
                    'role': user.role,
                    'total_complaints': total,
                    'resolved': resolved,
                    'pending': pending,
                    'critical': critical,
                    'resolution_rate': resolution_rate,
                    'by_issue_type': by_issue_type,
                    'heatmap': heatmap,
                },
                status=status.HTTP_200_OK,
            )

        # Citizen dashboard
        my_total = Complaint.objects.filter(user=user).count()
        my_resolved = Complaint.objects.filter(user=user, status='resolved').count()
        my_pending = Complaint.objects.filter(user=user).exclude(status='resolved').count()
        return Response(
            {
                'role': user.role,
                'civic_points': user.civic_points,
                'my_total': my_total,
                'my_resolved': my_resolved,
                'my_pending': my_pending,
            },
            status=status.HTTP_200_OK,
        )


class NotificationsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        notifications = Notification.objects.filter(user=request.user).order_by('-created_at')[:20]
        data = [
            {
                'id': n.id,
                'message': n.message,
                'is_read': n.is_read,
                'created_at': n.created_at,
            }
            for n in notifications
        ]
        return Response(data, status=status.HTTP_200_OK)

    def patch(self, request):
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response({'message': 'Marked as read'}, status=status.HTTP_200_OK)
