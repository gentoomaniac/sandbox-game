"""Plays a module with libmodplug, the system's ModPlug library (through ctypes), as an independent
player to check the generator and the game's renderer against: ours could share a misreading of
the format with each other, ModPlug doesn't. None of the game's code uses it.

libmodplug is found as the shared library "modplug" (Gentoo: media-libs/libmodplug); `LIBRARY` is
None where it isn't installed, and the checks that need it say they were skipped.
"""

import ctypes
import ctypes.util

import numpy as np

_path = ctypes.util.find_library("modplug")
LIBRARY = ctypes.CDLL(_path) if _path else None

RESAMPLE_LINEAR = 1


class _Settings(ctypes.Structure):
    _fields_ = [
        (name, ctypes.c_int)
        for name in (
            "mFlags mChannels mBits mFrequency mResamplingMode mStereoSeparation mMaxMixChannels "
            "mReverbDepth mReverbDelay mBassAmount mBassRange mSurroundDepth mSurroundDelay mLoopCount"
        ).split()
    ]


if LIBRARY:
    LIBRARY.ModPlug_Load.restype = ctypes.c_void_p
    LIBRARY.ModPlug_Load.argtypes = [ctypes.c_char_p, ctypes.c_int]
    for _name in ("ModPlug_Unload", "ModPlug_GetLength", "ModPlug_NumChannels", "ModPlug_NumPatterns", "ModPlug_GetCurrentOrder", "ModPlug_GetCurrentRow"):
        getattr(LIBRARY, _name).argtypes = [ctypes.c_void_p]
    LIBRARY.ModPlug_Read.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int]


def play(module, rate, block_frames):
    """The module played once through, mono at `rate`, with linear interpolation and nothing added
    (no reverb, bass or surround): its samples (-1..1), the (order, row) at the end of each block of
    `block_frames` samples, and what ModPlug reads of the file (channels, patterns, length in ms)."""
    settings = _Settings(mFlags=0, mChannels=1, mBits=16, mFrequency=rate, mResamplingMode=RESAMPLE_LINEAR, mStereoSeparation=128, mMaxMixChannels=32)
    LIBRARY.ModPlug_SetSettings(ctypes.byref(settings))
    handle = LIBRARY.ModPlug_Load(module, len(module))
    if not handle:
        raise ValueError("libmodplug cannot load the module")
    try:
        info = {
            "channels": LIBRARY.ModPlug_NumChannels(handle),
            "patterns": LIBRARY.ModPlug_NumPatterns(handle),
            "length_ms": LIBRARY.ModPlug_GetLength(handle),
        }
        buffer = ctypes.create_string_buffer(block_frames * 2)
        blocks, positions = [], []
        while (read := LIBRARY.ModPlug_Read(handle, buffer, len(buffer))) > 0:
            blocks.append(np.frombuffer(buffer.raw[:read], dtype="<i2").copy())
            positions.append((LIBRARY.ModPlug_GetCurrentOrder(handle), LIBRARY.ModPlug_GetCurrentRow(handle)))
    finally:
        LIBRARY.ModPlug_Unload(handle)
    return np.concatenate(blocks) / 32768, positions, info
