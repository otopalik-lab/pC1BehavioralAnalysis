function [fig_heatmap, fig_stats] = plot_pC1_song_heatmap( ...
    line_input, dataset_type, stim_period, varargin)
%PLOT_PC1_SONG_HEATMAP  Heatmap of evoked song across pC1 activation lines.
%
%   Plots pulse and sine song as heatmaps (rows = SS lines, cols = LED power)
%   with an accompanying significance heatmap, for either isolated or courting
%   male activation experiments.
%
%   For ISOLATED males : pulse/min and sine %time (raw values scaled to a
%                        5-s window and to % time, respectively).
%   For COURTING males : z-scores relative to the empty-split control (line 1),
%                        computed per trial as (ΔLED − ctrl_mean) / ctrl_std.
%
% ── USAGE ─────────────────────────────────────────────────────────────────
%   [fh, fs] = plot_pC1_song_heatmap('all', 'isolated', 'LED')
%   [fh, fs] = plot_pC1_song_heatmap([1 3 5], 'courting', 'transient')
%   [fh, fs] = plot_pC1_song_heatmap('all', 'isolated', 'post', ...
%                                    'clim_pulse', [0 80], 'alpha', 0.01)
%
% ── REQUIRED INPUTS ───────────────────────────────────────────────────────
%   line_input    'all' | char | cell | numeric   Lines to include
%                   'all'              → all lines (workspace variable)
%                   'SS102671'         → single line by name
%                   {'SS102671', …}    → subset by name
%                   [1 3 5 …]          → subset by 1-based index
%   dataset_type  'isolated' | 'courting'
%   stim_period   'LED' | 'transient' | 'post'
%
% ── OPTIONAL NAME-VALUE INPUTS ────────────────────────────────────────────
%   'clim_pulse'  [lo hi]  Pulse color limits (default [0 100] / [-6 6])
%   'clim_sine'   [lo hi]  Sine color limits  (default [] auto / [-6 6])
%   'alpha'       scalar   Significance threshold (default 0.05)
%   'sig_lo'      int      Min sig. intensities → light gray (default 1)
%   'sig_hi'      int      Min sig. intensities → black      (default 3)
%   'SavePath'    char     Directory to save figures (requires SaveFormat)
%   'SaveFormat'  char     '.pdf', '.png', etc.
%
% ── BASE WORKSPACE REQUIREMENTS ───────────────────────────────────────────
%   data_activation      isolated-male activation struct (1×35)
%   data_MFP_activation  courting-male  activation struct (1×35)
%   lines                1×35 cell array of SS line name strings
%   celltypes            1×35 cell array of cell-type name strings
%
% ── STATS ─────────────────────────────────────────────────────────────────
%   Isolated : one-way ANOVA + Dunnett's test (each LED intensity vs. PRE
%              baseline, Dunnett's control group = 1).
%   Courting : one-sample t-test on per-trial z-scores against 0.
%   Light-gray cell = ≥ sig_lo significant intensities.
%   Black cell      = ≥ sig_hi significant intensities.
%
% ── OUTPUTS ───────────────────────────────────────────────────────────────
%   fig_heatmap   Figure handle – pulse and sine heatmaps side-by-side
%   fig_stats     Figure handle – significance heatmaps (pulse | sine)

