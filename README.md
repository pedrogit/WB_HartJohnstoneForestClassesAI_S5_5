# WB_HartJohnstoneForestClassesAI_S5_5

Version **0.1.0** uses the same non-drainage parameters and six-class biomass rules as the
original `WB_HartJohnstoneForestClasses` module and as `WB_HartJohnstoneForestClassesAI_Sol6_1`.
It adapts the stand-type definitions of Appendix S3 of Greuel et al. (2021, doi:10.1002/ecs2.3481),
which follow Table 1 of Hart et al. (2019), with biomass replacing basal area and stem density.
Agreement with the original is not ecological validation. No age, drainage or minimum-biomass
rule is applied, and there is no drainage parameter, input or seventh class.

## Classes

Species codes use case-insensitive literal prefix matching. Each cohort belongs to the first
matching group: jack pine, larch, spruce, additional conifer, then the residual (everything
else, including unmatched and missing codes, which need not be true deciduous trees). Biomass is
summed over all ages by pixel group; the denominator includes all biomass. Rules are tested in
this order. Every threshold is inclusive (`>=`), and there is no floating-point tolerance:

| Priority | Code / label | Rule | Appendix S3 rule |
|---:|---|---|---|
| 1 | 4 / jackpine | Jack pine / total biomass >= 2/3 | >= 66% jack pine |
| 2 | 5 / larch | Larch / total biomass >= 0.75 | > 75% larch |
| 3 | 6 / spruce | Spruce / total biomass >= 2/3 | >= 66% spruce |
| 4 | 3 / conimix | All four conifer groups / total biomass >= 2/3 | < 66% spruce or jack pine but >= 2/3 conifer |
| 5 | 1 / deci | 1 - conifer / total >= 2/3 (the non-conifer share) | >= 66% broadleaf deciduous species |
| 6 | 2 / mixed | Otherwise (default class), including groups with zero biomass | < 66% broadleaf and < 66% conifer |

Differences from Appendix S3 that remain: thresholds use 2/3 where the appendix writes 66%;
larch is inclusive at 0.75 where the appendix says "> 75%"; the deciduous class is the share of
all biomass outside the four conifer groups (which includes unrecognised or missing species
codes), not the share of broadleaf species; mixed is the default for everything else, so it also
receives stands that the appendix leaves undefined; and biomass replaces basal area and stem
density.

Default jack pine is `Pinu_ban`, not all pines. Other pines and fir count as conifers, so a
stand of 70% larch is conimix. Map IDs without cohorts, and missing cells, are `NA`. A zero ID
with cohorts is classified. The raster layer and variable name is `standtype`.

## Parameters

| Parameter | Default |
|---|---|
| `.plots` | `"screen"` |
| `.plotInitialTime` | `NA` |
| `.plotInterval` | `NA` |
| `WB_HJForestClassesTimeStep` | `NA_real_` |
| `.saveInitialTime` | `NA` |
| `.saveInterval` | `NA` |
| `.useCache` | `FALSE` |
| `jackPineSp` | `c("Pinu_ban")` |
| `larchSp` | `c("Lari")` |
| `spruceSp` | `c("Pice")` |
| `otherConiferSp` | `c("Abie", "Calc", "Cham", "Juni", "Pinu", "Pseu", "Sequ", "Taxu", "Thuj", "Tsug")` |
| `writeClassificationCsv` | `FALSE` |

Each species parameter accepts an empty character vector, which matches nothing. Entries cannot
be missing, blank or whitespace-padded.

## Timing and outputs

Inputs `cohortData` (factor `speciesCode`) and `pixelGroupMap` must be supplied, for example by
Biomass_core. The module never creates synthetic inputs by itself; use `syntheticForestInputs()`
explicitly for examples. The output object is `WB_HartJohnstoneForestClassesAI_S5_5_Map`.

An `NA` timestep follows the core succession interval (10 years standalone); an explicit value
must match the core. Classification runs at priority 8.5 (after growth 6 and summary 8.25) at
the simulation start and at `start + n * interval`, up to the end. Plots (8.75) and saves (9)
start only when their initial times are set; their `NA` intervals follow the classification
interval.

When `writeClassificationCsv = TRUE`, each classification writes
`WB_HartJohnstoneForestClassesAI_S5_5_<time padded to three digits>.csv` to `outputPath(sim)`,
with the original's columns, row-name column and integer-truncated percentages. Caching is
skipped in that case so the file is always written. Saves write
`WB_HartJohnstoneForestClassesAI_S5_5_Map_time_<time>.tif` with the colour table inside the file.
Existing outputs are never overwritten.

## Reusing the classification outside SpaDES

```r
source("R/classifyForestClasses.R")
source("R/writeForestClassRaster.R")

forestClasses <- classifyForestClasses(cohortData, pixelGroupMap)
writeForestClassRaster(forestClasses, "forestClasses.tif")
```

`writeForestClassRaster()` stores the colour table inside the `.tif`; QGIS only shows the class
names as labels when the `.aux.xml` sidecar is written (`sidecar = TRUE`).

## Differences from the original

Output object and file names differ by design. This module refuses to overwrite files, stops
on malformed input (non-finite or negative biomass, bad IDs) and requires supplied inputs. It
does not reproduce the original's mutation of the caller's `cohortData`.

## Migration from 0.0.1

Removed: `dominanceThreshold`, `updateInterval`, `defaultForestSpeciesGroups()` and the `speciesGroups` and `forestClassColours` arguments. Use
`WB_HJForestClassesTimeStep` and the four species prefix parameters. The output object is now
`WB_HartJohnstoneForestClassesAI_S5_5_Map` and the layer is `standtype`. Class names and colours
now match the original. Deciduous is no longer tested first at 66%; see the rules above.

## Tests

Run `source("tests/unitTests.R")` from any directory. `tests/verify-parity.R` is a development
harness that compares this module with the original and Sol6_1; neither is a runtime dependency.

## Reference

Hart, S.J., Henkelman, J., McLoughlin, P.D., Nielsen, S.E., Truchon-Savard, A., Johnstone,
J.F. (2019). Examining forest resilience to changing fire frequency in a fire-prone region
of boreal forest. Global Change Biology 25, 869-884. https://doi.org/10.1111/gcb.14550

Drafted with assistance from Claude (Posit Assistant).
