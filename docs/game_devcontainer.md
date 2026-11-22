# Making a game in a dev container

How to use the cookbook's dev container to make your own game, so that the game's files never end up in the cookbook repository.

## Why the game cannot live inside the cookbook's container

- **Only the cookbook folder is shared with your machine.** The container sees your clone at `/workspaces/Godot-Cookbook`. Anything you create elsewhere in the container, such as `~/games/my_game`, is invisible to your machine and is lost when the container is rebuilt.
- **The container is headless.** Its Godot can import, lint and test, but it cannot open the editor or play the game. You need the Godot editor on your machine for that, at the version in `.godot-version`.

So the game lives on your machine, in its own repository, and a container is given access to it through a mount.

## Layout

Keep the two repositories side by side on your machine:

```
~/dev/
├── Godot-Cookbook/        this repository, unchanged
└── my_game/               your game, with its own `git init`
    ├── .devcontainer/
    │   └── devcontainer.json
    ├── .gitignore
    └── project.godot      created with the Godot editor on your machine
```

The game is a separate repository in a separate folder, so `git add` in the cookbook never sees it.

## The game's dev container

The game gets its own dev container. It builds the cookbook's image, so it has the same Godot, `gdlint`, `gdformat` and Claude Code, and mounts the cookbook next to the game. Save this as `my_game/.devcontainer/devcontainer.json`:

```jsonc
{
	"name": "My Game",
	"build": {
		// The cookbook's image: the same Godot, gdlint/gdformat and Claude Code.
		"dockerfile": "../../Godot-Cookbook/.devcontainer/Dockerfile",
		"context": "../../Godot-Cookbook"
	},
	"remoteUser": "vscode",
	"workspaceFolder": "/workspaces/my_game",
	"mounts": [
		// The cookbook, read-only: nothing done in this container can change it.
		"source=${localWorkspaceFolder}/../Godot-Cookbook,target=/workspaces/Godot-Cookbook,type=bind,readonly",
		"source=my-game-claude-config,target=/home/vscode/.claude,type=volume"
	],
	"containerEnv": { "CLAUDE_CONFIG_DIR": "/home/vscode/.claude" },
	"postCreateCommand": "[ -f project.godot ] && godot --headless --import || true",
	"customizations": {
		"vscode": {
			"extensions": ["geequlim.godot-tools", "EditorConfig.EditorConfig", "anthropic.claude-code"],
			"settings": {
				"godotTools.editorPath.godot4": "/usr/local/bin/godot",
				"godotTools.lsp.headless": true,
				"editor.insertSpaces": false
			}
		}
	}
}
```

The paths assume the cookbook clone is a folder named `Godot-Cookbook` next to the game; change them if yours is elsewhere. Claude Code asks you to sign in once in this container, because its sign-in volume is separate from the cookbook container's.

Give the game a `.gitignore` with at least `.godot/` in it; the cookbook's own `.gitignore` is a good start.

## Working on the game

1. In VS Code, open `~/dev/my_game` (not the cookbook) and choose **Reopen in Container**.
2. Add recipes from the container's terminal:

   ```bash
   /workspaces/Godot-Cookbook/tools/cookbook add third_person_movement --to /workspaces/my_game
   ```

   ```bash
   /workspaces/Godot-Cookbook/tools/cookbook status --to /workspaces/my_game
   ```

   The copies go into `my_game/addons/cookbook/` and belong to the game's repository.
3. Open `~/dev/my_game` in the Godot editor on your machine to build scenes and play. It is the same folder as `/workspaces/my_game`, so changes appear on both sides at once.
4. Commit to the game's repository, from the container or from your machine.
5. To get newer recipes, `git pull` in `~/dev/Godot-Cookbook` on your machine (it is read-only in the container), then run `tools/cookbook add <recipe> --force` again. `status` says which copies are behind.

## Why not a folder inside the cookbook

Putting the game in a subfolder of the cookbook and hiding it with `.git/info/exclude` works, but leaves a git repository inside a git repository and a Godot project inside a Godot project, and the cookbook's checks and editor would scan the game's files. A sibling folder avoids all of that.
