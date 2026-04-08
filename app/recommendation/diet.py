import sys
import os
import ast
import json
import random
import pandas as pd
from typing import Dict, Optional, Tuple
from datetime import date, timedelta

# Add parent directory to sys.path to import db_functions
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from db_functions import connect_to_database 

class DietRecommendation:
    def __init__(self, user_id: str, recipe_csv_path: str):
        self.user_id = user_id
        self.recipe_csv_path = recipe_csv_path
        self.conn = connect_to_database()
        self.cursor = self.conn.cursor()
        self.df_recipes = None
        self.user_data = None
        self.filtered_recipes = None # Recipes filtered by diet/health labels
        self.macro_filtered_recipes = None # Recipes filtered by macronutrient split
        self.serving_variations = None
        self.combined_df = None # Stores all serving variations of macro_filtered_recipes
        self.weekly_plan = None # To store the generated weekly plan

    def load_recipe_data(self) -> None:
        """Load recipe data from CSV file"""
        try:
            self.df_recipes = pd.read_csv(self.recipe_csv_path)
            
            # Ensure required columns exist
            required_columns = ['recipe_id', 'label', 'health_labels', 'diet_labels', 'calories', 
                                 'fat', 'carbs', 'protein', 'servings']
            if not all(col in self.df_recipes.columns for col in required_columns):
                raise ValueError("CSV file is missing required columns. Ensure 'id' column exists.")
                
            # Handle potential NaN values in label columns before normalization
            for col in ['health_labels', 'diet_labels']:
                self.df_recipes[col] = self.df_recipes[col].fillna('')

        except FileNotFoundError:
            raise ValueError(f"Error: Recipe CSV file not found at {self.recipe_csv_path}")
        except Exception as e:
            raise ValueError(f"Error loading recipe data: {str(e)}")

    def load_user_data(self) -> None:
        """Load user data from database"""
        query = """
        SELECT meal_calories, total_calories, macronutrient_grams, 
               diet_labels, health_labels, macronutrient_split
        FROM matrices
        WHERE user_id = %s
        """
        try:
            self.cursor.execute(query, (self.user_id,))
            row = self.cursor.fetchone()
            
            if not row:
                raise ValueError(f"No matrix data found for user ID: {self.user_id}. Please ensure the user_id exists in the 'matrices' table.")
                
            self.user_data = {
                "meal_calories": json.loads(row[0]),
                "total_calories": float(row[1]),
                "macronutrient_grams": json.loads(row[2]),
                "diet_labels": ast.literal_eval(row[3]),
                "health_labels": ast.literal_eval(row[4]),
                "macronutrient_split": json.loads(row[5])
            }
        except json.JSONDecodeError as e:
            raise ValueError(f"Error decoding JSON from database for user {self.user_id}: {e}. Check 'meal_calories', 'macronutrient_grams', 'macronutrient_split' fields.")
        except Exception as e:
            raise ValueError(f"Error loading user data from database: {str(e)}")

    def filter_by_labels(self) -> None:
        """Filter recipes based on user's dietary and health preferences."""
        ignore_diet_labels = {'low-carb', 'low-fat', 'low-protein', 'high-protein'}

        def normalize_labels_func(label_str):
            if pd.isna(label_str) or label_str == '':
                return []
            return [label.strip().lower() for label in str(label_str).split(',')]

        self.df_recipes['normalized_health'] = self.df_recipes['health_labels'].apply(normalize_labels_func)
        self.df_recipes['normalized_diet'] = self.df_recipes['diet_labels'].apply(normalize_labels_func)

        user_health_labels_lower = [label.lower() for label in self.user_data['health_labels']]
        user_diet_labels_lower = [label.lower() for label in self.user_data['diet_labels']]

        def match_labels_func(row):
            health_match = not user_health_labels_lower or all(
                label in row['normalized_health'] for label in user_health_labels_lower
            )
            
            diet_labels_to_check = [
                label for label in user_diet_labels_lower
                if label not in ignore_diet_labels
            ]
            diet_match = not diet_labels_to_check or all(
                label in row['normalized_diet'] for label in diet_labels_to_check
            )
            
            return health_match and diet_match

        self.filtered_recipes = self.df_recipes[self.df_recipes.apply(match_labels_func, axis=1)].copy()
        if self.filtered_recipes.empty:
            raise ValueError("No recipes found after applying user's diet and health label filters. Please check your data or preferences.")
        
        print(f"Number of recipes after health/diet label filtering: {len(self.filtered_recipes)}")

    def filter_by_macronutrients(self, tolerance: int = 15) -> None:
        """
        Further filters recipes based on the user's target macronutrient ratio.
        Requires 'calories', 'fat', 'carbs', 'protein' columns.
        """
        if self.filtered_recipes is None or self.filtered_recipes.empty:
            raise ValueError("No recipes to filter by macronutrients. Run 'filter_by_labels' first.")

        macro_ratio = self.user_data['macronutrient_split']

        def matches_macro_split(row):
            if pd.isna(row['calories']) or row['calories'] <= 0 or \
               pd.isna(row['fat']) or pd.isna(row['carbs']) or pd.isna(row['protein']):
                return False

            fat_pct = (row['fat'] * 9) / row['calories'] * 100
            carbs_pct = (row['carbs'] * 4) / row['calories'] * 100
            protein_pct = (row['protein'] * 4) / row['calories'] * 100

            fat_ok = abs(fat_pct - macro_ratio['fat']) <= tolerance
            carbs_ok = abs(carbs_pct - macro_ratio['carbs']) <= tolerance
            protein_ok = abs(protein_pct - macro_ratio['protein']) <= tolerance

            return fat_ok and carbs_ok and protein_ok

        self.macro_filtered_recipes = self.filtered_recipes[
            self.filtered_recipes.apply(matches_macro_split, axis=1)
        ].copy()

        if self.macro_filtered_recipes.empty:
            raise ValueError("No recipes found matching the user's macronutrient ratio. Consider adjusting the tolerance or user macro targets.")
        
        print(f"Number of recipes after macronutrient ratio filtering: {len(self.macro_filtered_recipes)}")

    def create_serving_variations(self) -> None:
        """
        Create different serving size variations (1x, 1.5x, 2x) for each recipe.
        Uses recipes from `self.macro_filtered_recipes`.
        """
        if self.macro_filtered_recipes is None or self.macro_filtered_recipes.empty:
            raise ValueError("No recipes to create serving variations from. Run 'filter_by_macronutrients' first.")

        nutr_cols = ['calories', 'fat', 'carbs', 'protein','fiber', 'sugars', 'sodium']
        
        if 'servings' not in self.macro_filtered_recipes.columns:
            raise ValueError("Missing 'servings' column in macro-filtered recipes.")
        
        self.macro_filtered_recipes['servings'] = pd.to_numeric(self.macro_filtered_recipes['servings'], errors='coerce')
        self.macro_filtered_recipes.dropna(subset=['servings'], inplace=True)
        self.macro_filtered_recipes = self.macro_filtered_recipes[self.macro_filtered_recipes['servings'] > 0] # Avoid division by zero
        
        if self.macro_filtered_recipes.empty:
            raise ValueError("No valid recipes left after processing 'servings' column (e.g., all were non-numeric or zero).")

        for col in nutr_cols:
            self.macro_filtered_recipes[f'{col}_per_serving'] = self.macro_filtered_recipes[col] / self.macro_filtered_recipes['servings']

        all_variations = []
        for original_idx, row in self.macro_filtered_recipes.iterrows():
            base_servings = row['servings']
            
            for multiplier, suffix in [(1, '1x'), (1.5, '1.5x'), (2, '2x')]:
                variation = row.copy()
                variation['calculated_servings'] = base_servings * multiplier
                
                for col in nutr_cols:
                    variation[col] = row[f'{col}_per_serving'] * variation['calculated_servings']
                
                variation['servings_multiplier'] = suffix
                
                # Keep the original index so we can trace back to the unique recipe
                variation.name = original_idx 
                all_variations.append(variation)

        self.combined_df = pd.DataFrame(all_variations)
        
        # Drop temporary per_serving columns
        self.combined_df.drop(columns=[f'{col}_per_serving' for col in nutr_cols], errors='ignore', inplace=True)
        
        # Round numerical columns to one decimal place for presentation
        self.combined_df[nutr_cols + ['calculated_servings']] = self.combined_df[nutr_cols + ['calculated_servings']].round(1)

        if self.combined_df.empty:
            raise ValueError("No valid serving variations could be created. Check your recipe data and serving values.")
        
        print(f"Created {len(self.combined_df)} serving variations from filtered recipes.")

    @staticmethod
    def percent_diff(actual: float, target: float) -> str:
        """Calculate percentage difference from target"""
        if target == 0:
            return "N/A (Target is 0)"
        return f"{((actual - target) / target) * 100:+.1f}%"

    def select_meals(self, max_attempts: int = 1000, dataframe: Optional[pd.DataFrame] = None) -> Optional[Tuple[Dict, Dict]]:
        """
        Select meals that match calorie and macro targets from a given DataFrame.
        Returns tuple of (selected_meals, totals) or None if no match found.
        """
        df_to_use = dataframe if dataframe is not None else self.combined_df
        
        if df_to_use is None or df_to_use.empty:
            return None # No recipes available to select from

        target_meal_cal = self.user_data['meal_calories']
        target_total_cal = self.user_data['total_calories']
        target_fat = self.user_data['macronutrient_grams']['fat_grams']
        target_carbs = self.user_data['macronutrient_grams']['carbs_grams']
        target_protein = self.user_data['macronutrient_grams']['protein_grams']

        # Calculate tolerances
        cal_tol = target_total_cal * 0.05 # 5% tolerance for total calories
        fat_tol = target_fat * 0.10      # 10% tolerance for macros
        carbs_tol = target_carbs * 0.10
        protein_tol = target_protein * 0.10
        
        # Dynamically determine meal types and ensure a logical order
        all_possible_meal_order = ['breakfast', 'brunch', 'lunch', 'dinner', 'snack']
        dynamic_meal_types_for_day = [
            meal_type for meal_type in all_possible_meal_order
            if meal_type in target_meal_cal
        ]
        
        if not dynamic_meal_types_for_day:
            print("Warning: No meal types defined in user_data['meal_calories']. Skipping meal selection.")
            return None

        for _ in range(max_attempts):
            selected = {}
            totals = {'calories': 0, 'fat': 0, 'carbs': 0, 'protein': 0}
            used_original_indices_for_day = set() 
            success = True

            for i, meal_type in enumerate(dynamic_meal_types_for_day):
                target_cal_for_meal_type = target_meal_cal[meal_type]
                lower_cal = target_cal_for_meal_type * 0.95
                upper_cal = target_cal_for_meal_type * 1.05
                
                candidates = df_to_use[
                    (df_to_use['calories'] >= lower_cal) & 
                    (df_to_use['calories'] <= upper_cal) &
                    (~df_to_use.index.isin(used_original_indices_for_day))
                ]
                
                if candidates.empty:
                    success = False
                    break # Cannot find a suitable meal for this type

                found_meal_for_type = False
                for original_idx, meal_data_row in candidates.sample(frac=1, random_state=random.randint(0, 10000)).iterrows():
                    temp_totals = {
                        'calories': totals['calories'] + meal_data_row['calories'],
                        'fat': totals['fat'] + meal_data_row['fat'],
                        'carbs': totals['carbs'] + meal_data_row['carbs'],
                        'protein': totals['protein'] + meal_data_row['protein']
                    }
                    
                    is_last_meal_in_sequence = (i == len(dynamic_meal_types_for_day) - 1)
                    
                    if is_last_meal_in_sequence:
                        if (abs(temp_totals['calories'] - target_total_cal) <= cal_tol and
                            abs(temp_totals['fat'] - target_fat) <= fat_tol and
                            abs(temp_totals['carbs'] - target_carbs) <= carbs_tol and
                            abs(temp_totals['protein'] - target_protein) <= protein_tol):
                            
                            selected[meal_type] = {
                                'recipe_id': self.macro_filtered_recipes.loc[original_idx, 'recipe_id'], # Retrieve recipe_id
                                'recipe_name': self.macro_filtered_recipes.loc[original_idx, 'label'], 
                                'servings': meal_data_row['calculated_servings'], 
                                'calories': meal_data_row['calories'],
                                'fat': meal_data_row['fat'],
                                'carbs': meal_data_row['carbs'],
                                'protein': meal_data_row['protein'],
                                'fiber': meal_data_row['fiber'],
                                'sugars': meal_data_row['sugars'],
                                'sodium': meal_data_row['sodium'],
                                'original_index': original_idx 
                            }
                            totals = temp_totals
                            used_original_indices_for_day.add(original_idx) 
                            found_meal_for_type = True
                            break 
                    else:
                        selected[meal_type] = {
                            'recipe_id': self.macro_filtered_recipes.loc[original_idx, 'recipe_id'], # Retrieve recipe_id
                            'recipe_name': self.macro_filtered_recipes.loc[original_idx, 'label'], 
                            'servings': meal_data_row['calculated_servings'], 
                            'calories': meal_data_row['calories'],
                            'fat': meal_data_row['fat'],
                            'carbs': meal_data_row['carbs'],
                            'protein': meal_data_row['protein'],
                            'fiber': meal_data_row['fiber'],
                            'sugars': meal_data_row['sugars'],
                            'sodium': meal_data_row['sodium'],
                            'original_index': original_idx 
                        }
                        totals = temp_totals
                        used_original_indices_for_day.add(original_idx) 
                        found_meal_for_type = True
                        break 

                if not found_meal_for_type:
                    success = False
                    break 

            if success:
                return selected, totals
        
        return None

    def generate_weekly_plan(self) -> Dict:
        """Generate a 7-day meal plan with unique recipes each day"""
        weekly_plan = {}
        weekly_used_recipe_indices = set() 

        for day_num in range(7): # 0 to 6 for 7 days
            current_date = date.today() + timedelta(days=1 + day_num) # Start tomorrow, then next 6 days
            day_key = f"Day {day_num + 1}"
            
            # 1. Filter the combined_df to exclude recipes already used in the week
            available_recipes_for_day = self.combined_df[~self.combined_df.index.isin(weekly_used_recipe_indices)]
            
            result = self.select_meals(dataframe=available_recipes_for_day)
            
            if result:
                selected_meals_for_day, totals_for_day = result
                weekly_plan[day_key] = {
                    'date': current_date, # Store the date for this day
                    'meals': selected_meals_for_day,
                    'totals': totals_for_day
                }
                for meal_info in selected_meals_for_day.values():
                    weekly_used_recipe_indices.add(meal_info['original_index'])
            else:
                print(f"Could not find valid unique meals for {day_key} ({current_date}). Attempting with potential recipe reuse for this day.")
                result_reuse = self.select_meals(dataframe=self.combined_df) 
                if result_reuse:
                    selected_meals_for_day, totals_for_day = result_reuse
                    weekly_plan[day_key] = {
                        'date': current_date, # Store the date for this day
                        'meals': selected_meals_for_day,
                        'totals': totals_for_day
                    }
                    for meal_info in selected_meals_for_day.values():
                        weekly_used_recipe_indices.add(meal_info['original_index'])
                else:
                    print(f"Failed to generate a complete meal plan for {day_key} ({current_date}) even with recipe reuse. This day will be empty.")
                    weekly_plan[day_key] = {
                        'date': current_date,
                        'meals': {},
                        'totals': {'calories': 0, 'fat': 0, 'carbs': 0, 'protein': 0}
                    }
        self.weekly_plan = weekly_plan # Store the generated plan
        return weekly_plan

    def calculate_and_print_weekly_summary(self) -> None:
        """Calculates and prints the weekly summary and difference from targets."""
        if not self.weekly_plan:
            print("No weekly plan generated yet to summarize.")
            return

        target_total_calories = self.user_data['total_calories']
        target_fat = self.user_data['macronutrient_grams']['fat_grams']
        target_carbs = self.user_data['macronutrient_grams']['carbs_grams']
        target_protein = self.user_data['macronutrient_grams']['protein_grams']

        weekly_totals = {'calories': 0, 'fat': 0, 'carbs': 0, 'protein': 0}

        for content in self.weekly_plan.values():
            for key in weekly_totals:
                weekly_totals[key] += content['totals'][key]

        print("\n=== Weekly Totals ===")
        print(f"Calories: {weekly_totals['calories']:.1f} kcal")
        print(f"Fat: {weekly_totals['fat']:.1f} g")
        print(f"Carbs: {weekly_totals['carbs']:.1f} g")
        print(f"Protein: {weekly_totals['protein']:.1f} g")

        print("\n=== Weekly Targets ===")
        print(f"Calories: {target_total_calories * 7:.1f} kcal")
        print(f"Fat: {target_fat * 7:.1f} g")
        print(f"Carbs: {target_carbs * 7:.1f} g")
        print(f"Protein: {target_protein * 7:.1f} g")

        print("\n=== % Difference from Weekly Targets ===")
        print(f"Calories: {self.percent_diff(weekly_totals['calories'], target_total_calories * 7)}")
        print(f"Fat: {self.percent_diff(weekly_totals['fat'], target_fat * 7)}")
        print(f"Carbs: {self.percent_diff(weekly_totals['carbs'], target_carbs * 7)}")
        print(f"Protein: {self.percent_diff(weekly_totals['protein'], target_protein * 7)}")


    def print_weekly_plan(self, weekly_plan: Dict) -> None:
        """Print the weekly plan in the requested format"""
        target_total_cal = self.user_data['total_calories']
        target_fat = self.user_data['macronutrient_grams']['fat_grams']
        target_carbs = self.user_data['macronutrient_grams']['carbs_grams']
        target_protein = self.user_data['macronutrient_grams']['protein_grams']

        # Get the actual meal types the user has defined in their plan
        user_meal_types_ordered = [
            meal_type for meal_type in ['breakfast', 'brunch', 'lunch', 'dinner', 'snack']
            if meal_type in self.user_data['meal_calories']
        ]

        for day, content in weekly_plan.items():
            print(f"\n{'-'*50}") # Separator for days
            print(f"{day} ({content['date'].strftime('%Y-%m-%d')})") # Print date
            meals = content['meals']
            totals = content['totals']

            for meal_type in user_meal_types_ordered:
                if meal_type in meals:
                    meal = meals[meal_type]
                    print(f"{meal_type.title()}: {meal['recipe_name']} ({meal['calories']:.1f} cal, "
                          f"{meal['servings']:.1f} servings, {meal['fat']:.1f}g fat, "
                          f"{meal['carbs']:.1f}g carbs, {meal['protein']:.1f}g protein, , {meal['fiber']:.1f}g fiber, {meal['sugars']:.1f}g sugars, {meal['sodium']:.1f}g sodium)")
                else:
                    print(f"{meal_type.title()}: No meal selected")

            print("\n--- Daily Totals ---")
            print(f"Calories: {totals['calories']:.1f} kcal")
            print(f"Fat: {totals['fat']:.1f} g")
            print(f"Carbs: {totals['carbs']:.1f} g")
            print(f"Protein: {totals['protein']:.1f} g")

            print("\n--- % Difference from Target ---")
            print(f"Calories: {self.percent_diff(totals['calories'], target_total_cal)}")
            print(f"Fat: {self.percent_diff(totals['fat'], target_fat)}")
            print(f"Carbs: {self.percent_diff(totals['carbs'], target_carbs)}")
            print(f"Protein: {self.percent_diff(totals['protein'], target_protein)}")
        
        self.calculate_and_print_weekly_summary() # Call summary after printing daily plans


    def save_plan_to_db(self) -> None:
        """
        Saves the generated weekly meal plan with smart regeneration logic:
        - Before end date: Updates existing plan while preserving completed meals
        - After end date: Creates new plan
        """
        if not self.weekly_plan:
            raise ValueError("No weekly plan generated to save")

        # Calculate totals and dates
        weekly_totals = {k: sum(d['totals'][k] for d in self.weekly_plan.values()) 
                        for k in ['calories', 'fat', 'carbs', 'protein']}
        
        today = date.today()
        date_generated = today
        start_date = today + timedelta(days=1)
        end_date = start_date + timedelta(days=6)

        try:
            # 1. Check for existing active plan
            self.cursor.execute(
                """SELECT id, end_date FROM weekly_diet_plan 
                WHERE user_id = %s AND is_active = TRUE""",
                (self.user_id,)
            )
            existing_plan = self.cursor.fetchone()

            if existing_plan:
                weekly_plan_id, existing_end_date = existing_plan
                
                if existing_end_date >= today:  # Current plan still active
                    print(f"Updating existing plan (ID: {weekly_plan_id})")
                    self._update_existing_plan(weekly_plan_id, date_generated, start_date, 
                                            end_date, weekly_totals)
                    self._update_daily_meals(weekly_plan_id)
                else:  # Plan has expired
                    print(f"Current plan expired, creating new one")
                    self._deactivate_old_plan(weekly_plan_id)
                    weekly_plan_id = self._create_new_plan(date_generated, start_date, 
                                                        end_date, weekly_totals)
                    self._insert_new_daily_meals(weekly_plan_id)
            else:  # No existing plan
                print("No existing plan found, creating new one")
                weekly_plan_id = self._create_new_plan(date_generated, start_date, 
                                                    end_date, weekly_totals)
                self._insert_new_daily_meals(weekly_plan_id)

            self.conn.commit()
            
        except Exception as e:
            self.conn.rollback()
            raise ValueError(f"Error saving meal plan: {e}")

    def _update_existing_plan(self, plan_id, date_generated, start_date, end_date, totals):
        """Update metadata of existing weekly plan"""
        self.cursor.execute(
            """UPDATE weekly_diet_plan
            SET date_generated = %s,
                start_date = %s,
                end_date = %s,
                plan_calories = %s ,
                plan_fats = %s,
                plan_carbs = %s,
                plan_protein = %s,
                updated_at = NOW()
            WHERE id = %s""",
            (date_generated, start_date, end_date,
            totals['calories'], totals['fat'],
            totals['carbs'], totals['protein'], 
            plan_id)
        )

    def _deactivate_old_plan(self, plan_id):
        """Mark old plan as inactive"""
        self.cursor.execute(
            "UPDATE weekly_diet_plan SET is_active = FALSE WHERE id = %s",
            (plan_id,)
        )

    def _create_new_plan(self, date_generated, start_date, end_date, totals):
        """Create a brand new weekly plan"""
        self.cursor.execute(
            """INSERT INTO weekly_diet_plan
            (user_id, start_date, end_date, date_generated,
             plan_calories, plan_fats, plan_carbs, plan_protein)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
            (self.user_id, start_date, end_date, date_generated,
             totals['calories'], totals['fat'],
             totals['carbs'], totals['protein'])
        )
        # For MySQL, retrieve the last inserted ID using cursor.lastrowid
        return self.cursor.lastrowid

    def _update_daily_meals(self, weekly_plan_id):
        """Update daily meals for existing plan, updating all days regardless of date."""
        for day_key, day_data in self.weekly_plan.items():
            current_date = day_data['date']

            for meal_type, meal_info in day_data['meals'].items():
                self.cursor.execute(
                    """INSERT INTO daily_meal_plan
                    (weekly_plan_id, plan_date, meal_type,
                    recipe_id, recipe_name, servings,
                    target_cal, target_fat, target_carbs, target_protein, target_fiber, target_sugar, target_sodium)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE
                        recipe_id = VALUES(recipe_id),
                        recipe_name = VALUES(recipe_name),
                        servings = VALUES(servings),
                        target_cal = VALUES(target_cal),
                        target_fat = VALUES(target_fat),
                        target_carbs = VALUES(target_carbs),
                        target_protein = VALUES(target_protein),
                        target_fiber = VALUES(target_fiber),
                        target_sugar = VALUES(target_sugar),
                        target_sodium = VALUES(target_sodium)""",
                    (
                        weekly_plan_id, current_date, meal_type,
                        int(meal_info['recipe_id']), meal_info['recipe_name'],
                        float(meal_info['servings']), float(meal_info['calories']),
                        float(meal_info['fat']), float(meal_info['carbs']),
                        float(meal_info['protein']), float(meal_info['fiber']), 
                        float(meal_info['sugars']), float(meal_info['sodium'],)
                    )
                )


    def _insert_new_daily_meals(self, weekly_plan_id):
        """Insert all meals for a new plan"""
        for day_key, day_data in self.weekly_plan.items():
            current_date = day_data['date']
            
            for meal_type, meal_info in day_data['meals'].items():
                self.cursor.execute(
                    """INSERT INTO daily_meal_plan
                    (weekly_plan_id, plan_date, meal_type,
                    recipe_id, recipe_name, servings,
                    target_cal, target_fat, target_carbs, target_protein, target_fiber, target_sugar, target_sodium)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                    (weekly_plan_id, current_date, meal_type,
                    int(meal_info['recipe_id']), meal_info['recipe_name'],
                    float(meal_info['servings']), float(meal_info['calories']),
                    float(meal_info['fat']), float(meal_info['carbs']),
                    float(meal_info['protein']), float(meal_info['fiber']), 
                    float(meal_info['sugars']), float(meal_info['sodium'],))
                )

    def log_daily_plan(self):
        """
        Log the planned daily values from the current weekly_plan into daily_log table.
        Assumes self.weekly_plan is a dict keyed by day with 'totals' containing daily totals.
        """
        try:
            for day_key, day_data in self.weekly_plan.items():
                plan_date = day_data['date']
                totals = day_data['totals']

                self.cursor.execute(
                    """INSERT INTO daily_log
                    (user_id, log_date, total_calories, total_fat, total_carbs, total_protein, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, NOW(), NOW())
                    ON DUPLICATE KEY UPDATE
                        total_calories=VALUES(total_calories),
                        total_fat=VALUES(total_fat),
                        total_carbs=VALUES(total_carbs),
                        total_protein=VALUES(total_protein),
                        updated_at=NOW()""",
                    (self.user_id, plan_date, totals['calories'], totals['fat'], totals['carbs'], totals['protein'])
                )
            self.conn.commit()
            print("Logged daily planned totals into daily_log table.")
        except Exception as e:
            self.conn.rollback()
            print(f"Error logging daily plan to daily_log: {e}")


    def update_actual_intake(self, log_date: date, actual_values: dict):
        """Update the actual intake values for a specific date in daily_log."""
        try:
            self.cursor.execute(
                """UPDATE daily_log
                SET actual_calories = %s,
                    actual_fat = %s,
                    actual_carbs = %s,
                    actual_protein = %s,
                    updated_at = NOW()
                WHERE user_id = %s AND log_date = %s""",
                (
                    actual_values.get('calories', 0),
                    actual_values.get('fat', 0),
                    actual_values.get('carbs', 0),
                    actual_values.get('protein', 0),
                    self.user_id,
                    log_date
                )
            )
            self.conn.commit()
        except Exception as e:
            self.conn.rollback()
            raise ValueError(f"Error updating actual intake: {str(e)}")

    def get_progress_data(self, start_date: date, end_date: date):
        """Get progress data (planned vs actual) for a date range."""
        try:
            self.cursor.execute(
                """SELECT log_date, total_calories, actual_calories,
                        total_fat, actual_fat,
                        total_carbs, actual_carbs,
                        total_protein, actual_protein
                FROM daily_log
                WHERE user_id = %s
                    AND log_date BETWEEN %s AND %s
                ORDER BY log_date""",
                (self.user_id, start_date, end_date)
            )
            return self.cursor.fetchall()
        except Exception as e:
            raise ValueError(f"Error fetching progress data: {str(e)}")



    def close_connection(self) -> None:
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()

