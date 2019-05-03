Copy Scripts and Sprites into your own world folder, or just delete the existing levels from this world and make new ones. Requires Lily's modloader.

Examples:

keke is move if baba is on tile - Keke is move as long as at least one Baba is on a tile.

keke is move if baba is lonely - Keke is move as long as at least one Baba is lonely.

keke is move if baba is not lonely - Keke is move as long as at least one Baba isn't lonely.

keke is move if all baba is on tile - Keke is move as long as every Baba is on a tile. (If there are no Babas, this is true automatically.)

keke is move if one baba is on tile - Keke is move as long as exactly one Baba is on a tile, no more or no less. You can make two, three, four and so on by editing object properties and creating text objects called text_2, text_3, text_4 and so on with text type 11.

keke is move if baba is push - Keke is move as long as at least one Baba is push. For example, given "keke is move if baba is push" and "baba near rock is push", Keke will only move as long as a Baba is near a rock.

keke is move if not baba is pull - Keke is move as long as something that isn't Baba (or text) is pull.

keke is move if baba is not push - Keke is move as long as at least one Baba isn't push. You don't need a rule saying "baba is not push", it applies as long as no rule says it is push.

keke is move if baba is lonely and rock is near baba - Keke is move as long as at least one Baba is lonely and at least one rock is near a Baba (not necessarily the same Baba). You could also write this as "keke is move if baba is lonely *if* rock is near baba"

Limitations:

These currently don't work:

if baba is on rock and tile - You can't use and like this.
if baba is on rock and near tile - Not like this either.
if baba has rock - You can only check for "is" properties.
if all is lonely - This doesn't work because it thinks the "all" is acting as a quantifier, not a noun. But you can do "if all all is lonely".

Paradoxes like "rock is push if rock is not push" won't crash the game, but they might not act how you expect, depending on what you expect.

On the state machine SVGs:

These probably aren't useful for you but I left them in anyway. This is the state machine Baba uses to parse rules, although it might not be perfectly accurate. States with "C" are variants of the existing states where `doingcond` is true. States with "-C" are those with `stage2reached` true. Most states have a loop for "not" but I left these out to make the diagram cleaner. Passing this state machine doesn't necessarily mean the rule is valid, it might get rejected later.