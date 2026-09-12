# mactap-midi

Knock the MacBook chassis, get a MIDI note. A headless build of MacTap's
sensor and tap detector that publishes a virtual CoreMIDI source and,
optionally, OSC for Max for Live.

## Build and run

```
./midi-bridge/build.sh
./build/mactap-midi --calibrate
```

Needs the Command Line Tools only. No Accessibility or Input Monitoring
grant — those exist for the app's shortcut actions, not the sensor.

A MIDI source named **MacTap** appears while it runs. A knock on the
left palm rest sends note 36 (C1), on the right note 38 (D1), channel 1,
velocity from the impact strength, note-off 30 ms later. Two pads, no
setup. `--no-sides` makes it one pad at ~7 ms latency instead of ~33.

## Ableton, no Max

1. Preferences → Link, Tempo & MIDI → Input **MacTap** → Track On.
2. MIDI track, monitor **In**, Drum Rack with sounds on C1 and D1.
3. Knock.

## Max for Live

Run with OSC on:

```
./build/mactap-midi --osc 127.0.0.1:7400
```

Each hit sends one message:

```
/mactap/hit <side:int 0=L 1=R> <velocity:int 1-127> <peak:float g> <latency:float ms>
```

The side comes from the gyro: a knock
tilts the chassis, and the sign of the roll rate in the first few
milliseconds read 39/40 labelled knocks correctly, with the lateral
accelerometer as fallback for the rest.

Minimal MIDI-effect device:

```
[udpreceive 7400]
 |
[route /mactap/hit]
 |
[unpack i i f f]
 |    |
 |   [$1]           velocity
[sel 0 1]           side → pitch
[36(  [38(
 |     |
[pack 0 0]          pitch velocity
 |
[makenote 100 30]   hold 30 ms
 |
[midiformat]
 |
[midiout]
```

Do both at once (MIDI source and OSC) if you want Live's raw note path
and the Max device side by side.

### Dials in the device

The bridge listens for settings on UDP 7401 (`--control PORT`, 0 to
turn off). A dial in the device sends one float and the change applies
to the next knock:

```
[live.dial]  0..1                  [live.dial]  0.01..0.1
 |                                  |
[prepend /mactap/sensitivity]      [prepend /mactap/ceil]
 |                                  |
[udpsend 127.0.0.1 7401]           [udpsend 127.0.0.1 7401]
```

| Address | Value | Same as flag |
|---|---|---|
| `/mactap/sensitivity` | 0..1 | `--sensitivity` |
| `/mactap/floor` | g | `--floor` |
| `/mactap/ceil` | g | `--ceil` |
| `/mactap/curve` | 0.1..4 | `--curve` |
| `/mactap/gate` | ms | `--gate` |
| `/mactap/note` | 0..127 | `--note` |
| `/mactap/note-right` | 0..127 | `--note-right` |
| `/mactap/refractory` | ms | `--refractory` |
| `/mactap/sides` | 0 or 1 | `--sides` |
| `/mactap/invert` | 0 or 1 | `--invert` |
| `/mactap/side-hold` | ms | `--side-hold` |

The bridge prints `set sensitivity 0.850` for each change it accepts.
Settings are not saved; the device's own parameter state restores them
when the set loads, provided the dials send their value on load
(`[loadbang]` → `[live.dial]` outputs its stored value).

## Zones (experimental)

More than left/right: the bridge can learn where on the chassis a knock
landed and send a different note per spot.

```
./build/mactap-midi --learn "front-left:36,front-right:38,back:42"
```

It prompts for each zone in turn; knock it 10 times (`--learn-count`),
firmly, and wait for the next prompt. At the end it prints a confusion
table — rows are where you knocked, columns what it read — saves
`~/.mactap-zones.json`, and goes live. Only trust a zone whose row is
clean. Afterwards:

```
./build/mactap-midi --zones
```

A `?` after the zone name means the knock sat between two fingerprints.

What separates spots is not the direction of the tilt (that alone read
19/40) but how much the chassis tilts per g of knock — in effect the
distance from the sensor — plus the vertical share of the impact. On
one MacBook, front-left / front-right / the whole hinge strip read
39/40; splitting the back into left and right did not (36/40), so the
back is one zone. Different spots may separate on a different machine;
the confusion table is the test.

Zones use the 32 ms side hold, so latency is ~33 ms. Across sessions
left/right has held 20/20; zones have not yet — treat them as a
playground, not a pad layout.

## Options

| Flag | Default | Meaning |
|---|---|---|
| `--note N` | 36 | note for a hit |
| `--sides` / `--no-sides` | on | left/right from the gyro (a knock tilts the chassis); right hits use `--note-right` (38). Reading the side holds each hit `--side-hold` ms; `--no-sides` is one pad at ~7 ms |
| `--invert` | off | swap left and right if your chassis reads mirrored |
| `--side-hold MS` | 32 | how long a hit is held before its side is read. Measured: 32 ms read 20/20, 16 ms was near random — the tilt the gyro sees builds over ~30 ms |
| `--channel C` | 1 | MIDI channel |
| `--gate MS` | 30 | note length |
| `--sensitivity S` | 0.9 | detector threshold, 0..1 |
| `--refractory MS` | 45 | minimum gap between hits (≈22 hits/s) |
| `--floor G` / `--ceil G` | 0.012 / 0.09 | peak magnitude that maps to velocity 1 / 127 (measured: soft ≈ 0.023 g, hard ≈ 0.09 g) |
| `--curve X` | 0.6 | velocity curve exponent; 1 is linear |
| `--osc HOST:PORT` | off | OSC output |
| `--no-midi` | — | skip the CoreMIDI source |
| `--calibrate` | — | print peak, SNR, latency, gap and sample rate per hit |
| `--test` | — | fire one synthetic hit at start to check the plumbing |
| `--control PORT` | 7401 | OSC settings listener; 0 turns it off |
| `--learn SPEC` | — | learn zones, `"name:note,name:note,…"`; saves `~/.mactap-zones.json` |
| `--learn-count N` | 10 | knocks per zone while learning |
| `--zones [FILE]` | — | classify by learned zones (default file); implies `--sides` |

## Calibrating

The defaults come from one 148-hit session on a MacBook palm rest (peaks 0.022–0.051 g). Run `--calibrate`, tap soft,
medium and hard twenty times each, and set `--floor` to a soft peak and
`--ceil` to a hard one.

`--calibrate` prints the accelerometer rate at start and on every hit. `PARKED` means macOS idled the sensor below 450 Hz, which
under-samples an 8–25 ms attack. The keep-alive in `SensorManager`
should hold it at ~800 Hz on a still chassis; if a hit after a long rest
shows `PARKED`, that is the problem to fix next.

## What changed in the app

`TapDetector` gained a `musicalMode` flag and an `onHit` callback. In
that mode a hit fires as soon as its capture closes (~8–15 ms) instead of
after the 320 ms double-tap grouping window, and the typing and burst
lockouts are off. `refractoryPeriod` became settable. The GUI path is
unchanged.
