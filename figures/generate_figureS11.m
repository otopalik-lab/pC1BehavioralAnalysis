% This script regenerates all of the plots that comprise Figure Supplement
% 11. pC1/pC1x neurons differentially promote diverse component social behaviors. 


%% Edit Path to Repository: 

PathToRepository = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis';


%% Load Data and Metadata to for Base Workspace:

addpath(genpath(PathToRepository));
load('MaleMaleBehavior_BaseWorkspace.mat'); % load workspace with pre-generated data and randomly selected trials (SSinds) for each stable split line, for reproducible figures:
% Settings for Saving Plots:
SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figureS11'; % can change as desired


%% Figure S11A: Heatmaps of behavioral probabilities over time across all pC1 SS Lines for all behavioral classes:

binsize = 1000; %in milliseconds
plot_malemalebehavior_PSTH_heatmap('all','close', binsize) %'proximal is equivalent to 'close' in the paper
plot_malemalebehavior_PSTH_heatmap('all','still', binsize)  
plot_malemalebehavior_PSTH_heatmap('all','chase',binsize)  
plot_malemalebehavior_PSTH_heatmap('all','approach',binsize)  
plot_malemalebehavior_PSTH_heatmap('all','orient',binsize)  
plot_malemalebehavior_PSTH_heatmap('all','unilateralwing',binsize)  
plot_malemalebehavior_PSTH_heatmap('all','tussle',binsize)  
plot_malemalebehavior_PSTH_heatmap('all','boxing',binsize)  
plot_malemalebehavior_PSTH_heatmap('all','headbutt',binsize)  
plot_malemalebehavior_PSTH_heatmap('all','wingflick',binsize)  

%% Figure 511B: 2-bin (30-sec each) Heatmaps of behavioral probabilities with p-value annotations all pC1 SS Lines for all behavioral classes:

plot_malemalebehavior_stimbin_heatmap('all','close', binsize) %'proximal is equivalent to 'close' in the paper
plot_malemalebehavior_stimbin_heatmap('all','still', binsize)  
plot_malemalebehavior_stimbin_heatmap('all','chase',binsize)  
plot_malemalebehavior_stimbin_heatmap('all','approach',binsize)  
plot_malemalebehavior_stimbin_heatmap('all','orient',binsize)  
plot_malemalebehavior_stimbin_heatmap('all','unilateralwing',binsize)  
plot_malemalebehavior_stimbin_heatmap('all','tussle',binsize)  
plot_malemalebehavior_stimbin_heatmap('all','boxing',binsize)  
plot_malemalebehavior_stimbin_heatmap('all','headbutt',binsize)  
plot_malemalebehavior_stimbin_heatmap('all','wingflick',binsize)  

%% Figure 511C-D: Sankey Diagrams for LED Stimulation and Post-Stimulation Periods, all behavioral classes:

plot_behavior_sankey('all', {'close','still','chase','approach','orient',...
    'unilateralwing','tussle','boxing','headbutt','wingflick'}, false)
