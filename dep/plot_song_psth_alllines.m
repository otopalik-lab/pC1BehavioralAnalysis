function figs = plot_song_psth_alllines(line_input, dataset_type, varargin)
%PLOT_SONG_PSTH_ALLLINES  LED-aligned joint PSTHs for all specified SS lines.
%
%   Lines are distributed across figures with up to max_per_fig lines each (default 6).
%   Each figure has:
%     1. LED stimulus trace (reference epoch, top)
%     2…M+1. Joint pulse/sine PSTH for each line in that figure
%              (pulse: red filled area, left y-axis;
%               sine:  blue filled area, right y-axis)
%
%   PSTH computation follows plot_song_raster_psth exactly: events are
%   pooled across all specified LED bouts (plotbouts) and all trials,
%   then binned at 100-ms resolution and normalised to events/s.
%
% ── USAGE ─────────────────────────────────────────────────────────────────
%   figs = plot_song_psth_alllines('all', 'isolated_activation')
%   figs = plot_song_psth_alllines([1 3 5], 'courting_activation')
%   figs = plot_song_psth_alllines('all', 'courting_silencing', ...
%              'max_per_fig', 4, 'ylim_pulse', [0 20], ...
%              'SavePath', '/save/dir', 'SaveFormat', '.pdf')
%
% ── REQUIRED INPUTS ───────────────────────────────────────────────────────
%   line_input    'all' | char | cell | numeric   Lines to include
%                   'all'              → all lines (workspace variable)
%                   'SS102671'         → single line by name
%                   {'SS102671', …}    → subset by name
%                   [1 3 5 …]          → subset by 1-based index
%   dataset_type  'isolated_activation' | 'courting_activation' |
%                 'courting_silencing'
%
% ── OPTIONAL NAME-VALUE INPUTS ────────────────────────────────────────────
%   All defaults are set per dataset_type to match plot_song_raster_psth.
%
%   'max_per_fig'     int       Maximum lines per figure; new figure starts when full (default 6)
%   'plotbouts'       int vec   LED bout indices to pool across
%   'select_trials'   int vec   Trial indices to include ([] = all)
%   'led_ref_bout'    int       Bout index for the LED trace panel
%   'psth_xlim'       [lo hi]   X-axis range (s) for all panels
%   'ylim_pulse'      [lo hi]   Pulse left y-axis limits
%   'ylim_sine'       [lo hi]   Sine right y-axis limits
%   'SavePath'        char      Directory to save figures (requires SaveFormat)
%   'SaveFormat'      char      File format, e.g. '.pdf', '.png', '.svg'
%
% ── DATASET DEFAULTS ──────────────────────────────────────────────────────
%
%   Parameter           isolated_activation  courting_activation  courting_silencing
%   ─────────────────   ───────────────────  ───────────────────  ──────────────────
%   plotbouts           96:100               42:46                41:45
%   select_trials       [] (all)             [] (all)             [] (all)
%   led_ref_bout        99                   18                   18
%   psth_xlim           [-5 10]              [-5 10]              [-5 10]
%   ylim_pulse          [0 30]               [0 15]               [0 15]
%   ylim_sine           [0 1500]             [0 2000]             [0 2000]
%
% ── ALIGNMENT NOTES ───────────────────────────────────────────────────────
%   All datasets: LED onset is displayed at 0 s (x-axis = time from stimulus onset).
%
% ── BASE WORKSPACE REQUIREMENTS ───────────────────────────────────────────
%   data_isolatedmale_activation | data_courtingmale_activation |
%   data_courtingmale_silencing
%   lines       1×N cell array of SS line name strings
%   celltypes   1×N cell array of cell-type name strings
%
% ── OUTPUT ────────────────────────────────────────────────────────────────
%   figs   1×n_figs array of figure handles

