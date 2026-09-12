#!/usr/bin/env python3
"""Generate MacTap.amxd (Max for Live MIDI effect) and MacTap.maxpat.

The .amxd container, read off Live 12's own "Max MIDI Effect.amxd":
  "ampf" <u32 4> "mmmm" "meta" <u32 4> <4 zero bytes> "ptch" <u32 n> <patch json + "\\n\\0">
"""
import json
import struct
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent

boxes = []
lines = []
_n = 0


def box(maxclass, x, y, w, h, text=None, inlets=1, outlets=1, outlettype=None, **extra):
    global _n
    _n += 1
    b = {
        "id": f"obj-{_n}",
        "maxclass": maxclass,
        "numinlets": inlets,
        "numoutlets": outlets,
        "patching_rect": [float(x), float(y), float(w), float(h)],
    }
    if outlets:
        b["outlettype"] = outlettype or [""] * outlets
    if text is not None:
        b["text"] = text
    b.update(extra)
    boxes.append({"box": b})
    return b["id"]


def obj(text, x, y, w=None, inlets=1, outlets=1, outlettype=None):
    return box("newobj", x, y, w or max(40, 7 * len(text) + 12), 20, text,
               inlets, outlets, outlettype, fontname="Arial Bold", fontsize=10.0)


def comment(text, x, y, w=None):
    return box("live.comment", x, y, w or 7 * len(text) + 10, 18, text, 1, 0, textjustification=0)


def connect(src, dst, out=0, inl=0):
    lines.append({"patchline": {"source": [src, out], "destination": [dst, inl]}})


def param(longname, shortname, ptype, lo, hi, initial, unitstyle, enum=None, steps=None):
    v = {
        "parameter_longname": longname,
        "parameter_shortname": shortname,
        "parameter_type": ptype,          # 0 float, 1 int, 2 enum
        "parameter_mmin": lo,
        "parameter_mmax": hi,
        "parameter_initial_enable": 1,
        "parameter_initial": [initial],
        "parameter_unitstyle": unitstyle,  # 0 int, 1 float, 2 time(ms)
    }
    if enum:
        v["parameter_enum"] = enum
    if steps:
        v["parameter_steps"] = steps
    return {"valueof": v}


def dial(varname, longname, shortname, lo, hi, initial, px, py, unitstyle=1, x=0, y=0, ptype=0):
    return box("live.dial", x, y, 44, 48, None, 1, 2, ["", "float"],
               varname=varname, parameter_enable=1, presentation=1,
               presentation_rect=[float(px), float(py), 44.0, 48.0],
               saved_attribute_attributes=param(longname, shortname, ptype, lo, hi, initial, unitstyle))


def numbox(varname, longname, shortname, lo, hi, initial, px, py, x=0, y=0):
    return box("live.numbox", x, y, 44, 15, None, 1, 2, ["", "float"],
               varname=varname, parameter_enable=1, presentation=1,
               presentation_rect=[float(px), float(py), 44.0, 15.0],
               saved_attribute_attributes=param(longname, shortname, 1, lo, hi, initial, 0))


def toggle(varname, longname, shortname, initial, px, py, x=0, y=0):
    return box("live.toggle", x, y, 15, 15, None, 1, 1, [""],
               varname=varname, parameter_enable=1, presentation=1,
               presentation_rect=[float(px), float(py), 15.0, 15.0],
               saved_attribute_attributes=param(longname, shortname, 2, 0, 1, initial, 0, enum=["off", "on"]))


def label(text, px, py, w, x=0, y=0):
    return box("live.comment", x, y, w, 18, text, 1, 0, presentation=1,
               presentation_rect=[float(px), float(py), float(w), 18.0], textjustification=1,
               fontsize=9.0)


# ---------------------------------------------------------------- MIDI passthrough
comment("MIDI from Live passes straight through", 20, 10)
midiin = obj("midiin", 20, 34, 40, 1, 1, ["int"])
midiout_thru = obj("midiout", 20, 64, 47, 1, 0)
connect(midiin, midiout_thru)

