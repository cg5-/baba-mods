This advanced, somewhat experimental version of the If Mod has a more complete syntax.

It includes a rewrite of the rule parser, which fixes some bugs and who knows, maybe introduces some new ones?

Installation: copy Scripts and Sprites into your own world folder, or just delete the existing levels from this world and make new ones. Requires Lily's modloader.

Examples:

keke is move if baba is on tile - Keke is move as long as at least one Baba is on a tile.

keke is move if baba is lonely - Keke is move as long as at least one Baba is lonely.

keke is move if baba is not lonely - Keke is move as long as at least one Baba isn't lonely.

keke is move if every baba is on tile - Keke is move as long as every Baba is on a tile. (If there are no Babas, this is true automatically.)

keke is move if one baba is on tile - Keke is move as long as exactly one Baba is on a tile, no more or no less. You can make two, three, four and so on by editing object properties and creating text objects called text_2, text_3, text_4 and so on with text type 11.

keke is move if baba is push - Keke is move as long as at least one Baba is push. For example, given "keke is move if baba is push" and "baba near rock is push", Keke will only move as long as a Baba is near a rock.

keke is move if not baba is pull - Keke is move as long as something that isn't Baba (or text) is pull.

keke is move if baba is not push - Keke is move as long as at least one Baba isn't push. You don't need a rule saying "baba is not push", it applies as long as no rule says it is push.

keke is move if baba is lonely and rock is near baba - Keke is move as long as at least one Baba is lonely and at least one rock is near a Baba (not necessarily the same Baba). You could also write this as "keke is move if baba is lonely *if* rock is near baba"

keke is move if baba and rock is on tile - Keke is move as long as at least one Baba and at least one rock is on a tile.

keke is move if every baba near rock is on tile - Keke is move as long as all the Babas which are near rocks are on a tile. The Babas which aren't near rocks don't matter. Put another way, every Baba must either be on a tile or not near a rock.

keke is move if all is on tile - Keke is move as long as at least one of each kind of non-text object in the level is on a tile. This matches the default behaviour of "on all", "near all" and so on. If you want to test if *everything* matches a condition, use "if every all is [condition]".

keke is move if not every baba is near rock - This is equivalent to "keke is move if baba is not near rock"
keke is move if baba is near tile and rock
keke is move if baba is lonely and near tile and push

Limitations:

These currently don't work:

if baba has rock - You can only check for "is" properties.

Paradoxes like "rock is push if rock is not push" won't crash the game, but they might not act how you expect, depending on what you expect.

"keke is move if baba is near rock and tile and box is push" - This rule is ambiguous. "Box" could either attach to the "near" condition on the left or the "is push" on the right. It will be parsed as "keke is move if baba is (near rock and tile) and box is push". To make it be parsed the other way, use "keke is move if baba is near rock *if* tile and box is push" instead.