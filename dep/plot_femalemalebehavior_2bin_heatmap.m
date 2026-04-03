function plot_femalemalebehavior_2bin_heatmap(line_input, behavior, varargin)
%PLOT_FEMALEMALEBEHAVIOR_2BIN_HEATMAP  2-bin heatmap of p(behavior) across
%   driver lines in FemaleMaleData. The two bins are:
%     Bin 1 ('pre')  — 2 minutes immediately prior to LED onset
%     Bin 2 ('stim') — 2 minutes during LED stimulation
%
%   Per-trial means are averaged across LEDStims epochs within each trial.
%   Experiments with putative copulation are excluded. Lines significantly
%   different from the Empty Split control (ANOVA + Dunn-Šidák, α = 0.01)
%   are annotated on the stim column.
%
% INPUTS:
%   line_input  - Lines to display. Accepted formats:
%                   'all'           → all unique drivers in FemaleMaleData
%                   char/string     → single driver, e.g. 'SS102671'
%                   cell array      → subset, e.g. {'SS102671','SS03661'}
%                   numeric vector  → indices into unique driver list
%                 The Empty Split control line must be included for
%                 significance testing.
%   behavior    - Binary behavior field name (e.g., 'close', 'm_orient')
%
% OPTIONAL INPUTS (any order after behavior):
%   bins        - Which bins to display:
%                   'both' (default) → pre and stim columns
%                   'pre'            → pre column only
%                   'stim'           → stim column only
%   plotmode    - Color values to display:
%                   'prob' (default) → mean p(behavior); gray colormap
%                   'zscore'         → mean z-score vs Empty Split;
%                                      blue-white-red colormap; significant
%                                      lines annotated with black dots
%   SavePath    - Directory in which to save the figure
%   SaveFormat  - File format string, e.g. '.pdf' or '.png'
%                 Both SavePath and SaveFormat must be provided to save.
%
% EXAMPLE:
%   plot_femalemalebehavior_2bin_heatmap('all', 'close')
%   plot_femalemalebehavior_2bin_heatmap('all', 'close', 'stim')
%   plot_femalemalebehavior_2bin_heatmap('all', 'close', 'zscore')
%   plot_femalemalebehavior_2bin_heatmap('all', 'close', 'stim', 'zscore')
%   plot_femalemalebehavior_2bin_heatmap('all', 'close', 'zscore', '/save', '.pdf')
%
% BASE WORKSPACE REQUIREMENTS:
%   FemaleMaleData    struct array with per-trial behavioral fields
%   lines, celltypes  (optional) for y-axis labels

%% Parse varargin — identify bins, plotmode, and SavePath/SaveFormat
valid_bins      = {'pre', 'stim', 'both'};
valid_plotmodes = {'prob', 'zscore'};
bins      = 'both';
plotmode  = 'prob';
SavePath  = '';
SaveFormat= '';
do_save   = false;

i = 1;
while i <= numel(varargin)
    arg = varargin{i};
    if (ischar(arg) || isstring(arg)) && ismember(lower(char(arg)), valid_bins)
        bins = lower(char(arg));
    elseif (ischar(arg) || isstring(arg)) && ismember(lower(char(arg)), valid_plotmodes)
        plotmode = lower(char(arg));
    elseif (ischar(arg) || isstring(arg)) && i < numel(varargin)
        % Assume SavePath followed by SaveFormat
        SavePath   = char(arg);
        SaveFormat = char(varargin{i+1});
        do_save    = true;
        i = i + 1;
    end
    i = i + 1;
end

%% Tunable defaults
bin_sec            = 120;   % 2-minute bins
LEDStims           = [3 4];
copulation_dist_mm = 4;
copulation_dur_sec = 60;

%% Load from base workspace
FemaleMaleData = evalin('base', 'FemaleMaleData');
fieldNames     = fieldnames(FemaleMaleData);

%% Validate behavior field
if ~ismember(behavior, fieldNames)
    error('Field "%s" not found in FemaleMaleData. Check spelling.', behavior);
end

%% Get unique driver list ordered by lines/celltypes workspace variables
all_drivers_raw = unique({FemaleMaleData.driver}, 'stable');

try
    lines_ws      = evalin('base', 'lines');
    celltypes_ws  = evalin('base', 'celltypes');
    has_ws_labels = true;
