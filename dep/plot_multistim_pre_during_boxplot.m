function [stats_out, fig_handle] = plot_multistim_pre_during_boxplot(behavior, condition_list, stim_use, window_seconds, condition_colors, SavePath, SaveFormat)
% PLOT_MULTISTIM_PRE_DURING_BOXPLOT  Per-experiment paired pre-stim vs
% during-stim mean of a multi-stim variable (aggression % or dcenter mm),
% with a Wilcoxon matched-pairs signed-rank test annotated per condition
% (ns / * / ** / *** = p>=0.05 / <0.05 / <0.01 / <0.001).
%
% Each pair of bars within a condition shows: bar 1 = mean(pre-stim window)
% per experiment, bar 2 = mean(during-stim window) per experiment, with
% paired connecting lines between matched experiments. Bar height is the
% group mean across experiments; individual experiments are scatter points.
% The pre bar is uniform light grey; the during bar is salmon/pink. The
% condition (empty vs aIPg, etc.) is indicated by dot color.
%
% INPUTS:
%   behavior          'aggression' (uses agg_percbehavior, %) or
%                     'dcenter'     (uses dcenter_meanperframe, mm)
%   condition_list    cell array of condition names, e.g. {'empty','aIPg'}
%   stim_use          (optional) which stim epoch (1..num_stims) to quantify
%                     pre/during for. default = MultiStimCfg.alignment_stim
%                     (typically 1).
%   window_seconds    (optional) controls the pre/during window lengths:
%                       []    or NaN     -> legacy: pre = MultiStimCfg.pre
%                                           frames, during = the actual
%                                           indicator-derived stim duration
%                                           (S.stim_durations) per experiment
%                       scalar (e.g. 15) -> pre AND during set to that many
%                                           seconds (equal-length windows)
%                       [pre_s dur_s]    -> pre = pre_s seconds, during =
%                                           dur_s seconds (independent)
%   condition_colors  (optional) struct mapping condition -> [R G B] used
%                     for dot fill. default: olive-grey for empty, purple
%                     otherwise.
%   SavePath          (optional) directory to save figure
%   SaveFormat        (optional) e.g. '.pdf' / '.png' — both required to save
%
% OUTPUT:
%   stats_out         struct array (one entry per condition) with fields:
%                     condition, n, p_value, signrank_stats, pre_means,
%                     during_means, pre_window_sec, during_window_sec
%   fig_handle        MATLAB figure handle
%
% BASE WORKSPACE REQUIREMENTS:
%   MultiStimData    produced by build_multistim_workspace.m
%   MultiStimCfg     produced by build_multistim_workspace.m

MultiStimData = evalin('base', 'MultiStimData');
MultiStimCfg  = evalin('base', 'MultiStimCfg');

if nargin < 3 || isempty(stim_use);   stim_use   = MultiStimCfg.alignment_stim; end
if nargin < 4;                        window_seconds = []; end
if nargin < 5;                        condition_colors = struct(); end

%% Resolve pre/during window lengths
fps = MultiStimCfg.fps;
if isempty(window_seconds) || (isscalar(window_seconds) && isnan(window_seconds))
    pre_frames           = MultiStimCfg.pre;
    use_indicator_during = true;
    dur_frames_fixed     = NaN; %#ok<NASGU>
elseif isscalar(window_seconds)
    pre_frames           = round(window_seconds * fps);
    dur_frames_fixed     = pre_frames;
    use_indicator_during = false;
elseif numel(window_seconds) == 2
    pre_frames           = round(window_seconds(1) * fps);
    dur_frames_fixed     = round(window_seconds(2) * fps);
    use_indicator_during = false;
else
    error('window_seconds must be empty, NaN, scalar, or [pre_s dur_s].');
end

switch lower(behavior)
    case {'aggression','agg'}
        field      = 'agg_percbehavior';
        ylab       = 'Aggressive behaviors (%)';
        ymax_floor = 30;
    case {'dcenter','distance','interflydistance'}
        field      = 'dcenter_meanperframe';
        ylab       = 'Inter-fly distance (mm)';
        ymax_floor = 15;
    otherwise
        error('behavior must be ''aggression'' or ''dcenter''.');
