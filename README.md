# WB_HartJohnstoneForestClassesAI_S5_5

## Scheduling update (2026-11-03)

Initial and recurring classification run at priority 8.5 after core growth and
summary, at simulation start and each core succession boundary. `updateInterval = NA`
follows the core timestep (10 years standalone); an explicit interval must match
the core when coupled. Optional plots follow at 8.75 and saves at 9, with missing
output intervals following the resolved classification interval. Output enablement
and scientific rules remain unchanged. This supersedes older timing descriptions.

A SpaDES module that converts the `cohortData` and `pixelGroupMap` of Biomass_core into a
map of forest classes adapted from Table 1 of Hart et al. (2019). Biomass (`B`) is used as
the proxy for tree species dominance. The drainage split of the spruce and non-forest
states is not applied.

## Classes

| Value | Class | Rule (share of the pixel group's total biomass) |
|---|---|---|
| NA | Non-forest | `pixelGroupMap` is 0 or NA |
| 1 | Deciduous | deciduous >= 66% |
| 2 | Coni-deci mix | everything that fits no other class |
| 3 | Conifer mix | no single group >= 66%, but pine + larch + spruce >= 66% |
| 4 | Pine | pine >= 66% (jack pine `Pinu_ban` and lodgepole pine `Pinu_con`) |
| 5 | Larch | larch >= 66% (`Lari_*`) |
| 6 | Spruce | spruce >= 66% (`Pice_*`) |

Deciduous species are `Popu_*` and `Betu_*`. Species in none of the groups (for example fir,
hemlock or cedar) count toward no group but stay in the biomass total, so a pixel group
dominated by them falls in class 2. The 66% threshold is the parameter `dominanceThreshold`.

## Reusing the classification outside SpaDES

The module only calls two functions that live in the `R` folder:

```r
source("R/classifyForestClasses.R")
source("R/writeForestClassRaster.R")

forestClasses <- classifyForestClasses(cohortData, pixelGroupMap)
writeForestClassRaster(forestClasses, "forestClasses.tif")
```

`classifyForestClasses()` takes a `cohortData` table (columns `pixelGroup`, `speciesCode`, `B`)
and a `pixelGroupMap` raster, and returns a raster with class names and a colour table
attached.

## Legend in QGIS

`writeForestClassRaster()` stores the colour table inside the `.tif`, so QGIS shows coloured
classes with no other file. The class names are also stored inside the `.tif`, but QGIS only
shows them as labels when the `.aux.xml` sidecar is written (`sidecar = TRUE`).

## Module use

Inputs: `cohortData`, `pixelGroupMap` (from Biomass_core). Output:
`WB_HartJohnstoneForestClassesAIMap`. The map is recomputed every `updateInterval` years
(default 10, the Biomass_core succession timestep).

## Reference

Hart, S.J., Henkelman, J., McLoughlin, P.D., Nielsen, S.E., Truchon-Savard, A., Johnstone,
J.F. (2019). Examining forest resilience to changing fire frequency in a fire-prone region
of boreal forest. Global Change Biology 25, 869-884. https://doi.org/10.1111/gcb.14550

Drafted with assistance from Claude (Posit Assistant).
