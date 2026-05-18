function out = process_multistim_aggression_dcenter(cfg)
% PROCESS_MULTISTIM_AGGRESSION_DCENTER  Per-experiment loader for aggression
% (% of flies aggressing) and inter-fly distance (dcenter, mm) from a
% multi-stim optogenetic protocol, aligned to one stim epoch.
%
% This function preserves the data-processing logic of two source scripts:
%   AggMultiStim_caltechflytracker.m       (aggression % per frame)
%   AMultiStim_oneVone_perframefeatures.m  (dcenter), with the chamber-index
%                                          splitting INTENTIONALLY OMITTED
%                                          (single-chamber bowls), matching
%                                          the structure of the aggression
%                                          script.
%
% All file-existence checks from the source scripts are preserved.
%
% INPUTS (cfg struct fields):
%   conditions          cell array of condition names, e.g. {'empty','aIPg'}
%   datadirs            struct mapping condition -> absolute path to the
%                       directory containing experiment subfolders. Use the
%                       condition name as the field, e.g. datadirs.empty
%   behavior_score_file (optional) JAABA aggression scores file name
%                       default: 'scores_MMAggfRGBub.mat'
%   dcenter_relpath     (optional) dcenter file relative path within expdir
%                       default: fullfile('perframe','dcenter.mat')
%   tracksfile          (optional) registered tracks file name
%                       default: 'registered_trx.mat'
%   indicatorfile       (optional) indicator data file name
%                       default: 'indicatordata.mat'
%   pre                 (optional) frames before alignment stim, default 2550
%   post                (optional) frames after alignment stim, default 58650
%   num_stims           (optional) number of stims expected, default 6
%   alignment_stim      (optional) stim index used for alignment, default 1
%   bin                 (optional) bin size in frames, default 60
%   fps                 (optional) frame rate in Hz, default 169.99
%   writecsv            (optional) write CSV summaries, default false
%   outputdir           (optional) directory for CSV outputs, default tempdir
%
% OUTPUT (out struct):
%   out.cfg                                resolved cfg with defaults filled
%   out.<condition>.expdirs                {n_exp x 1} cellstr
%   out.<condition>.agg_percbehavior       [n_exp x tot]   per-frame %
%   out.<condition>.dcenter_meanperframe   [n_exp x tot]   per-frame mean (mm)
%   out.<condition>.agg_binned             [n_exp x n_bins]
%   out.<condition>.dcenter_binned         [n_exp x n_bins]
%   out.<condition>.binned_indicatordata   [1 x n_bins]    logical
%   out.<condition>.binlabels              [1 x n_bins]    seconds, movie time
%   out.<condition>.indicatorstarts        [n_exp x num_stims]
%   out.<condition>.stimstart              scalar (last experiment loaded)
%   out.<condition>.stim_durations         [n_exp x 1]     frames per expt
%
% NOTES:
%   Aggression: matches AggMultiStim_caltechflytracker.m exactly:
%     currbowl_data filled per fly using allScores.tStart/tEnd, then
%     per-frame % = nansum(col)/numel(~isnan(col))*100.
%   Inter-fly distance: matches AMultiStim_oneVone_perframefeatures.m up
%     through loading perframe/dcenter and registered_trx, then averages
%     across all flies in the bowl per frame (no chamber splitting), then
%     bins identically to the source.

%% Resolve defaults
if ~isfield(cfg, 'behavior_score_file'); cfg.behavior_score_file = 'scores_MMAggfRGBub.mat'; end
if ~isfield(cfg, 'dcenter_relpath');     cfg.dcenter_relpath     = fullfile('perframe','dcenter.mat'); end
if ~isfield(cfg, 'tracksfile');          cfg.tracksfile          = 'registered_trx.mat'; end
if ~isfield(cfg, 'indicatorfile');       cfg.indicatorfile       = 'indicatordata.mat'; end
if ~isfield(cfg, 'pre');                 cfg.pre                 = 2550;   end
if ~isfield(cfg, 'post');                cfg.post                = 58650;  end
if ~isfield(cfg, 'num_stims');           cfg.num_stims           = 6;      end
if ~isfield(cfg, 'alignment_stim');      cfg.alignment_stim      = 1;      end
if ~isfield(cfg, 'bin');                 cfg.bin                 = 60;     end
if ~isfield(cfg, 'fps');                 cfg.fps                 = 169.99; end
if ~isfield(cfg, 'writecsv');            cfg.writecsv            = false;  end
if ~isfield(cfg, 'outputdir');           cfg.outputdir           = tempdir; end

