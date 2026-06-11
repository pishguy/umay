class MigrationEngine {

  static Map<String, Map<String, String>>? oldSchema;

  static void run(Map<String, Map<String, String>> newSchema) {

    if (oldSchema == null) {
      oldSchema = newSchema;
      return;
    }

    newSchema.forEach((model, fields) {

      final old = oldSchema![model];

      if (old == null) {
        print("New table detected: $model");
        return;
      }

      fields.forEach((f, type) {

        if (!old.containsKey(f)) {
          print("New column: $model.$f");
        }
      });

      old.forEach((f, _) {

        if (!fields.containsKey(f)) {
          print("Removed column: $model.$f");
        }
      });
    });

    oldSchema = newSchema;
  }
}
