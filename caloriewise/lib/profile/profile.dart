import 'package:caloriewise/main_component/colors.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../main_component/nav.dart';
import 'package:caloriewise/main_component/side_bar.dart';
import 'package:caloriewise/profile/edit_profile.dart';

class ProfilePage extends StatefulWidget {
  final int accountId;

  const ProfilePage({super.key, required this.accountId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? metrics; // Add metrics to the state
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://10.0.2.2:5000/profile?account_id=${widget.accountId}',
        ),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        setState(() {
          userData = responseData['user_data'];
          metrics = responseData['metrics']; // Store metrics in the state
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  String _formatData(String data) {
    return data.replaceAll(', ', '\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavBar(),
      endDrawer: SideBar(accountId: widget.accountId),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        const SizedBox(height: 20),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                            const Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        const SizedBox(height: 20),
                        CircleAvatar(
                          radius: 70,
                          backgroundImage: AssetImage(
                            'assets/images/profile.jpg',
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Profile Data Table
                        Container(
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 201, 202, 252),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Table(
                            columnWidths: const {
                              0: FixedColumnWidth(150),
                              1: FixedColumnWidth(150),
                            },
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: [
                              _buildTableRow(
                                'Username:',
                                userData?['name']?.replaceAll('_', ' ') ??
                                    'N/A',
                              ),
                              _buildTableRow(
                                'Age:',
                                userData?['age'].toString() ?? 'N/A',
                              ),
                              _buildTableRow(
                                'Gender:',
                                userData?['gender'] ?? 'N/A',
                              ),
                              _buildTableRow(
                                'Weight:',
                                '${userData?['weight']} kg',
                              ),
                              _buildTableRow(
                                'Height:',
                                '${userData?['height']} cm',
                              ),
                              _buildTableRow(
                                'Goal:',
                                userData?['goal'] ?? 'N/A',
                              ),
                              _buildTableRow(
                                'Activity Level:',
                                userData?['activity_level'] ?? 'N/A',
                              ),
                              _buildTableRow(
                                'Diseases:',
                                userData?['diseases']?.join(', ') ?? 'N/A',
                              ),
                              _buildTableRow(
                                'Allergies:',
                                userData?['allergies']?.join(', ') ?? 'N/A',
                              ),
                            ],
                          ),
                        ),
                        // Display metrics if available
                        if (metrics != null) ...[
                          const SizedBox(height: 30),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 201, 202, 252),
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            child: Table(
                              columnWidths: const {
                                0: FixedColumnWidth(150),
                                1: FixedColumnWidth(150),
                              },
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                _buildTableRow(
                                  'BMI:',
                                  '${metrics!['bmi']} (${metrics!['bmi_category']})',
                                ),
                                _buildTableRow(
                                  'RMR:',
                                  '${metrics!['rmr']} kcal',
                                ),
                                _buildTableRow(
                                  'TDEE:',
                                  '${metrics!['tdee']} kcal',
                                ),
                                _buildTableRow(
                                  'Total Calories:',
                                  '${metrics!['total_calories']} kcal',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center, // Center the buttons
                              children: [
                                ElevatedButton(
                                  // In your ProfilePage's build method where you show the bottom sheet:
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20),
                                        ),
                                      ),
                                      builder:
                                          (context) => Padding(
                                            padding: EdgeInsets.only(
                                              bottom:
                                                  MediaQuery.of(
                                                    context,
                                                  ).viewInsets.bottom,
                                            ),
                                            child: EditProfile(
                                              userData: userData!,
                                              accountId: widget.accountId,
                                            ),
                                          ),
                                    ).then((result) {
                                      if (result != null) {
                                        setState(() {
                                          userData = result['user'];
                                          metrics = result['metrics'];
                                        });
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 50,
                                    ),
                                    backgroundColor: const Color.fromARGB(
                                      255,
                                      182,
                                      212,
                                      246,
                                    ),
                                  ),
                                  child: const Text(
                                    'Edit',
                                    style: TextStyle(color: kPrimaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            _formatData(_capitalize(value)),
            textAlign: TextAlign.right,
            style: GoogleFonts.lato(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
