from flask import Blueprint, request, jsonify
import pandas as pd
import os
import re

search_bp = Blueprint('search', __name__, url_prefix='/search')

# Load your dataset
DATASET_PATH = "C:/Users/USER/Documents/fyp2/dataset/recipe_dataset.csv"

try:
    recipe_df = pd.read_csv(DATASET_PATH)
    print(f"Loaded {len(recipe_df)} recipes.")
except Exception as e:
    print(f"Error loading dataset: {e}")
    recipe_df = pd.DataFrame()

@search_bp.route('', methods=['GET'])
def search_food():
    query = request.args.get('q', '').strip().lower()
    print(f"Search query: {query}")
    
    if not query or recipe_df.empty:
        return jsonify([])
    
    try:
        results = recipe_df[
            recipe_df['label'].str.lower().str.contains(query, na=False)
        ].head(20)
        
        # Ensure we return all required fields
        result_data = results[[
            'recipe_id', 
            'label', 
            'calories', 
            'fat', 
            'carbs', 
            'protein',
            'servings',
            'sugars',
            'fat',
            'carbs',
            'protein',
            'sodium',
            'fiber',
            'ingredient_lines',
            'recipe_instructions'
        ]].to_dict(orient='records')
        
        return jsonify(result_data)
        
    except Exception as e:
        print(f"Search error: {str(e)}")
        return jsonify({"error": str(e)}), 500
