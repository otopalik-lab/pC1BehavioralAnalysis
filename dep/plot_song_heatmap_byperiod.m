function [fig_heatmap, tbl] = plot_song_heatmap_byperiod( ...
    line_input, dataset_type, varargin)
%PLOT_SONG_HEATMAP_BYPERIOD  Heatmap of evoked song pooled across the top N
%   LED powers, with one column per stimulus period (Transient | LED | Post).
%
%   Rows = SS lines, cols = [Transient | LED | Post] (or a single period).
%   Each cell shows song averaged across ALL trials and the top n_top LED
%   powers (highest intensities).  No copulation-trial filter is applied
%   (cf. plot_songbypower_heatmap_cols, which restricts to copulation trials).
%
%   For ISOLATED males    : pulse/min (per 5-s window) and sine % time
%                           (raw values, not baseline-subtracted).
%                           LED columns: all available intensities; top n_top
%                           (default 2) are pooled.
%
%   For COURTING ACTIVATION : z-scores relative to the empty-split control
%                           (data index 1), computed per trial as
%                           z = (mean_Δ_top − ctrl_mean) / ctrl_std,
%                           where mean_Δ_top = mean across top n_top LED
%                           intensities of (song_stim − song_pre).
%                           LED columns: all available intensities (typically
%                           5 non-zero powers); top n_top are pooled.
%
%   For COURTING SILENCING  : same z-score formula as activation.
%                           LED columns: all available intensities (typically
%                           6 non-zero powers); top n_top are pooled.
%                           NOTE: unlike plot_songbypower_heatmap_cols, the
%                           lowest LED power is NOT dropped before pooling —
%                           because pooling the top n_top already excludes it.
%                           SS101146 and SS101156 have no data for this
%                           condition; their cells are left blank (NaN).
%
% ── USAGE ─────────────────────────────────────────────────────────────────
%   [fh, tbl] = plot_song_heatmap_byperiod('all', 'isolated_activation')
%   [fh, tbl] = plot_song_heatmap_byperiod([1 3 5], 'courting_activation', 'n_top', 2)
%   [fh, tbl] = plot_song_heatmap_byperiod('all', 'courting_silencing', ...
%                                           'period', 'led', 'alpha', 0.01)
%
% ── REQUIRED INPUTS ───────────────────────────────────────────────────────
%   line_input    'all' | char | cell | numeric   Lines to include
%                   'all'              → all lines (workspace variable)
%                   'SS102671'         → single line by name
%                   {'SS102671', …}    → subset by name
%                   [1 3 5 …]          → subset by 1-based index
%   dataset_type  'isolated_activation' | 'courting_activation' | 'courting_silencing'
%
% ── OPTIONAL NAME-VALUE INPUTS ────────────────────────────────────────────
%   'period'      char    Stimulus period to display and tabulate:
%                           'all' (default) | 'transient' | 'led' | 'post'
%   'n_top'       int     Number of highest LED powers to pool (default 2)
%   'clim_pulse'  [lo hi] Pulse color limits (default [0 100] / [-6 6])
%   'clim_sine'   [lo hi] Sine color limits  (default [] auto / [-6 6])
%   'alpha'       scalar  Significance threshold (default 0.05)
%   'SavePath'    char    Directory to save figure (requires SaveFormat)
%   'SaveFormat'  char    '.pdf', '.png', etc.
%
% ── BASE WORKSPACE REQUIREMENTS ───────────────────────────────────────────
%   data_isolatedmale_activation   isolated-male activation struct
%   data_courtingmale_activation   courting-male activation struct
%   data_courtingmale_silencing    courting-male silencing struct
%   lines       1×N cell array of SS line name strings
%   celltypes   1×N cell array of cell-type name strings
%
%
% ── STATS ─────────────────────────────────────────────────────────────────
%   Isolated : one-way ANOVA + Dunnett's test per line across
%              [PRE, Transient, LED, Post] (control group = PRE).
%   Courting : one-way ANOVA + Dunnett's test per stimulus period across all
%              selected lines, with the empty split as the control group.
%   Significant (line, period) cells are annotated with a black dot.
%
% ── OUTPUTS ───────────────────────────────────────────────────────────────
%   fig_heatmap   Figure handle
%   tbl           Table with one row per line: LineName, CellType, and for
%                 each displayed period: Pulse_[Period], Pulse_pval_[Period],
%                 Sine_[Period], Sine_pval_[Period].

