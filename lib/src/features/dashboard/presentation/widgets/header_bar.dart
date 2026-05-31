import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../admin_login_page.dart';

class HeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          const Icon(LucideIcons.plane, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            'Air Traffic Control Dashboard',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.bell),
          onPressed: () {},
        ),
        const SizedBox(width: 8),

        // 👉 Icône utilisateur cliquable
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminLoginPage(),
                ),
              );
            },
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryBlue,
              child: Icon(
                LucideIcons.user,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
