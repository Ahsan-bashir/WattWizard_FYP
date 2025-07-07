import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AISuggestionScreen extends StatelessWidget {
  const AISuggestionScreen({super.key});

  Future<List<String>> fetchSuggestions() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('wattwizard')
        .doc('2kRlWsYQuZjqEVI0TevS')
        .get();

    final data = docSnapshot.data();
    if (data != null && data['ai_suggestion'] is Map) {
      final Map suggestionsMap = data['ai_suggestion'];
      return suggestionsMap.values.map((e) => e.toString()).toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Suggestions"),
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFFEFF5F5),
            child: const Column(
              children: [
                Text(
                  "AI Assistant",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E425E),
                  ),
                ),
              ],
            ),
          ),

          // Suggestions
          Expanded(
            child: FutureBuilder<List<String>>(
              future: fetchSuggestions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading suggestions"));
                }

                final suggestions = snapshot.data ?? [];
                if (suggestions.isEmpty) {
                  return const Center(child: Text("No suggestions available."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    return Column(
                      children: [
                        _buildSuggestionBubble(suggestions[index]),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: const Color(0xFFEFF5F5),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Type your query...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF1E425E)),
                  onPressed: () {
                    // Handle user input if needed
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E425E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
