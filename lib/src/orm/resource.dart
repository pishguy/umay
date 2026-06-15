import 'model.dart';

/// Transforms a [Model] into a map representation for API responses.
abstract class Resource<T extends Model> {
  /// The underlying model instance.
  final T model;

  Resource(this.model);

  /// Serialize the model to a map (override to define shape).
  Map<String, dynamic> toMap();
}

/// Convert a list of [Resource]s into a list of maps via [Resource.toMap].
List<Map<String, dynamic>> collection(List<Resource> resources) {
  return resources.map((r) => r.toMap()).toList();
}
