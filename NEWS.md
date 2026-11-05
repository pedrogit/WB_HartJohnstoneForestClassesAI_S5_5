# WB_HartJohnstoneForestClassesAI_S5_5 0.1.0

* Parameters and six-class rules now match `WB_HartJohnstoneForestClasses` and
  `WB_HartJohnstoneForestClassesAI_Sol6_1`, without drainage. Classes: deci, mixed, conimix,
  jackpine, larch, spruce; layer name `standtype`.
* Added `jackPineSp`, `larchSp`, `spruceSp`, `otherConiferSp`, `WB_HJForestClassesTimeStep` and
  `writeClassificationCsv` (default `FALSE`). Removed `dominanceThreshold` and `updateInterval`.
* Output object renamed to `WB_HartJohnstoneForestClassesAI_S5_5_Map`.
* Inputs must be supplied; there is no silent synthetic fallback. Saves and CSVs never overwrite.
* Tests rewritten; added `tests/verify-parity.R`.

# WB_HartJohnstoneForestClassesAI_S5_5 0.0.1

* First version. Converts Biomass_core `cohortData` and `pixelGroupMap` into a forest class
  map using biomass as the proxy for species dominance.

Drafted with assistance from Claude (Posit Assistant).
