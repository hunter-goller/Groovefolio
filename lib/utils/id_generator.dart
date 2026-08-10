import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a new unique ID for a database entity.
///
/// Keeps a readable type prefix (e.g. `artist-<uuid>`) for easier
/// debugging in logs and the database browser, while the actual
/// uniqueness guarantee comes from a real UUID v4 — not a timestamp,
/// which can theoretically collide under concurrent inserts.
String generateId(String prefix) => '$prefix-${_uuid.v4()}';
