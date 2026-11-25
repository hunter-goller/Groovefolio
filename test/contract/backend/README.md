# Backend contract fixtures

These JSON files are what the Groovefolio backend
([Groovefolio-Backend](https://github.com/hunter-goller/Groovefolio-Backend))
sends, or expects to receive. `test/contract/backend_contract_test.dart` runs
the app's real parsing code over each one, so a change on either side that
breaks the other fails CI.

| File | Backend type | Endpoint |
|---|---|---|
| `installation_registered.json` | `InstallationService.Registration` | `POST /v1/installations` (201) |
| `installation_status.json` | `InstallationService.Status` | `GET /v1/installation`, `POST /v1/installation/rotate` |
| `installation_rotate_request.json` | request body read by `InstallationController.field` | `POST /v1/installation/rotate` |
| `discogs_connection_started.json` | `DiscogsConnectionService.Started` | `POST /v1/discogs/connections` (201) |
| `discogs_connection_<status>.json` | `DiscogsConnectionService.Progress` | `GET /v1/discogs/connections/{id}` |
| `discogs_account_*.json` | `DiscogsConnectionService.AccountStatus` | `GET /v1/discogs/account` |
| `discogs_search_page.json`, `discogs_barcode_page.json` | `DiscogsSearchPage` | `GET /v1/discogs/search`, `GET /v1/discogs/barcode/{barcode}` |
| `discogs_collection_page.json` | `DiscogsCollectionPage` | `GET /v1/discogs/collection` |
| `discogs_release*.json` | `DiscogsRelease` | `GET /v1/discogs/releases/{id}` |
| `error_codes.json` | every `ApiException` / `ApiErrors.write` code | any, as `{"code": "..."}` |

Things these pin down:

- Field names and types: ids are JSON integers, optional fields are sent as
  `null` (Jackson's default), lists are never `null`.
- Dates are ISO-8601 UTC strings (Jackson 3 `Instant`), with zero to six
  fraction digits.
- Tokens are 32 random bytes, base64url without padding (43 characters).
- The flow statuses the app can see: `pending`, `connected`, `canceled`
  (one "l"), `expired`, `failed`.

When the backend adds, renames or removes a field, status or error code,
update the matching file here in the same change, then make the app handle it.
The backend can use the same files in its own tests to check its output.
