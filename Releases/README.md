# Mod Build Lifecycle

This archive has three lifecycle folders:

- `Old Versions` contains superseded builds retained for recovery.
- `Stable` contains validated builds that are ready for user testing and are
  discoverable in the launcher, but are not public releases.
- `Released` contains only builds the user has explicitly approved for public
  release.

Agents must place new validated ZIPs in `Stable`. They must not promote a mod
to `Released` without direct user instruction.

When the user approves a release:

1. move the exact approved ZIP from `Stable` to `Released`;
2. set the matching `mods/<author>@<mod-id>/meta.json` field `released` to
   `true`;
3. change that metadata file's `downloadURL` from `Releases/Stable/` to
   `Releases/Released/`;
4. run `npm run build` and `npm test` from the repository root;
5. commit the promoted ZIP, metadata, and regenerated feed together.

Bill S.S. Ticket Repair 1.0.0, Dramatic Shape Battle Sprite Lighting Patch
1.0.0, and Gen1 Shiny System 1.0.0 were explicitly released by the user on
2026-08-19.