# ---------------------------------------------------------------- OSC hits → notes
comment("Knocks arrive from mactap-midi --osc 127.0.0.1:7400", 300, 10)
recv = obj("udpreceive 7400", 300, 34, 100)
route = obj("route /mactap/hit", 300, 64, 110, 2, 2)
unpack = obj("unpack i i f f", 300, 94, 100, 1, 4, ["int", "int", "float", "float"])
connect(recv, route)
connect(route, unpack)

sel = obj("sel 0 1", 300, 134, 50, 1, 3, ["bang", "bang", ""])
int_l = obj("int", 300, 174, 40, 2, 1, ["int"])
int_r = obj("int", 360, 174, 40, 2, 1, ["int"])
connect(unpack, sel, 0, 0)
connect(sel, int_l, 0, 0)
connect(sel, int_r, 1, 0)

pack_pv = obj("pack 0 0", 300, 214, 60, 2, 1, [""])
connect(unpack, pack_pv, 1, 1)          # velocity into the cold inlet first (unpack fires right-to-left)
connect(int_l, pack_pv, 0, 0)
connect(int_r, pack_pv, 0, 0)

makenote = obj("makenote 100 30", 300, 244, 100, 3, 2, ["int", "int"])
pack_out = obj("pack 0 0", 300, 274, 60, 2, 1, [""])
midiformat = obj("midiformat", 300, 304, 80, 7, 1, ["int"])
midiout = obj("midiout", 300, 334, 47, 1, 0)
connect(pack_pv, makenote)
connect(makenote, pack_out, 0, 0)
connect(makenote, pack_out, 1, 1)
connect(pack_out, midiformat)
connect(midiformat, midiout)

# ---------------------------------------------------------------- hit display
flash_l = box("button", 300, 400, 24, 24, None, 1, 1, ["bang"], presentation=1,
              presentation_rect=[236.0, 22.0, 24.0, 24.0])
flash_r = box("button", 340, 400, 24, 24, None, 1, 1, ["bang"], presentation=1,
              presentation_rect=[268.0, 22.0, 24.0, 24.0])
connect(sel, flash_l, 0, 0)
connect(sel, flash_r, 1, 0)
vel_show = box("number", 400, 400, 40, 20, None, 1, 2, ["", "bang"], presentation=1,
               presentation_rect=[236.0, 66.0, 56.0, 20.0], fontsize=10.0)
connect(unpack, vel_show, 1, 0)
label("L", 236, 4, 24)
label("R", 268, 4, 24)
label("velocity", 236, 50, 56)

# ---------------------------------------------------------------- dials → bridge
comment("Dials set the bridge live over OSC 7401", 20, 120)
send = obj("udpsend 127.0.0.1 7401", 20, 480, 130, 1, 0)

dials = [
    # varname, long, short, lo, hi, init, osc, presentation x, unitstyle
    ("sens",  "Sensitivity", "Sens",  0.0,   1.0,  0.9,   "/mactap/sensitivity", 8,   1),
    ("floor", "Floor g",     "Floor", 0.005, 0.05, 0.012, "/mactap/floor",       56,  1),
    ("ceil",  "Ceiling g",   "Ceil",  0.02,  0.2,  0.09,  "/mactap/ceil",        104, 1),
    ("curve", "Curve",       "Curve", 0.2,   2.0,  0.6,   "/mactap/curve",       152, 1),
]
loadbang = obj("live.thisdevice", 20, 150, 90, 1, 3, ["bang", "int", "int"])
trig = obj("t b b b b b b b b", 20, 180, 120, 1, 8, ["bang"] * 8)
connect(loadbang, trig, 0, 0)

dial_ids = []
for i, (var, long_, short, lo, hi, init, osc, px, unit) in enumerate(dials):
    d = dial(var, long_, short, lo, hi, init, px, 20, unit, x=20 + i * 90, y=220)
    p = obj(f"prepend {osc}", 20 + i * 90, 280, 90, 2, 1)
    connect(d, p, 0, 0)
    connect(p, send)
    dial_ids.append(d)
    label(short, px, 68, 44)

gate = dial("gate", "Gate ms", "Gate", 5.0, 200.0, 30.0, 200, 20, 2, x=380, y=220)
p_gate = obj("prepend /mactap/gate", 380, 280, 110, 2, 1)
connect(gate, p_gate, 0, 0)
connect(p_gate, send)
connect(gate, makenote, 0, 2)        # the device's own note length follows the dial too
label("Gate", 200, 68, 44)

