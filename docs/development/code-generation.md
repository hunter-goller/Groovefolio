# Code generation

Groovefolio uses `build_runner` for Riverpod and Drift generated code.

After changing annotated providers or Drift schema definitions:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

The project verification script also regenerates sources:

```powershell
.\tools\verify_vinylapp_012.ps1
```

The current repository does **not** track generated `*.g.dart` sources. Edit the annotated provider/schema source and regenerate locally; CI also regenerates it. Never fix a compiler error by hand-editing a generated file, because the next generation replaces it.

Drift schema snapshots under `drift_schemas/` are different: they **are** versioned migration evidence. Export and commit the new snapshot for a physical schema change while preserving older snapshots:

```sh
dart run drift_dev schema dump lib/db/app_database.dart drift_schemas/
git diff -- drift_schemas/
```

If generation fails, read the first generator error, verify `flutter pub get` completed, and check `part` directives and package imports (`vinyl_app`). Re-run analysis after generation. Do not delete migration snapshots to silence a CI schema difference. See the [migration procedure](../developer-guide.md#migration-procedure).
