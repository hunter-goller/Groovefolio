# Git workflow

Repository:

`https://github.com/hunter-goller/Groovefolio`

## Typical ticket branch

```powershell
git checkout main
git pull
git checkout -b VinylApp-108
```

Historical/project task IDs continue to use `VinylApp-###` for continuity.

## Before push

```powershell
.\tools\verify_vinylapp_012.ps1
flutter build apk --debug
```

## Push

```powershell
git push -u origin VinylApp-108
```

Use concise commits such as:

```text
VinylApp-108: rename app to Groovefolio and refresh docs
```

After merge, return to `main`, pull, and create the next ticket branch from the merged baseline.
