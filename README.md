This repository contains code for the processing and analysis of behavioral data collected for [Rubin et al., 2025](https://www.biorxiv.org/content/10.1101/2025.10.21.683766v1).

## Requirements

- MATLAB R2019b or later
- Statistics and Machine Learning Toolbox

## Getting Started

1. Clone this repository.

2. Download the [figure source data](https://doi.org/10.25378/janelia.32666358) and place the downloaded `data` folder in the repository's main directory (`.../pC1BehavioralAnalysis/data`).

3. In each figure script you intend to run (located in the `figures` directory), update the `PathToRepository` variable at the top of the script to match the location of the repository on your machine:
   ```matlab
   PathToRepository = '/your/local/path/to/pC1BehavioralAnalysis';
   ```
   If you wish to save figure outputs, also update `SavePath` accordingly. By default, figures are not saved.

4. Add the repository to your MATLAB path by running the following in the MATLAB Command Window:
   ```matlab
   addpath(genpath('/your/local/path/to/pC1BehavioralAnalysis'))
   ```

5. Open and run any script in the `figures` directory to regenerate panels with behavioral analyses for Figures 5-7 and Supplemental Figures S5-8, S11-12. Scripts can be run all at once or section-by-section using MATLAB's cell mode (Ctrl+Enter / Cmd+Enter per `%%` section).

6. Raw song recordings, song type classifications, animal tracking data, and behavioral classifications are available at by request. As a forewarning, together these comprise 500GB of data. Thus, it is recommended that users first explore the processed data provided at the link in Step 2 above.

## Repository Contents

| Folder    | Description |
|-----------|-------------|
| `data`    | Must be downloaded from [this link](https://doi.org/10.25378/janelia.32666358) . Contains workspaces and associated metadata used to generate figures. Not tracked by git (listed in `.gitignore`). |
| `figures` | Scripts to regenerate panels with behavioral data for Figures 5-7 and associated supplements. Depend on functions in `dep`. |
| `results` | Figure outputs are saved here when `SavePath` and `SaveFormat` are specified in a generate_figure script. Not tracked by git (listed in `.gitignore`). |
| `dep`     | Helper functions used by the generate_figure scripts. Includes functions written by A. Otopalik (at times with Claude's assistance) and third-party functions from MATLAB File Exchange (credited below). |

## Key Helper Functions (`dep`)

The following functions in `dep` are called by the figure-generating scripts. Functions not listed here are either third-party utilities (see [Third-Party Dependencies](#third-party-dependencies)) or internal helpers called indirectly.

### Analysis of Male Acoustic Signaling (Courtship Song) with Optogenetic Perturbations

| Function | Description |
|----------|-------------|
| `plot_song_raster_psth` | Generates a 5-panel figure with an LED stimulus trace, raw audio trace, pulse/sine song rasters, and a joint PSTH for a single SS line. |
| `plot_song_psth_alllines` | Produces LED-aligned joint pulse/sine PSTHs for multiple SS lines, distributing lines across figures. |
| `plot_songbypower_heatmap` | Plots a heatmap of evoked song across SS lines (rows) and LED powers (columns), with an accompanying significance heatmap. |
| `plot_song_heatmap_byperiod` | Generates a heatmap of evoked song pooled across the top N LED powers, with columns for Transient, LED, and Post stimulus periods. |

### Analysis of Male-Male Interactions with Optogenetic Activation

| Function | Description |
|----------|-------------|
| `plot_malemalebehavior_fullTimeseries` | Plots LED-aligned behavioral rasters and inter-fly distance time series for male–male interaction experiments. |
| `plot_malemalebehavior_STA` | Plots stimulus-triggered averages (rasters, PSTHs, inter-fly distance) aligned to the 3 highest-power LED pulses for a specified behavior. |
| `plot_malemalebehavior_PSTH_heatmap` | Plots a peri-stimulus PSTH heatmap of behavioral probability across SS lines, aligned to high-power LED epochs. |
| `plot_malemalebehavior_stimbin_heatmap` | Plots a 2-bin (pre vs. LED-on) heatmap of behavioral probability across SS lines with significance annotations. |
| `plot_malemalebehavior_2bin_heatmap` | Plots a 2-bin (30 s LED-on vs. 30 s LED-off) PSTH heatmap across SS lines with significance annotations. |
| `plot_behavior_sankey` | Computes behavioral probabilities during LED stimulation epochs and renders Sankey diagrams showing behavioral state transitions. |

### Analysis of Female-Male Interactions with Optogenetic Silencing

| Function | Description |
|----------|-------------|
| `plot_femalemale_STA` | Produces stimulus-triggered averages (rasters, PSTHs, timeseries) for female–male interaction data aligned to LED onset. |
| `plot_femalemale_PSTH_heatmap` | Generates a peri-stimulus PSTH heatmap of behavioral probability across SS lines for female–male interaction experiments. |
| `plot_femalemalebehavior_stimbin_heatmap` | Creates a 2-bin (pre vs. stim) heatmap of behavioral probability across SS lines for female–male interaction experiments. |

### Analysis of Interactions in Groups of Males with Optogenetic Activation

| Function | Description |
|----------|-------------|
| `build_multistim_workspace` | Assembles per-experiment struct arrays from raw aggression and inter-fly distance data for use by downstream multi-stim plotting functions. |
| `plot_multistim_timeseries` | Plots mean ± SEM time courses of aggression or inter-fly distance across conditions, with shaded stimulus epochs. |
| `plot_multistim_pre_during_boxplot` | Creates paired pre-stim vs. during-stim boxplots with Wilcoxon matched-pairs significance testing. |

## Third-Party Dependencies

The following were downloaded from the MathWorks File Exchange and reside in the `dep` directory:

- Rob Kohr (2026). [cell2csv](https://www.mathworks.com/matlabcentral/fileexchange/7601-cell2csv), MATLAB Central File Exchange. Retrieved February 25, 2026.
- Jan Gläscher (2026). [NaN Suite](https://www.mathworks.com/matlabcentral/fileexchange/6837-nan-suite), MATLAB Central File Exchange. Retrieved February 25, 2026.
- Marcin Konowalczyk (2026). [shplot](https://www.mathworks.com/matlabcentral/fileexchange/64990-shplot), MATLAB Central File Exchange. Retrieved February 25, 2026.
- Rajiv Narayan (2026). [Psth](https://www.mathworks.com/matlabcentral/fileexchange/14745-psth), MATLAB Central File Exchange. Retrieved February 25, 2026.
