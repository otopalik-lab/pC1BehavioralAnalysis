% This script regenerates all of the plots that comprise Figure 5

%% Settings for Saving Plots:

SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figure5'; % can change as desired

%% Load Data and Metadata to for Base Workspace:

addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));
load('MaleMaleBehavior_new.mat'); % load workspace with pre-generated data and randomly selected trials (SSinds) for each stable split line, for reproducible figures:
selectedLines = table2struct(readtable('SSLines_withCelltypes.csv')); % Load line and celltype lists
lines = {selectedLines.Var1}; lines = lines([1 3:35]);
celltypes = {selectedLines.Var2}; celltypes = celltypes([1 3:35])

%% Fig 5A: Example of LED stimulus-aligned rasters of unilateral wing events, aggression events, and interfly distance for one example chamber:

plot_behavior_fullTimeseries('SS102671',{'unilateralwing', 'aggression'})

%% Figure 5B: Plot LED stimulus-aligned rasters, PSTHs, and Inter-fly Distances for Selected Lines

plot_behavior_STA('Empty Split',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS03661',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS106638',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS102671',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS100424',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS59911',{'unilateralwing', 'aggression'});

%% Figure 5C: Heatmaps of behavioral probabilities over time across all pC1 SS Lines for selected behavioral classes:

binsize = 1000; %in milliseconds
plot_PSTH_heatmap('all','close', binsize) %'proximal is equivalent to 'close' in the paper
plot_PSTH_heatmap('all','unilateralwing', binsize)  
plot_PSTH_heatmap('all','aggression',binsize)  

%% Figure 5D: 2-bin (30-sec each) Heatmaps of behavioral probabilities with p-value annotations all pC1 SS Lines for selected behavioral classes:

plot_2bin_heatmap('all','close') %'proximal is equivalent to 'close' in the paper
plot_2bin_heatmap('all','proximal') %'proximal is equivalent to 'close' in the paper
plot_2bin_heatmap('all','unilateralwing')
plot_2bin_heatmap('all','aggression')

%% Figure 5E: Sankey Diagrams for LED Stimulation and Post-Stimulation Periods:

plot_behavior_sankey('all', {'proximal','aggression','unilateralwing'}, false)
