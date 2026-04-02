function plot_femalemale_contbehavior_boxplot(line_input, behavior, SavePath, SaveFormat)
%PLOT_FEMALEMALE_CONTBEHAVIOR_BOXPLOT  Two figures for female–male data:
%
%   Figure 1 — Boxplot of per-window mean of a continuous behavioral
%   timeseries (e.g. Distance) during the stimulus epoch, with overlaid
%   jittered scatter. Lines significantly different from the Empty Split
%   control are annotated in magenta (Wilcoxon rank-sum + Bonferroni).
%   Each data point is the mean value of the field during the stimulus
%   epoch for a single valid peri-stimulus window, pooled across LEDStims
%   epochs within each trial.
%
%   Figure 2 — Boxplot of the coefficient of variation (CV = std/mean) of
%   the raw frame values within each stimulus window. Each data point is
%   the CV of the frame-by-frame values during the stimulus epoch for one
%   valid peri-stimulus window, pooled across LEDStims epochs and trials
%   (identical pooling to Figure 1). Windows with a zero mean are excluded.
%
%   Experiments with putative copulation are excluded from both figures.
%
% INPUTS:
%   line_input  - Lines to display. Accepted formats:
%                   'all'           → all unique drivers in FemaleMaleData
%                   char/string     → single driver, e.g. 'SS102671'
%                   cell array      → subset, e.g. {'SS102671','SS03661'}
%                   numeric vector  → indices into unique driver list
%                 The Empty Split control line must be included for
%                 significance testing.
%   behavior    - Continuous field name in FemaleMaleData (e.g., 'Distance')
%   SavePath    - (optional) Directory in which to save the figure
%   SaveFormat  - (optional) File format string, e.g. '.pdf' or '.png'
%                 Both SavePath and SaveFormat must be provided to save.
%
% EXAMPLE:
%   plot_femalemale_contbehavior_boxplot('all', 'Distance')
%   plot_femalemale_contbehavior_boxplot({'Empty Split','SS102671'}, 'Distance', '/save', '.pdf')
%
% BASE WORKSPACE REQUIREMENTS:
%   FemaleMaleData    struct array with per-trial behavioral fields
%   lines, celltypes  (optional) for y-axis labels

%% Tunable defaults
pre_post_sec = 60;
stim_dur_sec = 120;
LEDStims     = [2 3 4];

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

%% Collect per-window means and per-window CV for each line
% data_by_line{idx} — pooled per-window means, capped at max_pts
% cv_by_line{idx}   — per-window CV (std/mean of frame values), same pooling
data_by_line = cell(numSelected, 1);
cv_by_line   = cell(numSelected, 1);
max_pts      = 18 * length(LEDStims);

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

    mean_vals = [];
    cv_vals   = [];
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
                seg      = double(FemaleMaleData(trial_inds(k)).(behavior));
                stim_seg = seg(onset : onset + stim_frames - 1);
                win_m    = mean(stim_seg);
                mean_vals(end+1) = win_m;   %#ok<AGROW>
                % CV within this window (exclude zero-mean windows)
                if win_m > 0
                    cv_vals(end+1) = std(stim_seg) / win_m; %#ok<AGROW>
                end
            end
        end
    end

    % Store mean values (subsampled)
    if isempty(mean_vals)
        data_by_line{idx} = NaN;
    else
        mean_vals = mean_vals(:);
        if length(mean_vals) > max_pts
            mean_vals = mean_vals(randperm(length(mean_vals), max_pts));
        end
        data_by_line{idx} = mean_vals;
    end

    % Store CV values (subsampled, same cap as mean values)
    if isempty(cv_vals)
        cv_by_line{idx} = NaN;
    else
        cv_vals = cv_vals(:);
        if length(cv_vals) > max_pts
            cv_vals = cv_vals(randperm(length(cv_vals), max_pts));
        end
        cv_by_line{idx} = cv_vals;
    end
end

