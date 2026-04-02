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

%% Figure S7A: Full TimeSeries of Empty Split

plot_femalemale_fullTimeSeries(lines{1}, {'m_unilateralwing'},{'Distance', 'FacingAngle', 'AngleBetween', 'MaleVelocity'})
plot_femalemale_fullTimeSeries(lines{2}, {'m_unilateralwing'},{'Distance', 'FacingAngle', 'AngleBetween', 'MaleVelocity'})
plot_femalemale_fullTimeSeries(lines{20}, {'m_unilateralwing'},{'Distance', 'FacingAngle', 'AngleBetween', 'MaleVelocity'})


%% Figure S7B: Heatmaps of behavioral probabilities over time across all pC1 SS Lines for all behavioral classes:

binsize = 4000; %in milliseconds
plot_femalemale_PSTH_heatmap('all','close', binsize) %'proximal is equivalent to 'close' in the paper
plot_femalemale_PSTH_heatmap('all','m_orient', binsize)  
plot_femalemale_PSTH_heatmap('all','chase',binsize) 
plot_femalemale_PSTH_heatmap('all','m_behind',binsize) 
plot_femalemale_PSTH_heatmap('all','m_approach',binsize) 
plot_femalemale_PSTH_heatmap('all','m_unilateralwing',binsize)  
plot_femalemale_PSTH_heatmap('all','m_still',binsize)  

%% Figure S7C: Boxplots of behavioral probabilities during LED period only:

plot_femalemale_behavior_boxplot('all', 'close')
plot_femalemale_behavior_boxplot('all', 'm_orient')
plot_femalemale_behavior_boxplot('all', 'm_behind')
plot_femalemale_behavior_boxplot('all', 'chase')
plot_femalemale_behavior_boxplot('all', 'm_approach')
plot_femalemale_behavior_boxplot('all', 'm_unilateralwing')
plot_femalemale_behavior_boxplot('all', 'm_still')


%% Figure S7C:
