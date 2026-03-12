function plot_femalemalebehavior_2bin_heatmap(line_input, behavior, SavePath, SaveFormat)
%PLOT_FEMALEMALEBEHAVIOR_2BIN_HEATMAP  2-bin heatmap of p(behavior) across
%   driver lines in FemaleMaleData. The two bins are:
%     Bin 1 ('pre')  — 2 minutes immediately prior to LED onset
%     Bin 2 ('stim') — 2 minutes during LED stimulation
%
%   Per-trial means are averaged across LEDStims epochs within each trial.
%   Experiments with putative copulation are excluded. Lines significantly
%   different from the Empty Split control (Wilcoxon rank-sum + Bonferroni,
%   α = 0.05) are annotated with magenta dots.
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
%   SavePath    - (optional) Directory in which to save the figure
%   SaveFormat  - (optional) File format string, e.g. '.pdf' or '.png'
%                 Both SavePath and SaveFormat must be provided to save.
%
% EXAMPLE:
%   plot_femalemalebehavior_2bin_heatmap('all', 'close')
%   plot_femalemalebehavior_2bin_heatmap({'Empty Split','SS102671'}, 'm_orient', '/save', '.pdf')
%
% BASE WORKSPACE REQUIREMENTS:
%   FemaleMaleData    struct array with per-trial behavioral fields
%   lines, celltypes  (optional) for y-axis labels

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

%% Collect per-trial bin means for each line
% For each trial, average p(behavior) across valid LEDStims windows.
% pre_by_line{idx}  — vector of per-trial means for the pre-stim bin
% stim_by_line{idx} — vector of per-trial means for the stim bin
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

    pre_trials  = NaN(numTrials, 1);
    stim_trials = NaN(numTrials, 1);

    for k = 1:numTrials
        trial_beh_len = length(FemaleMaleData(trial_inds(k)).(behavior));
        LED_raw_k     = double(FemaleMaleData(trial_inds(k)).LED)';
        epochs_k      = detect_binarybouts(LED_raw_k > 0);
        n_ep_k        = size(epochs_k, 1);
        if n_ep_k == 0; continue; end

        stim_inds_k = LEDStims(LEDStims <= n_ep_k);
        pre_wins  = [];
        stim_wins = [];

        for j = stim_inds_k
            onset     = epochs_k(j, 1);
            pre_start = onset - bin_frames;
            stim_end  = onset + bin_frames - 1;
            if pre_start >= 1 && stim_end <= trial_beh_len
                seg              = double(FemaleMaleData(trial_inds(k)).(behavior));
                pre_wins(end+1)  = mean(seg(pre_start : onset - 1)); %#ok<AGROW>
                stim_wins(end+1) = mean(seg(onset     : stim_end));  %#ok<AGROW>
            end
        end

        if ~isempty(pre_wins)
            pre_trials(k)  = mean(pre_wins);
            stim_trials(k) = mean(stim_wins);
        end
    end

    pre_by_line{idx}  = pre_trials(~isnan(pre_trials));
    stim_by_line{idx} = stim_trials(~isnan(stim_trials));
end

%% Compute line-level means for heatmap color values
SS_PSTHs = zeros(numSelected, 2);
for idx = 1:numSelected
    SS_PSTHs(idx, 1) = mean(pre_by_line{idx},  'omitnan');
    SS_PSTHs(idx, 2) = mean(stim_by_line{idx}, 'omitnan');
end

%% Statistics: Wilcoxon rank-sum vs Empty Split, Bonferroni corrected
sig_rows = cell(1, 2);
if do_stats && numSelected > 1
    es_pre  = pre_by_line{ES_idx};
    es_stim = stim_by_line{ES_idx};
    n_comp  = numSelected - 1;

    for bin = 1:2
        if bin == 1; es_data = es_pre;  else; es_data = es_stim; end
        sig_idx = [];
        for idx = 1:numSelected
            if idx == ES_idx; continue; end
            if bin == 1; line_data = pre_by_line{idx}; else; line_data = stim_by_line{idx}; end
            if isempty(line_data) || isempty(es_data); continue; end
            try
                [~, p] = ranksum(es_data, line_data);
            catch ME
                warning('ranksum failed for line %d: %s', idx, ME.message);
                p = 1;
            end
            if p < (0.05 / n_comp)
                sig_idx(end+1) = idx; %#ok<AGROW>
            end
        end
        sig_rows{bin} = unique(sig_idx);
    end
end

%% Plot heatmap
fig_h  = max(200, numSelected * 28 + 60);
f      = figure('Position', [1000 500 120 fig_h]);
h_prob = heatmap(SS_PSTHs);
h_prob.YDisplayLabels  = selected_labels;
h_prob.XDisplayLabels  = {'pre', 'stim'};
h_prob.GridVisible     = 'off';
h_prob.CellLabelColor  = 'none';
h_prob.ColorbarVisible = 'off';
h_prob.Colormap        = flipud(gray);
h_prob.Title           = ['p(' behavior ')'];
h_prob.FontSize        = 10;

% Behavior-specific color limits
color_limits = [];
switch behavior
    case 'close';      color_limits = [0 1.00];
    case 'still';      color_limits = [0 1.00];
    case 'orient';     color_limits = [0 1.00];
    case 'm_orient';   color_limits = [0 1.00];
    case 'f_orient';   color_limits = [0 1.00];
    case 'chase';      color_limits = [0 0.40];
    case 'approach';   color_limits = [0 0.50];
    case 'copulation'; color_limits = [0 0.50];
end
if ~isempty(color_limits)
    h_prob.ColorLimits = color_limits;
end

%% Annotate significant lines with magenta dots
annot_color = [220 38 127] ./ 255;   % magenta (#DC267F)
ax = struct(h_prob).Axes;
hold(ax, 'on');
for bin = 1:2
    sig = sig_rows{bin};
    if ~isempty(sig)
        scatter(ax, bin * ones(length(sig), 1), sig, 15, 'filled', ...
                'MarkerFaceColor', annot_color);
    end
end

%% Horizontal colorbar
clim_vals = color_limits;
if isempty(clim_vals)
    clim_vals = [min(SS_PSTHs(:)), max(SS_PSTHs(:))];
end
n     = 256;
cb_ax = axes(f, 'Position', [0.20, 0.05, 0.60, 0.02]);
imagesc(cb_ax, linspace(clim_vals(1), clim_vals(2), n), 1, (1:n));
colormap(cb_ax, flipud(gray));
cb_ax.YTick    = [];
cb_ax.XLim     = clim_vals;
cb_ax.TickDir  = 'in';
cb_ax.FontSize = 10;
xlabel(cb_ax, ['p(' behavior ')'], 'FontSize', 10);

%% Save (optional — only if both SavePath and SaveFormat are provided)
if nargin == 4
    if ~exist(SavePath, 'dir')
        mkdir(SavePath);
    end
    saveas(f, fullfile(SavePath, [behavior '_femalemalebehavior_2bin_heatmap' SaveFormat]));
end

end
