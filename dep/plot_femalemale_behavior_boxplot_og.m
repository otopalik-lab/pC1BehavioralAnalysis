function plot_femalemale_behavior_boxplot(line_input, behavior, SavePath, SaveFormat)
%PLOT_FEMALEMALE_BEHAVIOR_BOXPLOT  Boxplot of per-window p(behavior) during
%   the stimulus epoch for female–male data, with overlaid jittered scatter.
%   Lines significantly different from the Empty Split control are annotated
%   in magenta (one-way ANOVA + Dunn-Šidák post-hoc, α = 0.01).
%
%   Each data point is the fraction of stimulus frames where the behavior
%   was active (p = 1) for a single valid peri-stimulus window. Windows are
%   pooled across the specified LEDStims epochs within each trial.
%   Experiments with putative copulation are excluded.
%
% INPUTS:
%   line_input  - Lines to display. Accepted formats:
%                   'all'           → all unique drivers in FemaleMaleData
%                   char/string     → single driver, e.g. 'SS102671'
%                   cell array      → subset, e.g. {'SS102671','SS03661'}
%                   numeric vector  → indices into unique driver list
%                 The Empty Split control line must be included for
%                 significance testing.
%   behavior    - Behavior field name in FemaleMaleData (e.g., 'close')
%   SavePath    - (optional) Directory in which to save the figure
%   SaveFormat  - (optional) File format string, e.g. '.pdf' or '.png'
%                 Both SavePath and SaveFormat must be provided to save.
%
% EXAMPLE:
%   plot_femalemale_behavior_boxplot('all', 'close')
%   plot_femalemale_behavior_boxplot({'Empty Split','SS102671'}, 'm_orient', '/save', '.pdf')
%
% BASE WORKSPACE REQUIREMENTS:
%   FemaleMaleData    struct array with per-trial behavioral fields
%   lines, celltypes  (optional) for y-axis labels

%% Tunable defaults
pre_post_sec = 60;
stim_dur_sec = 120;
LEDStims     = [3 4];

% Copulation detection parameters
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
pre_frames            = round(pre_post_sec * FPS);
stim_frames           = round(stim_dur_sec  * FPS);
copulation_dur_frames = round(copulation_dur_sec * FPS);

%% Find Empty Split control index within selected lines
numSelected     = length(driver_inds);
selected_labels = labels(driver_inds);
ES_idx          = find(contains(selected_labels, 'Empty'), 1);
if isempty(ES_idx)
    warning('Empty Split control not found among selected lines. Significance testing will be skipped.');
    do_stats = false;
else
    do_stats = true;
end

%% Collect per-window p(behavior) during the stimulus epoch for each line
data_by_line = cell(numSelected, 1);

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

    p_vals = [];
    for k = 1:numTrials
        trial_beh_len = length(FemaleMaleData(trial_inds(k)).(behavior));
        LED_raw_k     = double(FemaleMaleData(trial_inds(k)).LED)';
        epochs_k      = detect_binarybouts(LED_raw_k > 0);
        n_ep_k        = size(epochs_k, 1);
        if n_ep_k == 0; continue; end

        stim_inds_k = LEDStims(LEDStims <= n_ep_k);
        for j = stim_inds_k
            onset     = epochs_k(j, 1);
            win_start = onset - pre_frames + 1;
            win_end   = onset + stim_frames + pre_frames;
            if win_start >= 1 && win_end <= trial_beh_len
                seg           = double(FemaleMaleData(trial_inds(k)).(behavior));
                stim_seg      = seg(onset : onset + stim_frames - 1);
                p_vals(end+1) = sum(stim_seg) / stim_frames; %#ok<AGROW>
            end
        end
    end

    if isempty(p_vals)
        data_by_line{idx} = NaN; % placeholder so group appears in boxplot
    else
        p_vals = p_vals(:);
        max_pts = 18 * length(LEDStims);
        if length(p_vals) > max_pts
            p_vals = p_vals(randperm(length(p_vals), max_pts));
        end
        data_by_line{idx} = p_vals;
    end
