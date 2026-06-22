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

6. Optionally, raw song recordings, song type classifications, animal tracking data, and behavioral classifications are available at [insert FigShare link here].

## Repository Contents

| Folder    | Description |
|-----------|-------------|
| `data`    | Must be downloaded from [insert FigShare link here]. Contains workspaces and associated metadata used to generate figures. Not tracked by git (listed in `.gitignore`). |
| `figures` | Scripts to regenerate panels with behavioral data for Figures 5-7 and associated supplements. Depend on functions in `dep`. |
| `results` | Figure outputs are saved here when `SavePath` and `SaveFormat` are specified in a generate_figure script. Not tracked by git (listed in `.gitignore`). |
| `dep`     | Helper functions used by the generate_figure scripts. Includes functions written by A. Otopalik (at times with Claude's assistance) and third-party functions from MATLAB File Exchange (credited below). |

## Third-Party Dependencies

The following were downloaded from the MathWorks File Exchange and reside in the `dep` directory:

- Rob Kohr (2026). [cell2csv](https://www.mathworks.com/matlabcentral/fileexchange/7601-cell2csv), MATLAB Central File Exchange. Retrieved February 25, 2026.
- Jan Gläscher (2026). [NaN Suite](https://www.mathworks.com/matlabcentral/fileexchange/6837-nan-suite), MATLAB Central File Exchange. Retrieved February 25, 2026.
- Marcin Konowalczyk (2026). [shplot](https://www.mathworks.com/matlabcentral/fileexchange/64990-shplot), MATLAB Central File Exchange. Retrieved February 25, 2026.
- Rajiv Narayan (2026). [Psth](https://www.mathworks.com/matlabcentral/fileexchange/14745-psth), MATLAB Central File Exchange. Retrieved February 25, 2026.
