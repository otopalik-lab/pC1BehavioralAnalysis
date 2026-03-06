% This script regenerates all of the plots that comprise Figure Supplement
% 6. pC1 cell types differentially contribute to male courtship behaviors

%% if need to load cell types and line numbers:

cd '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/metadata';
selectedLines = table2struct(readtable('SSLines_withCelltypes.csv')); % Load SS line and celltype lists%
lines = {selectedLines.Var1}; lines = lines([1:35]);
celltypes = {selectedLines.Var2}; celltypes = celltypes([1:35]);

%% Load Data and Metadata to for Base Workspace:
addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));
% Load Female-Male Behavioral Data:
load('FemaleMaleData_BaseWorkspace.mat')

%% Settings for Saving Plots:

SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figureS7'; % can change as desired

%%