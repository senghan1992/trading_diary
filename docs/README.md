# `docs/` — GitHub Pages root

This folder is the source for the project's GitHub Pages site. After
[enabling Pages on the `main` branch / `docs/` folder](https://github.com/senghan1992/trading_diary/settings/pages),
the contents become publicly available at:

```
https://senghan1992.github.io/trading_diary/
```

## `app-config.json`

`https://senghan1992.github.io/trading_diary/app-config.json` is the
endpoint the in-app **UpdateService** polls at startup to decide whether
to show the optional-update dialog, the force-update screen, or nothing.

### Schema

```json
{
  "latest_version":      "1.0.0",
  "minimum_version":     "1.0.0",
  "force_update":        false,
  "update_message_ko":   "...",
  "update_message_en":   "...",
  "store_url_ios":       "https://apps.apple.com/app/id...",
  "store_url_android":   "https://play.google.com/store/apps/details?id=..."
}
```

| Field | Behavior |
|---|---|
| `latest_version` | If the installed version is below this, surface the optional "Update available" dialog (unless blocked by force/minimum). |
| `minimum_version` | If the installed version is below this, block the app with the force-update screen. |
| `force_update` | When `true`, the force-update screen shows even if version math would allow access. |
| `update_message_ko` / `update_message_en` | Body text shown in the dialog/screen. Falls back to the bundled default when missing or empty. |
| `store_url_*` | Optional override for the store URL. When empty, `UpdateService` falls back to the `IOS_APP_STORE_ID` / `ANDROID_PACKAGE_NAME` `--dart-define` values. |

### Promoting a new release

1. Bump `pubspec.yaml` (`version: 1.1.0+2`) and ship the build.
2. After the new version is approved on both stores, edit `app-config.json`:
   - Set `latest_version: "1.1.0"` to surface the optional-update prompt to users still on 1.0.0.
3. If a critical bug or breaking server change needs to lock out old clients:
   - Raise `minimum_version` to the new version **or** flip `force_update: true`.
   - Either change locks every install below the threshold.
4. To release the lock: revert the field back. (30-minute in-app cache may delay the change on existing installs until they cold-start.)

See [`../scripts/UPDATE_SERVICE.md`](../scripts/UPDATE_SERVICE.md) for the
end-to-end ops runbook.

## GitHub Pages setup (one-time)

In the GitHub web UI for the repo:

1. **Settings → Pages**
2. **Source**: `Deploy from a branch`
3. **Branch**: `main` / `/docs`
4. **Save**

The first deploy takes ~30 seconds. After that, `app-config.json` is served
at the URL above with `Content-Type: application/json` and standard GitHub
Pages caching headers.

### Why `/docs` instead of `/`?

- Keeps the Pages-rooted files visually separate from app source.
- Matches the convention most Flutter projects on GitHub use (so the
  repo layout is recognizable to other contributors).
- Avoids accidentally exposing private `lib/` files to the public web.

## Verifying the live config

After Pages is enabled (or any time you change the JSON), run the
verification script from the repo root:

```bash
./scripts/verify_app_config.sh
```

It fetches the URL, parses the response, checks every required field,
cross-references `latest_version` against `pubspec.yaml`, and prints a
red-flagged exit code on any drift. Overridable:

```bash
APP_CONFIG_URL=https://staging.example.com/app-config.json \
  PUBSPEC_PATH=/path/to/other/pubspec.yaml \
  ./scripts/verify_app_config.sh
```

Requires `jq`. Install with `brew install jq` if missing.

Run it from a CI job after every config edit; a non-zero exit means the
in-app UpdateService will treat the config as null and silently skip the
update check.