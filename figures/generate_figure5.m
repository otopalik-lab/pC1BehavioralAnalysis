% This script regenerates all of the plots that comprise Figure 5. pC1
% differentially promote and modulate male acoustic signaling.

%% Settings for Saving Plots:

SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figure5'; % can change as desired

%% Load Data and Metadata to for Base Workspace:

addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));

% Load Isolated Male Activation Data
load('/Users/otopalika/Documents/GitHub/P1ScreenAnalysis/results/SingleMaleSong2/compiledActivationData_SMS2_v6_5secStimuli_PulseSineRatesOnly.mat');
data_activation = data;

% Load Courting Male Activation Data
load('/Users/otopalika/Documents/GitHub/P1ScreenAnalysis/results/MaleFemalePairSong_Chrimson/compiledData_MFPChrimson_v5.mat');
data_MFP_activation = data;

% Load Courting Male Silencing Data
load('/Users/otopalika/Documents/GitHub/P1ScreenAnalysis/results/MaleFemalePairSong/compiledSilencingData_v9_SongRatesOnly.mat'); % this has only song rates and idx data (1/1)
data_silence = data;

load('MaleMaleBehavior_new.mat'); % load workspace with pre-generated data and randomly selected trials (SSinds) for each stable split line, for reproducible figures:
selectedLines = table2struct(readtable('SSLines_withCelltypes.csv')); % Load line and celltype lists
lines = {selectedLines.Var1}; lines = lines([1 3:35]);
celltypes = {selectedLines.Var2}; celltypes = celltypes([1 3:35])

%% Fig 5A: 