%% ── Parse optional arguments ─────────────────────────────────────────────
ip = inputParser;
ip.addParameter('clim_pulse',  [],   @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('clim_sine',   [],   @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('alpha',       0.05, @(x) isnumeric(x) && isscalar(x));
ip.addParameter('sig_lo',      1,    @(x) isnumeric(x) && isscalar(x));
ip.addParameter('sig_hi',      3,    @(x) isnumeric(x) && isscalar(x));
ip.addParameter('SavePath',    '',   @ischar);
ip.addParameter('SaveFormat',  '',   @ischar);
ip.parse(varargin{:});
opts = ip.Results;

%% ── Validate required inputs ─────────────────────────────────────────────
dataset_type = lower(dataset_type);
stim_period  = lower(stim_period);
assert(ismember(dataset_type, {'isolated','courting'}), ...
    'dataset_type must be ''isolated'' or ''courting''.');
assert(ismember(stim_period, {'led','transient','post'}), ...
    'stim_period must be ''LED'', ''transient'', or ''post''.');

%% ── Load base-workspace variables ────────────────────────────────────────
lines     = evalin('base', 'lines');
celltypes = evalin('base', 'celltypes');
switch dataset_type
    case 'isolated';  data = evalin('base', 'data_isolatedmale_activation');
    case 'courting';  data = evalin('base', 'data_courtingmale_activation');
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
row_labels = all_labels(line_idx);

%% ── Colormaps ────────────────────────────────────────────────────────────
n_colors       = 256;
red_map        = flip([ones(n_colors,1), linspace(0,1,n_colors)', linspace(0,1,n_colors)']);
blue_to_white  = [linspace(0,1,n_colors/2)', linspace(0,1,n_colors/2)', ones(n_colors/2,1)];
white_to_red   = flip([ones(n_colors/2,1), linspace(0,1,n_colors/2)', linspace(0,1,n_colors/2)']);
unidirectional = red_map;
bidirectional  = [blue_to_white; white_to_red];

%% ── Extract heatmap data ─────────────────────────────────────────────────
switch dataset_type
    case 'isolated'
        [pulse_plot, sine_plot, x_labels] = ...
            extract_isolated(data, line_idx, stim_period);
        cmap          = unidirectional;
        clim_p_def    = [0 100];
        clim_s_def    = [];           % auto-scale
        label_pulse   = 'Pulse/min (per 5-s window)';
        label_sine    = 'Sine % time';

    case 'courting'
        [pulse_plot, sine_plot, x_labels] = ...
            extract_courting(data, line_idx, stim_period);
        cmap          = bidirectional;
        clim_p_def    = [-6  6];
        clim_s_def    = [-6  6];
        label_pulse   = 'Pulse z-score';
        label_sine    = 'Sine z-score';
end

clim_p = opts.clim_pulse; if isempty(clim_p), clim_p = clim_p_def; end
clim_s = opts.clim_sine;  if isempty(clim_s), clim_s = clim_s_def; end

%% ── Song heatmap figure ──────────────────────────────────────────────────
fig_h = max(400, 200 + n_lines * 14);
fig_heatmap = figure('Position', [200 200 520 fig_h]);
tlo = tiledlayout(1, 2, 'TileSpacing', 'loose');
title(tlo, sprintf('%s  |  %s', ...
    [upper(dataset_type(1)) dataset_type(2:end)], upper(stim_period)), ...
    'FontWeight', 'bold');

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
stats_byline = compute_stats(data, line_idx, stim_period, dataset_type, opts.alpha);

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

%% ── Stats figure ─────────────────────────────────────────────────────────
fig_stats = figure('Position', [750 200 240 fig_h]);
tls = tiledlayout(1, 2, 'TileSpacing', 'loose');
title(tls, sprintf('Stats  |  %s', upper(stim_period)), 'FontWeight', 'bold');

stat_xlabels = { ['Pulse-' upper(stim_period)], ['Sine-' upper(stim_period)] };
for col = 1:2
    nexttile;
    ss = heatmap(stats_mat(:,col), 'CellLabelColor', 'none');
    ss.GridVisible     = 'off';
    ss.Colormap        = flipud(gray);
    ss.ColorLimits     = [0 100];
    ss.ColorbarVisible = 'off';
    if col == 1
        ss.YDisplayLabels = row_labels;
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
%
%   For each selected line, prepends the PRE baseline as the first column,
%   then averages across trials.
%
%   Pulse scaling : raw (pulses/min) → /60*5  → pulses per 5-s window
%   Sine  scaling : raw (sec/min)   → /60*100 → % time in sine song

n_lines = length(line_idx);
n_int   = size(data(line_idx(1)).pulsePerMin.LED, 2);   % number of LED intensities

pulse_mat = zeros(n_lines, 1 + n_int);
sine_mat  = zeros(n_lines, 1 + n_int);

for k = 1:n_lines
    i     = line_idx(k);
    pre_p = data(i).pulsePerMin.PRE(:, 1);   % n_trials × 1, first PRE epoch
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
    pulse_mat(k,:) = nanmean(p_temp) ./ 60 .* 5;     % pulses per 5-s window
    sine_mat(k,:)  = nanmean(s_temp) ./ 60 .* 100;   % % time in sine
end

led_powers = data(line_idx(1)).LEDPowers;
x_labels   = [{'0'}, arrayfun(@num2str, led_powers, 'UniformOutput', false)];
end


function [zpulse, zsine, x_labels] = extract_courting(data, line_idx, period)
%EXTRACT_COURTING  Per-trial z-scores relative to the empty-split control.
%
%   Control is data(1) (the empty-split line).  Copulation trials are excluded
%   (criterion: mean sinePerMin.PRE > 1 sec/min AND pulse count during
%   pre-LED off windows > 600).
%
%   Z-score formula (per trial j, per intensity p):
%       z = ( (song_stim(j,p) - song_pre(j,p)) - ctrl_mean(p) ) / ctrl_std(p)
%
%   Convention (matching original script): the lowest LED intensity column
%   is dropped from the output; x_labels = LEDPowers(2:end).

fs           = data(1).fs;
LED_ON_bouts = detect_binarybouts(data(1).LED);
% LED-off baseline windows: 5 s before each LED-on onset (with 2500-sample buffer)
LED_OFF_bouts = [LED_ON_bouts(:,1) - 5*fs - 2500, LED_ON_bouts(:,1) - 2500];

% Control (empty-split) Δ-song statistics per LED intensity
ctrl_dp  = song_delta(data(1), period, 'pulse');  % n_trials_ctrl × n_int
ctrl_ds  = song_delta(data(1), period, 'sine');
ctrl_p_mn  = mean(ctrl_dp, 1);   ctrl_p_std = std(ctrl_dp, 0, 1);
ctrl_s_mn  = mean(ctrl_ds, 1);   ctrl_s_std = std(ctrl_ds, 0, 1);

n_lines = length(line_idx);
n_int   = size(ctrl_dp, 2);

zpulse = nan(n_lines, n_int - 1);   % drop lowest-intensity column
zsine  = nan(n_lines, n_int - 1);

for k = 1:n_lines
    i        = line_idx(k);
    n_trials = 20;             % standard trial count per line for courting data
    zp       = nan(n_trials, n_int);
    zs       = nan(n_trials, n_int);

    for j = 1:n_trials
        % Copulation filter
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

    zpulse(k,:) = nanmean(zp(:, 2:end));   % skip lowest-intensity column
    zsine(k,:)  = nanmean(zs(:, 2:end));
end

led_powers = data(line_idx(1)).LEDPowers;
x_labels   = arrayfun(@num2str, led_powers(2:end), 'UniformOutput', false);
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


function stats_byline = compute_stats(data, line_idx, period, dataset_type, alpha)
%COMPUTE_STATS  Test which LED intensities evoke significantly more song than
%               baseline.
%
%   Isolated : one-way ANOVA + Dunnett's test (each LED intensity vs. PRE,
%              group 1 = PRE). Returns indices of significant intensities.
%   Courting : one-sample t-test on per-trial z-scores vs 0 for each LED
%              intensity (skipping the lowest, matching extract_courting).

n_lines      = length(line_idx);
stats_byline = repmat(struct('pulse', [], 'sine', []), n_lines, 1);

switch dataset_type

    case 'isolated'
        for k = 1:n_lines
            i     = line_idx(k);
            pre_p = data(i).pulsePerMin.PRE(:, 1);   % n_trials × 1
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
            % Column-major flattening: group labels index which intensity column
            n_trials    = size(p_temp, 1);
            n_int_total = size(p_temp, 2);
            grp_lbl     = repelem((1:n_int_total)', n_trials);

            [~,~,st] = anova1(p_temp(:), grp_lbl, 'off');
            res = multcompare(st, 'CriticalValueType','dunnett', ...
                'Approximate', true, 'ControlGroup', 1, ...
                'Alpha', alpha, 'Display', 'off');
            stats_byline(k).pulse = find(res(:,6) < alpha);

            [~,~,st] = anova1(s_temp(:), grp_lbl, 'off');
            res = multcompare(st, 'CriticalValueType','dunnett', ...
                'Approximate', true, 'ControlGroup', 1, ...
                'Alpha', alpha, 'Display', 'off');
            stats_byline(k).sine = find(res(:,6) < alpha);
        end

    case 'courting'
        % Re-derive z-scores (same copulation filter as extract_courting)
        fs           = data(1).fs;
        LED_ON_bouts = detect_binarybouts(data(1).LED);
        LED_OFF_bouts = [LED_ON_bouts(:,1) - 5*fs - 2500, LED_ON_bouts(:,1) - 2500];

        ctrl_dp  = song_delta(data(1), period, 'pulse');
        ctrl_ds  = song_delta(data(1), period, 'sine');
        ctrl_p_mn = mean(ctrl_dp, 1);  ctrl_p_std = std(ctrl_dp, 0, 1);
        ctrl_s_mn = mean(ctrl_ds, 1);  ctrl_s_std = std(ctrl_ds, 0, 1);
        n_int = size(ctrl_dp, 2);

        for k = 1:n_lines
            i    = line_idx(k);
            zp   = nan(20, n_int);
            zs   = nan(20, n_int);

            for j = 1:20
                pulse_events = data(i).pulse_idx(data(i).pulse_trial_idx == j);
                pulse_cnt = sum(arrayfun( ...
                    @(r) sum(pulse_events > LED_OFF_bouts(r,1) & pulse_events < LED_OFF_bouts(r,2)), ...
                    1:size(LED_OFF_bouts,1)));

                if mean(data(i).sinePerMin.PRE(j,:)) > 1 && pulse_cnt > 600
                    dp = song_delta_trial(data(i), period, 'pulse', j);
                    ds = song_delta_trial(data(i), period, 'sine',  j);
                    zp(j,:) = (dp - ctrl_p_mn) ./ ctrl_p_std;
                    zs(j,:) = (ds - ctrl_s_mn) ./ ctrl_s_std;
                end
            end

            % One-sample t-test vs 0 for each displayed intensity (skip lowest column).
            % Implemented inline to avoid conflicts between MATLAB's ttest
            % (which calls nanstd(x,[],dim)) and nansuite's nanstd on the path.
            n_disp = n_int - 1;
            sig_p  = [];
            sig_s  = [];
            for col = 1:n_disp
                zp_col = zp(~isnan(zp(:, col+1)), col+1);
                zs_col = zs(~isnan(zs(:, col+1)), col+1);
                if numel(zp_col) > 2
                    pv = onesample_ttest(zp_col);
                    if pv < alpha, sig_p(end+1) = col; end %#ok<AGROW>
                end
                if numel(zs_col) > 2
                    pv = onesample_ttest(zs_col);
                    if pv < alpha, sig_s(end+1) = col; end %#ok<AGROW>
                end
            end
            stats_byline(k).pulse = sig_p;
            stats_byline(k).sine  = sig_s;
        end

end % switch dataset_type
end % compute_stats


function pv = onesample_ttest(x)
%ONESAMPLE_TTEST  Two-tailed one-sample t-test of x against 0.
%   Avoids calling MATLAB's ttest(), which internally uses nanstd(x,[],dim)
%   and conflicts with nansuite's nanstd on the MATLAB path.
%   Requires Statistics and Machine Learning Toolbox for tcdf.
x  = x(:);
n  = numel(x);
t  = mean(x) / (std(x) / sqrt(n));
pv = 2 * (1 - tcdf(abs(t), n - 1));
end
