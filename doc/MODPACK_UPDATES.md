# Modrinth modpack updates

Select a game, open **More**, then choose **Update Modpack**. The game must be stopped. The dialog offers newer versions from the same Modrinth project that use the installed Minecraft version and loader type. Stable releases do not automatically offer alpha or beta releases.

New Modrinth installations record their project, version, and managed file hashes in `.swiftcraft-modpack.json` inside the profile. Existing installations can be linked: enter the Modrinth project ID or slug, check versions, select the exact installed version, then choose **Link Installed Version**. Linking verifies the installed mod hashes. Select an older version only when it matches the installed files.

The updater downloads and verifies the selected pack before replacing the profile. It updates or removes unchanged pack-owned files. It preserves added files, worlds, server lists, and changed configuration files. A changed pack-owned mod or an occupied destination stops the update with an error. Disabled mods remain disabled, including renamed Fabric or Quilt mod files with the same mod ID.

A complete backup is retained in `modpack-backups` under the launcher working directory. **Show Backup** opens its location. To restore manually, stop the game and close the launcher, move the current profile aside, and copy the backup into its original profile location. If the update changed the loader version, restore the corresponding loader setting before launching.

This flow supports Modrinth `.mrpack` client packs. It does not upgrade Minecraft, switch loader types, update CurseForge packs, or resolve project dependencies declared outside the pack file list. Unsafe archive paths and symbolic links are rejected. Other profile writes and launches are blocked while the update runs.
