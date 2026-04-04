function fig = plot_song_raster_psth(line_input, dataset_type, varargin)
%PLOT_SONG_RASTER_PSTH  LED-aligned audio trace, raster plots, and
%                        PSTHs for pulse and sine song for one SS line.
%
%   Produces a 5-panel stacked figure:
%     1. LED stimulus trace
%     2. Example raw audio recording
%     3. Pulse song raster  (red dots, one row per trial per LED bout)
%     4. Sine song raster   (blue dots, one row per trial per LED bout)
%     5. Joint PSTH  (pulse: red filled area, left y-axis;
%                     sine:  blue filled area, right y-axis)
%
% ── USAGE ─────────────────────────────────────────────────────────────────
%   fig = plot_song_raster_psth(25, 'isolated_activation')
%   fig = plot_song_raster_psth('SS102671', 'courting_activation')
%   fig = plot_song_raster_psth(14, 'courting_silencing', ...
%             'ylim_pulse', [0 20], 'SavePath', '/save/dir', 'SaveFormat', '.pdf')
%
% ── REQUIRED INPUTS ───────────────────────────────────────────────────────
%   line_input    numeric index or string matching an SS line label
%   dataset_type  'isolated_activation' | 'courting_activation' |
%                 'courting_silencing'
%
% ── OPTIONAL NAME-VALUE INPUTS ────────────────────────────────────────────
%   All defaults are set per dataset_type to match the original analysis.
%
%   'plotbouts'       int vec   LED bout indices for rasters and PSTH
%   'select_trials'   int vec   Trial indices to include ([] = all trials)
%   'audio_trial'     int       Trial index for the raw audio trace
%   'audio_ylim'      [lo hi]   Y-axis limits for audio panel ([] = auto)
%   'led_ref_bout'    int       Bout index for LED stimulus display
%   'audio_ref_bout'  int       Bout index for audio display time window
%   'raster_xlim'     [lo hi]   X-axis range (s) for raster panels
%   'psth_xlim'       [lo hi]   X-axis range (s) for LED and PSTH panels
%   'ylim_pulse'      [lo hi]   Pulse PSTH left y-axis limits
%   'ylim_sine'       [lo hi]   Sine PSTH right y-axis limits
%   'psth_axis'       logical   Show axes and xlabel('seconds') on PSTH panel (default false)
%   'SavePath'        char      Directory to save figure (requires SaveFormat)
%   'SaveFormat'      char      File format, e.g. '.pdf', '.png', '.svg'
%
% ── DATASET DEFAULTS ──────────────────────────────────────────────────────
%
%   Parameter           isolated_activation  courting_activation  courting_silencing
%   ─────────────────   ───────────────────  ───────────────────  ──────────────────
%   plotbouts           96:100               42:46                41:45
%   select_trials       [] (all)             [] (all)             [] (all)
%   audio_trial         randi(20)            randi(20)            randi(20)
%   audio_ylim          [-0.15 0.25]         [] (auto)            [-0.15 0.25]
%   led_ref_bout        99                   18                   18
%   audio_ref_bout      99                   18                   50
%   raster_xlim         [5 20]               [-5 10]              [-5 10]
%   psth_xlim           [5 20]               [0 15]               [0 15]
%   ylim_pulse          [0 30]               [0 30]               [0 30]
%   ylim_sine           [0 2000]             [0 2000]             [0 2000]
%
% ── ALIGNMENT NOTES ───────────────────────────────────────────────────────
%   isolated_activation: 10-s pre/post window; LED onset displayed at 10 s
%                        on both raster and PSTH axes
%   courting datasets:    5-s pre/post window; LED onset displayed at 0 s
%                        on the raster and at 5 s on the PSTH axis
%
% ── BASE WORKSPACE REQUIREMENTS ───────────────────────────────────────────
%   data_isolatedmale_activation | data_courtingmale_activation |
%   data_courtingmale_silencing
%   lines       1×N cell array of SS line name strings
%   celltypes   1×N cell array of cell-type name strings
%
% ── OUTPUT ────────────────────────────────────────────────────────────────
%   fig   Figure handle

