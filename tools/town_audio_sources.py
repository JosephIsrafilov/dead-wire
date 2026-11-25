"""Where the town / train / creak audio is cut from, and out of what.

One module, imported by both the staging tool and the build tool, so the window
a FLAC excerpt covers and the window the build cuts can never drift apart.

Every source is a real recorded file under a CC0 dedication (see the SOURCE.md
in each pack directory and `docs/third_party_assets.md`). Nothing here
synthesises audio.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Source:
    """One registered recording and the pack it is staged under."""

    key: str
    pack: str
    original_name: str
    # Where the tracked excerpt starts and ends, in seconds of the original.
    excerpt_origin: float
    excerpt_end: float


@dataclass(frozen=True)
class Cut:
    """One runtime file, cut from a Source and shaped for its consumer."""

    target: str
    key: str
    start: float          # seconds into the ORIGINAL recording
    length: float
    stereo: bool
    filters: str
    # Exactly one of these is set. A bed is matched by integrated loudness. A
    # one-shot is matched by sample peak against the peak the replaced file
    # measured: peak is the hard constraint (it sets the bus headroom the scenes
    # were mixed against, and the -1 dBTP ceiling leaves no room to argue), so
    # matching it makes every foley replacement attenuation-only. A real contact
    # has far more crest than the near-continuous synth tone it replaces, so its
    # 50 ms hit lands lower; the build prints that delta instead of limiting the
    # transient away to hide it.
    target_lufs: float | None
    oneshot_peak: float | None
    comment: str = ""


# --- the recordings ---------------------------------------------------------
SOURCES: dict[str, Source] = {
    # Thimras, "Park Ambiences" (OpenGameArt, CC0): three recordings made in one
    # Adelaide public park in winter — birds in a copse before rain, a small
    # river over a low step, and an open field with more wind.
    "park_birds": Source("park_birds", "thimras_park",
                         "park_ambience_birds.wav", 185.0, 211.0),
    "park_wind": Source("park_wind", "thimras_park",
                        "park_ambience_wind.wav", 109.0, 139.0),
    "park_river": Source("park_river", "thimras_park",
                         "park_ambience_river.wav", 93.0, 111.0),
    # Nicholas A. Judy, "The Complete Designer's Choice SFX Collection"
    # (archive.org, CC0). UCS-named field and studio captures.
    "bar_walla": Source("bar_walla", "tdc_barwalla",
                        "amb_restaurant_bar_walla.wav", 29.0, 53.0),
    "quiet_nighttime": Source("quiet_nighttime", "tdc_air",
                              "amb_quiet_nighttime.wav", 147.0, 177.0),
    "splash_small": Source("splash_small", "tdc_splash",
                           "water_splash_small.wav", 0.0, 1.28),
    "wren": Source("wren", "tdc_wren",
                   "carolina_wren_chirping.wav", 3.4, 11.7),
    "whistle": Source("whistle", "tdc_whistle",
                      "train_steam_whistle_old_recording.wav", 0.0, 6.66),
    "steam_pass": Source("steam_pass", "sardin_steam",
                         "steam_locomotive_3009.flac", 13.0, 20.0),
    "campfire": Source("campfire", "tdc_campfire",
                       "saloon_fire_original.wav", 19.0, 36.0),
    "steam_release": Source("steam_release", "tdc_steam",
                            "steam_release_acme_windmaster.wav", 0.0, 5.72),
    "door_front": Source("door_front", "tdc_doorwood",
                         "door_front_open_close_squeaks.wav", 0.0, 15.00),
    "floorboard": Source("floorboard", "tdc_floorboard",
                         "floorboard_creak.wav", 0.0, 0.86),
    "ship_creak": Source("ship_creak", "tdc_shipcreak",
                         "ship_creaking_sound_design.wav", 5.95, 52.80),
    # AntumDeluge, "Tree Creaking" (OpenGameArt, CC0) — a real tree recorded,
    # cleaned and peak-normalised by the uploader.
    "tree_creak": Source("tree_creak", "antumdeluge_tree",
                         "tree_creak.flac", 0.0, 6.58),
}


# --- the runtime files ------------------------------------------------------
# Global beds (a non-positional AudioStreamPlayer) stay stereo; anything heard
# from a point in the world is mono so the 3D panner owns the image.
CUTS: tuple[Cut, ...] = (
    # Black Creek in daylight: the park's bird reach.
    Cut("town/day_town_ambience.wav", "park_birds", 188.0, 20.0, True,
        "highpass=f=38", -23.2, None,
        "the copse of trees before rain, real distance in the air"),
    # Dawn: the same park, the open field, where the wind is.
    Cut("town/dawn_mountain_wind.wav", "park_wind", 112.0, 24.0, True,
        "highpass=f=38", -21.7, None,
        "open field, more intense wind, no music and no birds"),
    # The same take's river reach, heard from the Timber Creek bridge.
    Cut("town/creek_rush_loop.wav", "park_river", 96.0, 12.0, False,
        "highpass=f=45", -18.3, None,
        "small river over a low step; steady enough here to loop"),
    # A bar heard through a plank wall: the room's weight survives, the
    # consonants that give words away do not. Two cascaded 1.5 kHz low-passes
    # are a 12 dB/oct roll-off, which is what a wall does; the 70 Hz high-pass
    # keeps the wall from sounding like a subwoofer.
    Cut("town/saloon_through_wall.wav", "bar_walla", 32.0, 18.0, False,
        "highpass=f=70,lowpass=f=1500,lowpass=f=1500", -26.2, None,
        "restaurant/bar walla behind a wall; no words leave it"),
    Cut("town/saloon_stove_fire.wav", "campfire", 20.0, 15.0, False,
        "highpass=f=100,lowpass=f=2900", -28.0, None),
    Cut("town/saloon_window_wind.wav", "park_wind", 113.0, 17.0, False,
        "highpass=f=80,lowpass=f=920", -29.0, None),
    # Mrs. Hargrove's room after dark. The take is already dark, so the chain
    # only takes the recorder's hiss off the top. No notch filters: the ringing
    # they add is worse than the hum they remove, and this take's low band is
    # room rumble rather than mains hum.
    Cut("town/boarding_room_tone.wav", "quiet_nighttime", 150.0, 24.0, True,
        "highpass=f=45,lowpass=f=7000", -23.2, None,
        "a quiet night, a faint fan somewhere in the building"),
    # A hand into the wash basin.
    Cut("town/water_splash_basin.wav", "splash_small", 0.05, 1.15, False,
        "highpass=f=45", None, -2.5, "one small splash"),
    # Wire frame under a tired man: dry wood friction in a quiet room, cut at
    # the labelled creak and clear of the take's opening handling noise.
    Cut("town/bed_creak_sleep.wav", "tree_creak", 1.20, 0.95, False,
        "highpass=f=45", None, -2.5, "wood under load, once"),
    # The wren's own take, cut where it sings without the recordist moving.
    Cut("town/morning_birds_wake.wav", "wren", 9.4, 2.30, False,
        "highpass=f=120", None, -3.1, "a Carolina wren answering itself"),

    # A recorded steam whistle, cut to one call and its decay. The old
    # recording's surface noise is what makes it period rather than clean.
    Cut("train/train_whistle.wav", "whistle", 0.06, 3.60, False,
        "highpass=f=180", -17.1, None, "one call, held then released"),
    Cut("train/train_rumble.wav", "steam_pass", 14.0, 5.00, False,
        "highpass=f=30,lowpass=f=850,afade=t=in:st=1:d=0.17,afade=t=out:st=5.20:d=0.80", -23.0, None,
        "steam locomotive and its wagons rolling past"),
    # A recorded steam release off a real whistle body, not filtered noise.
    Cut("train/train_steam.wav", "steam_release", 1.20, 2.85, False,
        "highpass=f=140", -14.8, None, "cylinder cock / whistle body venting"),

    # The front door's own squeak as it swings, not its latch click or its slam.
    Cut("foley/door_hinge.wav", "door_front", 9.55, 1.00, False,
        "highpass=f=60", None, -10.5, "a wooden door turning on its hinges"),
    # Three separate recorded wood contacts, so the three creaks never sound
    # like one sample at three pitches.
    Cut("foley/floor_creak_1.wav", "floorboard", 0.00, 0.72, False,
        "highpass=f=50", None, -17.0, "a single floorboard creak"),
    Cut("foley/floor_creak_2.wav", "tree_creak", 3.05, 0.50, False,
        "highpass=f=55", None, -17.0, "a drier, tighter timber creak"),
    Cut("foley/floor_creak_3.wav", "ship_creak", 6.00, 0.46, False,
        "highpass=f=55,lowpass=f=4500", None, -16.7, "a third timber creak"),
    # The two floorboards that speak in the office: different creaks out of one
    # timber take. The door board answers lower and sooner than the window
    # board, which is how the room is read by ear.
    Cut("foley/board_door.wav", "ship_creak", 11.95, 0.70, False,
        "highpass=f=50,lowpass=f=3200", None, -15.9,
        "the board just inside the door, duller"),
    Cut("foley/board_window.wav", "ship_creak", 41.40, 0.44, False,
        "highpass=f=50,lowpass=f=4200", None, -15.8,
        "the board before the window, brighter and shorter"),
)

# Beds the engine plays across a seam; only these get the equal-power crossfade.
LOOPED = frozenset({
    "town/day_town_ambience.wav",
    "town/dawn_mountain_wind.wav",
    "town/creek_rush_loop.wav",
    "town/boarding_room_tone.wav",
    "town/saloon_stove_fire.wav",
    "town/saloon_window_wind.wav",
})


def cuts_by_target() -> dict[str, Cut]:
    return {cut.target: cut for cut in CUTS}


def check() -> list[str]:
    """Every cut must sit inside its source's tracked excerpt."""
    problems = []
    for cut in CUTS:
        source = SOURCES.get(cut.key)
        if source is None:
            problems.append(f"{cut.target}: no source for key {cut.key}")
            continue
        if cut.start < source.excerpt_origin:
            problems.append(
                f"{cut.target}: starts {cut.start}s, before the excerpt at "
                f"{source.excerpt_origin}s")
        if cut.start + cut.length > source.excerpt_end:
            problems.append(
                f"{cut.target}: ends {cut.start + cut.length}s, past the "
                f"excerpt at {source.excerpt_end}s")
        if cut.target in LOOPED and cut.oneshot_peak is not None:
            problems.append(
                f"{cut.target}: a looping bed is matched by loudness, not peak")
        if (cut.target_lufs is None) == (cut.oneshot_peak is None):
            problems.append(
                f"{cut.target}: set exactly one of target_lufs / oneshot_peak")
    return problems
