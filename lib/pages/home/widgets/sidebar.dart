import 'package:flutter/material.dart';

class Sidebar extends StatefulWidget{
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isExpanded = true;
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: _isExpanded ? 260 : 80,
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          const SizedBox(height: 30),

          // --- HEADER SECTION ---
          SizedBox(
            height: 48,
            child: Stack(
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isExpanded ? 1.0 : 0.0,
                  child: const Center(
                    child: Text(
                      "SyncOS",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  right: _isExpanded ? 8 : 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _isExpanded ? Icons.menu_open : Icons.menu,
                          key: ValueKey(_isExpanded),
                        ),
                      ),
                      onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          
          // --- NAVIGATION ITEMS ---
          ValueListenableBuilder(
            valueListenable: _selectedIndex,
            builder: (context, value, child) {
              return Column(
                children: [
                _sidebarTile(Icons.dashboard, "Dashboard", 0, colorScheme),
                _sidebarTile(Icons.terminal, "Configure Commands", 1, colorScheme),
                _sidebarTile(Icons.notifications, "Notifications", 2, colorScheme),
                _sidebarTile(Icons.settings, "Settings", 3, colorScheme),
                ],
              );
            }
          ),

          const Spacer(),

          // --- PC STATUS CARD ---
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isExpanded ? 1.0 : 0.0,
            child: ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: Alignment.center,
                heightFactor: _isExpanded ? 1.0 : 0.0,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }


  Widget _sidebarTile(
    IconData icon, 
    String title, 
    int index, 
    ColorScheme colorScheme,
  ) {
    final bool selected = _selectedIndex.value == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          _selectedIndex.value = index;
        },
        borderRadius: BorderRadius.circular(28),
        hoverColor: colorScheme.onSecondary,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? colorScheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isExpanded ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}


