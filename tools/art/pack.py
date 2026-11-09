"""Builds assets/, the pictures and sounds Godot reads, out of art/generated/ and the hand-drawn
art of art/hand/ (run it with `make assets`; it draws nothing, so it takes seconds, where
`make art` takes minutes).

assets/ mirrors art/generated/ (the classic art's files, drawn at 16 px, are scaled up to the
game's tile on the way, see classic/scaling.py), but for the atlases: the object and decoration
atlases are packed here out of the sheet of each entity (see atlas.py), one atlas per look. Files
are only written where they changed, so Godot does not import again what did not change, and files
no source makes any more are removed. assets/ is build output and not in version control.

Hand-drawn art goes over the generated art. A hand file has the path of the generated file under
art/hand/ and a postfix for the art set it replaces: `objects/oak_32x32.png` for
art/generated/objects/oak.png, `objects/oak_16x16.png` for art/generated/classic/objects/oak.png.
Sounds have no postfix (`sounds/axe_chop_1.wav`). A hand picture has the generated one's size
exactly; of a sheet (looks, variants, frames) it takes the cells it draws, and a cell it leaves
empty stays the generated one, so art is replaced bit by bit. Hand art outside the palette is
warned about, a hand file that replaces nothing is an error.
"""

import sys
from io import BytesIO
from pathlib import Path

from PIL import Image

import atlas
from classic.scaling import classic_size
from palette import ASSETS, CELL_SIZES_FILE, GENERATED, HAND, ROOT, stray_colours

CLASSIC = "classic"
SET_POSTFIXES = {"_32x32": "", "_16x16": f"{CLASSIC}/"}
# Files of art/hand/ that are no art.
NOT_ART = ("README.md",)

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


def replaced_file(hand_relative):
    """The path under art/generated/ of the file the hand file at `hand_relative` (under art/hand/)
    replaces, or None if its name says nothing."""
    path = Path(hand_relative)
    if path.parts[0] == "sounds":
        return path.as_posix()
    for postfix, folder in SET_POSTFIXES.items():
        if path.suffix == ".png" and path.stem.endswith(postfix):
            return folder + path.with_name(path.stem.removesuffix(postfix) + ".png").as_posix()
    return None


class Sources:
    """art/generated/ with the hand-drawn art laid over it; collects what is wrong (`errors`), what
    is questionable (`warnings`) and which hand files were used (`used`)."""

    def __init__(self):
        self.errors = []
        self.warnings = []
        self.used = []
        self.cell_sizes = {}
        for sizes_file in GENERATED.rglob(CELL_SIZES_FILE):
            for line in sizes_file.read_text().split("\n"):
                if line:
                    path, width, height = line.split()
                    self.cell_sizes[path] = (int(width), int(height))
        self.hand = {}
        for path in sorted(HAND.rglob("*")) if HAND.exists() else []:
            if path.is_file() and path.name not in NOT_ART:
                self._add_hand_file(path)

    def _add_hand_file(self, path):
        name = path.relative_to(ROOT).as_posix()
        replaced = replaced_file(path.relative_to(HAND))
        if replaced is None:
            self.errors.append(f"{name}: the name ends in neither _32x32.png nor _16x16.png (sounds in sounds/ have no postfix)")
        elif not (GENERATED / replaced).is_file():
            self.errors.append(f"{name}: matches no generated file (art/generated/{replaced} does not exist); a typo in the path or postfix?")
        else:
            self.hand[replaced] = path

    def image(self, relative):
        """The picture at `relative` (under art/generated/), its hand-drawn cells laid over it."""
        generated = Image.open(GENERATED / relative).convert("RGBA")
        if relative not in self.hand:
            return generated
        name = self.hand[relative].relative_to(ROOT).as_posix()
        hand = Image.open(self.hand[relative]).convert("RGBA")
        if hand.size != generated.size:
            self.errors.append(
                f"{name}: {hand.width}x{hand.height} px, the generated picture is "
                f"{generated.width}x{generated.height} (hand art must have its size exactly)"
            )
            return generated
        stray = stray_colours(hand)
        if stray:
            self.warnings.append(f"{name}: {len(stray)} colours not in the palette")
        cell_width, cell_height = self.cell_sizes.get(relative, generated.size)
        cells = [
            (x, y, x + cell_width, y + cell_height)
            for y in range(0, hand.height, cell_height)
            for x in range(0, hand.width, cell_width)
        ]
        drawn = [box for box in cells if hand.crop(box).getchannel("A").getbbox() is not None]
        for box in drawn:
            generated.paste(hand.crop(box), box)
        self.used.append(f"{name}: {len(drawn)} of {len(cells)} cells")
        return generated

    def content(self, relative):
        """What assets/ gets of the file at `relative`: its bytes, or its picture if hand-drawn cells
        are laid over it."""
        if relative in self.hand and relative.endswith(".png"):
            return self.image(relative)
        if relative in self.hand:
            self.used.append(self.hand[relative].relative_to(ROOT).as_posix())
            return self.hand[relative].read_bytes()
        return (GENERATED / relative).read_bytes()


