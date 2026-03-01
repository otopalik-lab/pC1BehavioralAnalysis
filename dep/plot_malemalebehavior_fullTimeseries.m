function plot_behavior_fullTimeseries(line_input, behavior_list, SavePath, SaveFormat)
% PLOT_BEHAVIOR_FULLTIMESERIES  Plots LED-aligned raster plots for any
% behaviors + inter-fly distance time series
%
% INPUTS:
%   line_input     - SS line identifier as a string (e.g., 'SS102571')
%                    or a numeric index into lines{}
%   behavior_list  - Cell array of behavior field names to plot
%                    e.g., {'aggression', 'unilateralwing', 'wingflick'}
%   SavePath       - (optional) Directory in which to save the figure
%   SaveFormat     - (optional) File format string, e.g. '.pdf' or '.png'
%                    Both SavePath and SaveFormat must be provided to save.
%
% EXAMPLE:
%   plot_behavior_fullTimeseries('SS102571', {'unilateralwing', 'aggression'})
%
% NOTES:
%   Requires MaleMaleData, SSinds, lines, celltypes, SavePlots, SavePath,
%   SaveFormat to exist in the base workspace.

%% Load dependencies from base workspace
MaleMaleData = evalin('base', 'MaleMaleData');
SSinds       = evalin('base', 'SSinds');
lines        = evalin('base', 'lines');
celltypes    = evalin('base', 'celltypes');

%% Parameters
FPS        = MaleMaleData(1).FPS;
fieldNames = fieldnames(MaleMaleData);

% Build labels
numLines = length(lines);
labels = cell(numLines, 1);
for i = 1:numLines
    labels{i} = [lines{i} ' | ' celltypes{i}];
end

%% Resolve line_input to line_idx
if ischar(line_input) || isstring(line_input)
    % Search for the SS number string within the lines cell array
    matches = find(contains(lines, line_input));
    if isempty(matches)
        error('SS line "%s" not found in lines. Check the identifier and try again.', line_input);
    elseif length(matches) > 1
        warning('Multiple matches found for "%s". Using the first match (index %d).', line_input, matches(1));
    end
    line_idx = matches(1);
elseif isnumeric(line_input)
    % Allow original numeric index behaviour as a fallback
    line_idx = line_input;
else
    error('line_input must be either a string (e.g., ''SS102571'') or a numeric index.');
end


% Detect LED epochs
[LED_epochs, ~] = detect_binarybouts(MaleMaleData(1).LED);

% Trial indices
[~, numTrials] = size(SSinds);

%% Color palette — one color per behavior, distance gets its own color
% Cycles through a default set; extend as needed
default_colors = {'#648FFF', '#DC267F', '#FE6100', '#785EF0', '#FFB000', ...
                  '#009E73', '#56B4E9', '#E69F00', '#CC79A7', '#0072B2'};
numBehaviors   = length(behavior_list);
numSubplots    = numBehaviors + 2; % LED trace + N behavior rasters + distance

%% Validate behavior field names
for b = 1:numBehaviors
    if ~ismember(behavior_list{b}, fieldNames)
        error('Field "%s" not found in MaleMaleData. Check spelling.', behavior_list{b});
    end
end

%% Build figure
f = figure; clf;
f.Position = [100, 100, 500, 200 * numSubplots];

%% Subplot 1: LED stimulus trace
subplot(numSubplots, 1, 1)
% Shade the last 3 stimulus epochs (highest powers)
for ep = max(1, size(LED_epochs,1)-2) : size(LED_epochs,1)
    area(LED_epochs(ep,:) ./ FPS, [50 50], ...
        'FaceColor', [0 0 0], 'FaceAlpha', 0.1, 'LineStyle', 'none');
    hold on;
end
plot((1:length(MaleMaleData(1).LED)) ./ FPS, MaleMaleData(1).LED, 'k-', 'LineWidth', 2);
ylabel('LED (mW/cm^2)', 'FontSize', 12);
xlim([0, length(MaleMaleData(1).LED) ./ FPS]);
ylim([0 4]);
title([labels{line_idx} '  |  N = ' num2str(numTrials)]);
box off;

%% Subplots 2 to N+1: One raster per behavior
for b = 1:numBehaviors
    subplot(numSubplots, 1, b + 1)
    color = default_colors{mod(b-1, length(default_colors)) + 1};
    
    for k = 1:numTrials
        ind        = SSinds(line_idx, k);
        behav_temp = MaleMaleData(ind).(behavior_list{b});
        event_times = find(behav_temp == 1);
        
        if ~isempty(event_times)
            plot(event_times ./ FPS, k * ones(length(event_times), 1), ...
                '|', 'MarkerFaceColor', color, 'MarkerEdgeColor', color, ...
                'MarkerSize', 5);
        end
        hold on;
    end
    
    ylabel(strrep(behavior_list{b}, '_', ' '), 'FontSize', 12);
    ylim([0, numTrials + 1]);
    xlim([0, length(behav_temp) ./ FPS]);
    box off;
end

%% Last subplot: Inter-fly distance (mean ± SEM)
subplot(numSubplots, 1, numSubplots)

dist_traces = [];
for k = 1:numTrials
    ind  = SSinds(line_idx, k);
    temp = MaleMaleData(ind).dist_ctr;
    dist_traces = [dist_traces; temp]; %#ok<AGROW>
end

dist_color = default_colors{mod(numBehaviors, length(default_colors)) + 1};
t_axis     = (1:size(dist_traces, 2)) ./ FPS;

shplot(t_axis, mean(dist_traces, 1), std(dist_traces, 0, 1) ./ sqrt(size(dist_traces, 1)), ...
       'Color', dist_color);
hold on;
plot([t_axis(1), t_axis(end)], [6 6], 'k--', 'LineWidth', 1);
ylim([0 20]);
xlim([t_axis(1), t_axis(end)]);
ylabel('Distance (mm)', 'FontSize', 12);
xlabel('Time (s)', 'FontSize', 12);
box off;

%% Save (optional — only if SavePath and SaveFormat are provided)

if nargin == 4
    if ~exist(SavePath, 'dir')
        mkdir(SavePath);
    end
    linename = char(lines{line_idx});
    cellname = char(celltypes{line_idx});
    cellname = erase(cellname, "\");
    cellname = erase(cellname, " ");
    cellname = erase(cellname, ",");
    
    cd(SavePath);
    saveas(f, [linename '_' cellname '_behaviorplots_fullTimeseries' SaveFormat]);
end

end