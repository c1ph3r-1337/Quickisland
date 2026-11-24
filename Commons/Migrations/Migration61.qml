import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v61 (Game Mode transition label)");
    // The new JsonAdapter field uses its declared default for existing users.
    return true;
  }
}
