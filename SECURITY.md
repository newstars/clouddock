# Security Notes

CloudDock currently stores only non-sensitive UI preferences in `UserDefaults`.
User-added application launchers store local app bundle paths only; no credentials are stored for launchers.

Security boundaries for future cloud widgets:

- Do not store API tokens, AWS credentials, Datadog keys, GitHub tokens, account IDs, or private URLs in `UserDefaults`.
- Add a dedicated Keychain-backed credential store before implementing authenticated widgets.
- Collapsed widgets that can expose organization, repository, service, incident, or account names must provide a redacted display mode.
- Planned cloud widgets should stay disabled in the gallery until their credential storage, request scope, and redaction behavior are implemented.
- Network clients should live in narrow service types, not SwiftUI views.
- Avoid shelling out for cloud integrations unless there is no stable API alternative. Current Git status support uses a fixed `/usr/bin/git status` command with a configured repository path.
- External command-backed local widgets use fixed executable paths and short hard timeouts so the dock does not hang during launch or refresh.
- Command timeout cleanup is limited to CloudDock's own child command processes.
- CPU and memory expanded views can send `SIGTERM` to a process only after the user clicks that process row's terminate button. Do not add automatic process termination.
- Before distribution, package as a signed `.app` with hardened runtime and explicit entitlements.

Current local packaging uses ad-hoc signing for development only:

```sh
Scripts/package_app.sh
```
