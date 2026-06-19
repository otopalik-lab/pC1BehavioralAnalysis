% generate_figureS7R.m
%
% Regenerates Figure S7R: aIPg-SS > UAS-Chrimson optogenetic activation
% drives reduced inter-fly distance and elevated aggressive behaviors,
% relative to empty-split > UAS-Chrimson controls.
%
% Three panels:
%   (1) Inter-fly distance (mm) vs. time (min), mean +/- SEM per condition
%   (2) Aggressive behaviors (%) vs. time (min), mean +/- SEM per condition
%   (3) Per-experiment paired pre-stim vs during-stim aggression (%),
%       Wilcoxon matched-pairs signed-rank test per condition
%
% This script depends on:
%   dep/process_multistim_aggression_dcenter.m
%   dep/build_multistim_workspace.m
%   dep/plot_multistim_timeseries.m
%   dep/plot_multistim_pre_during_boxplot.m
%   dep/shplot/shplot.m
%
% Source data (one experiment per subfolder of each condition directory),
% each containing:
%   indicatordata.mat
%   scores_MMAggfRGBub.mat   (JAABA aggression scores)
%   perframe/dcenter.mat     (inter-fly distance perframe feature, mm)
%   registered_trx.mat       (FlyDisco registered tracks)

%% Add repo to path: 
addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));

%% Settings — edit these for your data layout / analysis windows
cfg = struct();
cfg.conditions     = {'empty', 'aIPg'};
cfg.datadirs       = struct();
cfg.datadirs.empty = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/data/EmptySS_Chrimson';
cfg.datadirs.aIPg  = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/data/aIPgSS_Chrimson';

cfg.behavior_score_file = 'scores_MMAggfRGBub.mat';
cfg.dcenter_relpath     = fullfile('perframe','dcenter.mat');
cfg.tracksfile          = 'registered_trx.mat';
cfg.indicatorfile       = 'indicatordata.mat';

cfg.pre            = 2550;     % frames before alignment stim (~15 s @ 169.99 fps)
cfg.post           = 58650;    % frames after alignment stim
cfg.num_stims      = 6;
cfg.alignment_stim = 1;        % first stim of 6
cfg.bin            = 60;       % time-course bin size, frames
cfg.fps            = 169.99;

cfg.writecsv  = true;         % set true to also save the original CSV summaries
cfg.outputdir = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/Figure7B';

% Plot settings (user-adjustable)
plot_window_min = [0.25 1.25];   % minutes (movie time)
stim_use        = 1;             % which stim's pre/during window to quantify
window_seconds  = 15;            % equal-length pre/during windows (seconds)
                                 %   scalar       -> pre and during both N s
                                 %   [pre_s dur_s]-> independent lengths
                                 %   []  or NaN   -> legacy: pre = cfg.pre,
                                 %                  during = indicator-derived

% Optional: condition colors (matches the figure)
condition_colors = struct();
condition_colors.empty = [0.74 0.78 0.70];
condition_colors.aIPg  = [0.50 0.45 0.65];

% Save options
SaveFormat = '.pdf';
SavePath   = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/Figure7B';

%% Load + assemble per-experiment workspace (assigns MultiStimData, MultiStimCfg)
build_multistim_workspace(cfg);

%% Panel 1: Inter-fly distance over time
plot_multistim_timeseries('dcenter',    cfg.conditions, plot_window_min, condition_colors, SavePath, SaveFormat);

%% Panel 2: Aggressive behaviors (%) over time
plot_multistim_timeseries('aggression', cfg.conditions, plot_window_min, condition_colors, SavePath, SaveFormat);

%% Panel 3: Per-experiment paired pre vs during, aggression, Wilcoxon
[stats_out, ~] = plot_multistim_pre_during_boxplot('aggression', cfg.conditions, stim_use, ...
                                                   window_seconds, condition_colors, SavePath, SaveFormat); %#ok<ASGLU>
disp(stats_out);
