// lib/features/citizen/screens/report_issue_screen.dart
// Camera-only photo capture with GPS geo-tagging
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/widgets/category_chip.dart';
import '../../issues/models/category.dart';
import '../../issues/models/issue.dart';
import '../../issues/models/issue_status.dart';
import '../../issues/models/location.dart';
import '../../issues/providers/issue_providers.dart';
import '../../issues/repositories/remote_issue_repository.dart';
import '../../auth/controllers/auth_controller.dart';

// Captured photo with geo-tag
class _GeoPhoto {
  final String path;
  final double? lat;
  final double? lng;
  _GeoPhoto({required this.path, this.lat, this.lng});

  String get geoTag {
    if (lat == null || lng == null) return 'Location unavailable';
    return '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}';
  }
}

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});
  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  int _step = 0;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  IssueCategory? _selectedCategory;
  bool _submitting = false;
  bool _locating = false;
  double? _currentLat;
  double? _currentLng;
  final List<_GeoPhoto> _photos = [];
  bool _isCapturing = false;

  final _steps = ['Category', 'Details', 'Location', 'Photos'];

  bool get _canProceed {
    switch (_step) {
      case 0: return _selectedCategory != null;
      case 1: return _titleCtrl.text.trim().isNotEmpty && _descCtrl.text.trim().length >= 10;
      case 2: return _areaCtrl.text.trim().isNotEmpty;
      case 3: return true;
      default: return false;
    }
  }

  void _nextStep() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  /// Get current GPS location
  Future<Position?> _getLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Capture photo from camera ONLY with geo-tag
  Future<void> _capturePhoto() async {
    if (_photos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
      );
      return;
    }

    // Request camera permission
    final camPerm = await Permission.camera.request();
    if (!camPerm.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to take photos')),
        );
      }
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final picker = ImagePicker();
      // CAMERA ONLY — no gallery
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (picked == null) {
        setState(() => _isCapturing = false);
        return;
      }

      // Get geo-tag at moment of capture
      final pos = await _getLocation();

      setState(() {
        _photos.add(_GeoPhoto(
          path: picked.path,
          lat: pos?.latitude,
          lng: pos?.longitude,
        ));
        _isCapturing = false;
      });
    } catch (e) {
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: ${e.toString()}')),
        );
      }
    }
  }

  /// Use device GPS to fill location field
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final pos = await _getLocation();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;
        _areaCtrl.text = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        _wardCtrl.text = 'Auto-detected';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get location. Please enter manually.')),
        );
      }
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;

    // Require at least one photo for AI + duplicate detection
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture at least one photo of the issue.')),
      );
      return;
    }

    setState(() => _submitting = true);

    final auth = ref.read(authControllerProvider);
    final remoteRepo = ref.read(remoteIssueRepositoryProvider);

    // Use first photo's geo-tag for issue location if available
    final firstPhoto = _photos.first;
    final lat = firstPhoto.lat ?? _currentLat;
    final lng = firstPhoto.lng ?? _currentLng;

    if (lat == null || lng == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location is required. Please use GPS or enter location details.'),
        ),
      );
      return;
    }

    try {
      final result = await remoteRepo.submitComplaint(
        imageFile: File(firstPhoto.path),
        latitude: lat,
        longitude: lng,
        address: _areaCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        severity: 'low',
        isEmergency: false,
      );

      if (!mounted) return;

      // Refresh remote-backed lists
      ref.invalidate(allIssuesProvider);
      ref.invalidate(myIssuesProvider);

      setState(() => _submitting = false);

      if (result.isRejected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _SuccessSheet(
          onDone: () {
            Navigator.pop(ctx);
            context.go('/citizen/my-issues');
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit complaint: $e')),
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _areaCtrl.dispose();
    _wardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
            } else {
              context.go('/citizen/home');
            }
          },
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Row(
              children: List.generate(_steps.length * 2 - 1, (i) {
                if (i.isOdd) {
                  return Expanded(
                    child: Container(
                      height: 2,
                      color: i ~/ 2 < _step
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  );
                }
                final idx = i ~/ 2;
                final done = idx < _step;
                final active = idx == _step;
                return Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: done || active
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : Center(
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active ? Colors.white : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _steps[idx],
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildStep(context),
              ),
            ),
          ),

          // Bottom actions
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: Row(
              children: [
                if (_step > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _canProceed && !_submitting ? _nextStep : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(0, 48),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_step == _steps.length - 1 ? 'Submit Issue' : 'Continue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _CategoryStep(
          selected: _selectedCategory,
          onSelect: (c) => setState(() => _selectedCategory = c),
        );
      case 1:
        return _DetailsStep(
          titleCtrl: _titleCtrl,
          descCtrl: _descCtrl,
          onChanged: () => setState(() {}),
        );
      case 2:
        return _LocationStep(
          areaCtrl: _areaCtrl,
          wardCtrl: _wardCtrl,
          currentLat: _currentLat,
          currentLng: _currentLng,
          locating: _locating,
          onUseCurrent: _useCurrentLocation,
          onChanged: () => setState(() {}),
        );
      case 3:
        return _PhotoStep(
          photos: _photos,
          isCapturing: _isCapturing,
          onCapture: _capturePhoto,
          onRemove: (i) => setState(() => _photos.removeAt(i)),
        );
      default:
        return const SizedBox();
    }
  }
}

// ─── Category Step ─────────────────────────────────────────────────────────
class _CategoryStep extends StatelessWidget {
  final IssueCategory? selected;
  final void Function(IssueCategory) onSelect;
  const _CategoryStep({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Category', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('What type of issue are you reporting?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9,
          ),
          itemCount: IssueCategories.all.length,
          itemBuilder: (_, i) {
            final cat = IssueCategories.all[i];
            return CategoryGridTile(
              category: cat,
              selected: selected?.id == cat.id,
              onTap: () => onSelect(cat),
            );
          },
        ),
      ],
    );
  }
}