%% Statistics: pairwise Wilcoxon rank-sum vs. full Empty Split, Bonferroni corrected
sig_inds = [];
if do_stats && numSelected > 1
    es_data       = data_by_line{ES_idx};
    es_data       = es_data(~isnan(es_data));
    n_comparisons = numSelected - 1;   % number of non-ES lines

    for idx = 1:numSelected
        if idx == ES_idx; continue; end
        line_data = data_by_line{idx};
        line_data = line_data(~isnan(line_data));
        if isempty(line_data) || isempty(es_data); continue; end
        try
            [~, p] = ranksum(es_data, line_data);
        catch ME
            warning('ranksum failed for line %d: %s', idx, ME.message);
            p = 1;
        end
        if p < (0.05 / n_comparisons)   % Bonferroni correction
            sig_inds(end+1) = idx; %#ok<AGROW>
        end
    end
    sig_inds = unique(sig_inds);
end

%% Build pooled data vectors for boxplot
all_data_vec   = [];
all_groups_vec = [];
for idx = 1:numSelected
    d = data_by_line{idx};
    all_data_vec   = [all_data_vec;   d(:)];                         %#ok<AGROW>
    all_groups_vec = [all_groups_vec; idx * ones(length(d(:)), 1)];  %#ok<AGROW>
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

% Jittered scatter overlay (all lines)
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
drawnow;   % ensure XLim has expanded to include scatter points
x_star = ax.XLim(2);
for s = sig_inds
    text(ax, x_star, s, ' *', ...
        'Color', annot_color, 'FontSize', 12, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'Interpreter', 'none');
end

ax.TickDir  = 'out';
ax.FontSize = 9;
box(ax, 'off');
xlabel(ax, ['mean ' behavior ' (stim)'],         'FontSize', 11, 'Interpreter', 'none');
title(ax,  ['mean ' behavior ' — stim window'],  'FontSize', 11, 'Interpreter', 'none');

%% Save figure 1 (optional)
if nargin == 4
    if ~exist(SavePath, 'dir')
        mkdir(SavePath);
    end
    saveas(f, fullfile(SavePath, [behavior '_femalemale_contbehavior_boxplot' SaveFormat]));
end

%% Statistics for CV: Wilcoxon rank-sum vs Empty Split, Bonferroni corrected
cv_sig_inds = [];
if do_stats && numSelected > 1
    es_cv         = cv_by_line{ES_idx};
    es_cv         = es_cv(~isnan(es_cv));
    n_comparisons = numSelected - 1;

    for idx = 1:numSelected
        if idx == ES_idx; continue; end
        line_cv = cv_by_line{idx};
        line_cv = line_cv(~isnan(line_cv));
        if isempty(line_cv) || isempty(es_cv); continue; end
        try
            [~, p] = ranksum(es_cv, line_cv);
        catch ME
            warning('CV ranksum failed for line %d: %s', idx, ME.message);
            p = 1;
        end
        if p < (0.05 / n_comparisons)
            cv_sig_inds(end+1) = idx; %#ok<AGROW>
        end
    end
    cv_sig_inds = unique(cv_sig_inds);
end

%% Figure 2: CV of per-window means across stim windows, per trial
cv_data_vec   = [];
cv_groups_vec = [];
for idx = 1:numSelected
    d = cv_by_line{idx};
    cv_data_vec   = [cv_data_vec;   d(:)];                         %#ok<AGROW>
    cv_groups_vec = [cv_groups_vec; idx * ones(length(d(:)), 1)];  %#ok<AGROW>
end

f2  = figure('Position', [1400 500 380 fig_h]);
ax2 = axes(f2);
hold(ax2, 'on');

boxplot(ax2, cv_data_vec, cv_groups_vec, ...
    'Orientation', 'horizontal', ...
    'Colors',      gray_color,   ...
    'Symbol',      '');

ax2.YTick                = 1:numSelected;
ax2.YTickLabel           = selected_labels;
ax2.TickLabelInterpreter = 'none';
ax2.YDir                 = 'reverse';
ax2.YLim                 = [0.5, numSelected + 0.5];

