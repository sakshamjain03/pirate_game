# Lane F — Art Pipeline — Implementation Notes

## Task F.1: Asset requests for owner-supplied art

**Status:** done

**Files changed:**
- `docs/10_ASSET_REQUESTS.md` — Added M29-M35 asset request section
- `scripts/world/IslandData.gd` — Added 2 seam @export fields

**Tests added:** None (F.1 has no specific test; verification via resource lint is handled by Lane D's D.3)

**Test results:** N/A

**Spec compliance:**

All items from Requirement F1.2 are present in the asset request table with complete rows:

1. ✓ Story-cast portraits (7 rows: P.1-P.7)
   - Quartermaster Higgins, Factor Cornelius Hale, Morrow, Commander Hollis, Marguerite, Admiral Vance, Almirante Cardenas
   - All follow `res://assets/portraits/<Name>.png` convention (verified via grep)
   - All 512×512, PNG, transparent

2. ✓ Two untextured ship models (V7) — rows SH.1-SH.2
   - Galleon and Brigantine texture atlases
   - 1024×1024, PNG, for M31

3. ✓ Figurehead — row FIG.1
   - Custom figurehead model, glTF/glB, 200-400 tris, M31

4. ✓ Faction flags and sails — rows F.1-F.8
   - Royal Navy, Spanish Empire, Merchant Guild, Pirate Clans
   - Each: flag (256×256) and sail (512×512), PNG, M31

5. ✓ Island owner banners — rows B.1-B.5
   - Port Royal, Santiago, Tortuga, Merchant, Neutral
   - All 64×64, PNG, M31

6. ✓ Port-view island scenes (M32) — rows S.1-S.5
   - Port Royal, Santiago, Tortuga, Merchant (north/south)
   - Godot scenes, 300-500 verts, 1-2 materials each

7. ✓ Cannon, smoke, fire, splash VFX textures — rows V.1-V.4
   - Cannon muzzle, water splash, explosion, smoke
   - PNG sprite sheets, 256×256 or 512×512, M29-M30

8. ✓ Retention UI icons (M30) — rows U.1-U.3
   - Streak, achievement, daily goal icons
   - 64×64, PNG, M30

9. ✓ App icon and store art — rows APP.1-APP.3
   - App icon, Play Store feature graphic, App Store promo
   - M35

**IslandData.gd seam fields added:**

```gdscript
@export_group("Art seams (owner-supplied, M31-M32)")
@export var port_scene_path: String = ""      # For M32 docking HUD
@export var owner_banner_path: String = ""    # For M31 owner label
```

Both default to empty string. No .tres files are written with these fields set yet; they are read by M31/M32 implementation.

**Notes for cross-lane merge:**

- Resource lint (Lane D.3) will pass with the new IslandData fields (both are String, both have empty defaults, both are properly commented)
- Portrait paths in the asset table are for Lane C to write into the Ch1-5 .tres files during their portrait_path implementation
- FactionData seam fields (flag_texture_path, sail_texture_path) are Lane B's responsibility and not modified here
- The asset request table is informational for the project owner; no code reads it

**Unverified (headless limitation):**

- Visual rendering of the fallback system when assets are missing (tested by visual inspection at checkpoint)
- Portrait frame sizing and text layout with actual PNG assets

**Deviation from spec:** None

**Commit:** `db30f9f`
