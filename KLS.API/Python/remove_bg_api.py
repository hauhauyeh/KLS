"""
Remove background using remove.bg API (paid, ~100% success rate).
Centers object and adds 10% margin.

Usage: python remove_bg_api.py <input> <output> <api_key>
"""
import sys
import requests
from io import BytesIO
from PIL import Image
import numpy as np


def remove_background(image_path, api_key):
    with open(image_path, 'rb') as image_file:
        response = requests.post(
            "https://api.remove.bg/v1.0/removebg",
            files={"image_file": image_file},
            data={"size": "auto"},
            headers={"X-Api-Key": api_key},
        )

    if response.status_code == 200:
        return Image.open(BytesIO(response.content)).convert("RGBA")
    else:
        errors = response.json().get("errors", "Unknown error")
        print(f"remove.bg API error: {errors}", file=sys.stderr)
        sys.exit(1)


def center_and_add_margin(image, min_margin_ratio=0.1):
    img_array = np.array(image)

    # Find bounding box using alpha channel
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


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python remove_bg_api.py <input> <output> <api_key>", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    api_key = sys.argv[3]

    processed = remove_background(input_path, api_key)
    processed = center_and_add_margin(processed)
    processed.save(output_path, "PNG")
    print(f"Saved: {output_path}")
