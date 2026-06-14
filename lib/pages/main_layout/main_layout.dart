// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:syncos_linux/pages/home/home_screen.dart';
import 'package:syncos_linux/pages/settings/settings_screen.dart';
import 'ui/sidebar.dart'; 
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0; // The source of truth

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _currentIndex, 
            onItemSelected: (index) {
              setState(() => _currentIndex = index); 
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                HomeScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}