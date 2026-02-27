function plot_behavior_STA(line_input, behavior_list, SavePath, SaveFormat)
% PLOT_BEHAVIOR_STA   Plot LED stimulus-aligned rasters, PSTHs, and inter-fly
%                     distance timeseries averaged across the 3 highest-power
%                     LED pulses (e.g. stimulus-triggered averages), for any set of behaviors in MaleMaleData.
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
%   PLOT_BEHAVIOR_STA('SS102571', {'unilateralwing', 'aggression'})
%   PLOT_BEHAVIOR_STA('SS102571', {'unilateralwing', 'aggression'}, '/save/path', '.pdf')

%% Load dependencies from base workspace
MaleMaleData = evalin('base', 'MaleMaleData');
SSinds       = evalin('base', 'SSinds');
lines        = evalin('base', 'lines');
celltypes    = evalin('base', 'celltypes');

%% Parameters
FPS        = MaleMaleData(1).FPS;
fieldNames = fieldnames(MaleMaleData);
LEDStims   = [5 6 7]; % Three highest LED power epochs

% Build labels
numLines = length(lines);
labels   = cell(numLines, 1);
for i = 1:numLines
    labels{i} = [lines{i} ' | ' celltypes{i}];
end

%% Resolve line_input to line_idx
if ischar(line_input) || isstring(line_input)
    matches = find(contains(labels, line_input));
    if isempty(matches)
        error('SS line "%s" not found in lines. Check the identifier and try again.', line_input);
    elseif length(matches) > 1
        warning('Multiple matches found for "%s". Using the first match (index %d).', line_input, matches(1));
    end
    line_idx = matches(1);
elseif isnumeric(line_input)
    line_idx = line_input;
else
    error('line_input must be either a string (e.g., ''SS102571'') or a numeric index.');
end

%% Validate behavior field names
for b = 1:length(behavior_list)
    if ~ismember(behavior_list{b}, fieldNames)
        error('Field "%s" not found in MaleMaleData. Check spelling.', behavior_list{b});
    end
end

%% Detect LED epochs and build peri-stimulus window info
[LED_epochs, ~]  = detect_binarybouts(MaleMaleData(1).LED);
LED_on_epochs    = [3600 5400; LED_epochs]; % prepend baseline epoch

[~, numTrials]   = size(SSinds);

% All LED stim windows should be the same length; use first to get window size
example_window = LED_on_epochs(LEDStims(1), 1) - 30*FPS : ...
                 LED_on_epochs(LEDStims(1), 2) + 30*FPS;
windowLength   = length(example_window);  % samples
windowDur      = windowLength / FPS;      % seconds

%% Color palette — one color per behavior, distance gets its own
default_colors = {'#648FFF', '#DC267F', '#FE6100', '#785EF0', '#FFB000', ...
                  '#009E73', '#56B4E9', '#E69F00', '#CC79A7', '#0072B2'};
numBehaviors   = length(behavior_list);

% numSubplots = one raster per behavior + one combined PSTH + one distance
numSubplots = numBehaviors + 2;

%% Build figure
f = figure; clf;
f.Position = [200, 700, 300, 180 * numSubplots];

%% Subplots 1 to numBehaviors: Rasters (one per behavior)
for b = 1:numBehaviors
    color      = default_colors{mod(b-1, length(default_colors)) + 1};
    event_times_all = []; % accumulate across trials and stim epochs for PSTH
    p          = 1;       % raster row counter

    subplot(numSubplots, 1, b); hold on;

    % Shade stimulus window
    area([30 30+30], [numTrials*length(LEDStims)+5, numTrials*length(LEDStims)+5], ...
        'FaceColor', [0 0 0], 'FaceAlpha', 0.1, 'LineStyle', 'none');

    for k = 1:numTrials
        ind = SSinds(line_idx, k);
        for j = LEDStims
            %window     = LED_on_epochs(j,1) - 30*FPS : LED_on_epochs(j,2) + 30*FPS;
            behav_temp = MaleMaleData(ind).(behavior_list{b});
            behav_temp = behav_temp(LED_on_epochs(j,1) - 30*FPS : LED_on_epochs(j,2) + 30*FPS);
            event_times = find(behav_temp == 1);

            if ~isempty(event_times)
                plot(event_times ./ FPS, p * ones(length(event_times), 1), ...
                    '|', 'MarkerFaceColor', color, 'MarkerEdgeColor', color, ...
                    'MarkerSize', 1);
            end
            event_times_all = [event_times_all, event_times]; %#ok<AGROW>
            p = p + 1;
        end
    end

    ylabel(strrep(behavior_list{b}, '_', ' '), 'FontSize', 12);
    ylim([0, p]);
    xlim([0, windowDur]);
    box off; %axis off;

    % Store event_times_all per behavior for PSTH subplot
    all_events{b} = event_times_all; %#ok<AGROW>
    total_rows(b) = p - 1;           % total raster rows = trials x stim epochs
end

% Title on first raster subplot
subplot(numSubplots, 1, 1);
title(labels{line_idx}, 'FontSize', 11, 'Interpreter', 'none');

%% Subplot numBehaviors+1: Combined PSTH (one trace per behavior)
subplot(numSubplots, 1, numBehaviors + 1); hold on;
area([30, 60], [1, 1], 'FaceColor', [0 0 0], 'FaceAlpha', 0.1, 'LineStyle', 'none');

for b = 1:numBehaviors
    color = default_colors{mod(b-1, length(default_colors)) + 1};
    [d, edges] = psth(all_events{b}, 500, 60, total_rows(b), windowLength);
    area(edges ./ 1000, d ./ 60, ...
        'FaceColor',  color, 'EdgeColor', color, ...
        'FaceAlpha', 0.2, 'LineWidth', 1.5);
end

xlim([0, windowDur]);
ylim([0, 1]);
ylabel('P(Behavior)', 'FontSize', 12);
box off;

% Add a simple legend
%legend(strrep(behavior_list, '_', ' '), 'Location', 'northeast', 'FontSize', 8);

%% Last subplot: Inter-fly distance (mean ± SEM across trials and stim epochs)
dist_traces = [];
for k = 1:numTrials
    for j = LEDStims
        ind    = SSinds(line_idx, k);
        %window = LED_on_epochs(j,1) - 30*FPS : LED_on_epochs(j,2) + 30*FPS;
        temp   = MaleMaleData(ind).dist_ctr(LED_on_epochs(j,1) - 30*FPS : LED_on_epochs(j,2) + 30*FPS);
        dist_traces = [dist_traces; temp]; %#ok<AGROW>
    end
end

dist_color = default_colors{mod(numBehaviors, length(default_colors)) + 1};
t_axis     = (1:size(dist_traces, 2)) ./ FPS;

subplot(numSubplots, 1, numSubplots); hold on;
area([30, 60], [50, 50], 'FaceColor', [0 0 0], 'FaceAlpha', 0.1, 'LineStyle', 'none');
shplot(t_axis, mean(dist_traces, 1), ...
       std(dist_traces, 0, 1) ./ sqrt(size(dist_traces, 1)), ...
       'Color', dist_color);
plot([0, windowDur], [6, 6], 'k--', 'LineWidth', 1);
ylim([0, 20]);
xlim([0, windowDur]);
ylabel('Distance (mm)', 'FontSize', 12);
xlabel('Time (s)', 'FontSize', 12);
box off;

%% Save (optional — only if both SavePath and SaveFormat are provided)


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
    saveas(f, [linename '_' cellname '_behaviorplots_STA' SaveFormat]);
end

end