end

pre  = MultiStimCfg.pre;
% Cropped traces are aligned so frame index pre+1 == alignment_stim onset.
% For a different stim_use we offset using indicatorstarts.
align_stim = MultiStimCfg.alignment_stim;

% Sanity: pre window can't extend before frame 1 of the cropped trace
if pre_frames > pre
    warning(['Requested pre window (%d frames, ~%.1f s) exceeds cropped pre period ', ...
             '(%d frames, ~%.1f s). Truncating to cropped pre.'], ...
             pre_frames, pre_frames/fps, pre, pre/fps);
    pre_frames = pre;
end

%% Per-condition: collect paired (pre, during) means
n_cond     = numel(condition_list);
pre_data   = cell(n_cond, 1);
dur_data   = cell(n_cond, 1);
stats_out  = struct('condition', condition_list(:)', 'n', [], 'p_value', [], ...
                    'signrank_stats', [], 'pre_means', [], 'during_means', []);

for c = 1:n_cond
    cond = condition_list{c};
    inds = find(strcmp({MultiStimData.condition}, cond));
    if isempty(inds)
        warning('No experiments for condition "%s"; skipping.', cond);
        continue
    end

    n_exp     = numel(inds);
    pre_vals  = nan(n_exp, 1);
    dur_vals  = nan(n_exp, 1);

    for ee = 1:n_exp
        S = MultiStimData(inds(ee));
        trace = S.(field);

        % Onset of stim_use within the cropped trace (frame index)
        onset_in_crop = S.indicatorstarts(stim_use) - S.indicatorstarts(align_stim) + pre + 1;

        % Pre window = `pre_frames` frames immediately before onset
        pre_start = onset_in_crop - pre_frames;
        pre_end   = onset_in_crop - 1;

        % During window: either fixed length (window_seconds) or
        % indicator-derived per-experiment stim duration.
        if use_indicator_during
            dur_frames_ee = S.stim_durations;
        else
            dur_frames_ee = dur_frames_fixed;
        end

        dur_start = onset_in_crop;
        dur_end   = onset_in_crop + dur_frames_ee - 1;

        if pre_start < 1 || dur_end > numel(trace)
            warning('Pre/during window out of bounds for %s/%s; skipping experiment.', ...
                    cond, S.expdir);
            continue
        end

        pre_vals(ee) = mean(trace(pre_start:pre_end), 'omitnan');
        dur_vals(ee) = mean(trace(dur_start:dur_end), 'omitnan');
    end

    pre_data{c} = pre_vals;
    dur_data{c} = dur_vals;

    % Wilcoxon matched-pairs signed-rank
    valid = ~isnan(pre_vals) & ~isnan(dur_vals);
    if nnz(valid) >= 1
        [p, ~, sr_stats] = signrank(pre_vals(valid), dur_vals(valid));
    else
        p = NaN; sr_stats = struct();
    end

    stats_out(c).condition         = cond;
    stats_out(c).n                 = nnz(valid);
    stats_out(c).p_value           = p;
    stats_out(c).signrank_stats    = sr_stats;
    stats_out(c).pre_means         = pre_vals;
    stats_out(c).during_means      = dur_vals;
    stats_out(c).pre_window_sec    = pre_frames / fps;
    if use_indicator_during
        stats_out(c).during_window_sec = NaN; % per-exp; see stim_durations
    else
        stats_out(c).during_window_sec = dur_frames_fixed / fps;
    end
end

%% Plot
default_empty  = [0.74 0.78 0.70];
default_purple = [0.50 0.45 0.65];
pre_bar_color  = [0.85 0.85 0.85];   % uniform light grey for the pre bar (per condition convention)
during_color   = [0.96 0.78 0.78];   % salmon / pink, matches the figure
gray_dot       = [0.45 0.45 0.45];

fig_handle = figure('Position', [200 400 360 300]); clf;
ax = axes(fig_handle); hold(ax, 'on');

