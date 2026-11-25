extends RefCounted

# Town coordinates have their own scene origin. M1's office axes translate by
# the depot origin; the track gauge and approach never rotate across the door.
const DEPOT_ORIGIN := Vector3(0.0, 0.0, -9.5)
const MAIN_LINE_Z := -18.0
const OFFICE_MAIN_LINE_Z := MAIN_LINE_Z - DEPOT_ORIGIN.z
