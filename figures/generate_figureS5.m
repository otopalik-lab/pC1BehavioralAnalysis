%% Load Data and Metadata to for Base Workspace:
addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));
% Load Song Data for all Experiment types:
load('SongRecordingData_BaseWorkspace.mat')

%% Settings for Saving Plots:

SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figureS5'; % can change as desired

%% Fig 5 Supplement #1: PSTH plots for all SS lines

plot_song_psth_alllines('all', 'isolated_activation')
plot_song_psth_alllines('all', 'courting_activation')
plot_song_psth_alllines('all', 'courting_silencing')
