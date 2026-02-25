# pC1_BehavioralAnalysis
## This repository contains code for the processing and analysis of behavioral data collected for Rubin et al., 2025.

## Getting Started

1. After cloning this repository, users must download the figure source data and place this folder (figure_src_data) in the repository so that its path is as follows: ('.../pC1_BehavioralAnalysis/figure_src_data').

2. Prior to running any scripts in MATLAB, the repository must be added to the MATLAB path:
      addpath(genpath([Insert path to pC1_BehavioralAnalysis here]);

3. The user can then run any of the scripts situated in the figures directory to regenerate Figures 4, 5 and associated supplements.

4. The user can also access and download the raw song recordings and song type classifications (constituting Figure 4 and associated supplements) and animal tracking data (constituting Figure 5 and associated supplements) at [insert link here]. The user can then employ scripts in src_code to process these data for regeneration of the figure source data folder.

## Repository Contents

figure_src_data: This must be downloaded from [insert link here] and contains the workspaces and associated metadata to generate Figures.

figures:  These scripts regenerate the contents of Figures 4, 5, and associated supplements. They depend on the functions in the 'dep' directory.

results:  If 'save' is set to 'True' in any of the figures scripts, the plots will be saved in the this directory, in the specified folder. The               default is that the figures will not be saved. This directory is only stored locally and listed in .gitignore.

src_code: 

dep:   Contains functions on which data processing and analysis code depends. Some functions are written by A. Otopalik, at times with assistance          from Claude. The following were downloaded from the Mathworks website:
        
        Rob Kohr (2026). cell2csv (https://www.mathworks.com/matlabcentral/fileexchange/7601-cell2csv), MATLAB Central File Exchange. Retrieved             February 25, 2026.

        Jan Gläscher (2026). NaN Suite (https://www.mathworks.com/matlabcentral/fileexchange/6837-nan-suite), MATLAB Central File Exchange.                 Retrieved February 25, 2026.

        Marcin Konowalczyk (2026). shplot (https://www.mathworks.com/matlabcentral/fileexchange/64990-shplot), MATLAB Central File Exchange.                Retrieved February 25, 2026.

        Rajiv Narayan (2026). Psth (https://www.mathworks.com/matlabcentral/fileexchange/14745-psth), MATLAB Central File Exchange. Retrieved               February 25, 2026.



        


