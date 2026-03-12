function fig = plot_femalemale_fullTimeSeries(line_input, behavior_list, SavePath, SaveFormat)
%PLOT_FEMALEMALE_FULLTIMESERIES  LED-aligned raster/trace plots for
%   female–male interaction data for a specified driver line.
%
%   For binary behavior fields:     tick-mark raster, one row per trial.
%   For continuous fields:          mean ± SEM shaded trace across trials.
%   Continuous fields are auto-detected; the following are always treated
%   as continuous: Distance, FacingAngle, AngleBetween, MaleVelocity,
%   FemaleVelocity. Any field whose values lie outside {0,1} is also
%   treated as continuous.
%   LED stimulus trace (first trial, truncated to behavior length) is
%   always plotted at the top.
%
% ── USAGE ─────────────────────────────────────────────────────────────────
%   plot_femalemale_fullTimeSeries('SS102671', {'close', 'chase'})
%   plot_femalemale_fullTimeSeries('SS102671', ...
%       {'close', 'chase', 'Distance', 'MaleVelocity'}, ...
%       '/save/dir', '.pdf')
%
% ── REQUIRED INPUTS ───────────────────────────────────────────────────────
%   line_input     String matching FemaleMaleData.driver (e.g., 'SS102671')
%                  or a numeric vector of row indices into FemaleMaleData.
%   behavior_list  Cell array of FemaleMaleData field names to plot, e.g.
%                  {'close', 'chase', 'Distance', 'MaleVelocity'}
%
% ── OPTIONAL INPUTS ───────────────────────────────────────────────────────
%   SavePath       Directory in which to save the figure
%   SaveFormat     File format string, e.g. '.pdf', '.png', '.svg'
%                  Both SavePath and SaveFormat must be provided to save.
%
% ── BASE WORKSPACE REQUIREMENTS ───────────────────────────────────────────
%   FemaleMaleData   struct array — see field list in function header
%   lines, celltypes (optional) used only for the figure title
%
% ── OUTPUT ────────────────────────────────────────────────────────────────
%   fig   figure handle

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

%% ── Common behavior vector length (minimum across all trials) ────────────
beh_len = inf;
for k = 1:numTrials
    beh_len = min(beh_len, length(FemaleMaleData(trial_inds(k)).(behavior_list{1})));
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

%% ── Color palette ────────────────────────────────────────────────────────
default_colors = {'#648FFF', '#DC267F', '#FE6100', '#785EF0', '#FFB000', ...
                  '#009E73', '#56B4E9', '#E69F00', '#CC79A7', '#0072B2'};

%% ── Build figure ─────────────────────────────────────────────────────────
numSubplots = numBehaviors + 1;
fig = figure; clf;
fig.Position = [100, 100, 500, 200 * numSubplots];

%% Panel 1: LED stimulus trace ────────────────────────────────────────────
subplot(numSubplots, 1, 1);
led_max = max(LED_vec);
if ~isempty(LED_epochs)
    y_top = max(led_max * 2, 1);
    for ep = max(1, size(LED_epochs,1)-2) : size(LED_epochs,1)
        x0 = double(LED_epochs(ep,1)) / double(FPS);
        x1 = double(LED_epochs(ep,2)) / double(FPS);
        % fill([x0 x1 x1 x0], [0 0 y_top y_top], [0 0 0], ...
        %     'FaceAlpha', 0.1, 'EdgeColor', 'none');
        hold on;
    end
end
plot(t_beh, LED_vec, 'k-', 'LineWidth', 2);
ylabel(['LED (' LED_units ')'], 'FontSize', 12);
xlim([t_beh(1), t_beh(end)]);
ylim([0, max(led_max * 1.2, eps)]);
title(title_str);
box off;

%% Panels 2–N+1: one per behavior ─────────────────────────────────────────
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
        mu  = mean(traces, 1);
        sem = std(traces, 0, 1) ./ sqrt(numTrials);
        shplot(t_beh, mu, sem, 'Color', color);
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
    if b == numBehaviors
        xlabel('Time (s)', 'FontSize', 12);
    end
    box off;
end

%% ── Save (optional) ──────────────────────────────────────────────────────
if nargin >= 3 && ~isempty(SavePath) && nargin >= 4 && ~isempty(SaveFormat)
    if ~exist(SavePath, 'dir'), mkdir(SavePath); end
    safe_name = regexprep(driver_str, '[\\/ ,]', '_');
    saveas(fig, fullfile(SavePath, [safe_name '_femalemale_fullTimeSeries' SaveFormat]));
end

end
