"""The 16x16 icons of the tools: hoe, axe, pickaxe, watering can, scythe, shovel and hammer, in
the five grades of tool_grades.py.

Each is a hand-drawn map of letters (see tool_grades.py) on the diagonal from the bottom left
to the top right, the classic item-icon pose: a wooden handle 2 px wide at a true 45 degrees
with the working end at the top right, in an ink outline so its silhouette reads on its own.
The heads are straight lines at 45 degrees or square to the picture, as the 32 px icons are
(tool_icons.py there); the watering can is of the grade's metal too.
"""

import item_icons as items
from canvas import blank
from tool_grades import GRADES, stamp

# fmt: off
MAPS = {
    "hoe": (
        "................",
        "..........mmmmm.",
        "..........msssk.",
        "..........msssk.",
        "..........eeeee.",
        "..........ld....",
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
        ".....mm.........",
        "......ksm.......",
        ".......ksm......",
        "........kssm....",
        ".........kssm...",
        ".........ldksm..",
        "........wd..ksm.",
        ".......wd....ke.",
        "......wd........",
        ".....wd.........",
        "....wd..........",
        "...wd...........",
        "..wd............",
        ".wd.............",
        "................",
    ),
    "hammer": (
        "................",
        "................",
        ".........em.....",
        "........essm....",
        ".........kssm...",
        "..........ksse..",
        ".........ldksse.",
        "........wd..ke..",
        ".......wd.......",
        "......wd........",
        ".....wd.........",
        "....wd..........",
        "...wd...........",
        "..wd............",
        ".wd.............",
        "................",
    ),
    "shovel": (
        "................",
        "...........lww..",
        "..........lw.w..",
        "..........wwww..",
        "...........ld...",
        "..........wd....",
        ".........wd.....",
        "........wd......",
        ".......wd.......",
        ".......mm.......",
        ".....msssk......",
        "....msssssk.....",
        "...mssssssk.....",
        "..essssssk......",
        "...eeeeek.......",
        "................",
    ),
    "scythe": (
        "................",
        "........mmmmm...",
        ".....mmmssssk...",
        "...mmsseeeesk...",
        "..mseee....ld...",
        "..ee......wd....",
        ".........wd.....",
        "........wd......",
        ".....lwwd.......",
        ".....lwd........",
        ".....wd.........",
        "....wd..........",
        "...wd...........",
        "..wd............",
        "................",
        "................",
    ),
    "watering_can": (
        "................",
        "................",
        "................",
        "....mmm....mmmm.",
        "...m...k...mksk.",
        "...m...k...mskk.",
        "..mmmmmmm...kk..",
        "..mkkkkks...ms..",
        "..msssssk..ms...",
        "..msssssk.ms....",
        "..mkkkkkkms.....",
        "..msssssk.......",
        "..msssssk.......",
        "..msssssk.......",
        "...kkkkk........",
        "................",
    ),
}
# fmt: on

MARKS = {
    "hoe": {"p": [(11, 2)], "q": [(12, 2)], "c": [(12, 2), (13, 3)], "g": [(11, 3), (12, 3), (13, 3)]},
    "axe": {"p": [(8, 4)], "q": [(9, 4)], "c": [(7, 3), (8, 4)], "g": [(8, 2), (7, 3), (6, 4)]},
    "pickaxe": {"p": [(10, 4)], "q": [(10, 5)], "c": [(11, 5), (12, 6)], "g": [(5, 1), (13, 7)]},
    "hammer": {"p": [(10, 4)], "q": [(11, 4)], "c": [(11, 5), (12, 6)], "g": [(9, 3), (12, 5)]},
    "shovel": {"p": [(6, 11), (5, 13)], "q": [(7, 11)], "c": [(7, 12), (8, 13)], "g": [(3, 13), (4, 13), (5, 13), (6, 13), (7, 13)]},
    "scythe": {"p": [(6, 2)], "q": [(7, 2)], "c": [(10, 2), (11, 2)], "g": [(5, 3), (6, 3), (3, 4)]},
    "watering_can": {"p": [(4, 8), (6, 12)], "q": [(5, 8)], "c": [(5, 11), (5, 12)], "g": [(3, 8), (3, 9)]},
}


def icon(item, grade):
    return items.outlined(stamp(blank(), 0, 0, MAPS[item], grade, MARKS[item]), "ink")


def icons(grade=GRADES[0]):
    """The 16x16 icons in one grade, by item id."""
    return {item: icon(item, grade) for item in MAPS}
