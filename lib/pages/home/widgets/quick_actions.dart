// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/material.dart';
import '../../../models/dashboard_item.dart';
import '../../../theme/app_theme.dart';

class DashboardGrid extends StatelessWidget {
  final List<DashboardItem> items;
  
  final double borderRadius = AppTheme.borderRadius;
  final double spacing = AppTheme.spacing;
  final double padding = AppTheme.padding;

  
  // Layout Breakpoints & Grid Extents
  static const double compactBreakpoint = 550.0;
  static const int gridCrossAxisCount = 3;
  static const double gridMainAxisExtent = 230.0;
  
  // Typography Sizes
  static const double titleFontSize = 20.0;
  static const double gridLabelFontSize = 18.0;
  static const double gridSubLabelFontSize = 13.0;
  static const double listLabelFontSize = 16.0;
  static const double listSubLabelFontSize = 12.0;
  
  // Icon and Inner Widget Sizes
  static const double gridMainIconSize = 26.0;
  static const double listMainIconSize = 22.0;
  static const double actionArrowIconSizeGrid = 18.0;
  static const double actionArrowIconSizeList = 16.0;
  
  static const double iconContainerPadding = 10.0;
  static const double actionArrowPadding = 8.0;
  static const double listTextSpacing = 14.0;
  static const double subLabelTopMargin = 2.0;
  static const double gridSubLabelTopMargin = 4.0;
  
  // Color Alphas
  static const double primaryBgAlpha = 0.08;
  static const double hoverStateAlpha = 0.04;
  static const double splashStateAlpha = 0.08;
  static const double subLabelTextAlpha = 0.6;



  const DashboardGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isListMode = width < compactBreakpoint; 

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: Text(
                "Quick Actions",
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            
            isListMode
                ? ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => SizedBox(height: spacing),
                    itemBuilder: (context, index) {
                      return _listCardTemplate(context, items[index]);
                    },
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCrossAxisCount,
                      mainAxisExtent: gridMainAxisExtent,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                    ),
                    itemBuilder: (context, index) {
                      return _gridCardTemplate(context, items[index]);
                    },
                  ),
          ],
        );
      },
    );
  }

  Widget _gridCardTemplate(BuildContext context, DashboardItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        hoverColor: colorScheme.onSurface.withValues(alpha: hoverStateAlpha),
        splashColor: colorScheme.onSurface.withValues(alpha: splashStateAlpha),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(iconContainerPadding),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: primaryBgAlpha),
                  borderRadius: BorderRadius.circular(borderRadius * 0.7),
                ),
                child: Icon(
                  item.icon, 
                  size: gridMainIconSize, 
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: gridLabelFontSize,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: gridSubLabelTopMargin),
              Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: gridSubLabelFontSize,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: subLabelTextAlpha),
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  padding: const EdgeInsets.all(actionArrowPadding),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded, 
                    size: actionArrowIconSizeGrid, 
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listCardTemplate(BuildContext context, DashboardItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(iconContainerPadding),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: primaryBgAlpha),
                  borderRadius: BorderRadius.circular(borderRadius * 0.7),
                ),
                child: Icon(
                  item.icon, 
                  size: listMainIconSize, 
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: listTextSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: listLabelFontSize,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: subLabelTopMargin),
                    Text(
                      item.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: listSubLabelFontSize,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: subLabelTextAlpha),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(actionArrowPadding),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded, 
                  size: actionArrowIconSizeList, 
                  color: colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}