// Copyright (c) 2026 Kartik. Licensed under GPL-3.0. See LICENSE for details.

import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:syncos_linux/core/misc/color_converter.dart';

part 'app_settings.g.dart';

class ThemeModeConverter implements JsonConverter<ThemeMode, int> {
  const ThemeModeConverter();

  @override
  ThemeMode fromJson(int json) => ThemeMode.values[json];

  @override
  int toJson(ThemeMode object) => object.index;
}

@JsonSerializable()
class AppSettings {
  @ThemeModeConverter()
  final ThemeMode themeMode;

  @ColorConverter()
  final Color seedColor;

  AppSettings({
    required this.themeMode,
    required this.seedColor,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
  Map<String, dynamic> toJson() => _$AppSettingsToJson(this);
}