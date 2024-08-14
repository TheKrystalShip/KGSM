# Blueprints 101

This document contains everything needed in order to understand what blueprints
are and how to work with them.

## What is a blueprint?

Blueprints are KGSM's way of storing the information needed in order to create
a game server. Very similar concept to how an architect has a _blueprint_ of a
house he can use to make said house with.

Under the hood, they are nothing more than simple text files with keys and
values inside.

## Where to find/store blueprints?

KGSM keeps all **blueprint** files inside the `blueprints/default` directory.
These files contain the default configuration for each game server that KGSM
supports.

## I need to change some values in a default blueprint

In the case where the default values need changing (for example the game world
to load at the start, or the game server port, etc), the way to do it is to
duplicate one of the existing blueprints from the `blueprints/default`
directory into the `blueprints` directory and changing all the desired values
in the new file.

The name of the new blueprints can be the same as the default, essentialy
working as an override for it.

> [!IMPORTANT]
> The **.bp** extension is required in order for KGSM to load the
> blueprint correctly

## I want to make a blueprint for a game KGSM doesn't have

Any new blueprint you make should be places in the `blueprints` directory and
not in the `blueprints/default` directory.

Also if you feel like your new blueprint should be part of KGSM, don't hesitate
to make a request to add it!