bar_w   = 0.35;
gap     = 0.15;          % gap between pre and during within a condition
pad     = 0.6;           % padding between conditions
group_w = 2*bar_w + gap; %#ok<NASGU>

xtick_centers = nan(n_cond, 1);

for c = 1:n_cond
    cond  = condition_list{c};
    pre_v = pre_data{c};
    dur_v = dur_data{c};
    if isempty(pre_v); continue; end

    if isfield(condition_colors, cond)
        cond_col = condition_colors.(cond);
    elseif strcmpi(cond, 'empty') || contains(lower(cond), 'empty')
        cond_col = default_empty;
    else
        cond_col = default_purple;
    end

    x_pre = (c-1) * (2*bar_w + gap + pad) + 1;
    x_dur = x_pre + bar_w + gap;
    xtick_centers(c) = (x_pre + x_dur) / 2;

    % Bars (mean of valid pairs). Pre bar = uniform light grey (regardless
    % of condition); during bar = salmon. Condition identity is shown by
    % dot color, not bar color.
    valid = ~isnan(pre_v) & ~isnan(dur_v);
    bar(ax, x_pre, mean(pre_v(valid)), bar_w, ...
        'FaceColor', pre_bar_color, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    bar(ax, x_dur, mean(dur_v(valid)), bar_w, ...
        'FaceColor', during_color, 'EdgeColor', 'none', 'FaceAlpha', 0.7);

    % Paired connecting lines + scatter
    for ee = find(valid(:))'
        plot(ax, [x_pre x_dur], [pre_v(ee) dur_v(ee)], '-', ...
             'Color', [gray_dot 0.6], 'LineWidth', 0.5);
    end
    scatter(ax, repmat(x_pre, nnz(valid), 1), pre_v(valid), 22, ...
            'MarkerFaceColor', cond_col, 'MarkerEdgeColor', 'k', ...
            'LineWidth', 0.4, 'MarkerFaceAlpha', 0.9);
    scatter(ax, repmat(x_dur, nnz(valid), 1), dur_v(valid), 22, ...
            'MarkerFaceColor', cond_col, 'MarkerEdgeColor', 'k', ...
            'LineWidth', 0.4, 'MarkerFaceAlpha', 0.9);
end

% Y limit: 10% headroom above the largest data point
all_vals = [];
for c = 1:n_cond
    all_vals = [all_vals; pre_data{c}; dur_data{c}]; %#ok<AGROW>
end
all_vals = all_vals(~isnan(all_vals));
ymax = max([ymax_floor, max(all_vals) * 1.25]);
ylim(ax, [0 ymax]);

% Significance annotations
for c = 1:n_cond
    if isnan(stats_out(c).p_value); continue; end
    p = stats_out(c).p_value;
    if     p < 0.001; annot = '***';
    elseif p < 0.01;  annot = '**';
    elseif p < 0.05;  annot = '*';
    else;             annot = 'ns';
    end
    x_pre = (c-1) * (2*bar_w + gap + pad) + 1;
    x_dur = x_pre + bar_w + gap;
    y_top = ymax * 0.95;
    plot(ax, [x_pre x_dur], [y_top y_top], 'k-', 'LineWidth', 0.75);
    text(ax, (x_pre + x_dur)/2, y_top * 1.03, annot, ...
         'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
end

ax.XTick      = xtick_centers(~isnan(xtick_centers));
ax.XTickLabel = condition_list(~isnan(xtick_centers));
ax.TickLabelInterpreter = 'none';
xlim(ax, [0.3, max(xtick_centers) + bar_w + 0.7]);
ylabel(ax, ylab, 'FontSize', 11);
xlabel(ax, '> UAS-Chrimson', 'FontSize', 10);
box(ax, 'off');
ax.TickDir = 'out';
ax.FontSize = 10;

if nargin >= 7 && ~isempty(SavePath) && ~isempty(SaveFormat)
    if ~exist(SavePath, 'dir'); mkdir(SavePath); end
    saveas(fig_handle, fullfile(SavePath, ['multistim_pre_during_' field SaveFormat]));
end

end
