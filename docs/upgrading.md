# Upgrading Godot

The cookbook targets one Godot version at a time, pinned in `.godot-version`. Recipes are only promised to work on that version.

A weekly workflow (`.github/workflows/latest_stable.yml`) compares the pin with the latest stable release. When a newer one exists it runs the checks against it and opens an "Upgrade to Godot ..." issue saying whether they pass.

## When

- **Patch releases** (4.7.2 → 4.7.3): as they appear.
- **Minor releases** (4.7 → 4.8): within a few weeks of the stable release.

## How

1. Put the new release tag in `.godot-version`, for example `4.8-stable`.
2. For a minor release, update the two places that name the minor version:
   - `config/features` in `project.godot`. Opening the project in the new editor does this for you.
   - `godot="..."` in each `recipes/*/recipe.cfg`, if the recipes now need the new version.
3. Rebuild the dev container, or run `tools/install_godot.sh`, to get the new binary.
4. Run `tools/check.sh`. The import step rewrites `.import` files when the importers changed; commit those.
5. Read the release's migration notes and fix deprecation warnings in the scripts, not only errors.
6. Open the project in the editor once and run the demos by hand. The headless checks do not look at rendering.
7. Update any recipe README whose behaviour or setup changed, and the version mentioned in the root `README.md`.
8. Commit as `chore: Migrate to Godot <version>` and close the upgrade issue.

`tools/check.sh repo` fails if `.godot-version` and `project.godot` disagree on the minor version.
