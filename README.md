## THIS README NEEDS REVISION AS OF 04/08/2026

This repository contains code for the processing and analysis of behavioral data collected for [Rubin et al., 2025](https://www.biorxiv.org/content/10.1101/2025.10.21.683766v1).

## Getting Started

1. After cloning this repository, users must download the figure source data and place this folder (data) in the repository's main directory (.../pC1_BehavioralAnalysis/data')

2. Prior to running any scripts in MATLAB, the repository must be added to the MATLAB path: addpath(genpath('.../pC1_BehavioralAnalysis))

3. The user can then run any of the scripts situated in the figures directory to regenerate Figures 5, 6 and associated supplements.

4. The user can also access and download the raw song recordings and song type classifications (constituting Figure 5 and associated supplements), as well as the animal tracking and behavioral classification data (constituting Figure 6 and associated supplements) at [insert link here]. The user can then employ scripts in processing_code to process these data for regeneration of the figure source data folder. 

## Repository Contents

| Folder             | Description                                                                                                                                                                                                                                           |
|--------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| data |   This must be downloaded from [insert link here] and contains the workspaces and associated metadata to generate Figures. By default, this directory is only stored locally and listed in .gitignore                                                 |
| figures            |   These scripts regenerate the contents of Figures 5, 6, and associated supplements. They depend on the functions in the 'dep' directory.                                                                                                             |
| results            |   If 'save' is set to 'True' in any of the figures scripts, the plots will be saved in the this directory, in the specified folder. By, default is the figures will not be saved and this directory is only stored locally and listed in .gitignore.  |                           
| processing_code    |   This code regenerates the figure_src_data from the raw song recordings and song types classifications, as well as animal tracking and behavioral classifications.                                                                                   |
| dep                |   This contains functions on which data processing and figure scripts depend. Some functions are written by A. Otopalik, at times with assistance from Claude, whereas others were downloaded from the Mathworks website and cited below.             | 

The following were downloaded from the Mathworks website and reside in the 'dep' directory:
        
        Rob Kohr (2026). cell2csv (https://www.mathworks.com/matlabcentral/fileexchange/7601-cell2csv), MATLAB Central File Exchange. Retrieved             February 25, 2026.

        Jan Gläscher (2026). NaN Suite (https://www.mathworks.com/matlabcentral/fileexchange/6837-nan-suite), MATLAB Central File Exchange.                 Retrieved February 25, 2026.

        Marcin Konowalczyk (2026). shplot (https://www.mathworks.com/matlabcentral/fileexchange/64990-shplot), MATLAB Central File Exchange.                Retrieved February 25, 2026.

        Rajiv Narayan (2026). Psth (https://www.mathworks.com/matlabcentral/fileexchange/14745-psth), MATLAB Central File Exchange. Retrieved               February 25, 2026.



        


