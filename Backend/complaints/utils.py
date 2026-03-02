"""
Utility functions for the complaints app.
Replaces the old imagehash-based approach with AI embedding cosine similarity.
"""

import math
import numpy as np
from .models import Complaint


# ── Duplicate detection ────────────────────────────────────────────────────────

def cosine_distance(a: list, b: list) -> float:
    """Return the cosine distance (0 = identical, 2 = opposite) between two vectors."""
    va = np.array(a, dtype=np.float32)
    vb = np.array(b, dtype=np.float32)
    dot = np.dot(va, vb)
    # Both vectors should already be L2-normalised, so norms ≈ 1.0
    na = np.linalg.norm(va)
    nb = np.linalg.norm(vb)
    if na == 0 or nb == 0:
        return 2.0  # treat as completely dissimilar
    similarity = dot / (na * nb)
    return float(1.0 - similarity)   # distance = 1 − similarity


def haversine_meters(lat1, lon1, lat2, lon2) -> float:
    """Calculate great-circle distance between two points in metres."""
    R = 6_371_000  # Earth radius in metres
    phi1, phi2 = math.radians(float(lat1)), math.radians(float(lat2))
    dphi = math.radians(float(lat2) - float(lat1))
    dlambda = math.radians(float(lon2) - float(lon1))
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))


COSINE_THRESHOLD = 0.15    # cosine distance < 0.15  ≡  cosine similarity > 0.85
GEO_RADIUS_M     = 100     # metres


def find_duplicate(lat, lng, embedding: list):
    """
    Look for an existing complaint that is:
      • Within GEO_RADIUS_M metres of (lat, lng)
      • Has a cosine distance to the new embedding < COSINE_THRESHOLD

    Returns the best-matching Complaint, or None.
    """
    if embedding is None:
        return None

    # Only compare against non-duplicate complaints that have stored embeddings
    candidates = Complaint.objects.filter(
        is_duplicate=False,
        image_embedding__isnull=False,
    )

    best = None
    best_dist = COSINE_THRESHOLD  # must be strictly better than this

    for complaint in candidates:
        try:
            geo_dist = haversine_meters(lat, lng, complaint.latitude, complaint.longitude)
            if geo_dist > GEO_RADIUS_M:
                continue

            stored_embedding = complaint.image_embedding
            if not stored_embedding:
                continue

            cos_dist = cosine_distance(embedding, stored_embedding)
            if cos_dist < best_dist:
                best_dist = cos_dist
                best = complaint
        except Exception:
            pass

    return best


# ── Severity scoring ───────────────────────────────────────────────────────────

def compute_severity_score(upvotes: int, severity: str, is_emergency: bool) -> float:
    base = {'low': 20, 'moderate': 50, 'critical': 80}
    score = base.get(severity, 20)
    score += min(upvotes * 2, 20)
    if is_emergency:
        score += 20
    return min(float(score), 100.0)