if __name__ == "__main__":
    USER_ID = "U66"
    RECIPE_CSV_PATH = 'C://Users//USER//Documents//fyp2//dataset//recipe_dataset.csv'

    recommender = None
    try:
        recommender = DietRecommendation(USER_ID, RECIPE_CSV_PATH)
        print("Loading recipe data...")
        recommender.load_recipe_data()
        print("Loading user data...")
        recommender.load_user_data()
        
        print("Filtering recipes based on diet and health preferences...")
        recommender.filter_by_labels()
        
        print("Further filtering recipes based on macronutrient ratios...")
        recommender.filter_by_macronutrients()

        print("Creating serving variations for filtered recipes...")
        recommender.create_serving_variations()
        
        if recommender.combined_df.empty:
            raise ValueError("No recipes available after creating serving variations. Check recipe filters and data.")

        print("Generating weekly meal plan...")
        weekly_plan = recommender.generate_weekly_plan()
        
        print(f"\n{'='*50}")
        print("Final Weekly Meal Plan Report")
        print(f"{'='*50}")
        recommender.print_weekly_plan(weekly_plan)
        print(f"\n{'='*50}")

        # Save plan to DB (existing function, creates weekly_plan record + daily meals)
        recommender.save_plan_to_db()

        # NEW: Log the daily totals to daily_log table for progress tracking
        recommender.log_daily_plan()

    except ValueError as ve:
        print(f"\nConfiguration/Data Error: {str(ve)}")
    except Exception as e:
        print(f"\nAn unexpected error occurred: {str(e)}")
    finally:
        if recommender:
            recommender.close_connection()
            print("\nDatabase connection closed.")

