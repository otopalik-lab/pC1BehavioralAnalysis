function plot_behavior_stimbin_heatmap(line_input, behavior, SavePath, SaveFormat)
% PLOT_BEHAVIOR_STIMBIN_HEATMAP  Plot a 2-bin (LED on / LED off, 30 s each) PSTH
%                    heatmap for the specified behavior across SS lines,
%                    with magenta scatter annotations marking lines
%                    significantly different from the Empty Split control
%                    (one-way ANOVA + Dunn-Šidák post-hoc, α = 0.01).
%
% INPUTS:
%   line_input  - SS lines to display as heatmap rows. Accepted formats:
%                   'all'           → all lines in the workspace (default)
%                   char/string     → single line, e.g. 'SS102671'
%                   cell array      → subset, e.g. {'SS102671','SS03661'}
%                   numeric vector  → row indices into lines{}
%                 The Empty Split control line must be included.
%   behavior    - Behavior field name in MaleMaleData (e.g., 'aggression')
%   SavePath    - (optional) Directory in which to save the figure
%   SaveFormat  - (optional) File format string, e.g. '.pdf' or '.png'
%                 Both SavePath and SaveFormat must be provided to save.
%
% EXAMPLE:
%   plot_2bin_heatmap('all', 'aggression')
%   plot_2bin_heatmap('all', 'unilateralwing', '/save/path', '.pdf')
%   plot_2bin_heatmap({'Empty Split','SS102671','SS03661'}, 'proximal')

%% Load dependencies from base workspace
MaleMaleData = evalin('base', 'MaleMaleData');
SSinds       = evalin('base', 'SSinds');
lines        = evalin('base', 'lines');
celltypes    = evalin('base', 'celltypes');

%% Parameters
FPS      = MaleMaleData(1).FPS;
binsize  = 30000;    % 30-s bins in ms → 2 bins per epoch (LED on, LED off)
LEDStims = [5 6 7]; % three highest-power LED epochs

%% Build line labels
numLines = length(lines);
labels   = cell(numLines, 1);
for i = 1:numLines
    labels{i} = [lines{i} ' | ' celltypes{i}];
end

%% Resolve line_input to a vector of row indices into lines{}
if isnumeric(line_input)
    line_inds = line_input(:)';
elseif ischar(line_input) || isstring(line_input)
    if strcmpi(line_input, 'all')
        line_inds = 1:numLines;
    else
        matches = find(contains(labels, char(line_input)));
        if isempty(matches)
            error('SS line "%s" not found in lines{}.', line_input);
        elseif numel(matches) > 1
            warning('Multiple matches for "%s"; using index %d.', line_input, matches(1));
        end
        line_inds = matches(1);
    end
elseif iscell(line_input)
    line_inds = [];
    for s = 1:numel(line_input)
        m = find(contains(labels, line_input{s}));
        if isempty(m)
            warning('SS line "%s" not found, skipping.', line_input{s});
        else
            line_inds(end+1) = m(1); %#ok<AGROW>
        end
    end
else
    error('line_input must be ''all'', a string, a cell array, or a numeric index vector.');
end

%% Validate behavior field name
fieldNames = fieldnames(MaleMaleData);
if ~ismember(behavior, fieldNames)
    error('Field "%s" not found in MaleMaleData. Check spelling.', behavior);
end

%% Find Empty Split control index within the selected lines
selected_labels = labels(line_inds);
ES_idx = find(contains(selected_labels, 'Empty'));
if isempty(ES_idx)
    error('Empty Split control not found among selected lines. Include it in line_input.');
end
ES_idx = ES_idx(1);

%% Detect LED epochs and build per-epoch windows (onset → 30 s after offset)
[LED_epochs_raw, ~] = detect_binarybouts(MaleMaleData(1).LED);
LED_on_epochs       = [3600 5400; LED_epochs_raw]; % prepend baseline epoch

% Window spans LED on (30 s) + 30 s post-LED = 60 s total → 2 × 30-s bins
LED_epochs_win = [LED_on_epochs(:,1), LED_on_epochs(:,2) + 30*FPS];
window         = LED_epochs_win(1,2) - LED_epochs_win(1,1) + 1; % frames

[~, numTrials] = size(SSinds);
numStims       = length(LEDStims);
numSelected    = length(line_inds);

%% Compute per-fly and per-line PSTHs
LEDon_mat         = NaN(numTrials, numSelected);
LEDoff_mat        = NaN(numTrials, numSelected);
SS_PSTHs_allLines = zeros(numSelected, 2);

