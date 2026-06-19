% This script regenerates all of the plots that comprise Figure 5. pC1
% differentially promote and modulate male acoustic signaling.

%% Edit Path to Repository: 

PathToRepository = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis';


%% Load Data and Metadata to for Base Workspace:
addpath(genpath(PathToRepository));
% Load Song Data for all Experiment types:
load('SongRecordingData_BaseWorkspace.mat')
% Settings for Saving Plots:
SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figure5'; % can change as desired

%% Fig 5B: Heatmaps for Transient Responses (1-second window) at Stimulus Onset across LED Powers

[pulse_activate, sine_activate] = plot_songbypower_heatmap('all','courting_activation','transient');
[pulse_silence, sine_silence] = plot_songbypower_heatmap('all','courting_silencing','transient');


%% Fig 5C: LED Stimulus-Aligned Sine and Pulse event raster plots, and PSTHs for selected pC1 SS line:
% For SS106638, expressing in pC1_13a, 14ab:

%Function that finds the audiofiles corresponding to line fo interest, if
%given location to look for these:

plot_song_raster_psth('SS106638', 'courting_activation','audio_dir',PathToRepository);
plot_song_raster_psth('SS106638', 'courting_silencing','audio_dir',PathToRepository);



%% For Figures 5E and S10: Heatmap and table for transient response period for selected pC1 SS line, combined 3 highest LED powers:
% Used for PCA visualization of pC1-to-Song Premotor Neuron Connectivity
% and song phenotypes (executed in
% connectomics_figure5_pC1toSongPathDiscovery_PCA.ipynb)

% Get Z scores (relative to Empty Split Control) for highest LED power
% during early response period ("transient") and accompanying p values, to
% use for connectomic inquiries relating song output to circuit
% connectivity. This includes data for the 2 highest LED powers (3 and 4
% mW/cm^2)

%this table is saved as 'CourtingMaleActivation_Zscores_Pvalues.csv' in the data folder

[fig, tbl] = plot_song_heatmap_byperiod('all', 'courting_activation','period','transient');
%[fig_silence, tbl_silence] = plot_song_heatmap_byperiod('all', 'courting_silencing','period','transient');
