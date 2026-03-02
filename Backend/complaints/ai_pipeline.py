"""
AI Pipeline — MobileNetV2 classifier + embedding extractor.
Uses the pothole_classifier.h5 model from the App Ai Module.
"""

import os
import sys
import numpy as np

# ── Lazy-load TensorFlow so Django can import this module
# ── even in environments where tf is not installed for admin commands.
_model = None
_backbone = None
_gap_layer = None

MODEL_PATH = os.path.join(
    os.path.dirname(__file__),  # Backend/complaints/
    "..", "..", "App Ai Module", "pothole_classifier.h5"
)
MODEL_PATH = os.path.normpath(MODEL_PATH)

# Mapping: model binary output → civic category names used in Complaint
# The classifier is a binary model (pothole / no_issue).
# For multi-class support extend this map.
CLASS_NAMES = ["pothole", "garbage", "water_leakage", "streetlight_damage"]


def _load_models():
    """Load the Keras model once and cache it in module-level globals."""
    global _model, _backbone, _gap_layer
    if _model is not None:
        return
    import tensorflow as tf
    _model = tf.keras.models.load_model(MODEL_PATH)
    # Layer 0 = MobileNetV2 backbone, Layer 1 = GlobalAveragePooling2D
    _backbone = _model.layers[0]
    _gap_layer = _model.layers[1]


def analyze_image(image_path: str):
    """
    Classify an image and extract its semantic embedding.

    Returns
    -------
    dict with keys:
      predicted_class : str   — one of CLASS_NAMES, or 'no_issue'
      confidence      : float — prediction confidence [0, 1]
      embedding       : np.ndarray shape (1280,) | None
    """
    import tensorflow as tf
    from tensorflow.keras.preprocessing import image as keras_image  # type: ignore
    from tensorflow.keras.applications.mobilenet_v2 import preprocess_input  # type: ignore

    _load_models()

    # ── 1. Pre-process image
    img = keras_image.load_img(image_path, target_size=(224, 224))
    img_array = keras_image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = preprocess_input(img_array).astype(np.float32)

    # ── 2. Classify
    raw_output = _model.predict(img_array, verbose=0)
    probability = float(raw_output[0][0])  # binary sigmoid output

    THRESHOLD = 0.65

    if probability < THRESHOLD:
        # Below threshold ⇒ no civic issue detected
        return {
            "predicted_class": "no_issue",
            "confidence": round(1.0 - probability, 4),
            "embedding": None,
        }

    # ── 3. Extract 1280-dim embedding from GlobalAveragePooling layer
    features = _backbone(img_array, training=False)
    embedding = _gap_layer(features).numpy()[0]          # shape: (1280,)
    norm = np.linalg.norm(embedding)
    if norm > 0:
        embedding = embedding / norm                     # L2-normalise

    # ── 4. Map probability to class name
    # Simple binary model → "pothole" when above threshold.
    # Extend with multi-class model for other categories.
    predicted_class = "pothole"

    return {
        "predicted_class": predicted_class,
        "confidence": round(probability, 4),
        "embedding": embedding,
    }