for idx = 1:numSelected
    i               = line_inds(idx);
    event_times_all = [];
    SS_byfly_PSTHs  = [];

    for k = 1:numTrials
        ind               = SSinds(i, k);
        behav_temp        = MaleMaleData(ind).(behavior);
        event_times_byfly = [];

        for j = LEDStims
            ep_start    = LED_epochs_win(j, 1);
            ep_end      = LED_epochs_win(j, 2);
            behav_win   = behav_temp(ep_start:ep_end);
            event_times = find(behav_win == 1);

            event_times_all   = [event_times_all,   event_times]; %#ok<AGROW>
            event_times_byfly = [event_times_byfly, event_times]; %#ok<AGROW>
        end

        [psth_temp, ~]      = psth(event_times_byfly, binsize, FPS, numStims, window);
        SS_byfly_PSTHs(k,:) = psth_temp; %#ok<AGROW>
    end

    % Bin 1 = LED on, Bin 2 = LED off
    LEDon_mat(:,  idx) = SS_byfly_PSTHs(:, 1);
    LEDoff_mat(:, idx) = SS_byfly_PSTHs(:, 2);

    % Line-level mean (pool all event times across trials and stim epochs)
    [line_psth, ~]          = psth(event_times_all, binsize, FPS, numTrials * numStims, window);
    SS_PSTHs_allLines(idx,:) = line_psth(1:2) ./ FPS;
end

%% Statistics: one-way ANOVA + Dunn-Šidák post-hoc vs Empty Split (α = 0.01)
sig_rows = cell(1, 2); % {significant row indices for LED-on, LED-off}
for bin = 1:2
    if bin == 1
        mat = LEDon_mat;
    else
        mat = LEDoff_mat;
    end

    [~, ~, stats]      = anova1(mat, selected_labels, 'off');
    [results, ~, ~, ~] = multcompare(stats, 'CriticalValueType', 'dunn-sidak', ...
                                     'Alpha', 0.01, 'Display', 'off');

    % Filter for comparisons that involve the Empty Split control
    comps = results(results(:,1) == ES_idx | results(:,2) == ES_idx, :);

    % Extract row indices (within selected_labels) of significant SS lines
    sig_idx = [];
    for r = 1:size(comps, 1)
        if comps(r, 6) < 0.05
            other_idx = comps(r, 1:2);
            sig_idx   = [sig_idx, other_idx(other_idx ~= ES_idx)]; %#ok<AGROW>
        end
    end
    sig_rows{bin} = unique(sig_idx);
end

%% Plot 2-bin heatmap
f = figure('Position', [1000 500 50 600]);
h_prob = heatmap(SS_PSTHs_allLines);
h_prob.YDisplayLabels  = selected_labels;
h_prob.XDisplayLabels  = {'on', 'off'};
h_prob.GridVisible     = 'off';
h_prob.CellLabelColor  = 'none';
h_prob.ColorbarVisible = 'off';
h_prob.Colormap        = flipud(gray);
h_prob.Title           = ['p(' behavior ')'];
h_prob.FontSize        = 10;   % small enough for 34 rows to render labels

% Behavior-specific color limits; stored separately to pass to the colorbar axes
color_limits = [];  % empty → HeatmapChart auto-scales
switch behavior
    case 'unilateralwing';  color_limits = [0 0.50];
    case 'aggression';      color_limits = [0 0.50];
    case 'close';           color_limits = [0 1.00];
    case 'still';           color_limits = [0 1.00];
    case 'chase';           color_limits = [0 0.40];
    case 'approach';        color_limits = [0 0.50];
    case 'orient';          color_limits = [0 1.00];
    case 'boxing';          color_limits = [0 0.50];
    case 'headbutt';        color_limits = [0 0.35];
    case 'tussle';          color_limits = [0 0.40];
    case 'wingflick';       color_limits = [0 0.04];
end
if ~isempty(color_limits)
    h_prob.ColorLimits = color_limits;
end

%% Annotate significant lines with magenta dots
annot_color = [220 38 127] ./ 255; % magenta (#DC267F)
ax = struct(h_prob).Axes;
hold(ax, 'on');
for bin = 1:2
    sig = sig_rows{bin};
    if ~isempty(sig)
        scatter(ax, bin * ones(length(sig), 1), sig, 15, 'filled', ...
                'MarkerFaceColor', annot_color);
    end
end

%% Horizontal colorbar drawn as an imagesc gradient in the bottom strip
% Avoids all HeatmapChart layout-manager restrictions.
clim_vals = color_limits;
if isempty(clim_vals)
    clim_vals = [min(SS_PSTHs_allLines(:)), max(SS_PSTHs_allLines(:))];
end
n = 256;
cb_ax = axes(f, 'Position', [0.20, 0.05, 0.60, 0.02]);
imagesc(cb_ax, linspace(clim_vals(1), clim_vals(2), n), 1, (1:n));
colormap(cb_ax, flipud(gray));
cb_ax.YTick   = [];
cb_ax.XLim    = clim_vals;
cb_ax.TickDir = 'in';
cb_ax.FontSize = 10;
xlabel(cb_ax, ['p(' behavior ')'], 'FontSize', 10);

%% Save (optional — only if both SavePath and SaveFormat are provided)
if nargin == 4
    if ~exist(SavePath, 'dir')
        mkdir(SavePath);
    end
    saveas(f, fullfile(SavePath, [behavior '_2bin_heatmap' SaveFormat]));
end

end
