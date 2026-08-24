final class SpaceUpdate {
  const SpaceUpdate({this.name, this.available});

  final String? name;
  final bool? available;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name case final value?) 'name': value.trim(),
      'available': ?available,
    };
  }
}
