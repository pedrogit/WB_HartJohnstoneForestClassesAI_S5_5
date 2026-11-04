# Prompts used to build WB_HartJohnstoneForestClassesAI_S5_5

Drafted with assistance from Claude (Posit Assistant).

This file records the requests made to the AI assistant while this module was built.

Part 1 is reconstructed from a summary of the early conversation, not copied word for word, because the
original wording was no longer available. Part 2 is copied word for word, spelling mistakes included.

## Part 1. Early requests (paraphrased)

1. read what is in G:\Home\repositories\main\AI and G:\Home\Projects\LichenBiomassFullAI and limit yourself to those folders

2. it is in one of the subfolder

3. did you read all the files

4. Read all files in guidelines/, AGENTS-rules/ and skills/ in the AI repo.

5. now read this pdf: http://www.ace-lab.ca/assets_b/Hart_et_al-2019-Global_Change_Biology.pdf and get forest type classification rules from the proper table

6. develop a new spades module in the G:\Home\Projects\LichenBiomassFullAI project folder named "WB_HartJohnstoneForestClassesAI" converting biomass_core pixelGroupMap and cohortdata to a raster representing the classes defined in the article. don't split spruce and non-forest by drainage yet. use biomass as a proxi for tree species dominance. non forest should only be based on pixelGroupMap being 0, null or na. other classes should be 1 for deciduous, 2 for coni-deci mix, 3 for coni mix, 4 for jack pine, 5 for larch and 6 for spruce. gather all the raster generation in one function that i can reuse somewhere else. That function should accept a cohortdata table and a pixelGroupMap raster and return a reclassified raster. Put that function in the R folder. propose a plan before proceeding

7. when udating the plan, always make a backup of the existing plan and show me the difference with the new plan. also name the output map "WB_HartJohnstoneForestClassesAIMap.

8. Answer the four open points so the plan can be finalized.
   - non-forest is `NA`;
   - the two pine species are merged into one class;
   - the map is updated every succession timestep;
   - species outside the four groups stay in the biomass total and count toward no group;
   - the output map is named `WB_HartJohnstoneForestClassesAIMap`;
   - the legend must work in QGIS (embedded colours, class names if possible, sidecar only if needed).

9. when i say show the diff i mean use vscode diff

10. i don't see the diff. by vscode i meant here in positron

11. can't you search on the web to know how to display a diff in positron

12. make sure the output raster contains a legend that work in qgis

13. is it possible to get a legend without any sister files

14. Use option 3: embed colours in the TIFF, try embedding names, and fall back to the .aux.xml sidecar only if QGIS doesn't show them.



## Part 2. Later requests (verbatim)

1. which tests did you do
2. where did you save the output rasters
3. List the scratch folder and give me the full path of the year-10 GeoTIFF to open in QGIS.
4. how big is this raster
5. what is spades recommandation about providing fake or default data so a module can run by itself
6. Check whether WB_HartJohnstoneForestClassesAI has a .inputObjects default, and add a small synthetic cohortData and pixelGroupMap so it runs standalone.
7. Add a testthat check that the standalone run gives classes 1 to 6 and two NA pixels.
8. Run the full test directory to confirm all tests pass together.
9. Add the module to setup_biomass_core_project.R so it runs after Biomass_core.
10. what means "I'm adding it after Biomass_core, through bash to avoid format-on-save."
11. Run the project script end to end and check that the forest class map is saved in outputs.
12. Check why the saved rasters have no CRS, starting with sim$pixelGroupMap.
13. add S5.5 to the module name
14. replace the dot with an underscore, add as a suffix and rename the output files
15. Delete the two old-named GeoTIFFs from outputs/ and rerun the full project script
16. change the main script to run for a loger time and set .saveInitialTime
17. Run the project script with end = 100 and check the saved maps across years.
18. Plot the class areas over time as a line chart.
19. save all prompts used in this discussion as a file in the module folder

read what is in G:\Home\Projects\LichenBiomassFullAI mostly what is in G:\Home\Projects\LichenBiomassFullAI\OtherRepos\AI

list the three version of the WB_HartJohnstoneForestClasses module


run the main project script alternatively activating each 


Now i want you to evaluate each three module by running the main project script alternatively with each module activated. Two of them should not be activated at the same time. Then I want you to:

- measure the performance of each module when running them alternatively
- evaluate the quality of each module implementation. Which one is worst? Which one is better? Why?
- compare the resulting rasters of each module
- evaluate the completeness and quality of each module documentation
- easiness of comprehension of each module implementation by a human

At the end make a comparison table in a .md file at the base of the project  with all your findings. Make no change to anything other than this .md file.

evaluate each three module separately based on this framework by running the main project script alternatively with each module activated. Two of them should not be activated at the same time. At the end make a comparison table in a .md file at the base of the project with all your findings. Make no change to anything other file than this .md file. make a plan before proceeding