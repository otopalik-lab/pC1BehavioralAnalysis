% This script regenerates all of the plots that comprise Figure Supplement
% 12. Silencing of pC1/pC1x cell types during male-female courtship. 

%% Edit Path to Repository: 

PathToRepository = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis';

%% Load Data and Metadata to for Base Workspace:
addpath(genpath(PathToRepository));
% Load Female-Male Behavioral Data:
load('FemaleMaleData_BaseWorkspace.mat')
% Settings for Saving Plots:
SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figureS12'; % can change as desired

%% Figures S12A: Example Full Timeseries

%plot_femalemale_fullTimeSeries_og(lines{24}, {'m_unilateralwing'},{'Distance', 'FacingAngle', 'AngleBetween'})
%plot_femalemale_fullTimeSeries_og(lines{29}, {'m_unilateralwing','chase'},{'Distance', 'FacingAngle', 'AngleBetween'})

%% Figure S12B: STAs selected lines 

plot_femalemale_STA(lines{1}, {'m_unilateralwing'},{'Distance', 'FacingAngle', 'AngleBetween'})
plot_femalemale_STA(lines{2}, {'m_unilateralwing'},{'Distance', 'FacingAngle', 'AngleBetween'})
plot_femalemale_STA(lines{20}, {'m_unilateralwing'},{'Distance', 'FacingAngle', 'AngleBetween'})


%% Figure S12C: Heatmaps of behavioral probabilities over time across all pC1 SS Lines for all behavioral classes:

binsize = 4000; %in milliseconds
plot_femalemale_PSTH_heatmap('all','close', binsize) %'proximal is equivalent to 'close' in the paper
plot_femalemale_PSTH_heatmap('all','m_orient', binsize) 
plot_femalemale_PSTH_heatmap('all','m_behind',binsize) 
plot_femalemale_PSTH_heatmap('all','chase',binsize) 
plot_femalemale_PSTH_heatmap('all','m_behind',binsize) 
plot_femalemale_PSTH_heatmap('all','m_approach',binsize) 
plot_femalemale_PSTH_heatmap('all','m_unilateralwing',binsize)  
plot_femalemale_PSTH_heatmap('all','m_still',binsize)  
plot_femalemale_PSTH_heatmap('all','f_still',binsize)  


%% Figure S12D: Single-Bin Heatmaps for stim period only
plot_femalemalebehavior_stimbin_heatmap('all','close','stim','zscore')
plot_femalemalebehavior_stimbin_heatmap('all','m_behind','stim','zscore')
plot_femalemalebehavior_stimbin_heatmap('all','m_orient','stim','zscore')
plot_femalemalebehavior_stimbin_heatmap('all','m_unilateralwing','stim','zscore')
plot_femalemalebehavior_stimbin_heatmap('all','chase','stim','zscore')
plot_femalemalebehavior_stimbin_heatmap('all','m_approach','stim','zscore')


%% Extra: Boxplots of behavioral probabilities during LED period only:
% 
% plot_femalemale_behavior_boxplot('all', 'close')
% plot_femalemale_behavior_boxplot('all', 'm_orient')
% plot_femalemale_behavior_boxplot('all', 'm_behind')
% plot_femalemale_behavior_boxplot('all', 'chase')
% plot_femalemale_behavior_boxplot('all', 'm_approach')
% plot_femalemale_behavior_boxplot('all', 'm_unilateralwing')
% plot_femalemale_behavior_boxplot('all', 'm_still')