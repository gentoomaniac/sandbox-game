"""The 16x16 icons of the tools: hoe, axe, pickaxe, watering can, scythe, shovel and hammer, in
the five grades of tool_grades.py.

Each is a hand-drawn map of letters (see tool_grades.py) on the diagonal from the bottom left
to the top right, the classic item-icon pose: a wooden handle 2 px wide at a true 45 degrees
with the working end at the top right, in an ink outline so its silhouette reads on its own.
As at 32 px (tool_icons.py there), every tool is one rigid object: its head sits square to the
handle, built of lines along it and across it. The watering can stands upright, of the grade's
metal.
"""

import item_icons as items
from canvas import blank
from tool_grades import GRADES, numeral, stamp

# fmt: off
MAPS = {
    "hoe": (
        "................",
        "................",
        "................",
        "................",
        "................",
        "..........mm....",
        ".........ldmm...",
        "........wd..mm..",
        ".......wd....me.",
        "......wd......e.",
        ".....wd.........",
        "....wd..........",
        "...wd...........",
        "..wd............",
        ".wd.............",
        "................",
    ),
    "axe": (
        "................",
        "........e.......",
        ".......emm......",
        "......esssm.....",
        ".....esssssmk...",
        "......kksssskk..",
        ".........ld.....",
        "........wd......",
        ".......wd.......",
        "......wd........",
        ".....wd.........",
        "....wd..........",
        "...wd...........",
        "..wd............",
        ".wd.............",
        "................",
    ),
    "pickaxe": (
        "................",
        "................",
        ".....em.........",
        "......mmm.......",
        "........mm......",
        ".........mm.....",
        ".........lmm....",
        "........wd.mm...",
        ".......wd...m...",
        "......wd....mm..",
        ".....wd......m..",
        "....wd........e.",
        "...wd...........",
        "..wd............",
        ".wd.............",
        "................",
    ),
    "hammer": (
        "................",
        "................",
        ".......ee.......",
        "......eesm......",
        ".......mssm.....",
        "........mssm....",
        ".........mssm...",
        "........ldmssm..",
        ".......wd..msee.",
        "......wd....ee..",
        ".....wd.........",
        "....wd..........",
        "...wd...........",
        "..wd............",
        ".wd.............",
        "................",
    ),
    "shovel": (
        "................",
        "................",
        "..........d.....",
        "...........d....",
        "...........ld...",
        "..........wd.d..",
        ".........wd.....",
        "........wd......",
        ".....m.wd.......",
        "....msmw........",
        "...msssm........",
        "..mssssk........",
        ".essssk.........",
        ".esssk..........",
        ".eekk...........",
        "................",
    ),
    "scythe": (
        "................",
        "................",
        ".....mmmmmm.....",
        "...meeeeeeemm...",
        "..ee......ssk...",
        "..e.......ld....",
        ".........wd.....",
        "........wd......",
        ".......wd.......",
        "......wd........",
        ".....wd.........",
        "....wd..........",
        "...wd...........",
        "..wd............",
        ".wd.............",
        "................",
    ),
    "watering_can": (
        "................",
        "................",
        "...........mmm..",
        "..mm......m...k.",
        ".mssk.....m...k.",
        ".mskk.....mkm.k.",
        "..kk.....msssk..",
        "...ms...msssssk.",
        "....ms..msssssk.",
        ".....ms.mkkkkkk.",
        ".......smsssssk.",
        "........msssssk.",
        "........msssssk.",
        ".........kkkkk..",
        "................",
        "................",
    ),
}
# fmt: on

MARKS = {
    "hoe": {"p": [(11, 6)], "q": [(12, 7)], "c": [(12, 6), (13, 7)], "g": [(13, 8)]},
    "axe": {"p": [(8, 4)], "q": [(9, 4)], "c": [(7, 3), (8, 4)], "g": [(8, 2), (7, 3), (6, 4)]},
    "pickaxe": {"p": [(8, 4)], "q": [(9, 5)], "c": [(11, 7), (12, 8)], "g": [(6, 2), (14, 11)]},
    "hammer": {"p": [(8, 4)], "q": [(9, 4)], "c": [(10, 5), (10, 6)], "g": [(8, 3), (11, 7)]},
    "shovel": {"p": [(4, 10), (3, 12)], "q": [(5, 10)], "c": [(4, 11), (5, 12)], "g": [(2, 12), (2, 13), (3, 13)]},
    "scythe": {"p": [(6, 2)], "q": [(7, 2)], "c": [(10, 4), (11, 4)], "g": [(8, 2), (9, 2)]},
    "watering_can": {"p": [(12, 8), (10, 11)], "q": [(11, 8)], "c": [(11, 11), (11, 12)], "g": [(13, 7), (13, 8), (3, 4)]},
}


def icon(item, grade):
    """The tool with the grade's numeral in its bottom left corner."""
    body = numeral(stamp(blank(), 0, 0, MAPS[item], grade, MARKS[item]), grade, 1)
    return items.outlined(body, "ink")


def icons(grade=GRADES[0]):
    """The 16x16 icons in one grade, by item id."""
    return {item: icon(item, grade) for item in MAPS}
