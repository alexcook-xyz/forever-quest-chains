# Releasing

## Checks before a release

```bash
python -m pytest -q
python tools/release.py check        # .toc fields, file list, changelog, generated data
python tools/package.py              # builds dist/ForeverQuestChains-<version>.zip
```

`tools/release.py check --public` additionally fails while third-party art is in
the tree. This repo carries none.

## Cut a release

1. Move the `## [Unreleased]` entries in `CHANGELOG.md` under a new
   `## [x.y.z]` heading and set `## Version:` in
   `MainStoryGuide/MainStoryGuide.toc` to the same version.
2. Commit, then tag and push: `git tag v<x.y.z> && git push origin v<x.y.z>`.
3. The `release` workflow builds the zip and attaches it to a GitHub release.
   Versions with a suffix such as `-alpha` or `-beta` are marked as pre-releases.

## Upload to CurseForge

1. Create the project once, using the text in [CURSEFORGE.md](../CURSEFORGE.md).
2. For every release, upload the zip from the GitHub release as a new file. The
   zip has one top-level folder, `MainStoryGuide`. Set the release type
   (Alpha, Beta or Release) to match the version, and paste the matching
   `CHANGELOG.md` section as the changelog.
3. After the project exists, add `## X-Curse-Project-ID: <id>` to the `.toc` so
   addon managers can match the project.

CurseForge may not list the WoW Forever client as its own game version; pick the
closest Classic version in the upload form and say in the description that the
addon targets WoW Forever.

## Branch protection

Protect `main` so that changes arrive by pull request with the CI jobs
`luacheck`, `pytest`, `voice`, `generated-data`, `changelog` and
`installer-smoke` green:

```bash
gh api -X PUT repos/alexcook-xyz/forever-quest-chains/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": {"strict": true, "contexts": ["luacheck", "pytest", "voice", "generated-data", "changelog", "installer-smoke"]},
  "enforce_admins": false,
  "required_pull_request_reviews": {"required_approving_review_count": 0},
  "restrictions": null
}
JSON
```
