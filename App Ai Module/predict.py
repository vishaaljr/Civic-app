import numpy as np
import tensorflow as tf
from tensorflow.keras.preprocessing import image # type: ignore
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input # type: ignore

# -------------------------
# Load trained classifier
# -------------------------
model = tf.keras.models.load_model("pothole_classifier.h5")

# -------------------------
# Extract backbone + pooling layer
# -------------------------
backbone = model.layers[0]   # MobileNetV2
gap_layer = model.layers[1]  # GlobalAveragePooling2D

# -------------------------
# Image preprocessing
# -------------------------
def process_image(img_path):
    img = image.load_img(img_path, target_size=(224, 224))
    img_array = image.img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)
    img_array = preprocess_input(img_array)
    return img_array


# -------------------------
# Classification + Embedding
# -------------------------
def predict_and_embed(img_path, threshold=0.7):
    try:
        img_array = process_image(img_path)

        # Classification
        probability = model.predict(img_array)[0][0]
        print(f"\nRaw Probability: {probability:.4f}")

        if probability > threshold:
            print("Prediction: POTHOLE")

            # Embedding extraction
            
            features = backbone(img_array, training=False)
            embedding = gap_layer(features).numpy()[0]
            embedding = embedding / np.linalg.norm(embedding)

            print(f"Embedding shape: {embedding.shape}")
            print("First 10 embedding values:")
            print(embedding[:10])

            return {
                "class": "pothole",
                "confidence": float(probability),
                "embedding": embedding
            }

        else:
            print("Prediction: NORMAL ROAD")
            return {
                "class": "normal",
                "confidence": float(1 - probability),
                "embedding": None
            }

    except Exception as e:
        print("Error:", e)


# -------------------------
# Interactive loop
# -------------------------
while True:
    img_path = input("\nEnter image path (or type 'exit'): ")

    if img_path.lower() == "exit":
        break

    predict_and_embed(img_path)