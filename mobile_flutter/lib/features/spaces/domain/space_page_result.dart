import 'package:mobile_flutter/features/spaces/domain/space_summary.dart';

final class SpacePageResult {
  SpacePageResult({
    required List<SpaceSummary> content,
    required this.size,
    required this.number,
    required this.totalElements,
    required this.totalPages,
  }) : content = List<SpaceSummary>.unmodifiable(content);

  factory SpacePageResult.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    if (rawContent is! List<dynamic>) {
      throw const FormatException('Campo content ausente ou inválido.');
    }

    final content = <SpaceSummary>[];
    for (var index = 0; index < rawContent.length; index += 1) {
      final item = rawContent[index];
      content.add(
        SpaceSummary.fromJson(_stringKeyedMap(item, field: 'content[$index]')),
      );
    }

    final page = _stringKeyedMap(json['page'], field: 'page');
    return SpacePageResult(
      content: content,
      size: _requiredNonNegativeInt(page, 'size'),
      number: _requiredNonNegativeInt(page, 'number'),
      totalElements: _requiredNonNegativeInt(page, 'totalElements'),
      totalPages: _requiredNonNegativeInt(page, 'totalPages'),
    );
  }

  final List<SpaceSummary> content;
  final int size;
  final int number;
  final int totalElements;
  final int totalPages;

  bool get isEmpty => content.isEmpty;

  bool get hasNextPage => number + 1 < totalPages;

  static Map<String, dynamic> _stringKeyedMap(
    Object? value, {
    required String field,
  }) {
    if (value is! Map) {
      throw FormatException('Campo $field ausente ou inválido.');
    }

    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('Campo $field inválido.');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  static int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value < 0) {
      throw FormatException('Campo page.$key ausente ou inválido.');
    }
    return value;
  }
}
