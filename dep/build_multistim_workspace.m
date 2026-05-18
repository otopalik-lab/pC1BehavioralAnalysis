function MultiStimData = build_multistim_workspace(cfg)
% BUILD_MULTISTIM_WORKSPACE  Wrap process_multistim_aggression_dcenter and
% assemble a per-experiment struct array (MultiStimData) suitable for
% downstream plot functions in this repo.
%
% Each struct array entry corresponds to one experiment directory. Fields:
%   condition              char, condition name (e.g. 'empty', 'aIPg')
%   expdir                 char, experiment subfolder name
%   agg_percbehavior       [1 x tot]   per-frame % flies aggressing
%   dcenter_meanperframe   [1 x tot]   per-frame mean inter-fly distance (mm)
%   agg_binned             [1 x n_bins]
%   dcenter_binned         [1 x n_bins]
%   binlabels              [1 x n_bins] (sec, movie time)
%   binned_indicatordata   [1 x n_bins] logical (LED on)
%   indicatorstarts        [1 x num_stims]
%   stim_durations         scalar (frames, this experiment)
%   stimstart              scalar
%   FPS, pre, post, bin, alignment_stim
%
% This function also assigns MultiStimData and the resolved cfg to the base
% workspace as 'MultiStimData' and 'MultiStimCfg', mirroring the data-load
% conventions used by the rest of the pC1 repo (e.g. MaleMaleData).
%
% INPUT:
%   cfg   see process_multistim_aggression_dcenter for fields. Required:
%         conditions, datadirs.
%
% OUTPUT:
%   MultiStimData   struct array, one entry per experiment

raw = process_multistim_aggression_dcenter(cfg);
cfg = raw.cfg;

MultiStimData = struct([]);
k = 0;
for c = 1:numel(cfg.conditions)
    cond = cfg.conditions{c};
    R = raw.(cond);
    n_exp = size(R.agg_percbehavior, 1);
    for ee = 1:n_exp
        k = k + 1;
        MultiStimData(k).condition            = cond;
        MultiStimData(k).expdir               = R.expdirs{ee};
        MultiStimData(k).agg_percbehavior     = R.agg_percbehavior(ee, :);
        MultiStimData(k).dcenter_meanperframe = R.dcenter_meanperframe(ee, :);
        MultiStimData(k).agg_binned           = R.agg_binned(ee, :);
        MultiStimData(k).dcenter_binned       = R.dcenter_binned(ee, :);
        MultiStimData(k).binlabels            = R.binlabels;
        MultiStimData(k).binned_indicatordata = R.binned_indicatordata;
        MultiStimData(k).indicatorstarts      = R.indicatorstarts(ee, :);
        MultiStimData(k).stim_durations       = R.stim_durations(ee);
        MultiStimData(k).stimstart            = R.stimstart;
        MultiStimData(k).FPS                  = cfg.fps;
        MultiStimData(k).pre                  = cfg.pre;
        MultiStimData(k).post                 = cfg.post;
        MultiStimData(k).bin                  = cfg.bin;
        MultiStimData(k).alignment_stim       = cfg.alignment_stim;
    end
end

assignin('base', 'MultiStimData', MultiStimData);
assignin('base', 'MultiStimCfg',  cfg);

end
