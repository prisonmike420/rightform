# Plugin monitoring

Rightform tracks every public upstream component declared in `Resources/plugins.json`. A plugin can depend on several tools (for example Images uses JPEG, PNG and WebP encoders), so the monitor records each component independently instead of treating one repository as the whole plugin.

The GitHub Actions workflow runs once a week, at minute 17 rather than on the hour. It requests only the latest GitHub release or tag for each repository. If the observed version has not changed, it exits without cloning a repository, downloading source code, inspecting branch commits, or building a plugin.

The first run records a baseline without a notification. Later changes create or update the GitHub issue **Upstream plugin updates detected**. The issue is the review point for a plugin-specific build and verification workflow.

An upstream release is not automatically safe to install. Rightform only offers an in-app **Update** when `Resources/plugins.json` has a verified archive URL, SHA-256 and compatible version. Current Homebrew and source-built plugins deliberately do not show a false **Update** action: their releases need a plugin-specific reproducible package first. This prevents an external repository update from being executed on a user's Mac before Rightform has a verified package for it.

The monitor currently reads GitHub releases or tags. A component hosted elsewhere is retained in the catalog and reported as unavailable rather than being silently treated as current.

Run the check on demand from GitHub Actions with **Monitor upstream plugins → Run workflow**.
