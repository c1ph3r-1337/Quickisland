import QtQuick

QtObject {
  function migrate(adapter, logger, rawJson) {
    logger.i("Settings", "Migrating settings to v60 (QuickIsland panel, media, and window controls)");
    // New JsonAdapter fields use their declared defaults when absent. Existing
    // islandConfig and user-selected UI values remain untouched.
    return true;
  }
}