note_l = numbox("noteL", "Note Left", "NoteL", 0, 127, 36, 8, 96, x=500, y=220)
note_r = numbox("noteR", "Note Right", "NoteR", 0, 127, 38, 56, 96, x=560, y=220)
p_nl = obj("prepend /mactap/note", 500, 280, 110, 2, 1)
p_nr = obj("prepend /mactap/note-right", 620, 280, 140, 2, 1)
connect(note_l, p_nl, 0, 0)
connect(note_r, p_nr, 0, 0)
connect(p_nl, send)
connect(p_nr, send)
connect(note_l, int_l, 0, 1)         # the device's own pitch follows the numbox
connect(note_r, int_r, 0, 1)
label("note L", 8, 114, 44)
label("note R", 56, 114, 44)

sides = toggle("sides", "Sides", "Sides", 1, 118, 96, x=780, y=220)
p_sides = obj("prepend /mactap/sides", 780, 280, 110, 2, 1)
connect(sides, p_sides, 0, 0)
connect(p_sides, send)
label("L/R", 108, 114, 36)

# on load, every control re-sends its value so the bridge matches the set
for i, d in enumerate(dial_ids + [gate, note_l, note_r, sides]):
    connect(trig, d, 7 - i, 0)

label("MacTap  —  run: mactap-midi --osc 127.0.0.1:7400", 8, 140, 290)

patcher = {
    "patcher": {
        "fileversion": 1,
        "appversion": {"major": 8, "minor": 1, "revision": 2, "architecture": "x64", "modernui": 1},
        "classnamespace": "box",
        "rect": [65.0, 399.0, 960.0, 560.0],
        "openrect": [0.0, 0.0, 0.0, 169.0],
        "bglocked": 0,
        "openinpresentation": 1,
        "default_fontsize": 10.0,
        "default_fontface": 0,
        "default_fontname": "Arial Bold",
        "gridonopen": 1,
        "gridsize": [8.0, 8.0],
        "gridsnaponopen": 1,
        "objectsnaponopen": 1,
        "statusbarvisible": 2,
        "toolbarvisible": 1,
        "lefttoolbarpinned": 0,
        "toptoolbarpinned": 0,
        "righttoolbarpinned": 0,
        "bottomtoolbarpinned": 0,
        "toolbars_unpinned_last_save": 0,
        "tallnewobj": 0,
        "boxanimatetime": 500,
        "enablehscroll": 1,
        "enablevscroll": 1,
        "devicewidth": 300.0,
        "description": "Knock the MacBook chassis to play notes. Needs mactap-midi running with --osc.",
        "digest": "MacBook chassis knocks as MIDI",
        "tags": "",
        "style": "",
        "subpatcher_template": "",
        "title": "MacTap",
        "boxes": boxes,
        "lines": lines,
        "dependency_cache": [],
        "latency": 0,
        "project": {
            "version": 1,
            "creationdate": int(time.time()) + 2082844800,
            "modificationdate": int(time.time()) + 2082844800,
            "viewrect": [0.0, 0.0, 300.0, 500.0],
            "autoorganize": 1,
            "hideprojectwindow": 1,
            "showdependencies": 1,
            "autolocalize": 0,
            "contents": {"patchers": {}},
            "layout": {},
            "searchpath": {},
            "detailsvisible": 0,
            "amxdtype": 1835887981,
            "readonly": 0,
            "devpathtype": 0,
            "devpath": ".",
            "sortmode": 0,
            "viewmode": 0,
        },
        "autosave": 0,
    }
}

text = json.dumps(patcher, indent="\t") + "\n"
(HERE / "MacTap.maxpat").write_text(text)

payload = text.encode() + b"\0"
amxd = (b"ampf" + struct.pack("<I", 4) + b"mmmm"
        + b"meta" + struct.pack("<I", 4) + b"\0\0\0\0"
        + b"ptch" + struct.pack("<I", len(payload)) + payload)
(HERE / "MacTap.amxd").write_bytes(amxd)
print(f"wrote MacTap.maxpat ({len(boxes)} boxes, {len(lines)} lines) and MacTap.amxd ({len(amxd)} bytes)")
