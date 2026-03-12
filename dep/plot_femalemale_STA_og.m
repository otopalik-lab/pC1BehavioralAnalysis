function fig = plot_femalemale_STA(line_input, behavior_list, timeseries_list, SavePath, SaveFormat)
%PLOT_FEMALEMALE_STA  Stimulus-triggered averages for female–male interaction data.
%
%   For each LED epoch index in LEDStims (default [1 2 3]), extracts a
%   peri-stimulus window (60 s pre + 120 s LED + 60 s post) anchored to
%   LED onset, and pools across all trials for the specified driver line.
%
%   Binary behavior fields → tick-mark rasters (rows = trials × epochs)
%   Continuous fields      → mean ± SEM shaded traces across windows
%   Combined PSTH          → P(Behavior) over time for all binary behaviors
%   Timeseries fields      → mean ± SEM shaded traces, one panel each
%                            (include 'Distance' here to plot inter-fly distance)
%
%   x-axis is aligned to LED onset: 0 = stimulus on, stim_dur = stimulus off.
%
% ── USAGE ─────────────────────────────────────────────────────────────────
%   plot_femalemale_STA('SS102671', {'close', 'chase'})
%   plot_femalemale_STA('SS102671', {'close', 'chase'}, {'MaleVelocity'})
%   plot_femalemale_STA('SS102671', {'close', 'chase'}, {'MaleVelocity'}, ...
%       '/save/dir', '.pdf')
%
% ── REQUIRED INPUTS ───────────────────────────────────────────────────────
%   line_input       Driver name string matching FemaleMaleData.driver, or a
%                    numeric vector of row indices into FemaleMaleData.
%   behavior_list    Cell array of FemaleMaleData field names to plot as
%                    rasters (binary) or mean±SEM traces (continuous), e.g.
%                    {'close', 'chase', 'Distance'}
%
% ── OPTIONAL INPUTS ───────────────────────────────────────────────────────
%   timeseries_list  Cell array of continuous FemaleMaleData field names to
%                    plot as additional mean±SEM panels below the PSTH, e.g.
%                    {'Distance', 'MaleVelocity', 'FemaleVelocity'}.
%                    Distance is NOT plotted unless listed here.
%                    Pass {} or omit to skip. A single string is also accepted.
%   SavePath         Directory in which to save the figure (requires SaveFormat)
%   SaveFormat       File format string, e.g. '.pdf', '.png', '.svg'
%
% ── PARAMETERS (edit defaults below) ─────────────────────────────────────
%   pre_post_sec   Seconds of pre/post window around each LED epoch (60 s)
%   stim_dur_sec   LED epoch duration in seconds (120 s)
%   LEDStims       Epoch indices (into per-trial detected epochs) to include,
%                  e.g. [1 2 3] uses the 1st, 2nd, and 3rd detected epochs
%
% ── BASE WORKSPACE REQUIREMENTS ───────────────────────────────────────────
%   FemaleMaleData    struct array with per-trial behavioral fields
%   lines, celltypes  (optional) for figure title
%
% ── OUTPUT ────────────────────────────────────────────────────────────────
%   fig   figure handle

%% ── Tunable defaults ─────────────────────────────────────────────────────
pre_post_sec = 60;        % pre- and post-stimulus window (seconds)
stim_dur_sec = 120;       % LED epoch duration (seconds) — hardcoded for this experiment
LEDStims     = [2 3 4];   % indices of LED epochs (per trial) to average

% Copulation detection parameters
copulation_dist_mm = 4;   % inter-animal distance threshold (mm); sustained proximity below
                          %   this value is considered indicative of copulation
copulation_dur_sec = 60;  % minimum contiguous duration (s) below threshold to flag window

%% ── Load from base workspace ─────────────────────────────────────────────
FemaleMaleData = evalin('base', 'FemaleMaleData');
fieldNames     = fieldnames(FemaleMaleData);