% Derived
pre   = cfg.pre;
post  = cfg.post;
tot   = pre + post;
post_idx = post - 1;       % preserves source convention: post = post-1 then crop stimstart-pre:stimstart+post
bin   = cfg.bin;
fps   = cfg.fps;

% Sanity check from the source-script comment ("tot needs to be evenly
% divisible by bin")
assert(mod(tot, bin) == 0, ...
    'pre+post (%d) must be evenly divisible by bin (%d).', tot, bin);

% Bin labels (movie-time, seconds) — recomputed per condition with offset
binlabels_template      = nan(1, tot/bin);
binlabels_template(1)   = mean(1:bin) * (1/fps);
for i = 1:tot/bin - 1
    binlabels_template(i+1) = mean(i*bin+1 : i*bin+bin) * (1/fps);
end

%% CSV output (optional)
fid_agg = []; fid_dist = [];
if cfg.writecsv
    if ~exist(cfg.outputdir, 'dir'); mkdir(cfg.outputdir); end
    ts = datestr(now, 'yyyymmddTHHMMSS'); %#ok<DATST>
    aggfile  = fullfile(cfg.outputdir, ['PercentageofFlies_', cfg.behavior_score_file(1:end-4), ...
                                        '_Meanbinsize', num2str(bin), '_', ts, '.csv']);
    distfile = fullfile(cfg.outputdir, ['MeanDcenterPerBowl_dcenter_Meanbinsize', num2str(bin), '_', ts, '.csv']);
    fid_agg  = fopen(aggfile,  'w');
    fid_dist = fopen(distfile, 'w');
end

out = struct();
out.cfg = cfg;

%% Loop over conditions
for cond = 1:numel(cfg.conditions)
    condition = cfg.conditions{cond};
    if ~isfield(cfg.datadirs, condition)
        error('cfg.datadirs has no entry for condition "%s".', condition);
    end
    datadir = cfg.datadirs.(condition);

    if ~exist(datadir, 'dir')
        error(['Data directory for condition "%s" does not exist or is not ', ...
               'accessible:\n  %s\nCheck cfg.datadirs and that any network ', ...
               'volume is mounted.'], condition, datadir);
    end

    expdirs_struct = dir(datadir);
    expdirs_struct(ismember({expdirs_struct.name}, {'.', '..', '.DS_Store'})) = [];
    % Keep only actual subdirectories (skip stray files in the parent dir)
    expdirs_struct = expdirs_struct([expdirs_struct.isdir]);
    n_exp = numel(expdirs_struct);

    if n_exp == 0
        error(['No experiment subdirectories found for condition "%s" in:\n  %s\n', ...
               'Each experiment must be its own subfolder under this directory.'], ...
               condition, datadir);
    end

    % Preallocate (these are the variables actually used downstream — the
    % source scripts preallocated different names by mistake; we allocate
    % the ones that are written to.)
    agg_percbehavior     = nan(n_exp, tot);
    dcenter_meanperframe = nan(n_exp, tot);
    agg_binned           = nan(n_exp, tot/bin);
    dcenter_binned       = nan(n_exp, tot/bin);
    indicatorstarts      = nan(n_exp, cfg.num_stims);
    stim_durations       = nan(n_exp, 1);
    expdir_names         = cell(n_exp, 1);

    % CSV section header
    if cfg.writecsv
        fprintf(fid_agg,  '%s \n', condition);
        fprintf(fid_dist, '%s \n', condition);
    end

    stimstart = NaN; %#ok<NASGU>  % will be set inside loop; final value used for binlabels offset

    for ee = 1:n_exp
        expdir = fullfile(datadir, expdirs_struct(ee).name);
        expdir_names{ee} = expdirs_struct(ee).name;

        %% Load indicator data (preserved check from source)
        if exist(fullfile(expdir, cfg.indicatorfile), 'file')
            load(fullfile(expdir, cfg.indicatorfile), 'indicatorLED');
        else
            sprintf('No indicatorLED file');
            return
        end

        %% Load aggression scores (preserved check from source)
        if exist(fullfile(expdir, cfg.behavior_score_file), 'file')
            load(fullfile(expdir, cfg.behavior_score_file), 'allScores');
        else
            sprintf('No trx file');
            return
        end

        %% Load dcenter perframe feature (preserved check from source)
        if exist(fullfile(expdir, cfg.dcenter_relpath), 'file')
            load(fullfile(expdir, cfg.dcenter_relpath), 'data');
        else
            sprintf('No perframe feature file');
            return
        end

        %% Load registered tracks (preserved check from source)
        if exist(fullfile(expdir, cfg.tracksfile), 'file')
            load(fullfile(expdir, cfg.tracksfile), 'trx');
        else
            sprintf('No trx file');
            return
        end

        %% Aggression: per-fly per-frame matrix, then per-frame %
        nflies_agg = numel(allScores.postprocessed);
        currbowl_agg = nan(nflies_agg, max(allScores.tEnd));
        for i = 1:nflies_agg
            currbowl_agg(i, allScores.tStart(i):allScores.tEnd(i)) = ...
                allScores.postprocessed{i}(allScores.tStart(i):allScores.tEnd(i));
        end

        % Stim alignment frame — guard against unexpected stim counts so
        % the failure mode is informative rather than a silent NaN.
        n_actual_stims = numel(indicatorLED.startframe);
        if n_actual_stims < cfg.alignment_stim
            error(['Experiment "%s" has only %d stim(s) in indicatorLED.startframe, ', ...
                   'but cfg.alignment_stim = %d.'], ...
                   expdirs_struct(ee).name, n_actual_stims, cfg.alignment_stim);
        end
        if n_actual_stims ~= cfg.num_stims
            warning(['Experiment "%s" has %d stims, expected cfg.num_stims = %d. ', ...
                     'Continuing; indicatorstarts row will be padded with NaNs.'], ...
                     expdirs_struct(ee).name, n_actual_stims, cfg.num_stims);
        end
        n_to_copy = min(n_actual_stims, cfg.num_stims);
        indicatorstarts(ee, 1:n_to_copy) = indicatorLED.startframe(1:n_to_copy);
        stimstart = indicatorLED.startframe(cfg.alignment_stim);

        % Crop and per-frame %
        agg_cropped = currbowl_agg(:, stimstart-pre:stimstart+post_idx);
        currbowl_percbehavior = nan(1, size(agg_cropped, 2));
        for i = 1:size(agg_cropped, 2)
            currbowl_percbehavior(i) = ...
                (nansum((agg_cropped(:, i))) / numel(find(~isnan(agg_cropped(:, i))))) * 100; %#ok<NANSUM>
        end
        agg_percbehavior(ee, :) = currbowl_percbehavior;

        % Bin (no omitnan — matches source)
        agg_binned(ee, 1) = mean(currbowl_percbehavior(1:bin));
        for i = 1:tot/bin - 1
            agg_binned(ee, i+1) = mean(currbowl_percbehavior(i*bin+1 : i*bin+bin));
        end

        %% Inter-fly distance (dcenter): per-fly per-frame, then per-frame mean (mm)
        nflies_dc = numel(data);
        currbowl_dc = nan(nflies_dc, max([trx.endframe]));
        for i = 1:nflies_dc
            framestart  = trx(i).firstframe;
            framelimit  = trx(i).endframe;
            % Non-difference perframe feature (dcenter): one value per frame
            currbowl_dc(i, framestart:framelimit) = data{i};
        end

        dc_cropped = currbowl_dc(:, stimstart-pre:stimstart+post_idx);
        % Single-chamber assumption: per-frame mean across all flies in the bowl
        mean_dc_per_frame = mean(dc_cropped, 1, 'omitnan');
        dcenter_meanperframe(ee, :) = mean_dc_per_frame;

        % Bin (omitnan — matches source's nanmean)
        dcenter_binned(ee, 1) = mean(mean_dc_per_frame(1:bin), 'omitnan');
        for i = 1:tot/bin - 1
            dcenter_binned(ee, i+1) = mean(mean_dc_per_frame(i*bin+1 : i*bin+bin), 'omitnan');
        end

        %% Stim duration for this experiment (from cropped digital indicator)
        % The alignment stim onset sits at frame index pre+1 of the cropped
        % trace; stim duration = run-length of consecutive 1's starting there.
        ind_dig_cropped = indicatorLED.indicatordigital(stimstart-pre : stimstart+post_idx);
        run = ind_dig_cropped(pre+1:end);
        first_zero = find(run == 0, 1, 'first');
        if isempty(first_zero)
            stim_durations(ee) = numel(run);
        else
            stim_durations(ee) = first_zero - 1;
        end

        %% CSV write (per-experiment row)
        if cfg.writecsv
            for i = 1:numel(agg_binned(ee, :))
                fprintf(fid_agg, '%.3f, ', agg_binned(ee, i));
            end
            fprintf(fid_agg, '\n');
            for i = 1:numel(dcenter_binned(ee, :))
                fprintf(fid_dist, '%.3f, ', dcenter_binned(ee, i));
            end
            fprintf(fid_dist, '\n');
        end
    end

    %% Indicator timing check (preserved from source — kept commented as in
    %  original, since not all datasets satisfy it strictly)
    % a = num2cell(diff(indicatorstarts'));
    % assert(isequal(a{:}), 'indicator timing is not equal');

    %% Binned indicator data + timestamps (uses last experiment's stimstart,
    %  matching source behavior)
    ind_dig_cropped = indicatorLED.indicatordigital(stimstart-pre : stimstart+post_idx);
    binned_indicatordata = nan(1, tot/bin);
    binned_indicatordata(1) = mean(ind_dig_cropped(1:bin));
    for i = 1:tot/bin - 1
        binned_indicatordata(i+1) = mean(ind_dig_cropped(i*bin+1 : i*bin+bin));
    end
    binned_indicatordata = binned_indicatordata >= 0.5;

    offset    = (stimstart - pre) * (1/fps);
    binlabels = binlabels_template + offset;

    %% CSV: indicator + timestamps (matches source format)
    if cfg.writecsv
        for fid = [fid_agg, fid_dist]
            fprintf(fid, 'binned digital indicator \n');
            for i = 1:tot/bin
                fprintf(fid, '%f, ', binned_indicatordata(i));
            end
            fprintf(fid, '\n');
            fprintf(fid, 'timestamps \n');
            for i = 1:tot/bin
                fprintf(fid, '%.2f, ', binlabels(i));
            end
            fprintf(fid, '\n');
        end
    end

    %% Stash per-condition results
    out.(condition).expdirs              = expdir_names;
    out.(condition).agg_percbehavior     = agg_percbehavior;
    out.(condition).dcenter_meanperframe = dcenter_meanperframe;
    out.(condition).agg_binned           = agg_binned;
    out.(condition).dcenter_binned       = dcenter_binned;
    out.(condition).binned_indicatordata = binned_indicatordata;
    out.(condition).binlabels            = binlabels;
    out.(condition).indicatorstarts      = indicatorstarts;
    out.(condition).stimstart            = stimstart;
    out.(condition).stim_durations       = stim_durations;
end

if cfg.writecsv
    fclose(fid_agg);
    fclose(fid_dist);
end

end
