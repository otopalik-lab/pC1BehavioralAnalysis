% This script regenerates all of the plots that comprise Figure 5. pC1
% differentially promote and modulate male acoustic signaling.


%% if need to load cell types and line numbers:

%addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));
%load('MaleMaleBehavior_BaseWorkspace.mat'); % load workspace with pre-generated data and randomly selected trials (SSinds) for each stable split line, for reproducible figures:
selectedLines = table2struct(readtable('SSLines_withCelltypes.csv')); % Load SS line and celltype lists%
lines = {selectedLines.Var1}; lines = lines([1:35]);
celltypes = {selectedLines.Var2}; celltypes = celltypes([1:35]);

%% Load Data and Metadata to for Base Workspace:

addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));

% Load Song Data for all Experiment types:
load('SongRecordingData_BaseWorkspace.mat')

%% Settings for Saving Plots:

SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figure5'; % can change as desired

%% Fig 5B: LED Stimulus-Aligned Sine and Pulse event raster plots, and PSTHs for selected pC1 SS line:



