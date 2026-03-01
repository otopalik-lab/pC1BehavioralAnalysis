% This script regenerates all of the plots that comprise Figure 5. pC1
% differentially promote and modulate male acoustic signaling.

%% Load Data and Metadata to for Base Workspace:

addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));

% Load Song Data for all Experiment types:
load('SongRecordingData_BaseWorkspace.mat')

%% Settings for Saving Plots:

SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figure5'; % can change as desired

%% Fig 5A: 