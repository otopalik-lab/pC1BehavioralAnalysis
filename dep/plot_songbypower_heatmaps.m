function [fig_heatmap, fig_stats] = plot_songbypower_heatmaps( ...
    line_input, dataset_type, stim_period, varargin)
%PLOT_SONGBYPOWER_HEATMAPS  Heatmap of evoked song across pC1 lines.
%
%   Plots pulse and sine song heatmaps (rows = SS lines, cols = LED power)
%   for isolated-male activation, courting-male activation, or courting-male
%   silencing experiments.
%
%   For ISOLATED males    : pulse/min and sine %time (raw values scaled to a
%                           5-s window and to % time, respectively).
%   For COURTING males    : z-scores relative to the empty-split control (line 1),
%                           computed per trial as (ΔLED − ctrl_mean) / ctrl_std.
%                           Applies to both activation and silencing datasets.
%
%   Statistical significance is reported in a separate grayscale figure
%   (fig_stats); no annotations are overlaid on the heatmap itself.
%
% ── USAGE ─────────────────────────────────────────────────────────────────
%   fh = plot_songbypower_heatmaps('all', 'isolated_activation', 'LED')
%   fh = plot_songbypower_heatmaps([1 3 5], 'courting_activation', 'transient')
%   fh = plot_songbypower_heatmaps('all', 'courting_silencing', 'post', ...
%                                  'clim_pulse', [0 80], 'alpha', 0.01)
%
% ── REQUIRED INPUTS ───────────────────────────────────────────────────────
%   line_input    'all' | char | cell | numeric   Lines to include
%                   'all'              → all lines (workspace variable)
%                   'SS102671'         → single line by name
%                   {'SS102671', …}    → subset by name
%                   [1 3 5 …]          → subset by 1-based index
%   dataset_type  'isolated_activation' | 'courting_activation' | 'courting_silencing'
%   stim_period   'LED' | 'transient' | 'post'
%
% ── OPTIONAL NAME-VALUE INPUTS ────────────────────────────────────────────
%   'clim_pulse'  [lo hi]  Pulse color limits (default [0 100] / [-6 6])
%   'clim_sine'   [lo hi]  Sine  color limits (default [] auto / [-6 6])
%   'alpha'       scalar   Significance threshold (default 0.05)
%   'sig_lo'      int      Min sig. intensities → light gray (default 1)
%   'sig_hi'      int      Min sig. intensities → black      (default 3)
%   'SavePath'    char     Directory to save figures (requires SaveFormat)
%   'SaveFormat'  char     '.pdf', '.png', etc.
%
% ── BASE WORKSPACE REQUIREMENTS ───────────────────────────────────────────
%   data_isolatedmale_activation   isolated-male activation struct
%   data_courtingmale_activation   courting-male  activation struct
%   data_courtingmale_silencing    courting-male  silencing  struct
%   lines       1×N cell array of SS line name strings
%   celltypes   1×N cell array of cell-type name strings
%
% ── STATS ─────────────────────────────────────────────────────────────────
%   Isolated : one-way ANOVA + Dunnett's test per line (each LED intensity
%              vs. PRE baseline, control group = 1).
%   Courting : one-way ANOVA + Dunnett's test per LED intensity across all
%              selected lines, with the empty split as the control group.
%   Significant cells are annotated with a black dot on the heatmap.
%
% ── OUTPUTS ───────────────────────────────────────────────────────────────
%   fig_heatmap   Figure handle – pulse and sine heatmaps
%   fig_stats     Figure handle – grayscale significance heatmaps (pulse | sine)
%                 Light gray = ≥ sig_lo significant intensities.
%                 Black      = ≥ sig_hi significant intensities.

