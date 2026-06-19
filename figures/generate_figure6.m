% This script regenerates all of the plots that comprise Figure 6.
% pC1 cell types promote diverse male-male social interactions.


%% Edit Path to Repository: 

PathToRepository = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis';


%% Load Data and Metadata to for Base Workspace:

addpath(genpath(PathToRepository));
load('MaleMaleBehavior_BaseWorkspace.mat'); % load workspace with pre-generated data and randomly selected trials (SSinds) for each stable split line, for reproducible figures:
% Settings for Saving Plots:
SaveFormat = '.svg'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figure6'; % can change as desired

%% Fig 6A: Example of LED stimulus-aligned rasters of unilateral wing events, aggression events, and interfly distance for one example chamber:

plot_malemalebehavior_fullTimeseries('SS102671',{'unilateralwing', 'aggression'})

%% Figure 6B: Plot LED stimulus-aligned rasters, PSTHs, and Inter-fly Distances for Selected Lines

plot_malemalebehavior_STA('Empty Split',{'unilateralwing', 'aggression'},SavePath,SaveFormat);
plot_malemalebehavior_STA('SS03661',{'unilateralwing', 'aggression'},SavePath,SaveFormat);
plot_malemalebehavior_STA('SS106638',{'unilateralwing', 'aggression'},SavePath,SaveFormat);
plot_malemalebehavior_STA('SS102671',{'unilateralwing', 'aggression'},SavePath,SaveFormat);
plot_malemalebehavior_STA('SS100424',{'unilateralwing', 'aggression'},SavePath,SaveFormat);
plot_malemalebehavior_STA('SS59911',{'unilateralwing', 'aggression'},SavePath,SaveFormat);

plot_malemalebehavior_STA('SS102696',{'unilateralwing', 'aggression'},SavePath,SaveFormat);
plot_malemalebehavior_STA('SS100769',{'unilateralwing', 'aggression'},SavePath,SaveFormat);


%% Figure 6C: Heatmaps of behavioral probabilities over time across all pC1 SS Lines for selected behavioral classes:

binsize = 1000; %in milliseconds
plot_malemalebehavior_PSTH_heatmap('all','close', binsize) %'proximal is equivalent to 'close' in the paper
plot_malemalebehavior_PSTH_heatmap('all','unilateralwing', binsize)  
plot_malemalebehavior_PSTH_heatmap('all','aggression',binsize)  

%% Figure 6D: 2-bin (30-sec each) Heatmaps of behavioral probabilities with p-value annotations all pC1 SS Lines for selected behavioral classes:

plot_malemalebehavior_2bin_heatmap('all','close') %'proximal is equivalent to 'close' in the paper
plot_malemalebehavior_2bin_heatmap('all','unilateralwing')
plot_malemalebehavior_2bin_heatmap('all','aggression')

%% Figure 6E: Sankey Diagrams for LED Stimulation and Post-Stimulation Periods:

plot_behavior_sankey('all', {'close','aggression','unilateralwing'}, false, SavePath)
