"""Builds assets/, the pictures and sounds Godot reads, out of art/generated/ (run it with
`make assets`; it draws nothing, so it takes seconds, where `make art` takes minutes).

assets/ mirrors art/generated/ (the classic art's files, drawn at 16 px, are scaled up to the
game's tile on the way, see classic/scaling.py), but for the atlases: the object and decoration
atlases are packed here out of the sheet of each entity (see atlas.py), one atlas per look. Files
are only written where they changed, so Godot does not import again what did not change, and files
no source makes any more are removed. assets/ is build output and not in git.
"""

import sys
from io import BytesIO
from pathlib import Path

from PIL import Image

import atlas
from classic.scaling import classic_size
from palette import ASSETS, GENERATED

CLASSIC = "classic"

# Godot's import settings of the font's page: the font file loads it, so it is not a texture.
# Godot writes the .import file of every other file itself.
FONT_PAGE_IMPORT = '[remap]\n\nimporter="skip"\n'


def png_bytes(image):
    buffer = BytesIO()
    image.save(buffer, "PNG")
    return buffer.getvalue()


def look_suffix(look):
    """The file name part of a look: summer keeps the plain names."""
    return "" if look == "summer" else f"_{look}"


def packed_atlases(folder, errors):
    """The files of the atlas in `folder` (under art/generated/), by path under assets/: one
    picture per look, a row of cells per entity, as many rows as there are entities. Appends
    what is wrong with the sheets to `errors`."""
    (cell_width, cell_height), looks, rows = atlas.read_manifest(GENERATED / folder / atlas.MANIFEST)
    width = max(count for _, count in rows) * cell_width
    pictures = {look: Image.new("RGBA", (width, len(rows) * cell_height), (0, 0, 0, 0)) for look in looks}
    for row, (entity, count) in enumerate(rows):
        sheet_path = GENERATED / folder / f"{entity}.png"
        if not count:
            continue
        if not sheet_path.exists():
            errors.append(f"{folder}/{entity}: source image missing ({sheet_path.relative_to(GENERATED.parent.parent)})")
            continue
        sheet = Image.open(sheet_path).convert("RGBA")
        if sheet.size != (count * cell_width, len(looks) * cell_height):
            errors.append(f"{folder}/{entity}: the source image is {sheet.size}, expected {(count * cell_width, len(looks) * cell_height)}")
            continue
        for index, look in enumerate(looks):
            cells = sheet.crop((0, index * cell_height, sheet.width, (index + 1) * cell_height))
            pictures[look].paste(cells, (0, row * cell_height))
    parent, name = Path(folder).parent, Path(folder).name
    return {(parent / f"{name}{look_suffix(look)}.png").as_posix(): picture for look, picture in pictures.items()}


def build_outputs(errors):
    """Everything assets/ is made of: its paths and their contents, bytes or images."""
    manifests = sorted(GENERATED.rglob(atlas.MANIFEST))
    atlas_folders = [manifest.parent.relative_to(GENERATED).as_posix() for manifest in manifests]
    outputs = {"ui/font.png.import": FONT_PAGE_IMPORT.encode()}
    for folder in atlas_folders:
        outputs.update(packed_atlases(folder, errors))
    # The object atlas's row of each type, which tests/test_object_atlas.gd compares with the
    # game's `atlas_row`s.
    _, _, object_rows = atlas.read_manifest(GENERATED / "objects" / atlas.MANIFEST)
    outputs["objects_rows.txt"] = "".join(f"{row} {entity} {count}\n" for row, (entity, count) in enumerate(object_rows)).encode()
    for path in sorted(GENERATED.rglob("*")):
        relative = path.relative_to(GENERATED).as_posix()
        if not path.is_file() or path.name in (atlas.MANIFEST, "cell_sizes.txt") or any(relative.startswith(f"{folder}/") for folder in atlas_folders):
            continue
        outputs[relative] = path.read_bytes()
    return outputs


def scale_classic(outputs):
    """The classic atlases and files as the game reads them (see classic/scaling.py)."""
    for relative in [path for path in outputs if path.startswith(f"{CLASSIC}/") and path.endswith(".png")]:
        image = outputs[relative]
        if isinstance(image, bytes):
            image = Image.open(BytesIO(image))
        scaled = classic_size(relative.removeprefix(f"{CLASSIC}/"), image)
        if scaled is not image:
            outputs[relative] = scaled


def write_assets(outputs):
    """Writes what changed, and removes what no output stands for (and its .import file)."""
    for relative, content in outputs.items():
        path = ASSETS / relative
        data = content if isinstance(content, bytes) else png_bytes(content)
        if not path.exists() or path.read_bytes() != data:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    for path in ASSETS.rglob("*"):
        relative = path.relative_to(ASSETS).as_posix()
        if path.is_file() and relative.removesuffix(".import") not in outputs and relative != ".packed":
            path.unlink()
    for folder in sorted(ASSETS.rglob("*"), reverse=True):
        if folder.is_dir() and not any(folder.iterdir()):
            folder.rmdir()


def main():
    errors = []
    outputs = build_outputs(errors)
    if errors:
        sys.exit("make assets failed:\n" + "\n".join(errors))
    scale_classic(outputs)
    write_assets(outputs)
    print(f"Built assets/ from art/generated/: {len(outputs)} files.")


if __name__ == "__main__":
    main()
