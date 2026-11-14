# Godot-Cookbook
Starter recipes for 3D game development in Godot.

## Development

Open the repository in the dev container (`.devcontainer/`) to get Godot 4.4.1 (headless), `gdlint` and `gdformat`.

```bash
tools/check.sh        # import every project and smoke-run its demo scene
tools/check.sh lint   # gdlint + gdformat --check
```

The container is headless: use it to import, lint and smoke-test. To play a recipe, open its project in the Godot editor on your machine.
