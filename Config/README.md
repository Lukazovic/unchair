# Signing configuration

App Groups (which widgets need to read live data from the app) require signing
with an Apple Developer team. The project picks entitlements automatically:

| `DEVELOPMENT_TEAM` | App entitlements | Widget entitlements |
|---|---|---|
| empty (sign to run locally) | `Unchair-NoTeam.entitlements` | `UnchairWidgets-NoTeam.entitlements` |
| set | `Unchair.entitlements` (App Group) | `UnchairWidgets.entitlements` (App Group) |

Without a team, everything works except that widgets show placeholder data.
Sandbox, camera, and file access entitlements come from build settings
(`ENABLE_APP_SANDBOX`, `ENABLE_RESOURCE_ACCESS_CAMERA`, `ENABLE_USER_SELECTED_FILES`).
