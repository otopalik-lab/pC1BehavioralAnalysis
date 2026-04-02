function fig = plot_femalemale_fullTimeSeries(line_input, behavior_list, timeseries_list, SavePath, SaveFormat)
%PLOT_FEMALEMALE_FULLTIMESERIES  LED-aligned raster/trace plots for
%   female–male interaction data for a specified driver line.
%
%   For binary behavior fields (behavior_list):
%       tick-mark raster, one row per trial.
%   For continuous fields (behavior_list):
%       mean ± SEM shaded trace across trials (auto-detected or known).
%   For explicitly requested timeseries (timeseries_list):
%       mean ± SEM shaded trace, one subplot per field, appended below
%       the behavior panels.
%   Continuous fields auto-detected; the following are always treated
%   as continuous: Distance, FacingAngle, AngleBetween, MaleVelocity,
%   FemaleVelocity. Any field whose values lie outside {0,1} is also
%   treated as continuous.
%   LED stimulus trace (first trial, truncated to behavior length) is
%   always plotted at the top.
%
% ── USAGE ─────────────────────────────────────────────────────────────────
%   plot_femalemale_fullTimeSeries('SS102671', {'close', 'chase'})
%   plot_femalemale_fullTimeSeries('SS102671', {'close', 'chase'}, ...
%       {'Distance', 'FacingAngle'})
%   plot_femalemale_fullTimeSeries('SS102671', {'close', 'chase'}, ...
%       {'Distance', 'AngleBetween'}, '/save/dir', '.pdf')
%
% ── REQUIRED INPUTS ───────────────────────────────────────────────────────
%   line_input       String matching FemaleMaleData.driver (e.g., 'SS102671')
%                    or a numeric vector of row indices into FemaleMaleData.
%   behavior_list    Cell array of FemaleMaleData field names for the raster
%                    panels, e.g. {'close', 'chase', 'm_orient'}
%
% ── OPTIONAL INPUTS ───────────────────────────────────────────────────────
%   timeseries_list  Cell array of continuous field names to plot as
%                    mean ± SEM traces below the behavior panels, e.g.
%                    {'Distance', 'FacingAngle', 'AngleBetween'}.
%                    Pass {} or omit to skip.
%   SavePath         Directory in which to save the figure
%   SaveFormat       File format string, e.g. '.pdf', '.png', '.svg'
%                    Both SavePath and SaveFormat must be provided to save.
%
% ── BASE WORKSPACE REQUIREMENTS ───────────────────────────────────────────
%   FemaleMaleData   struct array — see field list in function header
%   lines, celltypes (optional) used only for the figure title
%
% ── OUTPUT ────────────────────────────────────────────────────────────────
%   fig   figure handle

%% ── Handle optional timeseries_list ─────────────────────────────────────
if nargin < 3 || isempty(timeseries_list)
    timeseries_list = {};
end
numTimeseries = length(timeseries_list);

%% ── Load from base workspace ─────────────────────────────────────────────
FemaleMaleData = evalin('base', 'FemaleMaleData');
fieldNames     = fieldnames(FemaleMaleData);

%% ── Resolve line_input to trial indices ─────────────────────────────────
if ischar(line_input) || isstring(line_input)
    driver_str = char(line_input);
    trial_inds = find(strcmp({FemaleMaleData.driver}, driver_str));
    if isempty(trial_inds)
        error('Driver "%s" not found in FemaleMaleData.driver. Check the identifier.', driver_str);
    end
elseif isnumeric(line_input)
    trial_inds = line_input(:)';
    driver_str = FemaleMaleData(trial_inds(1)).driver;
else
    error('line_input must be a string driver name or a numeric index vector.');
end

numTrials = length(trial_inds);
FPS       = FemaleMaleData(trial_inds(1)).FPS;

%% ── Exclude trials with < 30 % close during 330–450 s ───────────────────
% Trials where the animals are not interacting at baseline are excluded.
interact_win_start = round(330 * FPS) + 1;
interact_win_end   = round(450 * FPS);
if ismember('close', fieldNames)
    keep = true(1, numTrials);
    for k = 1:numTrials
        c = double(FemaleMaleData(trial_inds(k)).close);
        if length(c) < interact_win_end
            keep(k) = false;   % trial too short to assess
            continue;
        end
        seg = c(interact_win_start : interact_win_end);
        if mean(seg) < 0.30
            keep(k) = false;
        end
    end
    trial_inds = trial_inds(keep);
    numTrials  = length(trial_inds);
    if numTrials == 0
        warning('No trials remain after interaction filter for driver "%s".', driver_str);
        fig = figure;
        return;
    end
