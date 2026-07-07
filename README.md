# Armoire

Armoire is a lightweight equipment set addon for World of Warcraft: The Burning Crusade Classic Anniversary Edition.

## Install

Copy this folder to:

```text
World of Warcraft/_anniversary_/Interface/AddOns/Armoire
```

The addon currently targets interface `20506`, used by TBC Anniversary 2.5.6.

## Use

Open the manager from the character pane with the Armoire button, or with:

```text
/armoire
```

Equip the gear you want, type a set name, then click **Save New**. Select a saved set to equip, update it from your currently equipped gear, or delete it.

Slash commands:

```text
/armoire
/armoire show
/armoire hide
/armoire save <name>
/armoire equip <name>
/armoire delete <name>
/armoire list
```

Saved sets are per character. If an item is missing from your bags, Armoire equips what it can and prints which slots are missing. If you try to equip during combat, Armoire queues the set and retries when combat ends.
