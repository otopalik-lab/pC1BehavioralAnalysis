% This script regenerates all of the plots that comprise Figure 5.
% pC1 cell types differentially promote and modulate male acoustic signaling.

%% 


addpath(genpath('/Users/otopalika/Documents/GitHub/P1ScreenAnalysis'))

% Load Single Male CsChrimson Data Set:

%load('/Users/otopalika/Documents/GitHub/P1ScreenAnalysis/results/SingleMaleSong2/compiledActivationData_SMS2_v3.mat'); %old data set 
%load('/Users/otopalika/Documents/GitHub/P1ScreenAnalysis/results/SingleMaleSong2/compiledActivationData_SMS2_v5_binned_3mWcm2.mat')
%load('/Users/otopalika/Documents/GitHub/P1ScreenAnalysis/results/SingleMaleSong2/compiledActivationData_SMS2_v4_5secStimulationsOnly.mat')
load('/Users/otopalika/Documents/GitHub/P1ScreenAnalysis/results/SingleMaleSong2/compiledActivationData_SMS2_v6_5secStimuli_PulseSineRatesOnly.mat');
data_activation = data;