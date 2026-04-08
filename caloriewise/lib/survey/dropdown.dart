import 'package:caloriewise/main_component/colors.dart';
import 'package:flutter/material.dart';

class DropdownField extends StatefulWidget {
  final String label;
  final List<String> items;
  final String? initialValue;
  final Function(String) onChanged;

  const DropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.initialValue,
  });

  @override
  State<StatefulWidget> createState() => _DropdownFieldState();
}

class _DropdownFieldState extends State<DropdownField> {
  String? selectedValue;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    selectedValue = widget.initialValue ?? widget.items.first;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label above the dropdown
        Text(
          widget.label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),

        // Row for displaying the current selected value and dropdown button
        GestureDetector(
          onTap: () {
            setState(() {
              _isDropdownOpen = !_isDropdownOpen;
            });
          },
          child: Row(
            children: [
              // Text showing the selected value (aligned with the label)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 15,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(width: 1, color: kPrimaryColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      selectedValue ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Dropdown button to toggle the dropdown menu
              Icon(
                _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 24,
                color: kPrimaryColor,
              ),
            ],
          ),
        ),

        // If dropdown is open, show list of items with a smooth drop effect
        if (_isDropdownOpen)
          ClipRRect(
            borderRadius: BorderRadius.circular(
              15,
            ), // Apply the radius clipping here
            child: Material(
              elevation: 0, // Remove any shadows or white space
              color:
                  Colors
                      .transparent, // Make the Material background transparent
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    95,
                    184,
                    222,
                    255,
                  ), // Background color
                ),
                child: Column(
                  children:
                      widget.items.map((String value) {
                        return ListTile(
                          title: Text(value),
                          onTap: () {
                            setState(() {
                              selectedValue = value;
                              _isDropdownOpen =
                                  false; // Close dropdown after selection
                            });
                            widget.onChanged(value);
                          },
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
