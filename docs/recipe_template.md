# Recipe name

One or two sentences: what it does and what it is built from.

## Add it to your project

Numbered steps: which files to copy, which nodes to add, what to connect.

## Requirements

Other recipes, input actions and physics layers. Must match `recipe.cfg`. Write "None" if there are none.

`tools/check.sh repo` compares this section with `recipe.cfg`: put each recipe in `depends` and each action in `input_actions` in backticks, and write physics layers as "layer 2" (or "layers 1 and 2"). Naming a recipe, action or layer number here that `recipe.cfg` does not list fails the check too.

## Settings

The exported properties worth knowing about, and which node they are on.

## Scene layout

Optional. The important nodes and what each is for.

## Where to take it next

The known shortcuts and limits, and the obvious next steps for a real game.