rng('shuffle');
for idx = 1:numSelected
    d = cv_by_line{idx};
    d = d(~isnan(d));
    if isempty(d); continue; end
    yj  = idx + (rand(length(d), 1) - 0.5) * 0.4;
    col = gray_color;
    if ismember(idx, cv_sig_inds)
        col = annot_color;
    end
    scatter(ax2, d, yj, 8, 'filled', ...
        'MarkerFaceColor', col, 'MarkerFaceAlpha', 0.6, 'MarkerEdgeColor', 'none');
end

% Magenta asterisk to the right of each significant CV line
drawnow;   % ensure XLim has expanded to include scatter points
x_star2 = ax2.XLim(2);
for s = cv_sig_inds
    text(ax2, x_star2, s, ' *', ...
        'Color', annot_color, 'FontSize', 12, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
        'Interpreter', 'none');
end

ax2.TickDir  = 'out';
ax2.FontSize = 9;
box(ax2, 'off');
xlabel(ax2, ['CV ' behavior ' (stim window)'],        'FontSize', 11, 'Interpreter', 'none');
title(ax2,  ['CV ' behavior ' — per stim window'],   'FontSize', 11, 'Interpreter', 'none');

%% Save figure 2 (optional)
if nargin == 4
    saveas(f2, fullfile(SavePath, [behavior '_femalemale_contbehavior_boxplot_CV' SaveFormat]));
end

%% Figure 3: Per-frame stimulus histograms (capped at 18 trials per line)
% Each sample is one frame from the stimulus epoch.  The data pool per line is
% length(selected_trials) × length(LEDStims) × stim_frames, where
% selected_trials = min(numTrials_after_exclusion, 18).
max_trials  = 18;
raw_by_line = cell(numSelected, 1);

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

    % Cap at max_trials (random subsample)
    if numTrials > max_trials
        trial_inds = trial_inds(randperm(numTrials, max_trials));
        numTrials  = max_trials;
    end

    raw_vals = [];
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
                seg      = double(FemaleMaleData(trial_inds(k)).(behavior));
                stim_seg = seg(onset : onset + stim_frames - 1);
                raw_vals = [raw_vals; stim_seg(:)]; %#ok<AGROW>
            end
        end
    end
    raw_by_line{idx} = raw_vals;
end

%% Plot Figure 3
row_h      = 70;   % px per histogram row
fig_h3     = max(400, numSelected * row_h + 80);
f3         = figure('Position', [2200 500 420 fig_h3]);
ax3_all    = gobjects(numSelected, 1);

for idx = 1:numSelected
    ax3 = subplot(numSelected, 1, idx);
    ax3_all(idx) = ax3;
    hold(ax3, 'on');

    d = raw_by_line{idx};
    if ~isempty(d)
        col = gray_color;
        if ismember(idx, sig_inds)
            col = annot_color;
        end
        histogram(ax3, d, 50, ...
            'Normalization', 'probability', ...
            'FaceColor', col, 'FaceAlpha', 0.7, 'EdgeColor', 'none');
    end

    ax3.TickDir  = 'out';
    ax3.FontSize = 7;
    ax3.YTick    = [];
    box(ax3, 'off');

    % Line label on the left
    ylabel(ax3, selected_labels{idx}, ...
        'Interpreter', 'none', 'FontSize', 7, ...
        'Rotation', 0, 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle');

    if idx < numSelected
        ax3.XTickLabel = [];
    end
end

% Link x-axes so all rows share the same scale
linkaxes(ax3_all, 'x');

xlabel(ax3_all(numSelected), behavior, 'FontSize', 11, 'Interpreter', 'none');
sgtitle(f3, [behavior ' — stim window (per frame)'], 'FontSize', 11, 'Interpreter', 'none');

%% Save figure 3 (optional)
if nargin == 4
    saveas(f3, fullfile(SavePath, [behavior '_femalemale_contbehavior_histogram' SaveFormat]));
end

end