def packed_atlases(folder, sources):
    """The files of the atlas in `folder` (under art/generated/), by path under assets/: one
    picture per look, a row of cells per entity, as many rows as there are entities."""
    (cell_width, cell_height), looks, rows = atlas.read_manifest(GENERATED / folder / atlas.MANIFEST)
    width = max(count for _, count in rows) * cell_width
    pictures = {look: Image.new("RGBA", (width, len(rows) * cell_height), (0, 0, 0, 0)) for look in looks}
    for row, (entity, count) in enumerate(rows):
        relative = f"{folder}/{entity}.png"
        if not count:
            continue
        if not (GENERATED / relative).exists():
            sources.errors.append(f"{folder}/{entity}: source image missing (art/generated/{relative}); `make art` draws it")
            continue
        sheet = sources.image(relative)
        expected = (count * cell_width, len(looks) * cell_height)
        if sheet.size != expected:
            sources.errors.append(f"{relative}: {sheet.width}x{sheet.height} px, expected {expected[0]}x{expected[1]}")
            continue
        for index, look in enumerate(looks):
            cells = sheet.crop((0, index * cell_height, sheet.width, (index + 1) * cell_height))
            pictures[look].paste(cells, (0, row * cell_height))
    parent, name = Path(folder).parent, Path(folder).name
    return {(parent / f"{name}{look_suffix(look)}.png").as_posix(): picture for look, picture in pictures.items()}


def build_outputs(sources):
    """Everything assets/ is made of: its paths and their contents, bytes or images."""
    if not (GENERATED / "objects" / atlas.MANIFEST).exists():
        sys.exit("make assets: art/generated/objects/atlas.txt is missing; art/generated/ is incomplete, `make art` draws it")
    manifests = sorted(GENERATED.rglob(atlas.MANIFEST))
    atlas_folders = [manifest.parent.relative_to(GENERATED).as_posix() for manifest in manifests]
    outputs = {"ui/font.png.import": FONT_PAGE_IMPORT.encode()}
    for folder in atlas_folders:
        outputs.update(packed_atlases(folder, sources))
    # The object atlas's row of each type, which tests/test_object_atlas.gd compares with the
    # game's `atlas_row`s.
    _, _, object_rows = atlas.read_manifest(GENERATED / "objects" / atlas.MANIFEST)
    outputs["objects_rows.txt"] = "".join(f"{row} {entity} {count}\n" for row, (entity, count) in enumerate(object_rows)).encode()
    for path in sorted(GENERATED.rglob("*")):
        relative = path.relative_to(GENERATED).as_posix()
        is_sheet = any(relative.startswith(f"{folder}/") for folder in atlas_folders)
        if not path.is_file() or path.name in (atlas.MANIFEST, CELL_SIZES_FILE) or is_sheet:
            continue
        outputs[relative] = sources.content(relative)
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
    sources = Sources()
    outputs = build_outputs(sources)
    for warning in sources.warnings:
        print(f"warning: {warning}")
    if sources.errors:
        sys.exit("make assets failed:\n" + "\n".join(sources.errors))
    scale_classic(outputs)
    write_assets(outputs)
    print(f"Built assets/ from art/generated/: {len(outputs)} files.")
    print(f"Hand-drawn art used ({len(sources.used)}):" if sources.used else "No hand-drawn art in art/hand/.")
    for line in sources.used:
        print(f"  {line}")


if __name__ == "__main__":
    main()