end

%% ── Cap at 18 trials (random subsample) ─────────────────────────────────
max_trials = 18;
if numTrials > max_trials
    rng('shuffle');
    n_total    = numTrials;
    trial_inds = trial_inds(randperm(n_total, max_trials));
    numTrials  = max_trials;
    fprintf('Randomly selected %d of %d available trials for driver "%s".\n', ...
        max_trials, n_total, driver_str);
end

%% ── Build figure title ───────────────────────────────────────────────────
try
    lines_ws     = evalin('base', 'lines');
    celltypes_ws = evalin('base', 'celltypes');
    m = find(contains(lines_ws, driver_str), 1);
    if ~isempty(m)
        title_str = [lines_ws{m} ' | ' celltypes_ws{m} '  |  N = ' num2str(numTrials)];
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

%% ── Validate timeseries fields ───────────────────────────────────────────
for s = 1:numTimeseries
    if ~ismember(timeseries_list{s}, fieldNames)
        error('Timeseries field "%s" not found in FemaleMaleData. Check spelling.', timeseries_list{s});
    end
end

%% ── Common vector length (minimum across all trials, first behavior field) ─
beh_len = inf;
ref_field = behavior_list{1};   % use first behavior field as length reference
for k = 1:numTrials
    beh_len = min(beh_len, length(FemaleMaleData(trial_inds(k)).(ref_field)));
end
beh_len = double(beh_len);
t_beh   = (0:beh_len-1) ./ FPS;   % time axis starting at 0 s

%% ── LED reference trace (first trial, truncated to beh_len) ─────────────
LED_raw  = double(FemaleMaleData(trial_inds(1)).LED);
LED_vec  = LED_raw(1:min(beh_len, length(LED_raw)));
% Pad with zeros if LED was shorter than beh_len (edge case)
if length(LED_vec) < beh_len
    LED_vec(end+1:beh_len) = 0;
end
LED_units = FemaleMaleData(trial_inds(1)).LEDunits;

% Detect LED epochs from binarised trace
LED_epochs = detect_binarybouts(LED_vec > 0);

%% ── Determine continuous vs binary for each requested behavior ───────────
known_continuous = {'Distance',    'FacingAngle', 'AngleBetween', ...
                    'MaleVelocity','FemaleVelocity'};
known_units      = {'mm',          'deg',          'deg', ...
                    'mm/s',        'mm/s'};

numBehaviors  = length(behavior_list);
is_continuous = false(1, numBehaviors);
beh_ylabel    = behavior_list;

for b = 1:numBehaviors
    idx_known = strcmp(behavior_list{b}, known_continuous);
    if any(idx_known)
        is_continuous(b) = true;
        beh_ylabel{b}    = [strrep(behavior_list{b}, '_', ' ') ' (' known_units{idx_known} ')'];
    else
        % Auto-detect: if data has values outside {0,1} treat as continuous
        d = double(FemaleMaleData(trial_inds(1)).(behavior_list{b}));
        uniq = unique(d(isfinite(d)));
        if ~all(ismember(uniq, [0 1]))
            is_continuous(b) = true;
        end
        beh_ylabel{b} = strrep(behavior_list{b}, '_', ' ');
    end
end

%% ── Build ylabel for each timeseries panel ───────────────────────────────
ts_ylabel = cell(numTimeseries, 1);
for s = 1:numTimeseries
    idx_known = strcmp(timeseries_list{s}, known_continuous);
    if any(idx_known)
        ts_ylabel{s} = [strrep(timeseries_list{s}, '_', ' ') ' (' known_units{idx_known} ')'];
    else
        ts_ylabel{s} = strrep(timeseries_list{s}, '_', ' ');
    end
end

%% ── Color palette (converted to RGB triplets for fill/patch compatibility) ─
hex_palette = {'#648FFF', '#DC267F', '#FE6100', '#785EF0', '#FFB000', ...
               '#009E73', '#56B4E9', '#E69F00', '#CC79A7', '#0072B2'};
default_colors = cellfun(@(h) sscanf(h(2:end), '%2x%2x%2x', [1 3])' / 255, ...
                         hex_palette, 'UniformOutput', false);

%% ── Build figure ─────────────────────────────────────────────────────────
numSubplots = 1 + numBehaviors + numTimeseries;
fig = figure; clf;
fig.Position = [100, 100, 700, 200 * numSubplots];