catch
    has_ws_labels = false;
end

if has_ws_labels
    ordered = {};
    for i = 1:length(lines_ws)
        for d = 1:length(all_drivers_raw)
            if contains(lines_ws{i}, all_drivers_raw{d}) && ~ismember(all_drivers_raw{d}, ordered)
                ordered{end+1} = all_drivers_raw{d}; %#ok<AGROW>
            end
        end
    end
    for d = 1:length(all_drivers_raw)
        if ~ismember(all_drivers_raw{d}, ordered)
            ordered{end+1} = all_drivers_raw{d}; %#ok<AGROW>
        end
    end
    all_drivers = ordered;
else
    all_drivers = all_drivers_raw;
end
numDrivers = length(all_drivers);

% Build y-axis labels
labels = cell(numDrivers, 1);
for i = 1:numDrivers
    if has_ws_labels
        m = find(contains(lines_ws, all_drivers{i}), 1);
        if ~isempty(m)
            labels{i} = erase([lines_ws{m} ' | ' celltypes_ws{m}], '\');
        else
            labels{i} = all_drivers{i};
        end
    else
        labels{i} = all_drivers{i};
    end
end

%% Resolve line_input to indices into all_drivers
if isnumeric(line_input)
    driver_inds = line_input(:)';
elseif ischar(line_input) || isstring(line_input)
    if strcmpi(line_input, 'all')
        driver_inds = 1:numDrivers;
    else
        matches = find(strcmp(all_drivers, char(line_input)));
        if isempty(matches)
            matches = find(contains(labels, char(line_input)));
        end
        if isempty(matches)
            error('Driver "%s" not found in FemaleMaleData.', line_input);
        elseif numel(matches) > 1
            warning('Multiple matches for "%s"; using index %d.', line_input, matches(1));
        end
        driver_inds = matches(1);
    end
elseif iscell(line_input)
    driver_inds = [];
    for s = 1:numel(line_input)
        m = find(strcmp(all_drivers, line_input{s}));
        if isempty(m)
            m = find(contains(labels, line_input{s}));
        end
        if isempty(m)
            warning('Driver "%s" not found, skipping.', line_input{s});
        else
            driver_inds(end+1) = m(1); %#ok<AGROW>
        end
    end
else
    error('line_input must be ''all'', a string, a cell array, or a numeric index vector.');
end

if isempty(driver_inds)
    error('No valid drivers resolved from line_input.');
end

%% Window parameters
FPS                   = FemaleMaleData(1).FPS;
bin_frames            = round(bin_sec * FPS);
copulation_dur_frames = round(copulation_dur_sec * FPS);

numSelected     = length(driver_inds);
selected_labels = labels(driver_inds);

%% Find Empty Split control
ES_idx = find(contains(selected_labels, 'Empty'), 1);
if isempty(ES_idx)
    warning('Empty Split control not found among selected lines. Significance testing will be skipped.');
    do_stats = false;
else
    do_stats = true;
end

%% Collect per-window p(behavior) for each line
pre_by_line  = cell(numSelected, 1);
stim_by_line = cell(numSelected, 1);

for idx = 1:numSelected
    driver_str = all_drivers{driver_inds(idx)};
    trial_inds = find(strcmp({FemaleMaleData.driver}, driver_str));
    numTrials  = length(trial_inds);

    % Copulation exclusion
    is_cop_trial = false(1, numTrials);
    for k = 1:numTrials
        dist_full = double(FemaleMaleData(trial_inds(k)).Distance);
        below     = double(dist_full < copulation_dist_mm);
        if any(conv(below, ones(1, copulation_dur_frames), 'valid') >= copulation_dur_frames)
            is_cop_trial(k) = true;
        end
    end
    trial_inds = trial_inds(~is_cop_trial);
    numTrials  = length(trial_inds);

    % Interaction filter: exclude trials with < 30% close during 330–450 s
    interact_win_start = round(330 * FPS) + 1;
    interact_win_end   = round(450 * FPS);
    if ismember('close', fieldNames) && numTrials > 0
        keep_int = true(1, numTrials);
        for k = 1:numTrials
            c = double(FemaleMaleData(trial_inds(k)).close);
            if length(c) < interact_win_end
                keep_int(k) = false; continue;
            end
            if mean(c(interact_win_start : interact_win_end)) < 0.30
                keep_int(k) = false;
            end
        end
        trial_inds = trial_inds(keep_int);
        numTrials  = length(trial_inds);
    end

    pre_vals  = [];
    stim_vals = [];

    for k = 1:numTrials
        trial_beh_len = length(FemaleMaleData(trial_inds(k)).(behavior));
        LED_raw_k     = double(FemaleMaleData(trial_inds(k)).LED)';
        epochs_k      = detect_binarybouts(LED_raw_k > 0);
        n_ep_k        = size(epochs_k, 1);
        if n_ep_k == 0; continue; end

        stim_inds_k = LEDStims(LEDStims <= n_ep_k);
        for j = stim_inds_k
            onset     = epochs_k(j, 1);
            pre_start = onset - bin_frames;
            stim_end  = onset + bin_frames - 1;
            if pre_start >= 1 && stim_end <= trial_beh_len
                seg               = double(FemaleMaleData(trial_inds(k)).(behavior));
                pre_vals(end+1)   = mean(seg(pre_start : onset - 1)); %#ok<AGROW>
                stim_vals(end+1)  = mean(seg(onset     : stim_end));  %#ok<AGROW>
            end
        end
    end

    pre_by_line{idx}  = pre_vals(:);
    stim_by_line{idx} = stim_vals(:);
end

%% Compute line-level means for heatmap color values
SS_PSTHs = zeros(numSelected, 2);
for idx = 1:numSelected
    SS_PSTHs(idx, 1) = mean(pre_by_line{idx},  'omitnan');
    SS_PSTHs(idx, 2) = mean(stim_by_line{idx}, 'omitnan');
end

%% Compute z-scores relative to Empty Split (if requested)
if strcmp(plotmode, 'zscore')
    if ~do_stats
        warning('zscore mode requires the Empty Split control. Falling back to prob.');
        plotmode = 'prob';
    else
        es_pre_mean  = mean(pre_by_line{ES_idx},  'omitnan');
        es_pre_std   = std( pre_by_line{ES_idx},   'omitnan');
        es_stim_mean = mean(stim_by_line{ES_idx}, 'omitnan');
        es_stim_std  = std( stim_by_line{ES_idx}, 'omitnan');
        ZS_PSTHs = zeros(numSelected, 2);
        for idx = 1:numSelected
            ZS_PSTHs(idx, 1) = (SS_PSTHs(idx, 1) - es_pre_mean)  / max(es_pre_std,  eps);
            ZS_PSTHs(idx, 2) = (SS_PSTHs(idx, 2) - es_stim_mean) / max(es_stim_std, eps);
        end
    end
end

%% Select source matrix and columns to display
src = SS_PSTHs;
if strcmp(plotmode, 'zscore'); src = ZS_PSTHs; end

switch bins
    case 'pre'
        plot_data = src(:, 1);
        xlabels   = {'pre'};
        stim_col  = NaN;
    case 'stim'
        plot_data = src(:, 2);
        xlabels   = {'stim'};
        stim_col  = 1;
    otherwise  % 'both'
        plot_data = src;
        xlabels   = {'pre', 'stim'};
        stim_col  = 2;
end

%% Statistics: one-way ANOVA + Dunn-Šidák post-hoc vs Empty Split (stim bin only), α = 0.01
sig_stim = [];
if do_stats && numSelected > 1
    all_stim_vec   = [];
    all_groups_vec = [];
    for idx = 1:numSelected
        d = stim_by_line{idx};
        d = d(~isnan(d));
        all_stim_vec   = [all_stim_vec;   d];                          %#ok<AGROW>
        all_groups_vec = [all_groups_vec; idx * ones(length(d), 1)];   %#ok<AGROW>
    end
    try
        [~, ~, stats]      = anova1(all_stim_vec, all_groups_vec, 'off');
        [results, ~, ~, ~] = multcompare(stats, 'CriticalValueType', 'dunn-sidak', ...
                                         'Alpha', 0.01, 'Display', 'off');
        comps = results(results(:,1) == ES_idx | results(:,2) == ES_idx, :);
        for r = 1:size(comps, 1)
            if comps(r, 6) < 0.05
                other_idx = comps(r, 1:2);
                sig_stim  = [sig_stim, other_idx(other_idx ~= ES_idx)]; %#ok<AGROW>
            end
        end
        sig_stim = unique(sig_stim);
    catch ME
        warning('Statistics failed: %s', ME.message);
    end
end

%% Colormap, color limits, annotation colour, and title — mode-dependent
if strcmp(plotmode, 'zscore')
    % Build blue-white-red colormap inline so white is always at the
    % midpoint regardless of the current axes CLim (bluewhitered reads
    % gca.CLim internally, which is unreliable before the heatmap exists).
    n_half = 128;
    cmap = [linspace(0,1,n_half)', linspace(0,1,n_half)', ones(n_half,1); ...
            ones(n_half,1), linspace(1,0,n_half)', linspace(1,0,n_half)'];
    color_limits = [-3, 3];
    annot_color  = [0 0 0];              % black dots for z-score mode
    title_str    = ['z(' behavior ')'];
    cb_label     = ['z(' behavior ')'];
else
    cmap         = flipud(gray);
    color_limits = [];
    switch behavior
        case 'm_unilateral';  color_limits = [0 0.50];
        case 'close';      color_limits = [0 1.00];
        case 'still';      color_limits = [0 1.00];
        case 'm_orient';   color_limits = [0 1.00];
        case 'm_behind';   color_limits = [0 0.80];
        case 'f_orient';   color_limits = [0 1.00];
        case 'chase';      color_limits = [0 0.50];
        case 'm_approach';   color_limits = [0 0.50];
        case 'copulation'; color_limits = [0 0.50];
    end
    annot_color = [220 38 127] ./ 255;  % magenta dots for prob mode
    title_str   = ['p(' behavior ')'];
    cb_label    = ['p(' behavior ')'];
end

%% Plot heatmap
fig_w  = 80 * size(plot_data, 2);  % 350 px reserved for y-axis labels
fig_h  = max(200, numSelected * 28 + 60);
f      = figure('Position', [1000 500 fig_w fig_h]);
h_prob = heatmap(f, plot_data);
h_prob.YDisplayLabels  = selected_labels;
h_prob.XDisplayLabels  = 'off';
h_prob.GridVisible     = 'off';
h_prob.CellLabelColor  = 'none';
h_prob.ColorbarVisible = 'off';
h_prob.Colormap        = cmap;
h_prob.Title           = title_str;
h_prob.FontSize        = 10;
h_prob.Interpreter     = 'none';
if ~isempty(color_limits)
    h_prob.ColorLimits = color_limits;
end

%% Annotate significant lines on the stim column (when visible)
drawnow;
ax = struct(h_prob).Axes;
hold(ax, 'on');
if ~isempty(sig_stim) && ~isnan(stim_col)
    scatter(ax, stim_col * ones(length(sig_stim), 1), sig_stim, 15, 'filled', ...
            'MarkerFaceColor', annot_color);
end
% Reassign labels after scatter — drawing on the underlying axes can cause
% the heatmap to re-render and drop its YDisplayLabels
h_prob.YDisplayLabels = selected_labels;

%% Horizontal colorbar
clim_vals = color_limits;
if isempty(clim_vals)
    clim_vals = [min(plot_data(:)), max(plot_data(:))];
end
n        = 256;
cb_data  = linspace(clim_vals(1), clim_vals(2), n);
cb_ax    = axes(f, 'Position', [0.20, 0.05, 0.60, 0.02]);
imagesc(cb_ax, cb_data, 1, cb_data);   % image values match the display range
colormap(cb_ax, cmap);
clim(cb_ax, clim_vals);                % CLim explicitly locked to heatmap limits
cb_ax.YTick    = [];
cb_ax.XLim     = clim_vals;
cb_ax.TickDir  = 'in';
cb_ax.FontSize = 10;
xlabel(cb_ax, cb_label, 'FontSize', 10, 'Interpreter', 'none');

%% Save (optional — only if both SavePath and SaveFormat are provided)
if do_save
    if ~exist(SavePath, 'dir')
        mkdir(SavePath);
    end
    saveas(f, fullfile(SavePath, [behavior '_femalemalebehavior_2bin_heatmap' SaveFormat]));
end

end
