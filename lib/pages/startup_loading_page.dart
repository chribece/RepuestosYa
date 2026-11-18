import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StartupLoadingPage extends StatelessWidget {
  const StartupLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.primaryContainer,
          ),
        ),
      ),
    );
  }
}