%% ── Dataset-type defaults ────────────────────────────────────────────────
dataset_type = lower(dataset_type);
switch dataset_type

    case 'isolated_activation'
        data_var          = 'data_isolatedmale_activation';
        pre_samples       = 50000;
        def_plotbouts     = 96:100;
        def_select_trials = [];
        def_led_ref       = 99;
        def_psth_xlim     = [-5 10];
        def_ylim_pulse    = [0 15];
        def_ylim_sine     = [0 2000];

    case 'courting_activation'
        data_var          = 'data_courtingmale_activation';
        pre_samples       = 25000;
        def_plotbouts     = 42:46;
        def_select_trials = [];
        def_led_ref       = 18;
        def_psth_xlim     = [-5 10];
        def_ylim_pulse    = [0 15];
        def_ylim_sine     = [0 2000];

    case 'courting_silencing'
        data_var          = 'data_courtingmale_silencing';
        pre_samples       = 25000;
        def_plotbouts     = 41:45;
        def_select_trials = [];
        def_led_ref       = 18;
        def_psth_xlim     = [-5 10];
        def_ylim_pulse    = [0 15];
        def_ylim_sine     = [0 2000];

    otherwise
        error(['dataset_type must be ''isolated_activation'', ' ...
               '''courting_activation'', or ''courting_silencing''.']);
end

%% ── Parse optional arguments ─────────────────────────────────────────────
ip = inputParser;
ip.addParameter('max_per_fig',   6,                 @(x) isnumeric(x) && isscalar(x));
ip.addParameter('plotbouts',     def_plotbouts,     @isnumeric);
ip.addParameter('select_trials', def_select_trials, @isnumeric);
ip.addParameter('led_ref_bout',  def_led_ref,       @(x) isnumeric(x) && isscalar(x));
ip.addParameter('psth_xlim',     def_psth_xlim,     @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('ylim_pulse',    def_ylim_pulse,    @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('ylim_sine',     def_ylim_sine,     @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('SavePath',      '',                @ischar);
ip.addParameter('SaveFormat',    '',                @ischar);
ip.parse(varargin{:});
opts = ip.Results;

fs = 5000;   % sampling rate (Hz), fixed across all datasets
led_onset_sec = pre_samples / fs;   % time (s) from window start to LED onset

%% ── Load base-workspace variables ────────────────────────────────────────
lines     = evalin('base', 'lines');
celltypes = evalin('base', 'celltypes');
data      = evalin('base', data_var);
n_total   = length(lines);

%% ── Build line labels ────────────────────────────────────────────────────
all_labels = cell(n_total, 1);
for ii = 1:n_total
    all_labels{ii} = [lines{ii} ' | ' celltypes{ii}];
end

%% ── Resolve line_input ───────────────────────────────────────────────────
if isnumeric(line_input)
    line_idx = line_input(:)';
elseif ischar(line_input) || isstring(line_input)
    if strcmpi(line_input, 'all')
        line_idx = 1:n_total;
    else
        m = find(contains(all_labels, char(line_input)));
        if isempty(m),   error('Line "%s" not found.', line_input);            end
        if numel(m) > 1, warning('Multiple matches for "%s"; using index %d.', ...
                line_input, m(1));                                             end
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

%% ── Detect LED bouts ─────────────────────────────────────────────────────
LED       = data(1).LED;
LED_bouts = detect_binarybouts(LED);   % N×2 matrix: [onset, offset] in samples

%% ── Pre-compute PSTH parameters ──────────────────────────────────────────
trial_len = length(LED_bouts(opts.plotbouts(end),1) - pre_samples : ...
                   LED_bouts(opts.plotbouts(end),2) + pre_samples);
binsize   = 100;   % ms
lastbin   = binsize * ceil((trial_len - 1) * 1000 / (fs * binsize));
edges     = 0 : binsize : lastbin;

% LED reference trace — identical for every figure
LED_vector = LED(LED_bouts(opts.led_ref_bout,1) - pre_samples : ...
                 LED_bouts(opts.led_ref_bout,2) + pre_samples);

%% ── Split lines across figures ───────────────────────────────────────────
lines_per_fig = opts.max_per_fig;
n_figs        = ceil(n_lines / lines_per_fig);

switch dataset_type
    case 'isolated_activation';  disp_name = 'Isolated (activation)';
    case 'courting_activation';  disp_name = 'Courting (activation)';
    case 'courting_silencing';   disp_name = 'Courting (silencing)';
end

figs = gobjects(1, n_figs);

%% ── Build one figure per group ───────────────────────────────────────────
for f = 1:n_figs

    % Subset of global line_idx for this figure
    grp_start = (f - 1) * lines_per_fig + 1;
    grp_end   = min(f * lines_per_fig, n_lines);
    grp       = grp_start : grp_end;
    n_grp     = length(grp);

    fig_h   = max(400, 60 + (lines_per_fig + 1) * 80);
    figs(f) = figure('Position', [100 + (f-1)*30, 100 + (f-1)*30, 300, fig_h]);
    tlo     = tiledlayout(lines_per_fig + 1, 1, 'TileSpacing', 'tight', 'Padding', 'compact');
    title(tlo, sprintf('%s  (%d / %d)', disp_name, f, n_figs), 'FontWeight', 'bold');

    % LED trace panel
    nexttile;
    plot(((1:length(LED_vector)) - 1 - pre_samples) ./ fs, LED_vector * 100, 'k-', 'LineWidth', 2);
    xlim(opts.psth_xlim);
    axis off;

    % One PSTH panel per line in this group
    for kk = grp
        li = line_idx(kk);

        if isempty(opts.select_trials)
            trial_list = 1:length(data(li).trial_idx);
        else
            trial_list = opts.select_trials;
        end

        % Pool events across all plotbouts × all trials
        all_pulse_times = [];
        all_sine_times  = [];
        trial_count     = 0;

        for k = 1:length(opts.plotbouts)
            bout_onset = LED_bouts(opts.plotbouts(k), 1);
            bout_end   = LED_bouts(opts.plotbouts(k), 2);
            for j = trial_list
                ev = data(li).pulse_idx(data(li).pulse_trial_idx == j);
                ev = ev(ev > bout_onset - pre_samples & ev < bout_end + pre_samples);
                all_pulse_times = [all_pulse_times; ev(:) - bout_onset + pre_samples]; %#ok<AGROW>

                ev = data(li).sine_idx(data(li).sine_trial_idx == j);
                ev = ev(ev > bout_onset - pre_samples & ev < bout_end + pre_samples);
                all_sine_times = [all_sine_times; ev(:) - bout_onset + pre_samples];   %#ok<AGROW>

                trial_count = trial_count + 1;
            end
        end

        PulseRate = psth(all_pulse_times, binsize, fs, trial_count, trial_len);
        SineRate  = psth(all_sine_times,  binsize, fs, trial_count, trial_len);

        nexttile;
        area(edges(1:end-1) ./ 1000 - led_onset_sec, PulseRate(1:end-1), ...
            'FaceColor', [1 0 0], 'EdgeColor', [1 0 0], 'FaceAlpha', 0.5, 'LineWidth', 1);
        hold on;
        % Auto-scale pulse y-axis if peak exceeds the specified limit
        if max(PulseRate(1:end-1)) > opts.ylim_pulse(2)
            ylim auto;
        else
            ylim(opts.ylim_pulse);
        end
        box off;

        yyaxis right;
        area(edges(1:end-1) ./ 1000 - led_onset_sec, SineRate(1:end-1), ...
            'FaceColor', [0 0 1], 'EdgeColor', [0 0 1], 'FaceAlpha', 0.25, 'LineWidth', 1);
        ylim(opts.ylim_sine);
        box off;

        xlim(opts.psth_xlim);

        % Y-axis labels (switch back to left before labelling)
        yyaxis left;
        ylabel('Pulses/s', 'FontSize', 10);
        yyaxis right;
        ylabel('Sine/s', 'FontSize', 10);

        title(row_labels{kk}, 'Interpreter', 'none', 'FontSize', 10);

        % Colour both y-axes to match their respective traces; hide x-axis
        ax = gca;
        ax.YAxis(1).Color = [1 0 0];   % pulse left  axis = red
        ax.YAxis(2).Color = [0 0 1];   % sine  right axis = blue
        if kk == grp(end)
            yyaxis left;
            xlabel('Time from Stimulus Onset (s)', 'FontSize', 10);
        else
            ax.XAxis.Visible = 'off';
        end
    end

    % Save this figure if requested
    if ~isempty(opts.SavePath) && ~isempty(opts.SaveFormat)
        if ~exist(opts.SavePath, 'dir'), mkdir(opts.SavePath); end
        fname = sprintf('%s_songPSTH_alllines_fig%dof%d%s', ...
            dataset_type, f, n_figs, opts.SaveFormat);
        saveas(figs(f), fullfile(opts.SavePath, fname));
    end

end

end