%% ── Resolve line_input to trial indices ─────────────────────────────────
if ischar(line_input) || isstring(line_input)
    driver_str = char(line_input);
    trial_inds = find(strcmp({FemaleMaleData.driver}, driver_str));
    if isempty(trial_inds)
        error('Driver "%s" not found in FemaleMaleData.driver.', driver_str);
    end
elseif isnumeric(line_input)
    trial_inds = line_input(:)';
    driver_str = FemaleMaleData(trial_inds(1)).driver;
else
    error('line_input must be a string driver name or a numeric index vector.');
end

max_trials = 18;
if length(trial_inds) > max_trials
    rng('shuffle');
    n_total    = length(trial_inds);
    trial_inds = trial_inds(randperm(n_total, max_trials));
    fprintf('Randomly selected %d of %d available trials.\n', max_trials, n_total);
end
numTrials = length(trial_inds);
FPS       = FemaleMaleData(trial_inds(1)).FPS;

%% ── Copulation detection (full experiment) ───────────────────────────────
% Scan each experiment's entire Distance trace. Any experiment containing a
% contiguous run of >= copulation_dur_sec seconds where inter-animal distance
% stays below copulation_dist_mm is flagged as a putative copulation event
% and excluded before any windowing or plotting.
copulation_dur_frames = round(copulation_dur_sec * FPS);

is_cop_trial = false(1, numTrials);
for k = 1:numTrials
    dist_full = double(FemaleMaleData(trial_inds(k)).Distance);
    below     = double(dist_full < copulation_dist_mm);
    if any(conv(below, ones(1, copulation_dur_frames), 'valid') >= copulation_dur_frames)
        is_cop_trial(k) = true;
    end
end

n_cop_excl    = sum(is_cop_trial);
numTrials_all = numTrials;   % pre-exclusion total (used in title)
if n_cop_excl > 0
    fprintf('Excluding %d / %d experiment(s) with putative copulation (dist < %.0f mm for >= %.0f s).\n', ...
        n_cop_excl, numTrials_all, copulation_dist_mm, copulation_dur_sec);
    trial_inds = trial_inds(~is_cop_trial);
    numTrials  = length(trial_inds);
    if numTrials == 0
        error('All experiments excluded due to putative copulation. No data to plot.');
    end
end

%% ── Interaction filter (baseline close ≥ 30 % during 330–450 s) ─────────
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
    if numTrials == 0
        error('No trials remain after interaction filter for driver "%s".', driver_str);
    end
end

