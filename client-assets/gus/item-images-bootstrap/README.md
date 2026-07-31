# GUS item image bootstrap

Temporary general product images for the initial GUS web portal setup.

The files in this folder are source/replay assets. Runtime upload output remains ignored under:

```text
KLS.API/wwwroot/Images/items/{ItemId}/101-300.png
KLS.API/wwwroot/Images/items/{ItemId}/101-1200.png
```

## Contents

- `bootstrap-general-mapping.csv` maps each local `GUS_2026.ItemCode` to a general image key.
- `source/` stores the source images downloaded from the client's current public site.
- `Generate-GusBootstrapItemImages.ps1` regenerates the ignored runtime image files.
- `GUS_ItemImage_Bootstrap_101.sql` inserts or refreshes the `ItemImage` rows.

## Replay

From `C:\Angular19\KLS`:

```powershell
powershell -ExecutionPolicy Bypass -File .\client-assets\gus\item-images-bootstrap\Generate-GusBootstrapItemImages.ps1
& "C:\Users\Howard Yeh\AppData\Local\sqlcmd\sqlcmd.exe" -S "lpc:(local)\SQLEXPRESS" -d GUS_2026 -U sa -P ketchup88 -N -C -b -i ".\client-assets\gus\item-images-bootstrap\GUS_ItemImage_Bootstrap_101.sql"
```

## Notes

- `ImageIndex = 101` is intentional. It avoids overwriting existing local `1-300.png` files when switching databases in the same API workspace.
- This is a general mapping only. The client can later replace images through the normal item image UI.
- The public GUS site does not expose exact local item codes, so matching is by item family and item name.
