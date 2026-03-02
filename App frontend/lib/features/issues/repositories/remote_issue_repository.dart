// lib/features/issues/repositories/remote_issue_repository.dart
// Connects CityPulse Flutter app to the Django REST API backend.
// Authentication token is automatically attached via ApiService.

import 'dart:io';
import '../../../core/services/api_service.dart';
import '../models/issue.dart';
import '../models/issue_status.dart';
import '../models/category.dart';
import '../models/location.dart';
import 'issue_repository.dart';

class SubmitComplaintResult {
  final bool isDuplicate;
  final bool isRejected;
  final String? complaintId;
  final String? complaintNumber;
  final String predictedClass;
  final double confidence;
  final String message;

  const SubmitComplaintResult({
    required this.isDuplicate,
    required this.isRejected,
    required this.complaintId,
    required this.complaintNumber,
    required this.predictedClass,
    required this.confidence,
    required this.message,
  });
}

/// Maps backend issue_type strings to frontend IssueCategory objects.
IssueCategory _categoryFromType(String issueType) {
  switch (issueType) {
    case 'pothole':
      return IssueCategories.road;
    case 'garbage':
      return IssueCategories.garbage;
    case 'water_leakage':
    case 'drain':
      return IssueCategories.water;
    case 'streetlight':
    case 'streetlight_damage':
      return IssueCategories.electricity;
    default:
      return IssueCategories.other;
  }
}

/// Maps backend status strings to frontend IssueStatus enum.
IssueStatus _statusFromValue(String? s) => IssueStatus.fromValue(s ?? '');

/// Converts a raw complaint JSON map (from the list/detail endpoint)
/// into a frontend [Issue] model.
Issue _issueFromJson(Map<String, dynamic> json) {
  final imageUrl = json['primary_image'] as String?;
  return Issue(
    id: json['id'].toString(),
    title:
        '${(json['issue_type'] as String? ?? 'Issue').replaceAll('_', ' ').toUpperCase()} #${json['complaint_number'] ?? ''}',
    description: json['description'] as String? ?? '',
    category: _categoryFromType(json['issue_type'] as String? ?? ''),
    location: IssueLocation(
      latitude: double.tryParse(json['latitude'].toString()) ?? 0,
      longitude: double.tryParse(json['longitude'].toString()) ?? 0,
      areaName: json['address'] as String? ?? '',
      wardNumber: '',
    ),
    status: _statusFromValue(json['status'] as String?),
    createdAt:
        DateTime.tryParse(json['submitted_at'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['submitted_at'] as String? ?? '') ?? DateTime.now(),
    reporterId: json['user']?.toString() ?? '',
    reporterName: '',
    attachments: imageUrl != null ? [imageUrl] : [],
    upvotes: (json['upvote_count'] as num?)?.toInt() ?? 0,
    isUrgent: json['is_emergency'] as bool? ?? false,
  );
}

class RemoteIssueRepository extends IssueRepository {
  // ── Submit complaint with image (AI classification + duplicate detection) ──

  Future<SubmitComplaintResult> submitComplaint({
    required File imageFile,
    required double latitude,
    required double longitude,
    String address = '',
    String description = '',
    String severity = 'low',
    bool isEmergency = false,
  }) async {
    final response = await ApiService.postMultipart(
      '/complaints/submit/',
      fields: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'address': address,
        'description': description,
        'severity': severity,
        'is_emergency': isEmergency.toString(),
      },
      filePath: imageFile.path,
    );

    final data = ApiService.decodeResponse(response) as Map<String, dynamic>;

    if (response.statusCode == 400 &&
        data['reason'] == 'no_issue') {
      return SubmitComplaintResult(
        isDuplicate: false,
        isRejected: true,
        complaintId: null,
        complaintNumber: null,
        predictedClass: 'no_issue',
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
        message: data['message'] as String? ?? 'Image rejected by AI.',
      );
    }

    if (!ApiService.isSuccess(response)) {
      throw Exception(data['error'] ?? 'Failed to submit complaint');
    }

    final isDuplicate = data['status'] == 'duplicate';
    return SubmitComplaintResult(
      isDuplicate: isDuplicate,
      isRejected: false,
      complaintId: data['complaint_id']?.toString(),
      complaintNumber: data['complaint_number']?.toString(),
      predictedClass: data['predicted_class'] as String? ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      message: data['message'] as String? ?? '',
    );
  }

  // ── Fetch all complaints ───────────────────────────────────────────────────

  Future<List<Issue>> fetchComplaints({
    IssueFilters? filters,
    SortOrder sort = SortOrder.latest,
  }) async {
    var path = '/complaints/';
    final params = <String>[];
    if (filters?.status != null) params.add('status=${filters!.status!.value}');
    if (filters?.categoryId != null && filters!.categoryId!.isNotEmpty) {
      params.add('issue_type=${filters.categoryId}');
    }
    if (params.isNotEmpty) path += '?${params.join('&')}';

    final response = await ApiService.get(path);
    if (!ApiService.isSuccess(response)) return [];

    final data = ApiService.decodeResponse(response);
    if (data is! List) return [];
    final issues = data
        .whereType<Map<String, dynamic>>()
        .map(_issueFromJson)
        .toList();

    if (sort == SortOrder.oldest) {
      issues.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return issues;
  }

  // ── Fetch MY complaints ────────────────────────────────────────────────────

  Future<List<Issue>> fetchMyComplaints() async {
    final response = await ApiService.get('/complaints/mine/');
    if (!ApiService.isSuccess(response)) return [];
    final data = ApiService.decodeResponse(response);
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(_issueFromJson)
        .toList();
  }

  // ── Upvote a complaint ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> upvoteComplaint(String complaintId) async {
    final response = await ApiService.post(
      '/complaints/$complaintId/upvote/',
      {},
    );
    return ApiService.decodeResponse(response) as Map<String, dynamic>;
  }

  // ── Dashboard stats ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchDashboard() async {
    final response = await ApiService.get('/dashboard/');
    if (!ApiService.isSuccess(response)) return {};
    return ApiService.decodeResponse(response) as Map<String, dynamic>;
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchNotifications() async {
    final response = await ApiService.get('/notifications/');
    if (!ApiService.isSuccess(response)) return [];
    final data = ApiService.decodeResponse(response);
    if (data is! List) return [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> markNotificationsRead() async {
    await ApiService.patch('/notifications/', {});
  }
}