%% ── Dataset-type defaults and alignment parameters ───────────────────────
dataset_type = lower(dataset_type);
switch dataset_type

    case 'isolated_activation'
        % 10-s pre/post window. Alignment subtracts pre_samples from events
        % before dividing by fs, then adds plot_offset_sec so LED onset
        % appears at pre_samples/fs = 10 s on the raster x-axis.
        data_var        = 'data_isolatedmale_activation';
        pre_samples     = 50000;               % 10-s window half-width
        align_sub       = pre_samples;         % subtract pre_samples when aligning
        plot_offset_sec = 2 * pre_samples / 5000;  % = 20; LED onset → 10 s on raster
        def_plotbouts      = 96:100;
        def_select_trials  = [];               % [] = all trials
        def_audio_trial    = [];
        def_audio_ylim     = [-0.15 0.25];
        def_led_ref        = 99;
        def_audio_ref      = 99;
        def_raster_xlim    = [5 20];
        def_psth_xlim      = [5 20];
        def_ylim_pulse     = [0 30];
        def_ylim_sine      = [0 2000];

    case 'courting_activation'
        % 5-s pre/post window. Events aligned directly to LED onset (no
        % additional subtraction), so LED onset appears at 0 s on raster.
        data_var        = 'data_courtingmale_activation';
        pre_samples     = 25000;               % 5-s window half-width
        align_sub       = 0;
        plot_offset_sec = 0;                   % LED onset at 0 s on raster
        def_plotbouts      = 42:46;
        def_select_trials  = [];
        def_audio_trial    = [];
        def_audio_ylim     = [];               % [] = auto-scale
        def_led_ref        = 18;
        def_audio_ref      = 18;
        def_raster_xlim    = [-5 10];
        def_psth_xlim      = [0 15];
        def_ylim_pulse     = [0 30];
        def_ylim_sine      = [0 2000];

    case 'courting_silencing'
        % Same 5-s window as courting activation; uses a subset of trials
        % and different reference bouts for LED vs audio display panels.
        data_var        = 'data_courtingmale_silencing';
        pre_samples     = 25000;
        align_sub       = 0;
        plot_offset_sec = 0;
        def_plotbouts      = 41:45;
        def_select_trials  = [];               % [] = all trials
        def_audio_trial    = [];
        def_audio_ylim     = [-0.15 0.25];
        def_led_ref        = 18;
        def_audio_ref      = 50;               % different bout for audio window
        def_raster_xlim    = [-5 10];
        def_psth_xlim      = [0 15];
        def_ylim_pulse     = [0 30];
        def_ylim_sine      = [0 2000];

    otherwise
        error(['dataset_type must be ''isolated_activation'', ' ...
               '''courting_activation'', or ''courting_silencing''.']);
end

%% ── Parse optional arguments ─────────────────────────────────────────────
ip = inputParser;
ip.addParameter('plotbouts',     def_plotbouts,    @isnumeric);
ip.addParameter('select_trials', def_select_trials,@isnumeric);
ip.addParameter('audio_trial',   def_audio_trial,  @(x) isnumeric(x) && (isempty(x) || isscalar(x)));
ip.addParameter('audio_ylim',    def_audio_ylim,   @(x) isnumeric(x) && (isempty(x) || numel(x)==2));
ip.addParameter('led_ref_bout',  def_led_ref,      @(x) isnumeric(x) && isscalar(x));
ip.addParameter('audio_ref_bout',def_audio_ref,    @(x) isnumeric(x) && isscalar(x));
ip.addParameter('raster_xlim',   def_raster_xlim,  @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('psth_xlim',     def_psth_xlim,    @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('ylim_pulse',    def_ylim_pulse,   @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('ylim_sine',     def_ylim_sine,    @(x) isnumeric(x) && numel(x)==2);
ip.addParameter('psth_axis',     false,            @islogical);
ip.addParameter('SavePath',      '',               @ischar);
ip.addParameter('SaveFormat',    '',               @ischar);
ip.parse(varargin{:});
opts = ip.Results;

fs = 5000;   % sampling rate (Hz), fixed across all datasets

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
    line_idx = line_input;
elseif ischar(line_input) || isstring(line_input)
    m = find(contains(all_labels, char(line_input)));
    if isempty(m)
        error('Line "%s" not found in labels.', line_input);
    elseif numel(m) > 1
        warning('Multiple matches for "%s"; using index %d.', line_input, m(1));
    end
    line_idx = m(1);
else
    error('line_input must be a string or a numeric index.');
end

%% ── Detect LED bouts ─────────────────────────────────────────────────────
LED       = data(1).LED;
LED_bouts = detect_binarybouts(LED);   % N×2 matrix: [onset, offset] in samples

% Trial list: [] default means all trials for the selected line
if isempty(opts.select_trials)
    trial_list = 1:length(data(line_idx).trial_idx);
else
    trial_list = opts.select_trials;
end

% Resolve audio_trial now that we know the actual trial count
if isempty(opts.audio_trial)
    opts.audio_trial = trial_list(randi(length(trial_list)));
end

audio_pre = 25000;   % fixed 5-s audio window half-width (all datasets)

%% ── Build figure ─────────────────────────────────────────────────────────
fig = figure('Position', [100 100 300 600]);
tiledlayout(5, 1, 'TileSpacing', 'loose');

%% ── Panel 1: LED stimulus trace ──────────────────────────────────────────
% x-axis: time in seconds from start of pre-window; LED onset at pre_samples/fs
nexttile;
LED_vector = LED(LED_bouts(opts.led_ref_bout,1) - pre_samples : ...
                 LED_bouts(opts.led_ref_bout,2) + pre_samples);
plot((1:length(LED_vector)) ./ fs, LED_vector * 100, 'k-', 'LineWidth', 2);
%ylim([-0.1 2.5]);
xlim(opts.psth_xlim);
title(all_labels{line_idx});
axis off;

%% ── Panel 2: Example raw audio trace ────────────────────────────────────
nexttile;
wavfile    = char(data(line_idx).paths2audio(opts.audio_trial));
timewindow = [LED_bouts(opts.audio_ref_bout,1) - audio_pre, ...
              LED_bouts(opts.audio_ref_bout,2) + audio_pre] ./ fs;
PlotSampleAudioTrace(wavfile, timewindow);
if ~isempty(opts.audio_ylim)
    ylim(opts.audio_ylim);
end
axis off;

%% ── Panel 3: Pulse song raster ───────────────────────────────────────────
% Raster x-axis formula (unified across datasets):
%   plot_x = (ev - bout_onset - align_sub) / fs + plot_offset_sec
%
%   isolated:  align_sub = pre_samples, plot_offset_sec = 2*pre_samples/fs
%              → LED onset displayed at pre_samples/fs = 10 s
%   courting:  align_sub = 0, plot_offset_sec = 0
%              → LED onset displayed at 0 s
%
% PSTH event times (unified, LED onset always at pre_samples samples):
%   psth_ev = ev - bout_onset + pre_samples
nexttile;
trial_num       = 1;
all_pulse_x     = [];
all_pulse_y     = [];
all_pulse_times = [];
for k = 1:length(opts.plotbouts)
    bout_onset = LED_bouts(opts.plotbouts(k), 1);
    bout_end   = LED_bouts(opts.plotbouts(k), 2);
    for j = trial_list
        ev = data(line_idx).pulse_idx(data(line_idx).pulse_trial_idx == j);
        ev = ev(ev > bout_onset - pre_samples & ev < bout_end + pre_samples);
        ev = ev(:);
        all_pulse_x     = [all_pulse_x;     (ev - bout_onset - align_sub) ./ fs + plot_offset_sec]; %#ok<AGROW>
        all_pulse_y     = [all_pulse_y;     trial_num * ones(size(ev))];                             %#ok<AGROW>
        all_pulse_times = [all_pulse_times; ev - bout_onset + pre_samples];                          %#ok<AGROW>
        trial_num = trial_num + 1;
    end
end
pulse_trial_num = trial_num - 1;
plot(all_pulse_x, all_pulse_y, '.', 'Color', 'r', 'MarkerSize', 0.5);
ylim([0 trial_num]);
xlim(opts.raster_xlim);
box off;
axis off;

%% ── Panel 4: Sine song raster ────────────────────────────────────────────
nexttile;
trial_num      = 1;
all_sine_x     = [];
all_sine_y     = [];
all_sine_times = [];
for k = 1:length(opts.plotbouts)
    bout_onset = LED_bouts(opts.plotbouts(k), 1);
    bout_end   = LED_bouts(opts.plotbouts(k), 2);
    for j = trial_list
        ev = data(line_idx).sine_idx(data(line_idx).sine_trial_idx == j);
        ev = ev(ev > bout_onset - pre_samples & ev < bout_end + pre_samples);
        ev = ev(:);
        all_sine_x     = [all_sine_x;     (ev - bout_onset - align_sub) ./ fs + plot_offset_sec]; %#ok<AGROW>
        all_sine_y     = [all_sine_y;     trial_num * ones(size(ev))];                             %#ok<AGROW>
        all_sine_times = [all_sine_times; ev - bout_onset + pre_samples];                          %#ok<AGROW>
        trial_num = trial_num + 1;
    end
end
sine_trial_num = trial_num - 1;
plot(all_sine_x, all_sine_y, '.', 'Color', 'b', 'MarkerSize', 0.5);
ylim([0 trial_num]);
xlim(opts.raster_xlim);
box off;
axis off;

%% ── Panel 5: Joint PSTH ──────────────────────────────────────────────────
% PSTH events are aligned so LED onset = pre_samples samples from trial start.
% This places LED onset at pre_samples/fs seconds on the psth_xlim axis:
%   isolated: 50000/5000 = 10 s  (psth_xlim [5 20])
%   courting: 25000/5000 =  5 s  (psth_xlim [0 15])
trial_len = length(LED_bouts(opts.plotbouts(end),1) - pre_samples : ...
                   LED_bouts(opts.plotbouts(end),2) + pre_samples);
binsize   = 100;   % ms
lastbin   = binsize * ceil((trial_len - 1) * 1000 / (fs * binsize));
edges     = 0:binsize:lastbin;

PulseRate = psth(all_pulse_times, binsize, fs, pulse_trial_num, trial_len);
SineRate  = psth(all_sine_times,  binsize, fs, sine_trial_num,  trial_len);

nexttile;
area(edges(1:end-1) ./ 1000, PulseRate(1:end-1), ...
    'FaceColor', [1 0 0], 'EdgeColor', [1 0 0], 'FaceAlpha', 0.5, 'LineWidth', 1);
hold on;
ylim(opts.ylim_pulse);
box off;

yyaxis right;
area(edges(1:end-1) ./ 1000, SineRate(1:end-1), ...
    'FaceColor', [0 0 1], 'EdgeColor', [0 0 1], 'FaceAlpha', 0.25, 'LineWidth', 1);
ylim(opts.ylim_sine);
box off;
xlim(opts.psth_xlim);
if opts.psth_axis
    axis on;
    xlabel('seconds');
else
    axis off;
end

%% ── Save (optional) ──────────────────────────────────────────────────────
if ~isempty(opts.SavePath) && ~isempty(opts.SaveFormat)
    if ~exist(opts.SavePath, 'dir'), mkdir(opts.SavePath); end
    linename = char(lines{line_idx});
    cellname = char(celltypes{line_idx});
    cellname = erase(cellname, '\');
    cellname = erase(cellname, ' ');
    cellname = erase(cellname, ',');
    filename = [linename '_' cellname '_' dataset_type '_songRasterPSTH' opts.SaveFormat];
    saveas(fig, fullfile(opts.SavePath, filename));
end

end
