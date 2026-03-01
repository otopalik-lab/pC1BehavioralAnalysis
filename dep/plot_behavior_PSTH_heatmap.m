function plot_behavior_PSTH_heatmap(line_input, behavior, binsize, SavePath, SaveFormat)
% PLOT_BEHAVIOR_PSTH_HEATMAP  Plot a peri-stimulus PSTH heatmap of p(behavior) for
%                    the specified SS lines aligned to the three
%                    highest-power LED stimulus epochs.
%
% INPUTS:
%   line_input  - SS lines to display as heatmap rows. Accepted formats:
%                   'all'           → all lines in the workspace (default)
%                   char/string     → single line, e.g. 'SS102671'
%                   cell array      → subset, e.g. {'SS102671','SS03661'}
%                   numeric vector  → row indices into lines{}
%   behavior    - Behavior field name in MaleMaleData (e.g., 'aggression')
%   binsize     - PSTH bin width in milliseconds (e.g., 1000 for 1-s bins,
%                 30000 for 30-s bins)
%   SavePath    - (optional) Directory in which to save the figure
%   SaveFormat  - (optional) File format string, e.g. '.pdf' or '.png'
%                 Both SavePath and SaveFormat must be provided to save.
%
% EXAMPLE:
%   plot_PSTH_heatmap('all', 'aggression', 1000)
%   plot_PSTH_heatmap('all', 'unilateralwing', 1000, '/save/path', '.pdf')
%   plot_PSTH_heatmap({'SS102671','SS03661'}, 'proximal', 30000)

%% Load dependencies from base workspace
MaleMaleData = evalin('base', 'MaleMaleData');
SSinds       = evalin('base', 'SSinds');
lines        = evalin('base', 'lines');
celltypes    = evalin('base', 'celltypes');

%% Parameters
FPS      = MaleMaleData(1).FPS;
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

%% Detect LED epochs and build uniform per-epoch windows
[LED_epochs_raw, ~] = detect_binarybouts(MaleMaleData(1).LED);
LED_on_epochs       = [3600 5400; LED_epochs_raw]; % prepend baseline epoch

% Recast each epoch as a fixed 3600-frame window from its onset
LED_epochs_win = [LED_on_epochs(:,1), LED_on_epochs(:,1) + 3599];
window         = LED_epochs_win(1,2) - LED_epochs_win(1,1) + 1; % frames per epoch

[~, numTrials] = size(SSinds);
numStims       = length(LEDStims);

%% Compute per-line mean PSTH (pooled across all trials and stim epochs)
numSelected  = length(line_inds);
SS_PSTHs_all = [];

for idx = 1:numSelected
    i               = line_inds(idx);
    event_times_all = [];

    for k = 1:numTrials
        ind        = SSinds(i, k);
        behav_temp = MaleMaleData(ind).(behavior);

        for j = LEDStims
            behav_win   = behav_temp(LED_epochs_win(j,1) : LED_epochs_win(j,2));
            event_times = find(behav_win == 1);
            event_times_all = [event_times_all, event_times]; %#ok<AGROW>
        end
    end

    [psth_temp, ~]       = psth(event_times_all, binsize, FPS, numTrials * numStims, window);
    SS_PSTHs_all(idx, :) = psth_temp; %#ok<AGROW>
end

%% Determine colormap and color limits (resolved before plotting)
% Falls back to flipud(gray) if the workspace colormap variable is missing.
cmap         = flipud(gray);   % default colormap
color_limits = [];             % empty → auto-scale
switch behavior
    case 'unilateralwing'
        try; cmap = evalin('base', 'blue_map');    catch; end
        color_limits = [0 0.5];
    case 'aggression'
        try; cmap = evalin('base', 'magenta_map'); catch; end
        color_limits = [0 0.5];
    case 'proximal'
        try; cmap = evalin('base', 'orange_map');  catch; end
end

%% Plot heatmap with imagesc
% imagesc() on a plain axes avoids the TiledChartLayout that heatmap()
% installs, so a second axes for the colorbar can be placed freely below.
f  = figure('Position', [1000 500 280 600]);
ax = axes(f, 'Position', [0.40, 0.10, 0.55, 0.87]);
imagesc(ax, SS_PSTHs_all ./ FPS);
colormap(ax, cmap);
if ~isempty(color_limits)
    caxis(ax, color_limits);
end
ax.YTick                = 1:numSelected;
ax.YTickLabel           = labels(line_inds);
ax.TickLabelInterpreter = 'none';
ax.XTick                = [];
ax.FontSize             = 9;
ax.TickDir              = 'out';
title(ax, ['p(' behavior ')'], 'FontSize', 12);

%% Horizontal colorbar drawn as an imagesc gradient in the bottom strip
clim_vals = color_limits;
if isempty(clim_vals)
    clim_vals = [min(SS_PSTHs_all(:)), max(SS_PSTHs_all(:))] ./ FPS;
end
n     = 256;
cb_ax = axes(f, 'Position', [0.42, 0.06, 0.50, 0.02]);
imagesc(cb_ax, linspace(clim_vals(1), clim_vals(2), n), 1, (1:n));
colormap(cb_ax, cmap);
cb_ax.YTick    = [];
cb_ax.XLim     = clim_vals;
cb_ax.TickDir  = 'out';
cb_ax.FontSize = 10;
xlabel(cb_ax, ['p(' behavior ')'], 'FontSize', 10);

%% Save (optional — only if both SavePath and SaveFormat are provided)
if nargin == 5
    if ~exist(SavePath, 'dir')
        mkdir(SavePath);
    end
    saveas(f, fullfile(SavePath, [behavior '_PSTH_heatmap' SaveFormat]));
end

end
