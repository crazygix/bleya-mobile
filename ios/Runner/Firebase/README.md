Firebase iOS config files are selected per build configuration.

Required files:

- `Dev/GoogleService-Info.plist` for the local app bundle ID `com.bleyachat.dev`
- `Prod/GoogleService-Info.plist` for the production app bundle ID `com.bleyachat`

The dev file is already present. Add the prod file before building the `prod`
scheme.