%% Panel 1: LED stimulus trace ────────────────────────────────────────────
subplot(numSubplots, 1, 1);
led_max = max(LED_vec);
if ~isempty(LED_epochs)
    for ep = max(1, size(LED_epochs,1)-2) : size(LED_epochs,1)
        hold on;
    end
end
plot(t_beh, LED_vec, 'k-', 'LineWidth', 2);
ylabel(['LED (' LED_units ')'], 'FontSize', 12);
xlim([t_beh(1), t_beh(end)]);
ylim([0, max(led_max * 1.2, eps)]);
title(title_str);
box off;

%% Panels 2 – (numBehaviors+1): one per behavior ──────────────────────────
for b = 1:numBehaviors
    subplot(numSubplots, 1, b + 1);
    color = default_colors{mod(b-1, length(default_colors)) + 1};

    if is_continuous(b)
        % Collect traces across trials, each truncated to beh_len
        traces = zeros(numTrials, beh_len);
        for k = 1:numTrials
            d = double(FemaleMaleData(trial_inds(k)).(behavior_list{b}));
            n = min(beh_len, length(d));
            traces(k, 1:n) = d(1:n);
        end
        mu  = mean(traces, 1);  mu  = mu(:)';
        sem = std(traces, 0, 1) ./ sqrt(numTrials);  sem = sem(:)';
        hold on;
        fill([t_beh, fliplr(t_beh)], [mu + sem, fliplr(mu - sem)], ...
            color, 'FaceAlpha', 0.25, 'EdgeColor', 'none');
        plot(t_beh, mu, 'Color', color, 'LineWidth', 1.5);
        xlim([t_beh(1), t_beh(end)]);

    else
        % Binary raster — one tick mark per event frame
        for k = 1:numTrials
            d = double(FemaleMaleData(trial_inds(k)).(behavior_list{b}));
            d = d(1:min(beh_len, end));
            event_times = find(d == 1);
            if ~isempty(event_times)
                plot(event_times ./ FPS, k * ones(size(event_times)), ...
                    '|', 'MarkerFaceColor', color, 'MarkerEdgeColor', color, ...
                    'MarkerSize', 5);
            end
            hold on;
        end
        ylim([0, numTrials + 1]);
        xlim([t_beh(1), t_beh(end)]);
    end

    ylabel(beh_ylabel{b}, 'FontSize', 12);
    % x-axis label on the last panel (behavior or timeseries)
    if b == numBehaviors && numTimeseries == 0
        xlabel('Time (s)', 'FontSize', 12);
    end
    box off;
end

%% Panels (numBehaviors+2) – end: one mean±SEM trace per timeseries ────────
for s = 1:numTimeseries
    panel_idx = 1 + numBehaviors + s;
    subplot(numSubplots, 1, panel_idx);
    color = default_colors{mod(numBehaviors + s - 1, length(default_colors)) + 1};

    % Collect traces across trials
    traces = zeros(numTrials, beh_len);
    for k = 1:numTrials
        d = double(FemaleMaleData(trial_inds(k)).(timeseries_list{s}));
        n = min(beh_len, length(d));
        traces(k, 1:n) = d(1:n);
    end
    mu  = mean(traces, 1);
    sem = std(traces, 0, 1) ./ sqrt(numTrials);

    shplot(t_beh, mu, sem, 'Color', color);
    xlim([t_beh(1), t_beh(end)]);
    switch timeseries_list{s}
        case 'Distance';       ylim([0   15]);
        case 'FacingAngle';    ylim([0   90]);
        case 'AngleBetween';   ylim([90 180]);
        case 'MaleVelocity';   ylim([0   30]);
        case 'FemaleVelocity'; ylim([0   30]);
    end

    ylabel(ts_ylabel{s}, 'FontSize', 12);
    if s == numTimeseries
        xlabel('Time (s)', 'FontSize', 12);
    end
    box off;
end

%% ── Save (optional) ──────────────────────────────────────────────────────
if nargin >= 4 && ~isempty(SavePath) && nargin >= 5 && ~isempty(SaveFormat)
    if ~exist(SavePath, 'dir'), mkdir(SavePath); end
    safe_name = regexprep(driver_str, '[\\/ ,]', '_');
    saveas(fig, fullfile(SavePath, [safe_name '_femalemale_fullTimeSeries' SaveFormat]));
end

end
