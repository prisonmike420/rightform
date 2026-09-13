# Plugin monitoring

Rightform tracks the public upstream repositories declared in `Resources/plugins.json`.

The GitHub Actions workflow runs once a week, at minute 17 rather than on the hour. It requests only the latest GitHub release or tag for each repository. If the observed version has not changed, it exits without cloning a repository, downloading source code, inspecting branch commits, or building a plugin.

The first run records a baseline without a notification. Later changes create or update the GitHub issue **Upstream plugin updates detected**. The issue is the review point for a plugin-specific build and verification workflow.

An upstream release is not automatically safe to install. Rightform only offers an in-app **Update** when `Resources/plugins.json` has a verified archive URL, SHA-256 and compatible version. This prevents an external repository update from being executed on a user's Mac before Rightform has a reproducible package for it.

Run the check on demand from GitHub Actions with **Monitor upstream plugins → Run workflow**.
