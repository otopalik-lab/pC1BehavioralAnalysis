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

%% Fig 5A: Setup & Complete Optogenetic Stimulation Paradigms

figure(1);
subplot(3,1,1);
power_calib_factor = max(data_courtingmale_activation(1).LEDPowers)./max(data_courtingmale_activation(1).LED);
plot([1:length(data_courtingmale_activation(1).LED)]./data_courtingmale_activation(1).fs, power_calib_factor.*data_courtingmale_activation(1).LED, 'r-','LineWidth',1)
ylabel('629nm LED (mW/cm^2)'); box off

subplot(3,1,2);
power_calib_factor = max(data_courtingmale_silencing(1).LEDPowers)./max(data_courtingmale_silencing(1).LED);
plot([1:length(data_courtingmale_silencing(1).LED)]./data_courtingmale_silencing(1).fs, power_calib_factor.*data_courtingmale_silencing(1).LED, 'g-','LineWidth',1)
ylabel('525nm LED (mW/cm^2)'); box off

subplot(3,1,3);
power_calib_factor = max(data_isolatedmale_activation(1).LEDPowers)./max(data_isolatedmale_activation(1).LED);
plot([1:length(data_isolatedmale_activation(1).LED)]./data_isolatedmale_activation(1).fs, power_calib_factor.*data_isolatedmale_activation(1).LED, 'r-','LineWidth',1)
ylabel('629nm LED (mW/cm^2)'); box off; xlabel('seconds')

%% Fig 5C: LED Stimulus-Aligned Sine and Pulse event raster plots, and PSTHs for selected pC1 SS line:
% For SS106638, expressing in pC1_13a, 14ab:
plot_song_raster_psth('SS106638', 'isolated_activation')
plot_song_raster_psth('SS106638', 'courting_activation');
plot_song_raster_psth('SS106638', 'courting_silencing');


%% Fig 5D: Heatmaps for Transient Responses (1-second window) at Stimulus Onset across LED Powers


plot_songbypower_heatmaps_cols('all','courting_activation', 'transient');
plot_songbypower_heatmaps_cols('all','courting_silencing', 'transient');
plot_songbypower_heatmaps_cols('all','isolated_activation', 'transient');
plot_songbypower_heatmaps_cols('all','isolated_activation', 'post');



%% Fig 5E: Heatmaps for transient, LED, and post-stimulus periods for selected pC1 SS line, combined 3 highest LED powers:
% useful for connectomic analysis?

plot_song_heatmap_byperiod('all', 'isolated_activation')
plot_song_heatmap_byperiod('all', 'courting_activation')
plot_song_heatmap_byperiod('all', 'courting_silencing')

