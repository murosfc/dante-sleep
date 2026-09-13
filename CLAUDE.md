# Dante Sleep — Project Notes

## Web deployment (Firebase Hosting)

This project has a deployed web version at **https://dante-sleep.web.app**, hosted on Firebase Hosting (project `dante-sleep`).

Whenever code changes are made that affect the app (features, fixes, UI changes), after the work is done:

1. Build the web release: `flutter build web --release`
2. Deploy it: `firebase deploy --only hosting`

If it's not clear whether the user wants an immediate redeploy (e.g. mid-session, uncommitted/unfinished work, or the change is experimental), **ask first** instead of deploying automatically. Otherwise, default to deploying after completing an update so the web version stays in sync with the codebase.

Config files: `.firebaserc` (project alias) and the `hosting` block in `firebase.json` (public dir `build/web`, SPA rewrite).
