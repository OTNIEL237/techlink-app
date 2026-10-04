import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class InviteFriendsScreen extends StatelessWidget {
  const InviteFriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for friends
    final List<Map<String, String>> friends = [
      {'name': 'Tynisha Obey', 'phone': '+1-300-555-0135'},
      {'name': 'Florencio Dorrance', 'phone': '+1-202-555-0136'},
      {'name': 'Chantal Shelburne', 'phone': '+1-300-555-0119'},
      {'name': 'Maryland Winkles', 'phone': '+1-300-555-0161'},
      {'name': 'Rodolfo Goode', 'phone': '+1-300-555-0136'},
      {'name': 'Benny Spanbauer', 'phone': '+1-202-555-0167'},
      {'name': 'Tyra Dhillon', 'phone': '+1-202-555-0119'},
      {'name': 'Jamel Eusebio', 'phone': '+1-300-555-0171'},
      {'name': 'Pedro Huard', 'phone': '+1-202-555-0171'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invite Friends', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    friend['name']![0],
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend['name']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        friend['phone']!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
