import 'dart:ui';
import 'package:json_annotation/json_annotation.dart';

// the current json serializable doesn't convert color to json so this is a custom mapper
class ColorConverter implements JsonConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromJson(int json) => Color(json);

  @override
  int toJson(Color object) => object.value;
}