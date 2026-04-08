from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
import tensorflow as tf
from tensorflow import keras
from keras._tf_keras.keras.preprocessing.image import load_img, img_to_array
import numpy as np
import os

classify_bp = Blueprint('classify', __name__, url_prefix='/classify')

# Model configuration
MODEL_DIR = 'model'
MODEL_FILE = 'mobilenet_food_classifier.h5'
MODEL_PATH = os.path.join(MODEL_DIR, MODEL_FILE)

# Load model with error handling
try:
    model = tf.keras.models.load_model(MODEL_PATH)
    print(f"Successfully loaded model from {MODEL_PATH}")
except Exception as e:
    print(f"Error loading model from {MODEL_PATH}: {str(e)}")
    model = None

CLASS_NAMES = [
    "Apple Pie", "Baked Potato", "Burger", "Chai", 
    "Cheesecake", "Chicken Curry", "Crispy Chicken", "Donut", "Dumpling", 
    "Fried Rice", "Fries", "Hot Dog", "Ice Cream", "Naan", "Omelette", 
    "Pizza", "Samosa", "Sandwich", "Sushi", "Taco"
]

def preprocess_image(img_path, target_size=(224, 224)):
    """Load and preprocess an image for model prediction"""
    img = load_img(img_path, target_size=target_size)
    img_array = img_to_array(img)
    img_array = np.expand_dims(img_array, axis=0)
    img_array /= 255.0  
    return img_array

@classify_bp.route('', methods=['POST'])
def classify_food():
    # Check if model is loaded
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 500
    
    # Check file in request
    if 'image' not in request.files:
        return jsonify({'error': 'No image provided'}), 400
    
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No image selected'}), 400
    
    # Secure filename and create temp path
    filename = secure_filename(file.filename)
    temp_dir = 'tmp'
    os.makedirs(temp_dir, exist_ok=True)  # Create tmp dir if not exists
    temp_path = os.path.join(temp_dir, filename)
    
    try:
        # Save and process image
        file.save(temp_path)
        processed_image = preprocess_image(temp_path)
        
        # Make prediction
        predictions = model.predict(processed_image)
        predicted_class_idx = np.argmax(predictions[0])
        predicted_class = CLASS_NAMES[predicted_class_idx]
        confidence = float(np.max(predictions[0]))
        
        return jsonify({
            'prediction': predicted_class,
            'confidence': confidence,
            'confidence_percentage': f"{confidence * 100:.2f}%"
        })
        
    except Exception as e:
        return jsonify({'error': f"Prediction failed: {str(e)}"}), 500
        
    finally:
        # Clean up temp file
        if os.path.exists(temp_path):
            os.remove(temp_path)