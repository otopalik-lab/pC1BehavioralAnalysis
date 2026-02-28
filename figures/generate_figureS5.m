% This script regenerates all of the plots that comprise Figure Supplement
% 5. Extended Description of Behavioral Phenotypes during Male-Male
% Interactions across pC1 driver lines.

%% Load Data and Metadata to for Base Workspace:

addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));
load('MaleMaleBehavior_BaseWorkspace.mat');

%% Settings for Saving Plots:

SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figure5'; % can change as desired

%% Figure S5A: Heatmaps of behavioral probabilities over time across all pC1 SS Lines for all behavioral classes:

binsize = 1000; %in milliseconds
plot_PSTH_heatmap('all','close', binsize) 
plot_PSTH_heatmap('all','still', binsize)  
plot_PSTH_heatmap('all','chase',binsize)  
plot_PSTH_heatmap('all','approach',binsize)  
plot_PSTH_heatmap('all','orient',binsize)  
plot_PSTH_heatmap('all','unilateralwing',binsize)  
plot_PSTH_heatmap('all','tussle',binsize)  
plot_PSTH_heatmap('all','boxing',binsize)  
plot_PSTH_heatmap('all','headbutt',binsize)  
plot_PSTH_heatmap('all','wingflick',binsize)  

%% Figure 5SB: 2-bin (30-sec each) Heatmaps of behavioral probabilities with p-value annotations all pC1 SS Lines for all behavioral classes:

plot_2bin_heatmap('all','close') 
plot_2bin_heatmap('all','still')  
plot_2bin_heatmap('all','chase') 
plot_2bin_heatmap('all','approach')
plot_2bin_heatmap('all','orient')
plot_2bin_heatmap('all','unilateralwing')
plot_2bin_heatmap('all','tussle')
plot_2bin_heatmap('all','boxing')
plot_2bin_heatmap('all','headbutt')
plot_2bin_heatmap('all','wingflick')

%% Figure 5SC-D: Sankey Diagrams for LED Stimulation and Post-Stimulation Periods, all behavioral classes:

plot_behavior_sankey('all', {'close','still','chase','approach','orient',...
    'unilateralwing','tussle','boxing','headbutt','wingflick'}, false)
