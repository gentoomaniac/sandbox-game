"""The maps of the tools in the hand (character.py): the head of each tool as a map of letters in
the colours of its grade (tool_grades.py), drawn pointing to the right, with the handle's two
columns where `character.head` is told they are; the watering can whole. Data alone, without the
figure, so that other generators can draw the same tools.
"""

# fmt: off
HOE_HEAD = (
    "..mmmmme",
    "kkssssse",
)
SPADE_GRIP = ("lwwd",)
SPADE_BLADE = (
    ".kssk.",
    ".mssk.",
    "mssssk",
    "mssssk",
    "mssssk",
    "mssssk",
    "mssssk",
    "mssssk",
    "eeeeek",
    ".eeee.",
    "..ee..",
)
SCYTHE_BLADE = (
    "..mmmm..",
    "kkeessm.",
    "....eesm",
    "......ee",
)
SCYTHE_NIB = (
    "..lw",
    "..ld",
)
AXE_HEAD = (
    "....mme",
    "kssssse",
    "kssssse",
    "kssssse",
    "....kke",
)
PICK_HEAD = (
    "..mmmmm..",
    ".mskkssm.",
    "ks.....sk",
    "e.......e",
)
HAMMER_HEAD = (
    "emmmmme",
    "essssse",
    "essssse",
    "ekkkkke",
)
CAN = (
    "..kk.....",
    ".kkkk....",
    ".mmmm..mm",
    "mkkkkk.sk",
    "mssssk..s",
    "mkkkkk.s.",
    "mssssks..",
    "mssssk...",
    "mssssk...",
    ".kkkk....",
)
# fmt: on
