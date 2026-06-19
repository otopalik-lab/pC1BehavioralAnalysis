% This script regenerates the plots that comprise Figures S6-S8. Changes in male courtship 
% song in responses to pC1/pC1x optogenetic perturbations across lines, sets 1-3.

addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));
%% Load Data and Metadata to for Base Workspace:
load('SongRecordingData_BaseWorkspace.mat')
% Settings for Saving Plots:
SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figureS6to8'; % can change as desired

%% Figure Supplements 6-8: PSTH plots for all SS lines

plot_song_psth_alllines('all', 'isolated_activation')
plot_song_psth_alllines('all', 'courting_activation')
plot_song_psth_alllines('all', 'courting_silencing')
