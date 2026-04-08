import 'package:caloriewise/main_component/colors.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

class RecipeModal {
  static void show(
    BuildContext context,
    Map<String, dynamic> recipe, {
    required Function(Map<String, dynamic>) onAddToIntake,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              RecipeModalContent(recipe: recipe, onAddToIntake: onAddToIntake),
    );
  }
}

class RecipeModalContent extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final Function(Map<String, dynamic>) onAddToIntake;

  const RecipeModalContent({
    super.key,
    required this.recipe,
    required this.onAddToIntake,
  });

  @override
  State<RecipeModalContent> createState() => _RecipeModalContentState();
}

class _RecipeModalContentState extends State<RecipeModalContent> {
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.recipe['label'] == null)
                Text(
                  'WARNING: Missing recipe name',
                  style: TextStyle(color: Colors.red),
                ),
              // In RecipeModalContent's build method
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.recipe['label'] ?? 'Recipe Details',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isAdding ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildNutritionSection(widget.recipe),
              const SizedBox(height: 16),
              _buildSection(
                'Ingredients',
                _formatIngredients(widget.recipe['ingredient_lines']),
              ),
              const SizedBox(height: 16),
              _buildSection(
                'Instructions',
                widget.recipe['recipe_instructions']?.toString() ??
                    'Not available',
              ),
              const SizedBox(height: 24),
              _buildAddButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child:
              _isAdding
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: () => _showConfirmationDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                    ),
                    child: Text(
                      "Add to Intake",
                      style: TextStyle(color: kPrimaryColor),
                    ),
                  ),
        ),
      ],
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Add to Intake'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This will be added to your daily intake:'),
                const SizedBox(height: 12),
                Text('• Calories: ${widget.recipe['calories'] ?? 'N/A'}'),
                Text('• Protein: ${widget.recipe['protein'] ?? 'N/A'} g'),
                Text('• Carbs: ${widget.recipe['carbs'] ?? 'N/A'} g'),
                Text('• Fat: ${widget.recipe['fat'] ?? 'N/A'} g'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _handleAddToIntake(context),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );
  }

  Future<void> _handleAddToIntake(BuildContext context) async {
    if (_isAdding) return;

    setState(() => _isAdding = true);

    try {
      // Validate required fields
      final requiredFields = [
        'calories',
        'protein',
        'carbs',
        'fat',
        'recipe_id',
      ];
      final missingFields =
          requiredFields
              .where((field) => widget.recipe[field] == null)
              .toList();

      if (missingFields.isNotEmpty) {
        throw Exception('Missing required data: ${missingFields.join(', ')}');
      }

      // Close dialog
      Navigator.pop(context);
      Navigator.pop(context);

      // Prepare complete data
      final intakeData = {
        'log_date': DateTime.now().toIso8601String().substring(0, 10),
        'recipe_id': widget.recipe['recipe_id'],
        'recipe_name': widget.recipe['label'],
        'calories': widget.recipe['calories']?.toString() ?? '0',
        'fat': widget.recipe['fat']?.toString() ?? '0',
        'carbs': widget.recipe['carbs']?.toString() ?? '0',
        'protein': widget.recipe['protein']?.toString() ?? '0',
        'servings': widget.recipe['servings']?.toString() ?? '1',
        'fiber': widget.recipe['fiber']?.toString() ?? '0',
        'sugars': widget.recipe['sugars']?.toString() ?? '0',
        'sodium': widget.recipe['sodium']?.toString() ?? '0',
      };

      log('Sending intake data: $intakeData'); // Debug log

      await widget.onAddToIntake(intakeData);
      if (!context.mounted) return;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to intake successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Widget _buildNutritionSection(Map<String, dynamic> recipe) {
    final nutritionItems = [
      {'label': 'Calories', 'value': recipe['calories']?.toString() ?? 'N/A'},
      {'label': 'Servings', 'value': recipe['servings']?.toString() ?? 'N/A'},
      {'label': 'Protein (g)', 'value': recipe['protein']?.toString() ?? 'N/A'},
      {'label': 'Carbs (g)', 'value': recipe['carbs']?.toString() ?? 'N/A'},
      {'label': 'Fat (g)', 'value': recipe['fat']?.toString() ?? 'N/A'},
      {'label': 'Sugar (g)', 'value': recipe['sugars']?.toString() ?? 'N/A'},
      {'label': 'Fiber (g)', 'value': recipe['fiber']?.toString() ?? 'N/A'},
      {'label': 'Sodium (mg)', 'value': recipe['sodium']?.toString() ?? 'N/A'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 236, 234, 245),
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: nutritionItems.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 5,
          crossAxisSpacing: 18,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) {
          final item = nutritionItems[index];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item['label']}: ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(child: Text(item['value']!)),
            ],
          );
        },
      ),
    );
  }

  String _formatIngredients(dynamic ingredients) {
    if (ingredients == null) return 'Not available';
    if (ingredients is List) return '• ${ingredients.join('\n• ')}';
    return ingredients.toString();
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }
}
