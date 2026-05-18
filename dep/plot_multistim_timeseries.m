function plot_multistim_timeseries(variable, condition_list, plot_window_min, condition_colors, SavePath, SaveFormat)
% PLOT_MULTISTIM_TIMESERIES  Mean +/- SEM time-course of a multi-stim
% experiment variable (aggression % or inter-fly distance), one trace per
% condition, with the optogenetic stimulation epoch shaded.
%
% INPUTS:
%   variable          'aggression' (uses agg_binned, %) or
%                     'dcenter'     (uses dcenter_binned, mm)
%   condition_list    cell array of condition names to overlay, in order
%                     e.g. {'empty', 'aIPg'}
%   plot_window_min   (optional) [tmin tmax] in MINUTES (movie time);
%                     default: [0.3 1.3]
%   condition_colors  (optional) struct mapping condition -> [R G B] in [0,1]
%                     default: gray for empty, purple for everything else
%   SavePath          (optional) directory to save figure
%   SaveFormat        (optional) e.g. '.pdf' or '.png' — both required to save
%
% BASE WORKSPACE REQUIREMENT:
%   MultiStimData     produced by build_multistim_workspace.m

if nargin < 3 || isempty(plot_window_min); plot_window_min = [0.3 1.3]; end
if nargin < 4; condition_colors = struct(); end

MultiStimData = evalin('base', 'MultiStimData');

switch lower(variable)
    case {'aggression','agg'}
        field   = 'agg_binned';
        ylab    = 'Aggressive behaviors (%)';
        ymax    = 40;
    case {'dcenter','distance','interflydistance'}
        field   = 'dcenter_binned';
        ylab    = 'Inter-fly distance (mm)';
        ymax    = 15;
    otherwise
        error('variable must be ''aggression'' or ''dcenter''.');
end

% Default colors (mirroring the figure: empty = olive-gray, aIPg = purple)
default_empty  = [0.74 0.78 0.70];
default_purple = [0.50 0.45 0.65];

f = figure('Position', [200 400 320 260]); clf;
ax = axes(f); hold(ax, 'on');

% Draw stim shading once, derived from the first listed condition's
% binned_indicatordata (all conditions share the same protocol).
first_cond_idx = find(strcmp({MultiStimData.condition}, condition_list{1}), 1);
if isempty(first_cond_idx)
    error('No experiments found for condition "%s" in MultiStimData.', condition_list{1});
end
binlabels_min        = MultiStimData(first_cond_idx).binlabels / 60;   % sec -> min
binned_indicator     = MultiStimData(first_cond_idx).binned_indicatordata;
[stim_starts, stim_ends] = local_runs(binned_indicator);
for s = 1:numel(stim_starts)
    x_on  = binlabels_min(stim_starts(s));
    x_off = binlabels_min(stim_ends(s));
    patch(ax, [x_on x_off x_off x_on], [0 0 ymax ymax], ...
          [1.0 0.80 0.80], 'FaceAlpha', 0.35, 'EdgeColor', 'none');
end

% Draw one mean+/-SEM trace per condition
legend_handles = gobjects(numel(condition_list), 1);
legend_labels  = cell(numel(condition_list), 1);
for c = 1:numel(condition_list)
    cond = condition_list{c};
    inds = find(strcmp({MultiStimData.condition}, cond));
    if isempty(inds)
        warning('No experiments for condition "%s"; skipping.', cond);
        continue
    end
    M = vertcat(MultiStimData(inds).(field));   % [n_exp x n_bins]
    mu  = mean(M, 1, 'omitnan');
    sem = std(M,  0, 1, 'omitnan') ./ sqrt(sum(~isnan(M), 1));

    if isfield(condition_colors, cond)
        col = condition_colors.(cond);
    elseif strcmpi(cond, 'empty') || contains(lower(cond), 'empty')
        col = default_empty;
    else
        col = default_purple;
    end

    H = shplot(binlabels_min, mu, sem, 'Color', col, 'LineWidth', 1.5);
    legend_handles(c) = H.line;
    legend_labels{c}  = strrep(cond, '_', ' ');
end

xlim(ax, plot_window_min);
ylim(ax, [0 ymax]);
xlabel(ax, 'Time (min)', 'FontSize', 11);
ylabel(ax, ylab,         'FontSize', 11);
box(ax, 'off');
ax.TickDir = 'out';
ax.FontSize = 10;

% Legend (only if multiple conditions)
if numel(condition_list) > 1
    valid = isgraphics(legend_handles);
    legend(ax, legend_handles(valid), legend_labels(valid), ...
           'Location', 'northeast', 'Box', 'off', 'FontSize', 9, ...
           'Interpreter', 'none');
end

if nargin == 6 && ~isempty(SavePath) && ~isempty(SaveFormat)
    if ~exist(SavePath, 'dir'); mkdir(SavePath); end
    saveas(f, fullfile(SavePath, ['multistim_timeseries_' field SaveFormat]));
end

end

% --- helper: contiguous run start/end indices of a logical vector --------
function [starts, ends] = local_runs(b)
    b = logical(b(:))';
    d = diff([false b false]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;
end
