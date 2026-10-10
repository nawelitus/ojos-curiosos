"""Cuts every findable object of a scenario out of its illustration.

The target list must show each object without its surroundings, otherwise the
background (sand, water, rock) gives its location away. This dev-only helper
crops each object from the illustration, removes the background with rembg and
writes one transparent PNG per object.

Needs Python with `rembg[cpu]` and Pillow (kept in a virtual environment outside
the repo). The game never runs this script.

Usage, from the repo root:
    python tools/make_icons.py <scenario_id> [--out folder] [--sheet preview.png]
                               [--model isnet-general-use] [--only id1,id2]
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw
from rembg import new_session, remove

REPO = Path(__file__).resolve().parent.parent
CROP_SCALE = 1.45      # crop half-size, in object radii
WORK_SIZE = 512        # the crop is enlarged to this before segmentation
ICON_SIZE = 192        # side of the written icon
MIN_ALPHA = 24         # alpha below this counts as background when trimming


def cut_object(image, obj, session, model):
    half = obj["radius"] * CROP_SCALE
    box = (round(obj["x"] - half), round(obj["y"] - half),
           round(obj["x"] + half), round(obj["y"] + half))
    crop = image.crop(box).resize((WORK_SIZE, WORK_SIZE), Image.LANCZOS)
    if model == "sam":
        # SAM segments whatever lies under a marked point: the object centre.
        centre = [WORK_SIZE // 2, WORK_SIZE // 2]
        cut = remove(crop, session=session,
                     sam_prompt=[{"type": "point", "data": centre, "label": 1}])
    else:
        cut = remove(crop, session=session, post_process_mask=True)

    alpha = cut.getchannel("A").point(lambda a: 255 if a >= MIN_ALPHA else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        return None
    cut = cut.crop(bounds)
    side = max(cut.size)
    icon = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    icon.alpha_composite(cut, ((side - cut.width) // 2, (side - cut.height) // 2))
    return icon.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)


def contact_sheet(icons, path):
    cols = 6
    cell = ICON_SIZE + 8
    rows = (len(icons) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * (cell + 16)), (255, 244, 214))
    draw = ImageDraw.Draw(sheet)
    for i, (object_id, icon) in enumerate(icons):
        x, y = (i % cols) * cell, (i // cols) * (cell + 16)
        draw.text((x + 4, y + 2), object_id, fill=(43, 45, 66))
        if icon is not None:
            sheet.paste(icon, (x + 4, y + 16), icon)
    sheet.save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("scenario_id")
    parser.add_argument("--out")
    parser.add_argument("--sheet")
    parser.add_argument("--model", default="isnet-general-use")
    parser.add_argument("--only", default="")
    args = parser.parse_args()

    data = json.loads((REPO / "data" / "scenarios" / f"{args.scenario_id}.json").read_text("utf-8"))
    image = Image.open(REPO / data["image"].replace("res://", "")).convert("RGB")
    out = Path(args.out) if args.out else REPO / "assets" / "scenarios" / f"{args.scenario_id}_icons"
    out.mkdir(parents=True, exist_ok=True)
    wanted = {name for name in args.only.split(",") if name}

    session = new_session(args.model)
    icons = []
    for obj in data["objects"]:
        if wanted and obj["id"] not in wanted:
            continue
        icon = cut_object(image, obj, session, args.model)
        icons.append((obj["id"], icon))
        if icon is None:
            print("EMPTY", obj["id"])
            continue
        icon.save(out / f"{obj['id']}.png")
        print("ok", obj["id"])
    if args.sheet:
        contact_sheet(icons, args.sheet)
        print("sheet", args.sheet)


if __name__ == "__main__":
    main()
