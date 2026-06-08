// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
  themeMode: const ThemeModeConverter().fromJson(
    (json['themeMode'] as num).toInt(),
  ),
  seedColor: const ColorConverter().fromJson(
    (json['seedColor'] as num).toInt(),
  ),
);

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'themeMode': const ThemeModeConverter().toJson(instance.themeMode),
      'seedColor': const ColorConverter().toJson(instance.seedColor),
    };
