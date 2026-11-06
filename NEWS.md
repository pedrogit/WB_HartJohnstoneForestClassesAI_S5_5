# WB_HartJohnstoneForestClassesAI_S5_5 (unreleased, after 0.1.0)

* The deciduous rule is now `1 - conifer share >= 2/3` instead of `> 2/3`, so it is inclusive
  like every other dominance rule and like Appendix S3 of Greuel et al. (2021) (">= 66% broadleaf
  deciduous species"). A pixel group whose non-conifer share is exactly 2/3 is now deci instead of
  mixed. The year 0, 50 and 100 snapshots have no such group, so their maps are unchanged. The
  original and `WB_HartJohnstoneForestClassesAI_Sol6_1` changed the same way.
* README rules table now lists the Appendix S3 rule next to each rule and the differences that remain.

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
