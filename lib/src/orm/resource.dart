import 'model.dart';

abstract class Resource<T extends Model> {
  final T model;

  Resource(this.model);

  Map<String, dynamic> toMap();
}

List<Map<String, dynamic>> collection(List<Resource> resources) {
  return resources.map((r) => r.toMap()).toList();
}