%% ── Parse optional arguments ─────────────────────────────────────────────
ip = inputParser;
ip.addParameter('period',     'all', @(x) ischar(x) && ismember(lower(x), {'all','transient','led','post'}));
ip.addParameter('n_top',      2,    @(x) isnumeric(x) && isscalar(x));
ip.addParameter('clim_pulse', [],   @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('clim_sine',  [],   @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('alpha',      0.05, @(x) isnumeric(x) && isscalar(x));
ip.addParameter('SavePath',   '',   @ischar);
ip.addParameter('SaveFormat', '',   @ischar);
ip.parse(varargin{:});
opts        = ip.Results;
opts.period = lower(opts.period);

%% ── Validate required inputs ─────────────────────────────────────────────
dataset_type = lower(dataset_type);
assert(ismember(dataset_type, {'isolated_activation','courting_activation','courting_silencing'}), ...
    'dataset_type must be ''isolated_activation'', ''courting_activation'', or ''courting_silencing''.');

%% ── Load base-workspace variables ────────────────────────────────────────
lines     = evalin('base', 'lines');
celltypes = evalin('base', 'celltypes');
switch dataset_type
    case 'isolated_activation';  data = evalin('base', 'data_isolatedmale_activation');
    case 'courting_activation';  data = evalin('base', 'data_courtingmale_activation');
    case 'courting_silencing';   data = evalin('base', 'data_courtingmale_silencing');
end
n_total = length(lines);

%% ── Build line labels ────────────────────────────────────────────────────
all_labels = cell(n_total, 1);
for i = 1:n_total
    all_labels{i} = [lines{i} ' | ' celltypes{i}];
end

%% ── Resolve line_input ───────────────────────────────────────────────────
if isnumeric(line_input)
    line_idx = line_input(:)';
elseif ischar(line_input) || isstring(line_input)
    if strcmpi(line_input, 'all')
        line_idx = 1:n_total;
    else
        m = find(contains(all_labels, char(line_input)));
        if isempty(m),   error('Line "%s" not found.', line_input);             end
        if numel(m) > 1, warning('Multiple matches for "%s"; using index %d.', ...
                line_input, m(1));                                              end
        line_idx = m(1);
    end
elseif iscell(line_input)
    line_idx = [];
    for s = 1:numel(line_input)
        m = find(contains(all_labels, line_input{s}));
        if isempty(m)
            warning('Line "%s" not found, skipping.', line_input{s});
        else
            line_idx(end+1) = m(1); %#ok<AGROW>
        end
    end
else
    error('line_input must be ''all'', a string, a cell array, or a numeric index vector.');
end
n_lines    = length(line_idx);
row_labels = strrep(all_labels(line_idx), '\', '');

%% ── Colormaps ────────────────────────────────────────────────────────────
n_colors       = 256;
red_map        = flip([ones(n_colors,1), linspace(0,1,n_colors)', linspace(0,1,n_colors)']);
blue_to_white  = [linspace(0,1,n_colors/2)', linspace(0,1,n_colors/2)', ones(n_colors/2,1)];
white_to_red   = flip([ones(n_colors/2,1), linspace(0,1,n_colors/2)', linspace(0,1,n_colors/2)']);
unidirectional = red_map;
bidirectional  = [blue_to_white; white_to_red];

%% ── Extract heatmap data ─────────────────────────────────────────────────
x_labels  = {'Transient', 'LED', 'Post'};
n_periods = 3;

switch dataset_type
    case 'isolated_activation'
        [pulse_plot, sine_plot] = ...
            extract_isolated_pooled(data, line_idx, opts.n_top);
        cmap        = unidirectional;
        clim_p_def  = [0 100];
        clim_s_def  = [];
        label_pulse = 'Number of Evoked Pulses';
        label_sine  = '% Time Sine Song Evoked';

    case {'courting_activation', 'courting_silencing'}
        [pulse_plot, sine_plot] = ...
            extract_courting_pooled(data, line_idx, opts.n_top);
        cmap        = bidirectional;
        clim_p_def  = [-6  6];
        clim_s_def  = [-6  6];
        label_pulse = 'Pulse Z-Score';
        label_sine  = 'Sine Z-Score';
end

% SS101146 and SS101156 have no data in courting_silencing — set their
% heatmap cells to NaN so they appear white (missing data colour).
if strcmp(dataset_type, 'courting_silencing')
    no_data_lines = {'SS101146', 'SS101156'};
    for nd = 1:numel(no_data_lines)
        nd_row = find(contains(row_labels, no_data_lines{nd}), 1);
        if ~isempty(nd_row)
            pulse_plot(nd_row, :) = NaN;
            sine_plot(nd_row, :)  = NaN;
        end
    end
end

%% ── Apply period filter ──────────────────────────────────────────────────
period_map = struct('transient', 1, 'led', 2, 'post', 3);
if ~strcmp(opts.period, 'all')
    pcol       = period_map.(opts.period);
    pulse_plot = pulse_plot(:, pcol);
    sine_plot  = sine_plot(:,  pcol);
    x_labels   = x_labels(pcol);
    n_periods  = 1;
end

clim_p = opts.clim_pulse; if isempty(clim_p), clim_p = clim_p_def; end
clim_s = opts.clim_sine;  if isempty(clim_s), clim_s = clim_s_def; end

%% ── Song heatmap figure ──────────────────────────────────────────────────
switch dataset_type
    case 'isolated_activation';  disp_name = 'Isolated (activation)';
    case 'courting_activation';  disp_name = 'Courting (activation)';
    case 'courting_silencing';   disp_name = 'Courting (silencing)';
end

fig_h = max(400, 200 + n_lines * 14) + 100;   % +100 px for colorbars below
fig_heatmap = figure('Position', [200 200 520 fig_h]);
tlo = tiledlayout(1, 2, 'TileSpacing', 'compact');
title(tlo, sprintf('%s  |  Top %d LED Powers', disp_name, opts.n_top), ...
    'FontWeight', 'bold');

% Pulse
nexttile;
hp = heatmap(pulse_plot, 'CellLabelColor', 'none');
hp.GridVisible     = 'off';
hp.YDisplayLabels  = row_labels;
hp.XDisplayLabels  = x_labels;
hp.YLabel          = 'SS Line';
hp.XLabel          = 'Stimulus Period';
hp.Colormap        = cmap;
if ~isempty(clim_p), hp.ColorLimits = clim_p; end
hp.ColorbarVisible  = 'off';
hp.MissingDataColor = [1 1 1];   % white for lines with no data
hp.Title            = label_pulse;

% Sine
nexttile;
hs = heatmap(sine_plot, 'CellLabelColor', 'none');
hs.GridVisible     = 'off';
hs.YDisplayLabels  = repmat({' '}, n_lines, 1);
hs.XDisplayLabels  = x_labels;
hs.XLabel          = 'Stimulus Period';
hs.Colormap        = cmap;
if ~isempty(clim_s), hs.ColorLimits = clim_s; end
hs.ColorbarVisible  = 'off';
hs.MissingDataColor = [1 1 1];   % white for lines with no data
hs.Title            = label_sine;

%% ── Statistics + heatmap annotation ─────────────────────────────────────
% Empty split is the reference for all comparisons — identify it first so
% it can be passed as the Dunnett control group and skipped in annotation.
es_row = find(contains(row_labels, 'Empty'));

stats_byline = compute_stats_pooled(data, line_idx, opts.n_top, ...
    dataset_type, opts.alpha, es_row);

% SS101146 and SS101156 have no data in courting_silencing — clear their
% stats entries so no significance dots are drawn.
if strcmp(dataset_type, 'courting_silencing')
    no_data_lines = {'SS101146', 'SS101156'};
    for nd = 1:numel(no_data_lines)
        nd_row = find(contains(row_labels, no_data_lines{nd}), 1);
        if ~isempty(nd_row)
            stats_byline(nd_row).pulse = [];
            stats_byline(nd_row).sine  = [];
        end
    end
end

%% ── Build output table ───────────────────────────────────────────────────
% pulse_plot / sine_plot are already filtered to the requested period(s).
% x_labels matches their columns.  tbl_stat_cols maps each display column
% back to the 1-3 index used in stats_byline.pulse_pval / .sine_pval.
if strcmp(opts.period, 'all')
    tbl_stat_cols = 1:3;
else
    tbl_stat_cols = period_map.(opts.period);   % scalar
end

line_names = cellfun(@(s) strtrim(s(1:strfind(s,' | ')-1)), row_labels, 'UniformOutput', false);
cell_names = cellfun(@(s) strtrim(s(strfind(s,' | ')+3:end)), row_labels, 'UniformOutput', false);

tbl = table(line_names(:), cell_names(:), 'VariableNames', {'LineName', 'CellType'});
for pc = 1:numel(tbl_stat_cols)
    sc  = tbl_stat_cols(pc);   % stats_byline index (1=Trans, 2=LED, 3=Post)
    pn  = x_labels{pc};
    pp  = arrayfun(@(k) stats_byline(k).pulse_pval(sc), (1:n_lines)');
    sp  = arrayfun(@(k) stats_byline(k).sine_pval(sc),  (1:n_lines)');
    tbl.(['Pulse_'      pn]) = pulse_plot(:, pc);
    tbl.(['Pulse_pval_' pn]) = pp;
    tbl.(['Sine_'       pn]) = sine_plot(:,  pc);
    tbl.(['Sine_pval_'  pn]) = sp;
end

% For both isolated and courting, stat column indices 1-3 map directly to
% heatmap columns 1-3 [Transient, LED, Post] — no col_offset needed.
annot_color = [0 0 0];   % black
ax_p = struct(hp).Axes;
ax_s = struct(hs).Axes;
hold(ax_p, 'on');
hold(ax_s, 'on');

% When a single period is displayed, remap stat column indices to display
% column 1 and suppress dots for other periods.
if strcmp(opts.period, 'all')
    disp_cols = 1:3;   % stats col → display col (identity)
else
    disp_cols = nan(1, 3);
    disp_cols(period_map.(opts.period)) = 1;
end

for k = 1:n_lines
    if any(k == es_row), continue; end
    sig_p_cols = stats_byline(k).pulse;
    sig_s_cols = stats_byline(k).sine;
    if ~isempty(sig_p_cols)
        dc = disp_cols(sig_p_cols);  dc = dc(~isnan(dc));
        if ~isempty(dc)
            scatter(ax_p, dc, k * ones(size(dc)), 15, 'filled', ...
                    'MarkerFaceColor', annot_color);
        end
    end
    if ~isempty(sig_s_cols)
        dc = disp_cols(sig_s_cols);  dc = dc(~isnan(dc));
        if ~isempty(dc)
            scatter(ax_s, dc, k * ones(size(dc)), 15, 'filled', ...
                    'MarkerFaceColor', annot_color);
        end
    end
end

%% ── Post-render: y-labels, x-labels, and horizontal colorbars ───────────
drawnow;   % finalise tiledlayout so axis positions and color limits are set

% Force y-tick labels always visible on the pulse panel.
ax_p.YTick                = 1:n_lines;
ax_p.YTickLabel           = row_labels;
ax_p.TickLabelInterpreter = 'none';

% Remove Y-axis from the sine panel entirely.
ax_s.YTick         = [];
ax_s.YTickLabel    = {};
ax_s.YAxis.Visible = 'off';

% Force x-tick labels always visible on both panels.
ax_p.XTick                = 1:n_periods;
ax_p.XTickLabel           = x_labels;
ax_p.XTickLabelRotation   = 0;
ax_p.TickLabelInterpreter = 'none';

ax_s.XTick                = 1:n_periods;
ax_s.XTickLabel           = x_labels;
ax_s.XTickLabelRotation   = 0;
ax_s.TickLabelInterpreter = 'none';

% Horizontal colorbars drawn as imagesc axes below each heatmap panel.
n_g          = 256;
clim_p_final = hp.ColorLimits;
clim_s_final = hs.ColorLimits;
pos_p        = ax_p.Position;   % [left bottom width height] normalised
pos_s        = ax_s.Position;
cb_gap       = 0.05;
cb_h         = 0.02;

cb_ax_p = axes(fig_heatmap, 'Position', ...
    [pos_p(1), pos_p(2) - cb_gap - cb_h, pos_p(3), cb_h]);
imagesc(cb_ax_p, linspace(clim_p_final(1), clim_p_final(2), n_g), 1, 1:n_g);
colormap(cb_ax_p, cmap);
cb_ax_p.YTick   = [];
cb_ax_p.XLim    = clim_p_final;
cb_ax_p.TickDir = 'in';
xlabel(cb_ax_p, label_pulse);

cb_ax_s = axes(fig_heatmap, 'Position', ...
    [pos_s(1), pos_s(2) - cb_gap - cb_h, pos_s(3), cb_h]);
imagesc(cb_ax_s, linspace(clim_s_final(1), clim_s_final(2), n_g), 1, 1:n_g);
colormap(cb_ax_s, cmap);
cb_ax_s.YTick   = [];
cb_ax_s.XLim    = clim_s_final;
cb_ax_s.TickDir = 'in';
xlabel(cb_ax_s, label_sine);

%% ── Save (optional) ──────────────────────────────────────────────────────
if ~isempty(opts.SavePath) && ~isempty(opts.SaveFormat)
    if ~exist(opts.SavePath, 'dir'), mkdir(opts.SavePath); end
    tag = [dataset_type '_top' num2str(opts.n_top)];
    saveas(fig_heatmap, fullfile(opts.SavePath, ...
        ['song_heatmap_byperiod_' tag opts.SaveFormat]));
end

end % main function


%% ════════════════════════════════════════════════════════════════════════
%  LOCAL HELPER FUNCTIONS
%  ════════════════════════════════════════════════════════════════════════

function [pulse_mat, sine_mat] = extract_isolated_pooled(data, line_idx, n_top)
%EXTRACT_ISOLATED_POOLED  Mean pulse/min and sine % time pooled across the
%   top n_top LED intensities, for each stimulus period.
%
%   Returns n_lines × 3 matrices, cols = [Transient, LED, Post].
%   Pulse scaling: /60*5  → pulses per 5-s window.
%   Sine  scaling: /60*100 → % time in sine song.

n_lines = length(line_idx);
periods = {'TRANSIENT', 'LED', 'POST'};
n_per   = numel(periods);

n_int    = size(data(line_idx(1)).pulsePerMin.LED, 2);
top_cols = max(1, n_int - n_top + 1) : n_int;   % indices of top n_top intensities

pulse_mat = zeros(n_lines, n_per);
sine_mat  = zeros(n_lines, n_per);

for k = 1:n_lines
    i = line_idx(k);
    for p = 1:n_per
        pd = periods{p};
        % Average across top LED intensities per trial, then across trials
        p_vals = mean(data(i).pulsePerMin.(pd)(:, top_cols), 2);  % n_trials × 1
        s_vals = mean(data(i).sinePerMin.(pd)(:, top_cols),  2);
        pulse_mat(k, p) = nanmean(p_vals) ./ 60 .* 5;     % pulses per 5-s window
        sine_mat(k, p)  = nanmean(s_vals) ./ 60 .* 100;   % % time in sine
    end
end
end


function [zpulse, zsine] = extract_courting_pooled(data, line_idx, n_top)
%EXTRACT_COURTING_POOLED  Per-trial z-scores pooled across the top n_top LED
%   intensities, for each stimulus period.
%
%   Returns n_lines × 3 matrices, cols = [Transient, LED, Post].
%   Z-score formula (per trial, per period):
%       z = ( mean_delta_top(j) − ctrl_mean ) / ctrl_std
%   where mean_delta_top(j) = mean across top n_top intensities of
%   (song_stim(j,:) − song_pre(j,:)).
%   Control = data(1) (empty-split line).

periods = {'TRANSIENT', 'LED', 'POST'};
n_per   = numel(periods);
n_lines = length(line_idx);

n_int    = size(data(line_idx(1)).pulsePerMin.LED, 2);
top_cols = max(1, n_int - n_top + 1) : n_int;

% Control (empty-split = data(1)) pooled-delta statistics per period
ctrl_p_mn  = zeros(1, n_per);
ctrl_p_std = zeros(1, n_per);
ctrl_s_mn  = zeros(1, n_per);
ctrl_s_std = zeros(1, n_per);
for p = 1:n_per
    pd           = periods{p};
    dp           = delta_pooled(data(1), pd, 'pulse', top_cols);
    ds           = delta_pooled(data(1), pd, 'sine',  top_cols);
    ctrl_p_mn(p)  = mean(dp);   ctrl_p_std(p) = std(dp);
    ctrl_s_mn(p)  = mean(ds);   ctrl_s_std(p) = std(ds);
end

zpulse = nan(n_lines, n_per);
zsine  = nan(n_lines, n_per);

for k = 1:n_lines
    i = line_idx(k);
    for p = 1:n_per
        pd = periods{p};
        dp = delta_pooled(data(i), pd, 'pulse', top_cols);
        ds = delta_pooled(data(i), pd, 'sine',  top_cols);
        zpulse(k, p) = nanmean((dp - ctrl_p_mn(p)) ./ ctrl_p_std(p));
        zsine(k, p)  = nanmean((ds - ctrl_s_mn(p)) ./ ctrl_s_std(p));
    end
end
end


function d = delta_pooled(line_data, period, song_type, top_cols)
%DELTA_POOLED  Mean stim-minus-PRE across top_cols LED intensities per trial.
%   Returns n_trials × 1 vector.
    if strcmp(song_type, 'pulse')
        pre  = line_data.pulsePerMin.PRE(:, top_cols);
        stim = line_data.pulsePerMin.(period)(:, top_cols);
    else
        pre  = line_data.sinePerMin.PRE(:, top_cols);
        stim = line_data.sinePerMin.(period)(:, top_cols);
    end
    d = mean(stim - pre, 2);   % n_trials × 1
end


function stats_byline = compute_stats_pooled(data, line_idx, n_top, ...
    dataset_type, alpha, es_idx)
%COMPUTE_STATS_POOLED  Significance tests for the by-period pooled heatmap.
%
%   Isolated : one-way ANOVA + Dunnett per line across
%              [PRE, Transient, LED, Post] (control group = 1 = PRE).
%              Returned column indices 1-3 map to [Transient, LED, Post].
%   Courting : one-way ANOVA + Dunnett per period across all selected lines,
%              empty split (es_idx) as the control group.

n_lines      = length(line_idx);
stats_byline = repmat(struct('pulse', [], 'pulse_pval', nan(1,3), ...
                              'sine',  [], 'sine_pval',  nan(1,3)), n_lines, 1);
periods      = {'TRANSIENT', 'LED', 'POST'};
n_per        = numel(periods);

n_int    = size(data(line_idx(1)).pulsePerMin.LED, 2);
top_cols = max(1, n_int - n_top + 1) : n_int;

switch dataset_type

    case 'isolated_activation'
        for k = 1:n_lines
            i = line_idx(k);
            % PRE baseline: mean across top intensities per trial
            pre_p    = mean(data(i).pulsePerMin.PRE(:, top_cols), 2);
            pre_s    = mean(data(i).sinePerMin.PRE(:, top_cols),  2);
            n_trials = size(pre_p, 1);

            p_all = pre_p;
            s_all = pre_s;
            grp   = ones(n_trials, 1);   % group 1 = PRE

            for p = 1:n_per
                pd    = periods{p};
                p_all = [p_all; mean(data(i).pulsePerMin.(pd)(:, top_cols), 2)]; %#ok<AGROW>
                s_all = [s_all; mean(data(i).sinePerMin.(pd)(:, top_cols),  2)]; %#ok<AGROW>
                grp   = [grp;   (p + 1) * ones(n_trials, 1)];                    %#ok<AGROW>
            end

            % Dunnett vs PRE (group 1); rows of res = [Transient, LED, Post]
            [~,~,st] = anova1(p_all, grp, 'off');
            res = multcompare(st, 'CriticalValueType', 'dunnett', ...
                'Approximate', true, 'ControlGroup', 1, ...
                'Alpha', alpha, 'Display', 'off');
            stats_byline(k).pulse      = find(res(:,6) < alpha);   % 1=Trans,2=LED,3=Post
            stats_byline(k).pulse_pval = res(:,6)';

            [~,~,st] = anova1(s_all, grp, 'off');
            res = multcompare(st, 'CriticalValueType', 'dunnett', ...
                'Approximate', true, 'ControlGroup', 1, ...
                'Alpha', alpha, 'Display', 'off');
            stats_byline(k).sine      = find(res(:,6) < alpha);
            stats_byline(k).sine_pval = res(:,6)';
        end

    case {'courting_activation', 'courting_silencing'}
        % One-way ANOVA per period across all selected lines, Dunnett vs
        % empty split (es_idx).
        for col = 1:n_per
            pd     = periods{col};
            p_vals = [];  s_vals = [];
            p_grps = [];  s_grps = [];

            for k = 1:n_lines
                i  = line_idx(k);
                dp = delta_pooled(data(i), pd, 'pulse', top_cols);
                ds = delta_pooled(data(i), pd, 'sine',  top_cols);
                p_vals = [p_vals; dp];                        %#ok<AGROW>
                s_vals = [s_vals; ds];                        %#ok<AGROW>
                p_grps = [p_grps; k * ones(size(dp))];        %#ok<AGROW>
                s_grps = [s_grps; k * ones(size(ds))];        %#ok<AGROW>
            end

            [~,~,st] = anova1(p_vals, p_grps, 'off');
            res = multcompare(st, 'CriticalValueType', 'dunnett', ...
                'Approximate', true, 'ControlGroup', es_idx, ...
                'Alpha', alpha, 'Display', 'off');
            for r = 1:size(res, 1)
                k = res(r, 1:2);  k = k(k ~= es_idx);
                if ~isempty(k)
                    stats_byline(k).pulse_pval(col) = res(r,6);       %#ok<AGROW>
                    if res(r,6) < alpha
                        stats_byline(k).pulse(end+1) = col;            %#ok<AGROW>
                    end
                end
            end

            [~,~,st] = anova1(s_vals, s_grps, 'off');
            res = multcompare(st, 'CriticalValueType', 'dunnett', ...
                'Approximate', true, 'ControlGroup', es_idx, ...
                'Alpha', alpha, 'Display', 'off');
            for r = 1:size(res, 1)
                k = res(r, 1:2);  k = k(k ~= es_idx);
                if ~isempty(k)
                    stats_byline(k).sine_pval(col) = res(r,6);        %#ok<AGROW>
                    if res(r,6) < alpha
                        stats_byline(k).sine(end+1) = col;             %#ok<AGROW>
                    end
                end
            end
        end

end % switch dataset_type
end % compute_stats_pooled
