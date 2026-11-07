import 'package:idb_shim/idb.dart';

/// The single IndexedDB database shared by the project and preset
/// repositories. Both must open it with the same version and upgrade
/// function: opening it with a lower version than the one on disk throws a
/// VersionError, which used to push projects into the localStorage fallback.
abstract final class SlowverbIdb {
  static const name = 'slowverb_web';
  static const version = 3;

  static const projects = 'projects';
  static const projectHandles = 'project_handles';
  static const customPresets = 'custom_presets';

  static void onUpgradeNeeded(VersionChangeEvent e) {
    final db = e.database;
    if (!db.objectStoreNames.contains(projects)) {
      db.createObjectStore(projects, keyPath: 'id');
    }
    if (!db.objectStoreNames.contains(projectHandles)) {
      db.createObjectStore(projectHandles);
    }
    if (!db.objectStoreNames.contains(customPresets)) {
      db.createObjectStore(customPresets, keyPath: 'id');
    }
  }

  static Future<Database> open(IdbFactory factory) => factory.open(
    name,
    version: version,
    onUpgradeNeeded: onUpgradeNeeded,
  );
}