%% ── Build figure title ───────────────────────────────────────────────────
try
    lines_ws     = evalin('base', 'lines');
    celltypes_ws = evalin('base', 'celltypes');
    m = find(contains(lines_ws, driver_str), 1);
    if ~isempty(m)
        title_str = erase([lines_ws{m} ' | ' celltypes_ws{m} '  |  N = ' num2str(numTrials)], '\');
    else
        title_str = [driver_str '  |  N = ' num2str(numTrials)];
    end
catch
    title_str = [driver_str '  |  N = ' num2str(numTrials)];
end
if n_cop_excl > 0
    title_str = [title_str sprintf('  (%d cop. excl. of %d)', n_cop_excl, numTrials_all)];
end

%% ── Validate behavior fields ─────────────────────────────────────────────
for b = 1:length(behavior_list)
    if ~ismember(behavior_list{b}, fieldNames)
        error('Field "%s" not found in FemaleMaleData. Check spelling.', behavior_list{b});
    end
end

%% ── Parse and validate timeseries_list ──────────────────────────────────
if nargin < 3 || isempty(timeseries_list)
    timeseries_list = {};
elseif ischar(timeseries_list) || isstring(timeseries_list)
    timeseries_list = {char(timeseries_list)};
end
numTimeseries = numel(timeseries_list);
for t = 1:numTimeseries
    if ~ismember(timeseries_list{t}, fieldNames)
        error('timeseries_list field "%s" not found in FemaleMaleData. Check spelling.', ...
            timeseries_list{t});
    end
end

%% ── Window parameters ────────────────────────────────────────────────────
pre_frames   = round(pre_post_sec * FPS);
stim_frames  = round(stim_dur_sec * FPS);

% Fixed window: pre_post_sec before LED onset, stim_dur_sec LED, pre_post_sec after
windowLength = pre_frames + stim_frames + pre_frames;
t_xlim       = [-pre_post_sec, stim_dur_sec + pre_post_sec];   % [-60, 180]
xt           = [-pre_post_sec, 0, pre_post_sec, stim_dur_sec, stim_dur_sec + pre_post_sec];  % [-60 0 120 180]
t_win        = (0:windowLength-1) ./ FPS - pre_post_sec;

%% ── Pre-compute valid peri-stimulus windows (per trial) ─────────────────
% Epochs are detected from the full LED vector so that later bouts are not
% truncated by the (shorter) behavior vector. LEDStims selects which epoch
% indices to include; each trial contributes one row per valid index
% (expected total = numTrials × length(LEDStims)).
valid_windows = zeros(0, 2);   % rows: [global_struct_index, onset_frame]

% Reference field used solely to measure each trial's data length.
% Prefer the first behavior field, then the first timeseries field, then
% 'Distance' (always present — already used for copulation detection).
if ~isempty(behavior_list)
    len_ref_field = behavior_list{1};
elseif ~isempty(timeseries_list)
    len_ref_field = timeseries_list{1};
else
    len_ref_field = 'Distance';
end

for k = 1:numTrials
    % Use this trial's own behavior length as the validity boundary
    trial_beh_len = double(length(FemaleMaleData(trial_inds(k)).(len_ref_field)));

    LED_raw_k = double(FemaleMaleData(trial_inds(k)).LED)';
    % Detect epochs from the full LED vector (not truncated to beh_len).
    % Window validity against trial_beh_len is checked below.
    epochs_k = detect_binarybouts(LED_raw_k > 0);
    n_ep_k   = size(epochs_k, 1);
    if n_ep_k == 0; continue; end

    % Use only the requested epoch indices that exist for this trial
    stim_inds_k = LEDStims(LEDStims <= n_ep_k);
    for j = stim_inds_k
        onset     = epochs_k(j, 1);
        win_start = onset - pre_frames + 1;
        win_end   = onset + stim_frames + pre_frames;
        if win_start >= 1 && win_end <= trial_beh_len
            valid_windows(end+1, :) = [trial_inds(k), onset]; %#ok<AGROW>
        end
    end
end

n_valid = size(valid_windows, 1);
if n_valid == 0
    error('No valid peri-stimulus windows found. Check LED timing and beh_len.');
end
fprintf('Found %d valid windows (%d trials × %d stims requested).\n', ...
    n_valid, numTrials, length(LEDStims));

%% ── Detect continuous vs binary behaviors ────────────────────────────────
% known_continuous / known_units are also referenced by the timeseries section.
known_continuous = {'Distance','FacingAngle','AngleBetween','MaleVelocity','FemaleVelocity'};
known_units      = {'mm',    'deg',        'deg',         'mm/s',        'mm/s'         };
known_ylims      = {[0 15],  [0 60],       [120 180],       [0 30],        [0 30]         };
% known_ylims: fixed [lo hi] to use for that field, or [] to auto-scale from data.

numBehaviors  = length(behavior_list);
is_continuous = false(1, numBehaviors);
beh_ylabel    = behavior_list;

for b = 1:numBehaviors
    idx_known = strcmp(behavior_list{b}, known_continuous);
    if any(idx_known)
        is_continuous(b) = true;
        beh_ylabel{b} = [strrep(behavior_list{b},'_',' ') ' (' known_units{idx_known} ')'];
    else
        d = double(FemaleMaleData(trial_inds(1)).(behavior_list{b}));
        uniq = unique(d(isfinite(d)));
        if ~all(ismember(uniq, [0 1]))
            is_continuous(b) = true;
        end
        beh_ylabel{b} = strrep(behavior_list{b}, '_', ' ');
    end
end
n_binary = sum(~is_continuous);

%% ── Color palette ────────────────────────────────────────────────────────
default_colors = {'#648FFF', '#DC267F', '#FE6100', '#785EF0', '#FFB000', ...
                  '#009E73', '#56B4E9', '#E69F00', '#CC79A7', '#0072B2'};

%% ── Figure layout ────────────────────────────────────────────────────────
% Behavior panels + combined PSTH (binary only) + timeseries panels
has_psth    = n_binary > 0;
numSubplots = numBehaviors + has_psth + numTimeseries;
fig = figure; clf;
fig.Position = [200, 700, 300, 180 * numSubplots];

%% ── Behavior panels ─────────────────────────────────────────────────────
all_events = cell(1, numBehaviors);
total_rows = zeros(1, numBehaviors);

for b = 1:numBehaviors
    color = default_colors{mod(b-1, length(default_colors)) + 1};
    subplot(numSubplots, 1, b); hold on;

    % Shade stimulus period (fill to large value; ylim will clip)
    fill([0 stim_dur_sec stim_dur_sec 0], [-1e6 -1e6 1e6 1e6], [0 0 0], ...
        'FaceAlpha', 0.1, 'EdgeColor', 'none');

    if ~is_continuous(b)
        %── Binary: tick-mark raster ─────────────────────────────────────
        event_times_all = [];

        for p = 1:n_valid
            trial_ind = valid_windows(p, 1);
            onset     = valid_windows(p, 2);
            win_start = onset - pre_frames + 1;
            win_end   = onset + stim_frames + pre_frames;

            d   = double(FemaleMaleData(trial_ind).(behavior_list{b}));
            seg = d(win_start : win_end);
            ev  = find(seg == 1);

            if ~isempty(ev)
                plot(ev ./ FPS - pre_post_sec, p * ones(size(ev)), ...
                    '|', 'MarkerFaceColor', color, 'MarkerEdgeColor', color, ...
                    'MarkerSize', 1);
            end
            event_times_all = [event_times_all, ev]; %#ok<AGROW>
        end

        all_events{b} = event_times_all;
        total_rows(b) = n_valid;
        ylim([0, n_valid + 1]);

    else
        %── Continuous: mean ± SEM trace ────────────────────────────────
        traces = zeros(n_valid, windowLength);
        for p = 1:n_valid
            trial_ind = valid_windows(p, 1);
            onset     = valid_windows(p, 2);
            win_start = onset - pre_frames + 1;
            win_end   = onset + stim_frames + pre_frames;

            d = double(FemaleMaleData(trial_ind).(behavior_list{b}));
            traces(p, :) = d(win_start : win_end);
        end
        tr_mean = mean(traces, 1);
        tr_sem  = std(traces, 0, 1) ./ sqrt(n_valid);
        shplot(t_win, tr_mean, tr_sem, 'Color', color);
        % Use fixed ylim for known fields, otherwise auto-scale from the data
        % (auto-scaling is needed because the fill's ±1e6 extent would otherwise dominate)
        idx_yl = strcmp(behavior_list{b}, known_continuous);
        if any(idx_yl) && ~isempty(known_ylims{idx_yl})
            ylim(known_ylims{idx_yl});
        else
            y_range = [min(tr_mean - tr_sem), max(tr_mean + tr_sem)];
            y_pad   = max(diff(y_range) * 0.15, 1e-6);
            ylim([y_range(1) - y_pad, y_range(2) + y_pad]);
        end
    end

    ylabel(beh_ylabel{b}, 'FontSize', 12);
    xlim(t_xlim);
    xticks(xt);
    box off;
end

% Title on first panel
subplot(numSubplots, 1, 1);
title(title_str, 'FontSize', 11, 'Interpreter', 'none');

%% ── Combined PSTH (binary behaviors only) ────────────────────────────────
if has_psth
    subplot(numSubplots, 1, numBehaviors + 1); hold on;

    fill([0 stim_dur_sec stim_dur_sec 0], [-1e6 -1e6 1e6 1e6], [0 0 0], ...
        'FaceAlpha', 0.1, 'EdgeColor', 'none');

    for b = 1:numBehaviors
        if is_continuous(b) || isempty(all_events{b}); continue; end
        color = default_colors{mod(b-1, length(default_colors)) + 1};
        [d, edges] = psth(all_events{b}, 500, FPS, total_rows(b), windowLength);
        area(edges ./ 1000 - pre_post_sec, d ./ FPS, ...
            'FaceColor', color, 'EdgeColor', color, ...
            'FaceAlpha', 0.2, 'LineWidth', 1.5);
    end

    ylim([0, 1]);
    xlim(t_xlim);
    xticks(xt);
    ylabel('P(Behavior)', 'FontSize', 12);
    box off;

    % Legend: binary behaviors only
    bin_labels = strrep(behavior_list(~is_continuous), '_', ' ');
    %legend(bin_labels, 'Location', 'northeast', 'FontSize', 8);
end

%% ── Additional timeseries panels (mean ± SEM) ────────────────────────────
for t = 1:numTimeseries
    sp_idx = numBehaviors + has_psth + t;
    color  = default_colors{mod(numBehaviors + t - 1, length(default_colors)) + 1};
    subplot(numSubplots, 1, sp_idx); hold on;

    fill([0 stim_dur_sec stim_dur_sec 0], [-1e6 -1e6 1e6 1e6], [0 0 0], ...
        'FaceAlpha', 0.1, 'EdgeColor', 'none');

    traces_t = zeros(n_valid, windowLength);
    for p = 1:n_valid
        trial_ind = valid_windows(p, 1);
        onset     = valid_windows(p, 2);
        win_start = onset - pre_frames + 1;
        win_end   = onset + stim_frames + pre_frames;
        d = double(FemaleMaleData(trial_ind).(timeseries_list{t}));
        traces_t(p, :) = d(win_start : win_end);
    end
    ts_mean = mean(traces_t, 1);
    ts_sem  = std(traces_t, 0, 1) ./ sqrt(n_valid);
    shplot(t_win, ts_mean, ts_sem, 'Color', color);
    % Use fixed ylim for known fields, otherwise auto-scale from the data
    % (auto-scaling is needed because the fill's ±1e6 extent would otherwise dominate)
    idx_yl = strcmp(timeseries_list{t}, known_continuous);
    if any(idx_yl) && ~isempty(known_ylims{idx_yl})
        ylim(known_ylims{idx_yl});
    else
        y_range = [min(ts_mean - ts_sem), max(ts_mean + ts_sem)];
        y_pad   = max(diff(y_range) * 0.15, 1e-6);
        ylim([y_range(1) - y_pad, y_range(2) + y_pad]);
    end

    % Y-axis label: use known units where available, otherwise the field name
    idx_known = strcmp(timeseries_list{t}, known_continuous);
    if any(idx_known)
        ts_ylabel = [strrep(timeseries_list{t},'_',' ') ' (' known_units{idx_known} ')'];
    else
        ts_ylabel = strrep(timeseries_list{t}, '_', ' ');
    end
    ylabel(ts_ylabel, 'FontSize', 12);
    xlim(t_xlim);
    xticks(xt);
    box off;
end

% x-axis label on the bottom-most panel
subplot(numSubplots, 1, numSubplots);
xlabel('Time from Stimulus Onset (s)', 'FontSize', 12);

%% ── Save (optional) ──────────────────────────────────────────────────────
if nargin >= 4 && ~isempty(SavePath) && nargin >= 5 && ~isempty(SaveFormat)
    if ~exist(SavePath, 'dir'), mkdir(SavePath); end
    safe_name = regexprep(driver_str, '[\\/ ,]', '_');
    saveas(fig, fullfile(SavePath, [safe_name '_femalemale_STA' SaveFormat]));
end

end
