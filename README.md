This repository contains code for the processing and analysis of behavioral data collected for [Rubin et al., 2025](https://www.biorxiv.org/content/10.1101/2025.10.21.683766v1).

## Getting Started

1. After cloning this repository, users must download the figure source data and place this folder (data) in the repository's main directory (.../pC1_BehavioralAnalysis/data'). The source data are found at [insert FigShare link here].

3. Prior to running any scripts in MATLAB, the repository must be added to the MATLAB path: addpath(genpath('.../pC1_BehavioralAnalysis))

4. The user can then run any of the scripts situated in the figures directory to regenerate panels with behavioral analyses for Figures 5-7 and Supplemental Figures S5-8, S11-12.

5. Users can also access and download the raw song recordings and song type classifications (constituting Figure 5 and associated supplements), as well as the animal tracking and behavioral classification data (constituting Figure 6 and associated supplements) at [insert FigShare link here]. 

## Repository Contents

| Folder             | Description                                                                                                                                                                                                                                           |
|--------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| data |   This must be downloaded from [insert FigShare link here] and contains the workspaces and associated metadata to generate figures. By default, this directory is only stored locally and listed in .gitignore                                                 |
| figures            |   These scripts regenerate the panels with behavioral data for Figures 5-7, and associated supplements. They depend on the functions in the 'dep' directory.                                                                                                             |
| results            |   If 'SavePath' and 'SaveFormat' is specified any functions called the generate_figure scripts, the associated plots will be saved in the this directory, in the folder specified by 'SavePath'. By, default is the figures will not be saved and this directory is only stored locally and listed in .gitignore.  |                                                                                                             |
| dep                |   This contains functions on which the generate_figure scripts depend. Some functions are written by A. Otopalik, at times with assistance from Claude, whereas others were downloaded from the Mathworks website and cited below.             | 

The following were downloaded from the Mathworks website and reside in the 'dep' directory:
        
        Rob Kohr (2026). cell2csv (https://www.mathworks.com/matlabcentral/fileexchange/7601-cell2csv), MATLAB Central File Exchange. Retrieved             February 25, 2026.

        Jan Gläscher (2026). NaN Suite (https://www.mathworks.com/matlabcentral/fileexchange/6837-nan-suite), MATLAB Central File Exchange.                 Retrieved February 25, 2026.

        Marcin Konowalczyk (2026). shplot (https://www.mathworks.com/matlabcentral/fileexchange/64990-shplot), MATLAB Central File Exchange.                Retrieved February 25, 2026.

        Rajiv Narayan (2026). Psth (https://www.mathworks.com/matlabcentral/fileexchange/14745-psth), MATLAB Central File Exchange. Retrieved               February 25, 2026.



        


