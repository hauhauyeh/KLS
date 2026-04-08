"""
Generate no-bg sized versions from a background-removed source image.
Crops to bounding box of non-transparent pixels, adds 10% margin,
centers on square canvas, then produces sized versions.

With-bg sizes are handled by ImageSharp in C# during Upload (not here).
crop_center_margin only works correctly on transparent PNGs — it uses
getbbox() which finds non-transparent pixel bounds.

Outputs: {index}-300-nobg.png, {index}-1200-nobg.png

Usage: python create_sizes.py <nobg_input> <output_dir> <image_index>
"""
import sys
import os
from PIL import Image, ImageOps


def crop_center_margin(img, margin_ratio=0.10):
    """Crop to bounding box, add margin, center on square canvas."""
    img = img.convert("RGBA")

    bbox = img.getbbox()
    if bbox:
        img_cropped = img.crop(bbox)
    else:
        img_cropped = img

    w, h = img_cropped.size
    margin = int(max(w, h) * margin_ratio)
    new_size = max(w, h) + 2 * margin

    canvas = Image.new("RGBA", (new_size, new_size), (0, 0, 0, 0))
    x = (new_size - w) // 2
    y = (new_size - h) // 2
    canvas.paste(img_cropped, (x, y), img_cropped)

    return canvas


def save_resized(image, out_path, target_size):
    """Resize proportionally then center on square canvas of target size."""
    resized = ImageOps.contain(image, (target_size, target_size), method=Image.LANCZOS)

    canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    x = (target_size - resized.width) // 2
    y = (target_size - resized.height) // 2
    canvas.paste(resized, (x, y), resized)

    canvas.save(out_path, "PNG")
    print(f"Saved {out_path}")


def process(nobg_path, output_dir, image_index):
    os.makedirs(output_dir, exist_ok=True)
    idx = image_index

    nobg_img = Image.open(nobg_path)
    nobg_prepared = crop_center_margin(nobg_img)

    sizes = [300, 1200]
    for size in sizes:
        out_file = os.path.join(output_dir, f"{idx}-{size}-nobg.png")
        save_resized(nobg_prepared, out_file, size)

    print("All processing complete.")


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print(
            "Usage: python create_sizes.py <nobg_input> <output_dir> <image_index>",
            file=sys.stderr
        )
        sys.exit(1)

    process(sys.argv[1], sys.argv[2], sys.argv[3])
