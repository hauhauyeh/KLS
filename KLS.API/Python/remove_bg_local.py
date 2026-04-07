"""
Remove background using rembg (local, free).
Preserves ICC profile for consistent color rendering.
Centers object and adds 10% margin for clean preview.

Usage: python remove_bg_local.py <input> <output>
"""
import sys
import numpy as np
from PIL import Image, PngImagePlugin
from rembg import remove


def center_and_add_margin(image, min_margin_ratio=0.1):
    img_array = np.array(image)

    mask = img_array[:, :, 3] > 0
    coords = np.argwhere(mask)

    if coords.size == 0:
        return image

    y_min, x_min = coords.min(axis=0)
    y_max, x_max = coords.max(axis=0)

    cropped = image.crop((x_min, y_min, x_max, y_max))
    width, height = cropped.size

    margin = int(max(width, height) * min_margin_ratio)
    new_width = width + 2 * margin
    new_height = height + 2 * margin

    centered_img = Image.new("RGBA", (new_width, new_height), (0, 0, 0, 0))
    centered_img.paste(cropped, (margin, margin), cropped)

    return centered_img


def process_image(input_path: str, output_path: str):
    # Open without immediate conversion so we can keep ICC
    src = Image.open(input_path)
    icc = src.info.get("icc_profile")

    # Run removal with alpha-matting & mask post-processing to reduce color spill at edges
    img_no_bg = remove(
        src,
        alpha_matting=True,
        alpha_matting_erode_size=10,
        alpha_matting_foreground_threshold=240,
        alpha_matting_background_threshold=10,
        post_process_mask=True
    )

    out = img_no_bg.convert("RGBA")
    out = center_and_add_margin(out)

    # Save with ICC profile if available, otherwise add sRGB hints
    if icc:
        out.save(output_path, "PNG", icc_profile=icc)
    else:
        pnginfo = PngImagePlugin.PngInfo()
        pnginfo.add_text("sRGB", "perceptual")
        pnginfo.add_text("gAMA", "0.45455")
        out.save(output_path, "PNG", pnginfo=pnginfo)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python remove_bg_local.py <input> <output>", file=sys.stderr)
        sys.exit(1)
    process_image(sys.argv[1], sys.argv[2])
