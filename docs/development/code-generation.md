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

Generated source changes should be committed when the repository already tracks them.
