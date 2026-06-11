enum ModelEventType {

  creating,
  created,

  updating,
  updated,

  deleting,
  deleted,

  restoring,
  restored

}

class ModelEvent {

  final ModelEventType type;

  final dynamic model;

  ModelEvent(this.type, this.model);

}
