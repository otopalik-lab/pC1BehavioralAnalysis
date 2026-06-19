% This script regenerates the plots that comprise Figure S5. Experimental conditions 
% for song recording assays and pC1/pC1x activation phenotypes in isolated males.

%% Edit Path to Repository: 

PathToRepository = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis';

%% Load Data and Metadata to for Base Workspace:
addpath(genpath(PathToRepository));
% Load Song Data for all Experiment types:
load('SongRecordingData_BaseWorkspace.mat')
% Settings for Saving Plots:
SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figureS5'; % can change as desired
%% Fig S5B: Setup & Complete Optogenetic Stimulation Paradigms

figure(1);
subplot(3,1,1);
power_calib_factor = max(data_courtingmale_activation(1).LEDPowers)./max(data_courtingmale_activation(1).LED);
plot([1:length(data_courtingmale_activation(1).LED)]./data_courtingmale_activation(1).fs, power_calib_factor.*data_courtingmale_activation(1).LED, 'r-','LineWidth',1)
ylabel('629nm LED (mW/cm^2)'); box off

subplot(3,1,2);
power_calib_factor = max(data_courtingmale_silencing(1).LEDPowers)./max(data_courtingmale_silencing(1).LED);
plot([1:length(data_courtingmale_silencing(1).LED)]./data_courtingmale_silencing(1).fs, power_calib_factor.*data_courtingmale_silencing(1).LED, 'g-','LineWidth',1)
ylabel('525nm LED (mW/cm^2)'); box off

subplot(3,1,3);
power_calib_factor = max(data_isolatedmale_activation(1).LEDPowers)./max(data_isolatedmale_activation(1).LED);
plot([1:length(data_isolatedmale_activation(1).LED)]./data_isolatedmale_activation(1).fs, power_calib_factor.*data_isolatedmale_activation(1).LED, 'r-','LineWidth',1)
ylabel('629nm LED (mW/cm^2)'); box off; xlabel('seconds')

%% Figure S5C: LED Stimulus-Aligned Sine and Pulse event raster plots, and PSTHs for selected pC1 SS line:
plot_song_raster_psth('SS106638', 'isolated_activation','audio_dir',PathToRepository);

%% Figure S5D: Heatmaps for Transient Responses (1-second window) at Stimulus Onset and
% Post-stimulation periods (5-sec window) across LED powers:

[pulse_activate_iso_transient, sine_activate_iso_transient] = plot_songbypower_heatmap('all','isolated_activation', 'transient');
[pulse_activate_iso_post, sine_activate_iso_post] = plot_songbypower_heatmap('all','isolated_activation', 'post');