end

%% Statistics: one-way ANOVA + Dunn-Šidák post-hoc vs Empty Split (α = 0.01)
sig_inds = [];
if do_stats && numSelected > 1
    all_data_vec   = [];
    all_groups_vec = [];
    for idx = 1:numSelected
        d = data_by_line{idx};
        d = d(~isnan(d));
        all_data_vec   = [all_data_vec;   d];               %#ok<AGROW>
        all_groups_vec = [all_groups_vec; idx * ones(length(d), 1)]; %#ok<AGROW>
    end

    try
        [~, ~, stats]      = anova1(all_data_vec, all_groups_vec, 'off');
        [results, ~, ~, ~] = multcompare(stats, 'CriticalValueType', 'dunn-sidak', ...
                                         'Alpha', 0.01, 'Display', 'off');
        comps = results(results(:,1) == ES_idx | results(:,2) == ES_idx, :);
        for r = 1:size(comps, 1)
            if comps(r, 6) < 0.05
                other_idx = comps(r, 1:2);
                sig_inds  = [sig_inds, other_idx(other_idx ~= ES_idx)]; %#ok<AGROW>
            end
        end
        sig_inds = unique(sig_inds);
    catch ME
        warning('Statistics failed: %s', ME.message);
    end
end

%% Build pooled data vectors for boxplot
all_data_vec   = [];
all_groups_vec = [];
for idx = 1:numSelected
    d = data_by_line{idx};
    all_data_vec   = [all_data_vec;   d];                         %#ok<AGROW>
    all_groups_vec = [all_groups_vec; idx * ones(length(d), 1)]; %#ok<AGROW>
end

%% Plot
annot_color = [220  38 127] ./ 255;   % magenta (#DC267F)
gray_color  = [0.55 0.55 0.55];

fig_h = max(200, numSelected * 28 + 60);
f  = figure('Position', [1000 500 380 fig_h]);
ax = axes(f);
hold(ax, 'on');

% Horizontal boxplot — one row per line, outliers suppressed
boxplot(ax, all_data_vec, all_groups_vec, ...
    'Orientation', 'horizontal', ...
    'Colors',      gray_color,   ...
    'Symbol',      '');

% Override y-tick labels and disable TeX interpreter
ax.YTick                = 1:numSelected;
ax.YTickLabel           = selected_labels;
ax.TickLabelInterpreter = 'none';
ax.YDir                 = 'reverse';   % first line at top, matching heatmap
ax.YLim                 = [0.5, numSelected + 0.5];

% Jittered scatter overlay
rng('shuffle');
for idx = 1:numSelected
    d = data_by_line{idx};
    d = d(~isnan(d));
    if isempty(d); continue; end
    yj  = idx + (rand(length(d), 1) - 0.5) * 0.4;
    col = gray_color;
    if ismember(idx, sig_inds)
        col = annot_color;
    end
    scatter(ax, d, yj, 8, 'filled', ...
        'MarkerFaceColor', col, 'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor', 'none');
end

% Magenta asterisk to the right of each significant line
x_star = ax.XLim(2);
for s = sig_inds
    text(ax, x_star, s, ' *', ...
        'Color', annot_color, 'FontSize', 12, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'Interpreter', 'none');
end

ax.XLim   = [0, 1];
ax.TickDir = 'out';
ax.FontSize = 9;
box(ax, 'off');
xlabel(ax, ['p(' behavior ')'],              'FontSize', 11, 'Interpreter', 'none');
title(ax,  ['p(' behavior ') — stim window'], 'FontSize', 11, 'Interpreter', 'none');

%% Save (optional — only if both SavePath and SaveFormat are provided)
if nargin == 4
    if ~exist(SavePath, 'dir')
        mkdir(SavePath);
    end
    saveas(f, fullfile(SavePath, [behavior '_femalemale_boxplot' SaveFormat]));
end

end
