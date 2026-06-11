import 'events.dart';
import 'model.dart';

abstract class ModelObserver {

  void creating(Model model){}
  void created(Model model){}
  void updating(Model model){}
  void updated(Model model){}
  void deleting(Model model){}
  void deleted(Model model){}

}

void registerObserver(ModelObserver observer){

  ModelEvents.listen("creating",observer.creating);
  ModelEvents.listen("created",observer.created);
  ModelEvents.listen("updating",observer.updating);
  ModelEvents.listen("updated",observer.updated);
  ModelEvents.listen("deleting",observer.deleting);
  ModelEvents.listen("deleted",observer.deleted);

}
