# Pull requests

Groovefolio uses pull requests as a self-review and CI checkpoint.

A PR should include:
- related `VinylApp-###` task
- summary of behavior/architecture changes
- verification performed
- screenshots for meaningful UI changes
- migration notes for schema changes
- secrets/configuration notes when integrations are involved (never paste actual secrets)

Before opening/updating a PR:

```powershell
.\tools\verify_vinylapp_012.ps1
flutter build apk --debug
```
