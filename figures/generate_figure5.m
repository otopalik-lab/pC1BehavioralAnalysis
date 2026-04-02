% This script regenerates all of the plots that comprise Figure 5. pC1
% differentially promote and modulate male acoustic signaling.


%% if need to load cell types and line numbers:

addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));
selectedLines = table2struct(readtable('SSLines_withCelltypes.csv')); % Load SS line and celltype lists%
lines = {selectedLines.Var1}; lines = lines([1:36]);
celltypes = {selectedLines.Var2}; celltypes = celltypes([1:36]);

%% Load Data and Metadata to for Base Workspace:
addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));
% Load Song Data for all Experiment types:
load('SongRecordingData_BaseWorkspace_v3.mat')

%% Settings for Saving Plots:

SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figure5'; % can change as desired

%% Fig 5B: LED Stimulus-Aligned Sine and Pulse event raster plots, and PSTHs for selected pC1 SS line:

plot_song_raster_psth('Empty Split', 'isolated_activation');
plot_song_raster_psth('SS03661', 'isolated_activation');
plot_song_raster_psth('SS106638', 'isolated_activation');
plot_song_raster_psth('SS43275', 'isolated_activation');

plot_song_raster_psth('Empty Split', 'courting_activation');
plot_song_raster_psth('SS03661', 'courting_activation');

plot_song_raster_psth('SS106638', 'courting_activation');
plot_song_raster_psth('SS43275', 'courting_activation');

plot_song_raster_psth('Empty Split', 'courting_silencing');
plot_song_raster_psth('SS03661', 'courting_silencing');
plot_song_raster_psth('SS106638', 'courting_silencing');
plot_song_raster_psth('SS43275', 'courting_silencing');
plot_song_raster_psth('SS46542', 'courting_silencing');


%% Fig 5C: PSTH plots for all SS lines with significant phenotypes (?)

plot_song_psth_alllines('all', 'isolated_activation')
plot_song_psth_alllines('all', 'courting_activation')
plot_song_psth_alllines('all', 'courting_silencing')

%% Fig 5D or Supp: "Classic" Heatmaps pulse rate and sine rate as a function of LED intensity:




%% Fig 5E: Heatmaps for transient, LED, and post-stimulus periods for selected pC1 SS line, combined 3 highest LED powers:
% useful for connectomic analysis?

plot_song_heatmap_byperiod('all', 'isolated_activation')
plot_song_heatmap_byperiod('all', 'courting_activation')
plot_song_heatmap_byperiod('all', 'courting_silencing')

