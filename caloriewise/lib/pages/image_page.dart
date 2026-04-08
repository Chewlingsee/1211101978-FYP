import 'dart:io';
import 'dart:developer';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:caloriewise/main_component/nav.dart';
import 'package:caloriewise/main_component/side_bar.dart';
import 'package:caloriewise/pages/search/recipe_card.dart';
import 'package:caloriewise/pages/search/recipe_modal.dart';

class ImagePage extends StatefulWidget {
  final int accountId;
  const ImagePage({super.key, required this.accountId});

  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  File? _selectedImage;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  final SearchController _searchController = SearchController();

  final List<Color> _cardColors = [
    Colors.blue.shade50,
    Colors.green.shade50,
    Colors.orange.shade50,
    Colors.purple.shade50,
    Colors.teal.shade50,
  ];

  List<Map<String, dynamic>> _searchResults = [];

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _isLoading = true;
      _searchResults = [];
    });

    await _classifyImage(_selectedImage!);
  }

  Future<void> _addRecipeToIntake(
    BuildContext context,
    Map<String, dynamic> recipe,
  ) async {
    try {
      // First get user_id from account_id
      final userResponse = await http.get(
        Uri.parse(
          'http://10.0.2.2:5000/profile/user_id?account_id=${widget.accountId}',
        ),
      );

      if (userResponse.statusCode != 200) {
        throw Exception('Failed to fetch user ID');
      }

      final userId = json.decode(userResponse.body)['user_id'];

      // Prepare complete intake data with proper field mapping
      final intakeData = {
        'user_id': userId,
        'log_date': DateTime.now().toIso8601String().substring(0, 10),
        'recipe_id': recipe['recipe_id'],
        'recipe_name':
            recipe['label'] ?? recipe['recipe_name'] ?? 'Unnamed Recipe',
        'calories': recipe['calories'],
        'fat': recipe['fat'],
        'carbs': recipe['carbs'],
        'protein': recipe['protein'],
        'servings': recipe['servings'] ?? 1,
        'fiber': recipe['fiber'] ?? 0,
        'sugars': recipe['sugars'] ?? 0,
        'sodium': recipe['sodium'] ?? 0,
      };

      log('Sending intake data: $intakeData'); // Debug log

      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/diet/log_intake'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(intakeData),
      );
      if (!context.mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${recipe['recipe_name']} to your intake'),
          ),
        );
      } else {
        throw Exception('Failed to save intake: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add: ${e.toString()}')));
    }
  }

  Future<void> _classifyImage(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:5000/classify'),
      );

      var stream = http.ByteStream(imageFile.openRead().cast<List<int>>());
      var length = await imageFile.length();
      var multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: basename(imageFile.path),
      );

      request.files.add(multipartFile);
      var response = await request.send();

      if (response.statusCode == 200) {
        final responseString = await response.stream.bytesToString();
        final result = json.decode(responseString);

        final prediction = result['prediction'];
        _searchController.text = prediction;
        await _searchRecipes(prediction);
      }
    } catch (e) {
      log('Classification failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchRecipes(String query) async {
    debugPrint("Searching for: $query");
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/search?q=$query'),
      );

      debugPrint("Response status: ${response.statusCode}");
      debugPrint("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
  }

  Future<List<String>> _getSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/search?q=$query'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint(
          "Suggestions received: ${data.length} items",
        ); // Add debug print
        return data.map<String>((e) => e['label']?.toString() ?? '').toList();
      }
      return [];
    } catch (e) {
      debugPrint("Suggestion error: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavBar(),
      endDrawer: SideBar(accountId: widget.accountId),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    _selectedImage != null
                        ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        )
                        : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 50,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add image',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo),
                    label: const Text("Gallery"),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SearchAnchor(
              searchController: _searchController,
              builder: (BuildContext context, SearchController controller) {
                return SearchBar(
                  controller: controller,
                  hintText: 'Search or upload food',
                  onTap: () => controller.openView(),
                  onChanged: (value) async {
                    if (value.isNotEmpty) {
                      controller.openView();
                    }
                  },
                  trailing: [
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed:
                              () => _searchRecipes(_searchController.text),
                        ),
                  ],
                );
              },
              suggestionsBuilder: (
                BuildContext context,
                SearchController controller,
              ) async {
                final suggestions = await _getSuggestions(controller.text);
                return suggestions.map((item) {
                  return ListTile(
                    title: Text(item),
                    onTap: () {
                      controller.closeView(item);
                      _searchController.text = item;
                      _searchRecipes(item);
                    },
                  );
                }).toList();
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child:
                  _searchResults.isEmpty
                      ? const Center(child: Text("No results"))
                      : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return // In ImagePage's build method
                          RecipeCard(
                            recipe: {
                              ...item, // Spread all original fields
                              'label':
                                  item['label'] ??
                                  item['recipe_name'] ??
                                  'Unnamed Recipe',
                              'recipe_id':
                                  item['recipe_id'], // Ensure ID is preserved
                            },
                            cardColor: _cardColors[index % _cardColors.length],
                            onTap:
                                () => RecipeModal.show(
                                  context,
                                  {
                                    ...item, // Spread all original fields
                                    'label':
                                        item['label'] ??
                                        item['recipe_name'] ??
                                        'Unnamed Recipe',

                                    'recipe_id':
                                        item['recipe_id'], // Ensure ID is preserved
                                  },
                                  onAddToIntake:
                                      (recipe) =>
                                          _addRecipeToIntake(context, recipe),
                                ),
                          );
                        },
                        separatorBuilder:
                            (context, index) => const SizedBox(height: 16),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
