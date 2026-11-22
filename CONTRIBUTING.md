# Contributing

Thank you for helping. The cookbook is a set of small recipes that people copy into their own games, so a change is judged by one question: is the recipe still small, readable and honest about its shortcuts?

## Before you start

- For a new recipe or a change in how a recipe behaves, open an issue first and say what you have in mind. A bug fix or a documentation fix can go straight to a pull request.
- Read the [recipe contract](docs/recipe_contract.md). It has the rules every recipe follows and the steps for adding one.
- [docs/architecture.md](docs/architecture.md) shows how the recipes depend on each other and the conventions they share.

## Setting up

You need the Godot version in `.godot-version`, Python 3, and `gdlint` / `gdformat` from the gdtoolkit version in `.gdtoolkit-version`.

- **Dev container (any OS).** Open the repository in the dev container (`.devcontainer/`). It has all of the above. It is headless: use it to import, lint and test, and open the project in the Godot editor on your own machine to play the demos. It also has [Claude Code](https://docs.claude.com/en/docs/claude-code/overview): run `claude` in its terminal (or use the Claude Code extension in VS Code) and sign in once. The sign-in is kept in a Docker volume, so it survives rebuilding the container.
- **Linux.** `tools/install_godot.sh` installs the pinned Godot binary, and `pip install "gdtoolkit==$(cat .gdtoolkit-version)"` the linter.
- **Windows and macOS without the container.** The editor and `tools/cookbook` work (on Windows run it as `python tools\cookbook ...`). `tools/check.sh` and `tools/install_godot.sh` are Bash scripts for Linux: run them in the dev container or in WSL.

## Checking your change

```bash
tools/check.sh
```

This takes about three minutes and is what CI runs on every pull request. Single steps are faster while you work: `tools/check.sh repo`, `unit`, `lint`, `import`, `smoke`, `test` or `cli`. The top of `tools/check.sh` says what each does. `gdformat recipes browser shared tests` fixes formatting.

The checks are headless. They do not look at rendering, animation or feel, so play the demo of anything you changed.

## What a pull request needs

- **One topic.** A fix and an unrelated refactor are two pull requests.
- **Tests** for behaviour worth pinning down: a `tests/test_<recipe>.gd` that extends `tests/support/test_case.gd` (see "Adding a recipe" in the contract). A bug fix comes with a test that fails without it, where that is practical.
- **The recipe's README** kept in step. It follows [docs/recipe_template.md](docs/recipe_template.md), its Requirements section must agree with `recipe.cfg`, and "Where to take it next" names the shortcuts you took. `tools/check.sh repo` checks the first two.
- **The root README table** has a row for a new recipe, under the heading of its category.
- **Assets are CC0** and listed in [CREDITS.md](CREDITS.md). The check fails for an asset file that is not listed.
- **Code style** as in [docs/style_guide.md](docs/style_guide.md).
- **A description** that says what changed and why, and how you tested it, including anything you could not test.

## Upgrading Godot

See [docs/upgrading.md](docs/upgrading.md). A weekly workflow opens an issue when a newer stable release exists.
