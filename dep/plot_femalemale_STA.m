function fig = plot_femalemale_STA(line_input, behavior_list, SavePath, SaveFormat)
%PLOT_FEMALEMALE_STA  Stimulus-triggered averages for female–male interaction data.
%
%   For each LED epoch index in LEDStims (default [1 2 3]), extracts a
%   peri-stimulus window (60 s pre + 120 s LED + 60 s post) anchored to
%   LED onset, and pools across all trials for the specified driver line.
%
%   Binary behavior fields → tick-mark rasters (rows = trials × epochs)
%   Continuous fields      → mean ± SEM shaded traces across windows
%   Combined PSTH          → P(Behavior) over time for all binary behaviors
%   Distance               → mean ± SEM inter-fly distance (always appended)
%
%   x-axis is aligned to LED onset: 0 = stimulus on, stim_dur = stimulus off.
%
% ── USAGE ─────────────────────────────────────────────────────────────────
%   plot_femalemale_STA('SS102671', {'close', 'chase'})
%   plot_femalemale_STA('SS102671', {'close', 'chase', 'MaleVelocity'}, ...
%       '/save/dir', '.pdf')
%
% ── REQUIRED INPUTS ───────────────────────────────────────────────────────
%   line_input     Driver name string matching FemaleMaleData.driver, or a
%                  numeric vector of row indices into FemaleMaleData.
%   behavior_list  Cell array of FemaleMaleData field names to plot, e.g.
%                  {'close', 'chase', 'Distance'}
%
% ── OPTIONAL INPUTS ───────────────────────────────────────────────────────
%   SavePath       Directory in which to save the figure (requires SaveFormat)
%   SaveFormat     File format string, e.g. '.pdf', '.png', '.svg'
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

%% ── Validate behavior fields ─────────────────────────────────────────────
for b = 1:length(behavior_list)
    if ~ismember(behavior_list{b}, fieldNames)
        error('Field "%s" not found in FemaleMaleData. Check spelling.', behavior_list{b});
    end
end

%% ── Window parameters ────────────────────────────────────────────────────
pre_frames   = round(pre_post_sec * FPS);
stim_frames  = round(stim_dur_sec * FPS);

% Fixed window: pre_post_sec before LED onset, stim_dur_sec LED, pre_post_sec after
windowLength = pre_frames + stim_frames + pre_frames;
t_xlim       = [-pre_post_sec, stim_dur_sec + pre_post_sec];   % [-60, 180]
xt           = [-pre_post_sec, 0, stim_dur_sec, stim_dur_sec + pre_post_sec];  % [-60 0 120 180]
t_win        = (0:windowLength-1) ./ FPS - pre_post_sec;

%% ── Pre-compute valid peri-stimulus windows (per trial) ─────────────────
% Epochs are detected from the full LED vector so that later bouts are not
% truncated by the (shorter) behavior vector. LEDStims selects which epoch
% indices to include; each trial contributes one row per valid index
% (expected total = numTrials × length(LEDStims)).
valid_windows = zeros(0, 2);   % rows: [global_struct_index, onset_frame]

for k = 1:numTrials
    % Use this trial's own behavior length as the validity boundary
    trial_beh_len = double(length(FemaleMaleData(trial_inds(k)).(behavior_list{1})));

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
known_continuous = {'Distance','FacingAngle','AngleBetween','MaleVelocity','FemaleVelocity'};
numBehaviors  = length(behavior_list);
is_continuous = false(1, numBehaviors);
beh_ylabel    = behavior_list;

for b = 1:numBehaviors
    idx_known = strcmp(behavior_list{b}, known_continuous);
    if any(idx_known)
        known_units = {'mm','deg','deg','mm/s','mm/s'};
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
% Behavior panels + combined PSTH (binary only) + Distance
has_psth    = n_binary > 0;
numSubplots = numBehaviors + has_psth + 1;
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
        shplot(t_win, mean(traces,1), std(traces,0,1)./sqrt(n_valid), 'Color', color);
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
    legend(bin_labels, 'Location', 'northeast', 'FontSize', 8);
end

%% ── Distance panel (mean ± SEM, always last) ─────────────────────────────
dist_color  = default_colors{mod(numBehaviors, length(default_colors)) + 1};
dist_traces = zeros(n_valid, windowLength);

for p = 1:n_valid
    trial_ind = valid_windows(p, 1);
    onset     = valid_windows(p, 2);
    win_start = onset - pre_frames + 1;
    win_end   = onset + stim_frames + pre_frames;

    d = double(FemaleMaleData(trial_ind).Distance);
    dist_traces(p, :) = d(win_start : win_end);
end

subplot(numSubplots, 1, numSubplots); hold on;

fill([0 stim_dur_sec stim_dur_sec 0], [-1e6 -1e6 1e6 1e6], [0 0 0], ...
    'FaceAlpha', 0.1, 'EdgeColor', 'none');

shplot(t_win, mean(dist_traces,1), std(dist_traces,0,1)./sqrt(n_valid), ...
    'Color', dist_color);

ylim([0, 15]);
xlim(t_xlim);
xticks(xt);
ylabel('Distance (mm)', 'FontSize', 12);
xlabel('Time from Stimulus Onset (s)', 'FontSize', 12);
box off;

%% ── Save (optional) ──────────────────────────────────────────────────────
if nargin >= 3 && ~isempty(SavePath) && nargin >= 4 && ~isempty(SaveFormat)
    if ~exist(SavePath, 'dir'), mkdir(SavePath); end
    safe_name = regexprep(driver_str, '[\\/ ,]', '_');
    saveas(fig, fullfile(SavePath, [safe_name '_femalemale_STA' SaveFormat]));
end

end