// ─── Details Step ──────────────────────────────────────────────────────────
class _DetailsStep extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final VoidCallback onChanged;
  const _DetailsStep({required this.titleCtrl, required this.descCtrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Issue Details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Describe the issue clearly.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        TextFormField(
          controller: titleCtrl,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            labelText: 'Issue Title *',
            hintText: 'e.g. Deep pothole on main road',
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLength: 80,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: descCtrl,
          onChanged: (_) => onChanged(),
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Description *',
            hintText: 'Describe the issue in detail. Include any safety concerns.',
            alignLabelWithHint: true,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}

// ─── Location Step ─────────────────────────────────────────────────────────
class _LocationStep extends StatelessWidget {
  final TextEditingController areaCtrl;
  final TextEditingController wardCtrl;
  final double? currentLat;
  final double? currentLng;
  final bool locating;
  final VoidCallback onUseCurrent;
  final VoidCallback onChanged;
  const _LocationStep({
    required this.areaCtrl, required this.wardCtrl,
    required this.currentLat, required this.currentLng,
    required this.locating, required this.onUseCurrent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasGps = currentLat != null && currentLng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Where is the issue located?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),

        // GPS status card
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasGps ? Colors.green.withValues(alpha: 0.08) : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasGps ? Colors.green.withValues(alpha: 0.4) : scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: hasGps ? Colors.green.withValues(alpha: 0.1) : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasGps ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                  color: hasGps ? Colors.green : scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasGps ? 'GPS Location Captured' : 'GPS Location',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: hasGps ? Colors.green : scheme.onSurface,
                      ),
                    ),
                    if (hasGps)
                      Text(
                        '${currentLat!.toStringAsFixed(5)}, ${currentLng!.toStringAsFixed(5)}',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        'Tap below to detect your location',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: locating ? null : onUseCurrent,
            icon: locating
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded, size: 18),
            label: Text(locating ? 'Detecting location...' : 'Detect Current Location'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        const SizedBox(height: 20),

        TextFormField(
          controller: areaCtrl,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            labelText: 'Area / Street *',
            prefixIcon: Icon(Icons.location_on_outlined, size: 20),
            hintText: 'e.g. Koramangala 5th Block',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: wardCtrl,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(
            labelText: 'Ward Number',
            prefixIcon: Icon(Icons.numbers_rounded, size: 20),
            hintText: 'e.g. 12',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}

// ─── Photo Step (Camera only) ───────────────────────────────────────────────
class _PhotoStep extends StatelessWidget {
  final List<_GeoPhoto> photos;
  final bool isCapturing;
  final VoidCallback onCapture;
  final void Function(int) onRemove;
  const _PhotoStep({
    required this.photos, required this.isCapturing,
    required this.onCapture, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo Evidence', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Take up to 3 photos. Each photo is automatically geo-tagged.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 20),

        // Capture button
        if (photos.length < 3)
          GestureDetector(
            onTap: isCapturing ? null : onCapture,
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.4),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: isCapturing
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, size: 36, color: scheme.primary),
                        const SizedBox(height: 8),
                        Text('Tap to take photo',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            )),
                        const SizedBox(height: 2),
                        Text('Camera only · Auto geo-tagged',
                            style: TextStyle(
                              color: scheme.primary.withValues(alpha: 0.6),
                              fontSize: 11,
                            )),
                      ],
                    ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
                const SizedBox(width: 8),
                const Text('Maximum 3 photos captured', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),

        if (photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('${photos.length} Photo${photos.length > 1 ? 's' : ''} Captured',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...photos.asMap().entries.map((entry) {
            final idx = entry.key;
            final p = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Image.file(
                          File(p.path),
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 160,
                            color: scheme.surfaceContainerHighest,
                            child: Icon(Icons.broken_image_rounded, color: scheme.onSurfaceVariant, size: 40),
                          ),
                        ),
                        // Remove button
                        Positioned(
                          top: 8, right: 8,
                          child: GestureDetector(
                            onTap: () => onRemove(idx),
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        // Photo index badge
                        Positioned(
                          top: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text('Photo ${idx + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                    // Geo-tag bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.green.withValues(alpha: 0.08),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 14,
                              color: p.lat != null ? Colors.green : scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              p.lat != null
                                  ? 'Geo-tagged: ${p.geoTag}'
                                  : 'Location not available',
                              style: TextStyle(
                                fontSize: 11,
                                color: p.lat != null ? Colors.green : scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: scheme.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Photos are taken from your camera only and automatically tagged with GPS coordinates.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Success Sheet ──────────────────────────────────────────────────────────
class _SuccessSheet extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessSheet({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 46),
            ),
            const SizedBox(height: 18),
            const Text('Issue Submitted!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Your report has been submitted successfully.\nOur team will review it shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onDone,
                icon: const Icon(Icons.my_library_books_outlined),
                label: const Text('View My Issues'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