%% ── Parse optional arguments ─────────────────────────────────────────────
ip = inputParser;
ip.addParameter('clim_pulse', [],   @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('clim_sine',  [],   @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('alpha',      0.05, @(x) isnumeric(x) && isscalar(x));
ip.addParameter('sig_lo',     1,    @(x) isnumeric(x) && isscalar(x));
ip.addParameter('sig_hi',     3,    @(x) isnumeric(x) && isscalar(x));
ip.addParameter('SavePath',   '',   @ischar);
ip.addParameter('SaveFormat', '',   @ischar);
ip.parse(varargin{:});
opts = ip.Results;

%% ── Validate required inputs ─────────────────────────────────────────────
dataset_type = lower(dataset_type);
stim_period  = lower(stim_period);
assert(ismember(dataset_type, {'isolated_activation','courting_activation','courting_silencing'}), ...
    'dataset_type must be ''isolated_activation'', ''courting_activation'', or ''courting_silencing''.');
assert(ismember(stim_period, {'led','transient','post'}), ...
    'stim_period must be ''LED'', ''transient'', or ''post''.');

%% ── Load base-workspace variables ────────────────────────────────────────
lines     = evalin('base', 'lines');
celltypes = evalin('base', 'celltypes');
switch dataset_type
    case 'isolated_activation'; data = evalin('base', 'data_isolatedmale_activation');
    case 'courting_activation'; data = evalin('base', 'data_courtingmale_activation');
    case 'courting_silencing';  data = evalin('base', 'data_courtingmale_silencing');
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
% Move SS43275 (pMP2) to row 3 if it is present in the selected lines.
pmp2_pos = find(contains(all_labels(line_idx), 'SS43275'), 1);
if ~isempty(pmp2_pos) && pmp2_pos ~= 3 && length(line_idx) >= 3
    order           = 1:length(line_idx);
    order(pmp2_pos) = [];
    order           = [order(1:2), pmp2_pos, order(3:end)];
    line_idx        = line_idx(order);
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

%% ── Dataset-specific display settings ───────────────────────────────────
switch dataset_type
    case 'isolated_activation'
        [pulse_plot, sine_plot, x_labels] = extract_isolated(data, line_idx, stim_period);
        cmap          = unidirectional;
        clim_p_def    = [0 100];
        clim_s_def    = [0 10];
        label_pulse   = 'Number of Evoked Pulses';
        label_sine    = '% Time Sine Song Evoked';
        disp_name     = 'Isolated (activation)';

    case 'courting_activation'
        [pulse_plot, sine_plot, x_labels] = extract_courting(data, line_idx, stim_period);
        cmap          = bidirectional;
        clim_p_def    = [-6  6];
        clim_s_def    = [-6  6];
        label_pulse   = 'Pulse Z-Score';
        label_sine    = 'Sine Z-Score';
        disp_name     = 'Courting (activation)';

    case 'courting_silencing'
        [pulse_plot, sine_plot, x_labels] = extract_courting(data, line_idx, stim_period);
        cmap          = bidirectional;
        clim_p_def    = [-6  6];
        clim_s_def    = [-6  6];
        label_pulse   = 'Pulse Z-Score';
        label_sine    = 'Sine Z-Score';
        disp_name     = 'Courting (silencing)';
end

clim_p = opts.clim_pulse; if isempty(clim_p), clim_p = clim_p_def; end
clim_s = opts.clim_sine;  if isempty(clim_s), clim_s = clim_s_def; end

%% ── Song heatmap figure ──────────────────────────────────────────────────
fig_h = max(400, 200 + n_lines * 14) + 100;
fig_heatmap = figure('Position', [200 200 520 fig_h]);
tlo = tiledlayout(1, 2, 'TileSpacing', 'compact');
title(tlo, sprintf('%s  |  %s', disp_name, upper(stim_period)), 'FontWeight', 'bold');

% Pulse
nexttile;
hp = heatmap(pulse_plot, 'CellLabelColor', 'none');
hp.GridVisible     = 'off';
hp.YDisplayLabels  = row_labels;
hp.XDisplayLabels  = x_labels;
hp.YLabel          = 'SS Line';
hp.XLabel          = 'LED Power (mW/cm²)';
hp.Colormap        = cmap;
if ~isempty(clim_p), hp.ColorLimits = clim_p; end
hp.ColorbarVisible = 'off';
hp.Title           = label_pulse;

% Sine
nexttile;
hs = heatmap(sine_plot, 'CellLabelColor', 'none');
hs.GridVisible     = 'off';
hs.YDisplayLabels  = repmat({' '}, n_lines, 1);
hs.XDisplayLabels  = x_labels;
hs.XLabel          = 'LED Power (mW/cm²)';
hs.Colormap        = cmap;
if ~isempty(clim_s), hs.ColorLimits = clim_s; end
hs.ColorbarVisible = 'off';
hs.Title           = label_sine;

%% ── Statistics ───────────────────────────────────────────────────────────
% Number of LED powers differs by dataset: isolated_activation and
% courting_activation have 5 powers (6 including 0 mW/cm²); courting_silencing
% has 7 (including 0).  All sizing is derived dynamically from the data struct.
es_row       = find(contains(row_labels, 'Empty'));
stats_byline = compute_stats(data, line_idx, stim_period, dataset_type, opts.alpha, es_row);

%% ── Post-render: y-labels and horizontal colorbars ───────────────────────
ax_p = struct(hp).Axes;
ax_s = struct(hs).Axes;
% Plotting invisible NaN points forces the heatmap axes to convert from
% categorical to numeric rulers, which is required before setting
% YTick/XTick with numeric values.
hold(ax_p, 'on');  scatter(ax_p, NaN, NaN, 1, 'w', 'filled');
hold(ax_s, 'on');  scatter(ax_s, NaN, NaN, 1, 'w', 'filled');
drawnow;

ax_p.YTick                = 1:n_lines;
ax_p.YTickLabel           = row_labels;
ax_p.TickLabelInterpreter = 'none';

ax_s.YTick         = [];
ax_s.YTickLabel    = {};
ax_s.YAxis.Visible = 'off';

n_cols = length(x_labels);
ax_p.XTick                = 1:n_cols;
ax_p.XTickLabel           = x_labels;
ax_p.XTickLabelRotation   = 0;
ax_p.TickLabelInterpreter = 'none';

ax_s.XTick                = 1:n_cols;
ax_s.XTickLabel           = x_labels;
ax_s.XTickLabelRotation   = 0;
ax_s.TickLabelInterpreter = 'none';

% Horizontal colorbars below each panel
n_g          = 256;
clim_p_final = hp.ColorLimits;
clim_s_final = hs.ColorLimits;
pos_p        = ax_p.Position;
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

%% ── Stats figure (grayscale) ─────────────────────────────────────────────
% Build binary significance matrix (0 = ns, 30 = ≥ sig_lo, 100 = ≥ sig_hi)
stats_mat = zeros(n_lines, 2);   % cols: [pulse, sine]
for k = 1:n_lines
    n_sig_p = numel(stats_byline(k).pulse);
    n_sig_s = numel(stats_byline(k).sine);
    if n_sig_p >= opts.sig_lo, stats_mat(k,1) = 30;  end
    if n_sig_p >= opts.sig_hi, stats_mat(k,1) = 100; end
    if n_sig_s >= opts.sig_lo, stats_mat(k,2) = 30;  end
    if n_sig_s >= opts.sig_hi, stats_mat(k,2) = 100; end
end

% SS101146 and SS101156 have no data yet in courting_silencing — zero out
% their stats entries so they appear white in the significance heatmap.
if strcmp(dataset_type, 'courting_silencing')
    no_data_lines = {'SS101146', 'SS101156'};
    for nd = 1:numel(no_data_lines)
        nd_row = find(contains(row_labels, no_data_lines{nd}), 1);
        if ~isempty(nd_row)
            stats_mat(nd_row, :) = 0;
        end
    end
end

fig_stats = figure('Position', [750 200 300 fig_h]);
tls = tiledlayout(1, 2, 'TileSpacing', 'loose');
title(tls, sprintf('Stats  |  %s', upper(stim_period)), 'FontWeight', 'bold');

% Escape underscores so TeX renders them as literal characters, not subscripts.
row_labels_tex = strrep(row_labels, '_', '\_');

stat_xlabels = { ['Pulse-' upper(stim_period)], ['Sine-' upper(stim_period)] };
for col = 1:2
    nexttile;
    ss = heatmap(stats_mat(:,col), 'CellLabelColor', 'none');
    ss.GridVisible     = 'off';
    ss.Colormap        = flipud(gray);
    ss.ColorLimits     = [0 100];
    ss.ColorbarVisible = 'off';
    if col == 1
        ss.YDisplayLabels = row_labels_tex;
        ss.YLabel         = 'SS Line';
    else
        ss.YDisplayLabels = repmat({' '}, n_lines, 1);
    end
    ss.XDisplayLabels = stat_xlabels(col);
    ss.Title          = stat_xlabels{col};
end

%% ── Save (optional) ──────────────────────────────────────────────────────
if ~isempty(opts.SavePath) && ~isempty(opts.SaveFormat)
    if ~exist(opts.SavePath, 'dir'), mkdir(opts.SavePath); end
    tag = [dataset_type '_' stim_period];
    saveas(fig_heatmap, fullfile(opts.SavePath, ['song_heatmap_' tag opts.SaveFormat]));
    saveas(fig_stats,   fullfile(opts.SavePath, ['song_stats_'   tag opts.SaveFormat]));
end

end % main function


%% ════════════════════════════════════════════════════════════════════════
%  LOCAL HELPER FUNCTIONS
%  ════════════════════════════════════════════════════════════════════════

function [pulse_mat, sine_mat, x_labels] = extract_isolated(data, line_idx, period)
%EXTRACT_ISOLATED  Mean pulse/min and sine %time for isolated-male data.
%   Prepends PRE baseline as the first column, then averages across trials.
%   Pulse: raw (pulses/min) → /60*5  → pulses per 5-s window
%   Sine:  raw (sec/min)   → /60*100 → % time in sine song

n_lines = length(line_idx);
n_int   = size(data(line_idx(1)).pulsePerMin.LED, 2);

pulse_mat = zeros(n_lines, 1 + n_int);
sine_mat  = zeros(n_lines, 1 + n_int);

for k = 1:n_lines
    i     = line_idx(k);
    pre_p = data(i).pulsePerMin.PRE(:, 1);
    pre_s = data(i).sinePerMin.PRE(:, 1);
    switch period
        case 'led'
            p_temp = [pre_p, data(i).pulsePerMin.LED];
            s_temp = [pre_s, data(i).sinePerMin.LED];
        case 'transient'
            p_temp = [pre_p, data(i).pulsePerMin.TRANSIENT];
            s_temp = [pre_s, data(i).sinePerMin.TRANSIENT];
        case 'post'
            p_temp = [pre_p, data(i).pulsePerMin.POST];
            s_temp = [pre_s, data(i).sinePerMin.POST];
    end
    pulse_mat(k,:) = nanmean(p_temp) ./ 60 .* 5;
    sine_mat(k,:)  = nanmean(s_temp) ./ 60 .* 100;
end

led_powers = data(line_idx(1)).LEDPowers;
x_labels   = [{'0.0'}, arrayfun(@(x) num2str(x, '%.1f'), led_powers, 'UniformOutput', false)];
end


function [zpulse, zsine, x_labels] = extract_courting(data, line_idx, period)
%EXTRACT_COURTING  Per-trial z-scores relative to the empty-split control.
%   Control is data(1).  Copulation trials are excluded (sinePerMin.PRE > 1
%   sec/min AND pre-LED pulse count > 600).  Lowest LED intensity column is
%   dropped from the output.

fs            = data(1).fs;
LED_ON_bouts  = detect_binarybouts(data(1).LED);
LED_OFF_bouts = [LED_ON_bouts(:,1) - 5*fs - 2500, LED_ON_bouts(:,1) - 2500];

ctrl_dp   = song_delta(data(1), period, 'pulse');
ctrl_ds   = song_delta(data(1), period, 'sine');
ctrl_p_mn = mean(ctrl_dp, 1);   ctrl_p_std = std(ctrl_dp, 0, 1);
ctrl_s_mn = mean(ctrl_ds, 1);   ctrl_s_std = std(ctrl_ds, 0, 1);

n_lines = length(line_idx);
n_int   = size(ctrl_dp, 2);

zpulse = nan(n_lines, n_int - 1);
zsine  = nan(n_lines, n_int - 1);

for k = 1:n_lines
    i        = line_idx(k);
    n_trials = 20;
    zp       = nan(n_trials, n_int);
    zs       = nan(n_trials, n_int);

    for j = 1:n_trials
        pulse_events = data(i).pulse_idx(data(i).pulse_trial_idx == j);
        pe = pulse_events(:);
        pulse_cnt = sum(any(pe > LED_OFF_bouts(:,1)' & pe < LED_OFF_bouts(:,2)', 2));

        if mean(data(i).sinePerMin.PRE(j,:)) > 1 && pulse_cnt > 600
            dp = song_delta_trial(data(i), period, 'pulse', j);
            ds = song_delta_trial(data(i), period, 'sine',  j);
            zp(j,:) = (dp - ctrl_p_mn) ./ ctrl_p_std;
            zs(j,:) = (ds - ctrl_s_mn) ./ ctrl_s_std;
        end
    end

    zpulse(k,:) = nanmean(zp(:, 2:end));
    zsine(k,:)  = nanmean(zs(:, 2:end));
end

led_powers = data(line_idx(1)).LEDPowers;
x_labels   = arrayfun(@(x) num2str(x, '%.1f'), led_powers(2:end), 'UniformOutput', false);
end


function delta = song_delta(d, period, song_type)
%SONG_DELTA  Stim-minus-PRE for all trials of one line (all intensities).
    if strcmp(song_type, 'pulse')
        pre = d.pulsePerMin.PRE;
        switch period
            case 'led';       delta = d.pulsePerMin.LED       - pre;
            case 'transient'; delta = d.pulsePerMin.TRANSIENT  - pre;
            case 'post';      delta = d.pulsePerMin.POST       - pre;
        end
    else
        pre = d.sinePerMin.PRE;
        switch period
            case 'led';       delta = d.sinePerMin.LED       - pre;
            case 'transient'; delta = d.sinePerMin.TRANSIENT  - pre;
            case 'post';      delta = d.sinePerMin.POST       - pre;
        end
    end
end


function delta = song_delta_trial(d, period, song_type, j)
%SONG_DELTA_TRIAL  Stim-minus-PRE for a single trial j.
    if strcmp(song_type, 'pulse')
        pre = d.pulsePerMin.PRE(j,:);
        switch period
            case 'led';       delta = d.pulsePerMin.LED(j,:)       - pre;
            case 'transient'; delta = d.pulsePerMin.TRANSIENT(j,:)  - pre;
            case 'post';      delta = d.pulsePerMin.POST(j,:)       - pre;
        end
    else
        pre = d.sinePerMin.PRE(j,:);
        switch period
            case 'led';       delta = d.sinePerMin.LED(j,:)       - pre;
            case 'transient'; delta = d.sinePerMin.TRANSIENT(j,:)  - pre;
            case 'post';      delta = d.sinePerMin.POST(j,:)       - pre;
        end
    end
end


function stats_byline = compute_stats(data, line_idx, period, dataset_type, alpha, es_idx)
%COMPUTE_STATS  Determine which LED intensities are significantly different
%               from baseline or from the empty-split control.
%
%   Isolated : one-way ANOVA + Dunnett's test per line (each LED intensity
%              vs. PRE, control group = 1).
%   Courting : one-way ANOVA + Dunnett's test per LED intensity across all
%              selected lines, with es_idx as the Dunnett control group.
%              Lowest LED intensity column is skipped to match heatmap columns.

n_lines      = length(line_idx);
stats_byline = repmat(struct('pulse', [], 'sine', []), n_lines, 1);

switch dataset_type

    case 'isolated_activation'
        for k = 1:n_lines
            i     = line_idx(k);
            pre_p = data(i).pulsePerMin.PRE(:, 1);
            pre_s = data(i).sinePerMin.PRE(:, 1);
            switch period
                case 'led'
                    p_temp = [pre_p, data(i).pulsePerMin.LED];
                    s_temp = [pre_s, data(i).sinePerMin.LED];
                case 'transient'
                    p_temp = [pre_p, data(i).pulsePerMin.TRANSIENT];
                    s_temp = [pre_s, data(i).sinePerMin.TRANSIENT];
                case 'post'
                    p_temp = [pre_p, data(i).pulsePerMin.POST];
                    s_temp = [pre_s, data(i).sinePerMin.POST];
            end
            n_trials    = size(p_temp, 1);
            n_int_total = size(p_temp, 2);
            grp_lbl     = repelem((1:n_int_total)', n_trials);

            [~,~,st] = anova1(p_temp(:), grp_lbl, 'off');
            res = multcompare(st, 'CriticalValueType', 'dunnett', ...
                'Approximate', true, 'ControlGroup', 1, ...
                'Alpha', alpha, 'Display', 'off');
            stats_byline(k).pulse = find(res(:,6) < alpha);

            [~,~,st] = anova1(s_temp(:), grp_lbl, 'off');
            res = multcompare(st, 'CriticalValueType', 'dunnett', ...
                'Approximate', true, 'ControlGroup', 1, ...
                'Alpha', alpha, 'Display', 'off');
            stats_byline(k).sine = find(res(:,6) < alpha);
        end

    case {'courting_activation', 'courting_silencing'}
        n_int  = size(song_delta(data(line_idx(1)), period, 'pulse'), 2);
        n_disp = n_int - 1;

        for col = 1:n_disp
            p_vals = [];   s_vals = [];
            p_grps = [];   s_grps = [];

            for k = 1:n_lines
                i  = line_idx(k);
                dp = song_delta(data(i), period, 'pulse');
                ds = song_delta(data(i), period, 'sine');
                p_vals = [p_vals; dp(:, col+1)];              %#ok<AGROW>
                s_vals = [s_vals; ds(:, col+1)];              %#ok<AGROW>
                p_grps = [p_grps; k * ones(size(dp,1), 1)];  %#ok<AGROW>
                s_grps = [s_grps; k * ones(size(ds,1), 1)];  %#ok<AGROW>
            end

            [~,~,st] = anova1(p_vals, p_grps, 'off');
            res = multcompare(st, 'CriticalValueType', 'dunnett', ...
                'Approximate', true, 'ControlGroup', es_idx, ...
                'Alpha', alpha, 'Display', 'off');
            for r = 1:size(res, 1)
                if res(r,6) < alpha
                    k = res(r, 1:2);  k = k(k ~= es_idx);
                    if ~isempty(k), stats_byline(k).pulse(end+1) = col; end %#ok<AGROW>
                end
            end

            [~,~,st] = anova1(s_vals, s_grps, 'off');
            res = multcompare(st, 'CriticalValueType', 'dunnett', ...
                'Approximate', true, 'ControlGroup', es_idx, ...
                'Alpha', alpha, 'Display', 'off');
            for r = 1:size(res, 1)
                if res(r,6) < alpha
                    k = res(r, 1:2);  k = k(k ~= es_idx);
                    if ~isempty(k), stats_byline(k).sine(end+1) = col; end  %#ok<AGROW>
                end
            end
        end

end % switch dataset_type
end % compute_stats
