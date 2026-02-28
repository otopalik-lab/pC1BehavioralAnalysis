function plot_behavior_sankey(ss_lines, behaviors, normalize, SavePath, SaveFormat)
% PLOT_BEHAVIOR_SANKEY  Compute behavioral probabilities from LED stimulation
%                         epochs and render LED-ON / LED-OFF Sankey diagrams.
%
%   SOURCE NODES  : SS genetic driver lines
%   TARGET NODES  : behavioral outputs
%   RIBBON WIDTH  : probability of each behavioral output during the epoch
%
% ── INPUTS ───────────────────────────────────────────────────────────────────
%   ss_lines   – Cell array of SS-line identifier strings, e.g.
%                  {'SS02569', 'SS25349'}.
%                Alternatively a numeric vector of row indices into SSinds.
%                Pass 'all' (string) to include every line in SSinds.
%   behaviors  – Cell array of behavioral field names (target nodes), e.g.
%                  {'proximal', 'pursuit', 'aggression'}.
%   normalize  – Logical.  true → rescale ribbon weights 0–1 within each
%                behavior column before building connection arrays.
%   SavePath   – (optional) Directory for saving .mat arrays and figures.
%   SaveFormat – (optional) Figure file extension, e.g. '.pdf' or '.png'.
%                Both SavePath and SaveFormat must be provided to save.
%
% ── WORKSPACE REQUIREMENTS ───────────────────────────────────────────────────
%   MaleMaleData  – data structure array
%   SSinds        – nLines × nTrials index matrix
%   lines         – cell array of SS-line name strings
%   celltypes     – cell array of cell-type strings
%
% ── SIGNIFICANCE CRITERION ───────────────────────────────────────────────────
%   One-way ANOVA across all lines, Dunn-Šidák post-hoc (alpha = 0.01).
%   A line is included as a source node only if its behavioral probability
%   during that epoch is significantly different from the empty-vector
%   control (auto-detected as the label containing the word "Empty").
%   Lines failing the criterion are excluded as source nodes.
%
% ── EXAMPLES ─────────────────────────────────────────────────────────────────
%   plot_behavior_sankey({'SS02569','SS25349'}, {'proximal','aggression'}, false)
%   plot_behavior_sankey('all', {'proximal','aggression'}, true, '/save/path', '.pdf')

%% ── Hard-coded analysis parameters ──────────────────────────────────────────
binsize  = 30000;   % PSTH bin size in ms → 2 bins of 30 s (ON, OFF)
LEDStims = 5:7;     % indices of the three highest-power LED epochs

%% ── Load base-workspace dependencies ────────────────────────────────────────
MaleMaleData = evalin('base', 'MaleMaleData');
SSinds       = evalin('base', 'SSinds');
lines        = evalin('base', 'lines');
celltypes    = evalin('base', 'celltypes');

FPS        = MaleMaleData(1).FPS;
fieldNames = fieldnames(MaleMaleData);
numLines   = length(lines);
numTrials  = size(SSinds, 2);

% Build full "SS##### | celltype" label strings
labels = cell(numLines, 1);
for ii = 1:numLines
    labels{ii} = [lines{ii} ' | ' celltypes{ii}];
end

%% ── Locate empty-vector control ─────────────────────────────────────────────
% The ANOVA compares every SS line against the empty-vector control.
% Auto-detect by looking for the word "empty" (case-insensitive) in labels.
empty_idx = find(cellfun(@(s) contains(lower(s), 'empty'), labels));
if isempty(empty_idx)
    warning('plot_behavior_sankey: No label containing Empty found. All selected lines with any activity will be shown.');
    useANOVA = false;
else
    if numel(empty_idx) > 1
        warning('plot_behavior_sankey: Multiple "Empty" matches found; using index %d (%s).', ...
            empty_idx(1), labels{empty_idx(1)});
        empty_idx = empty_idx(1);
    end
    useANOVA = true;
    fprintf('plot_behavior_sankey: using "%s" (index %d) as empty-vector control.\n', ...
        labels{empty_idx}, empty_idx);
end

%% ── Validate behavior field names ────────────────────────────────────────────
for b = 1:numel(behaviors)
    if ~ismember(behaviors{b}, fieldNames)
        error('plot_behavior_sankey: field "%s" not found in MaleMaleData.', behaviors{b});
    end
end
nBeh = numel(behaviors);

%% ── Resolve ss_lines → global row indices into SSinds ───────────────────────
if isnumeric(ss_lines)
    line_inds = ss_lines(:)';
    if any(line_inds < 1) || any(line_inds > numLines)
        error('plot_behavior_sankey: numeric indices must be in [1, %d].', numLines);
    end
elseif ischar(ss_lines) && strcmp(ss_lines, 'all')
    line_inds = 1:numLines;
else
    if ischar(ss_lines), ss_lines = {ss_lines}; end
    line_inds = zeros(1, numel(ss_lines));
    for ii = 1:numel(ss_lines)
        m = find(contains(labels, ss_lines{ii}));
        if isempty(m)
            error('plot_behavior_sankey: SS line "%s" not found in labels.', ss_lines{ii});
        end
        if numel(m) > 1
            warning('plot_behavior_sankey: multiple matches for "%s"; using index %d.', ...
                ss_lines{ii}, m(1));
        end
        line_inds(ii) = m(1);
    end
end

%% ── Detect LED epochs ────────────────────────────────────────────────────────
[LED_epochs, ~] = detect_binarybouts(MaleMaleData(1).LED);
LED_epochs      = [3600 5400; LED_epochs];   % prepend baseline epoch
window          = length(LED_epochs(1,1) : LED_epochs(1,2) + 30*FPS);

%% ── Compute PSTHs for ALL lines (ANOVA needs the full population) ────────────
% behav_probs_* : numLines × nBeh  (global indexing)
% LEDon_mat     : numTrials × numLines  (per behavior, reused each iteration)
behav_probs_LEDON  = zeros(numLines, nBeh);
behav_probs_LEDOFF = zeros(numLines, nBeh);

% significant_lines_LEDON/OFF{bi} : global line indices that are both
%   (a) significantly different from empty control AND
%   (b) in the user-requested ss_lines selection
sig_inds_LEDON  = cell(1, nBeh);
sig_inds_LEDOFF = cell(1, nBeh);

for bi = 1:nBeh
    bIdx = find(strcmp(fieldNames, behaviors{bi}), 1);

    LEDon_mat  = NaN(numTrials, numLines);
    LEDoff_mat = NaN(numTrials, numLines);

    for gi = 1:numLines           % loop over ALL lines (needed for ANOVA)
        event_times_all = [];
        byfly_psths     = NaN(numTrials, 2);   % NaN → skipped trials excluded

        for k = 1:numTrials
            ind = SSinds(gi, k);
            if isnan(ind) || ind == 0, continue; end

            event_times_byfly = [];
            for j = LEDStims
                behav_temp        = MaleMaleData(ind).(fieldNames{bIdx});
                seg               = behav_temp(LED_epochs(j,1) : LED_epochs(j,2) + 30*FPS);
                ev                = find(seg == 1);
                event_times_all   = [event_times_all,   ev]; %#ok<AGROW>
                event_times_byfly = [event_times_byfly, ev]; %#ok<AGROW>
            end

            [psth_fly, ~]    = psth(event_times_byfly, binsize, 60, numel(LEDStims), window);
            byfly_psths(k,:) = psth_fly(1:2);   % bin 1 = LED ON, bin 2 = LED OFF
        end

        LEDon_mat(:, gi)  = byfly_psths(:, 1);
        LEDoff_mat(:, gi) = byfly_psths(:, 2);

        [psth_line, ~]            = psth(event_times_all, binsize, 60, ...
                                         numTrials * numel(LEDStims), window);
        behav_probs_LEDON(gi, bi)  = psth_line(1) ./ 60;
        behav_probs_LEDOFF(gi, bi) = psth_line(2) ./ 60;
    end

    %% ── Significance: one-way ANOVA + Dunn-Šidák vs. empty control ──────────
    if useANOVA
        % LED ON ──────────────────────────────────────────────────────────────
        try
            [~, ~, stats_on] = anova1(LEDon_mat, labels, 'off');
            [res_on, ~, ~, ~] = multcompare(stats_on, ...
                'CriticalValueType', 'dunn-sidak', 'Alpha', 0.01, 'Display', 'off');
            % Rows of res_on involving the empty control
            mask_on  = res_on(:,1) == empty_idx | res_on(:,2) == empty_idx;
            comp_on  = res_on(mask_on, :);
            % For each such row, extract the NON-empty group index
            other_on            = comp_on(:, 2);
            swap                = comp_on(:, 1) ~= empty_idx;
            other_on(swap)      = comp_on(swap, 1);
            sig_global_on       = other_on(comp_on(:, 6) < 0.05);
        catch ME
            warning('plot_behavior_sankey: ANOVA failed for "%s" (LED ON): %s', ...
                behaviors{bi}, ME.message);
            sig_global_on = [];
        end

        % LED OFF ─────────────────────────────────────────────────────────────
        try
            [~, ~, stats_off] = anova1(LEDoff_mat, labels, 'off');
            [res_off, ~, ~, ~] = multcompare(stats_off, ...
                'CriticalValueType', 'dunn-sidak', 'Alpha', 0.01, 'Display', 'off');
            mask_off = res_off(:,1) == empty_idx | res_off(:,2) == empty_idx;
            comp_off = res_off(mask_off, :);
            other_off           = comp_off(:, 2);
            swap                = comp_off(:, 1) ~= empty_idx;
            other_off(swap)     = comp_off(swap, 1);
            sig_global_off      = other_off(comp_off(:, 6) < 0.05);
        catch ME
            warning('plot_behavior_sankey: ANOVA failed for "%s" (LED OFF): %s', ...
                behaviors{bi}, ME.message);
            sig_global_off = [];
        end

        % Intersect with user's requested ss_lines
        sig_inds_LEDON{bi}  = intersect(sig_global_on,  line_inds);
        sig_inds_LEDOFF{bi} = intersect(sig_global_off, line_inds);

    else
        % Fallback when no empty control: include selected lines with activity
        sig_inds_LEDON{bi}  = line_inds(behav_probs_LEDON( line_inds, bi) > 0);
        sig_inds_LEDOFF{bi} = line_inds(behav_probs_LEDOFF(line_inds, bi) > 0);
    end
end

%% ── Optional normalization (applied across all lines, as in original) ─────────
if normalize
    plot_LEDON  = zeros(size(behav_probs_LEDON));
    plot_LEDOFF = zeros(size(behav_probs_LEDOFF));
    for bi = 1:nBeh
        plot_LEDON(:,  bi) = rescale(behav_probs_LEDON(:,  bi));
        plot_LEDOFF(:, bi) = rescale(behav_probs_LEDOFF(:, bi));
    end
    norm_tag = '_normalized';
else
    plot_LEDON  = behav_probs_LEDON;
    plot_LEDOFF = behav_probs_LEDOFF;
    norm_tag    = '';
end

%% ── Build connection arrays ──────────────────────────────────────────────────
% sig_inds_* hold global line indices; labels and prob matrices use same indexing
links_LEDON  = build_links(labels, behaviors, sig_inds_LEDON,  plot_LEDON);
links_LEDOFF = build_links(labels, behaviors, sig_inds_LEDOFF, plot_LEDOFF);

%% ── Save .mat connection arrays ──────────────────────────────────────────────
doSave = nargin >= 4 && ~isempty(SavePath);
if doSave
    if ~exist(SavePath, 'dir'), mkdir(SavePath); end
    cxn_array = links_LEDON;
    save(fullfile(SavePath, ['LEDON'  norm_tag '_cxn_array.mat']), 'cxn_array');
    cxn_array = links_LEDOFF;
    save(fullfile(SavePath, ['LEDOFF' norm_tag '_cxn_array.mat']), 'cxn_array');
    fprintf('plot_behavior_sankey: connection arrays saved to %s\n', SavePath);
end

%% ── Assign colors per behavior ───────────────────────────────────────────────
behavColors = get_behavior_colors(behaviors);

%% ── Plot Sankey diagrams ─────────────────────────────────────────────────────
fig_on  = plot_sankey(links_LEDON,  behaviors, behavColors, ...
    'LED ON: SS Line \rightarrow Behavioral Outputs',  normalize);
fig_off = plot_sankey(links_LEDOFF, behaviors, behavColors, ...
    'LED OFF: SS Line \rightarrow Behavioral Outputs', normalize);

%% ── Save figures ─────────────────────────────────────────────────────────────
if nargin == 5 && ~isempty(SavePath) && ~isempty(SaveFormat)
    if ~exist(SavePath, 'dir'), mkdir(SavePath); end
    saveas(fig_on,  fullfile(SavePath, ['SankeyDiagram_LEDON'  norm_tag SaveFormat]));
    saveas(fig_off, fullfile(SavePath, ['SankeyDiagram_LEDOFF' norm_tag SaveFormat]));
    fprintf('plot_behavior_sankey: figures saved to %s\n', SavePath);
end

end  % ══════════════════════════════ end main ══════════════════════════════════


%% ═══════════════════════════════════════════════════════════════════════════
%  LOCAL  build_links
%     Build an Nx3 cell array: {source_label, behavior_name, probability}
%     sig_inds_by_beh{bi} contains GLOBAL line indices.
%% ═══════════════════════════════════════════════════════════════════════════
function links = build_links(all_labels, behaviors, sig_inds_by_beh, prob_mat)

links   = {};
counter = 1;
for bi = 1:numel(behaviors)
    for si = 1:numel(sig_inds_by_beh{bi})
        gi = sig_inds_by_beh{bi}(si);          % global line index
        links{counter, 1} = all_labels{gi};    %#ok<AGROW>
        links{counter, 2} = behaviors{bi};
        links{counter, 3} = prob_mat(gi, bi);
        counter = counter + 1;
    end
end
end


%% ═══════════════════════════════════════════════════════════════════════════
%  LOCAL  get_behavior_colors
%     Return an nBeh × 3 RGB matrix.  Known behaviors receive their
%     canonical colors; unrecognized behaviors draw from a fallback palette.
%% ═══════════════════════════════════════════════════════════════════════════
function behavColors = get_behavior_colors(behaviors)

known_behaviors = {'close','still','chase','approach','orient', ...
                   'unilateralwing','wingflick','aggression','boxing', ...
                   'headbutt','tussle'};
known_colors    = [0.9961 0.3804 0.0000;   % close        #FE6100  orange
                   0.2745 0.3922 1.0000;   % still                 blue
                   0.8627 0.1490 0.4980;   % chase                   magenta
                   0.0000 0.7490 0.6863;   % approach                  teal
                   0.9843 0.7647 0.0000;   % orient                  yellow
                   0.3922 0.5608 1.0000;   % unilateralwing  #648FFF  blue
                   0.5490 0.2745 0.0784;   % wingflick                 brown
                   0.8627 0.1490 0.4980;   % aggression      #DC267F  magenta
                   0.4000 0.7020 0.0745;   % boxing                    dark lime green
                   0.2000 0.7216 0.9608;   % headbutt                  sky blue
                   0.9412 0.1765 0.1765];  % tussle                    red

% Fallback palette for behaviors not in the list above
fallback = [0.1216 0.4706 0.7059;
            0.8980 0.3059 0.1843;
            0.2000 0.6275 0.1725;
            0.5843 0.1412 0.4039;
            0.5490 0.3373 0.2941;
            0.8902 0.4667 0.7608;
            0.4980 0.4980 0.4980;
            0.7373 0.7412 0.1333;
            0.0902 0.7451 0.8118];

nBeh        = numel(behaviors);
behavColors = zeros(nBeh, 3);
fb_idx      = 1;

for b = 1:nBeh
    ki = find(strcmp(known_behaviors, behaviors{b}), 1);
    if ~isempty(ki)
        behavColors(b, :) = known_colors(ki, :);
    else
        behavColors(b, :) = fallback(mod(fb_idx - 1, size(fallback, 1)) + 1, :);
        fb_idx = fb_idx + 1;
    end
end
end


%% ═══════════════════════════════════════════════════════════════════════════
%  LOCAL  plot_sankey
%     Draw a Sankey diagram from a connection array.
%     Returns a handle to the Sankey figure; the ribbon-width legend is
%     embedded as an inset axes in the lower-right corner of that figure.
%% ═══════════════════════════════════════════════════════════════════════════
function fig = plot_sankey(raw, behaviors, behavColors, titleStr, normalize)

nB = numel(behaviors);

%% Guard: empty connections
if isempty(raw)
    fig = figure('Color', 'w');
    axis off;
    title(titleStr, 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'tex');
    text(0.5, 0.5, 'No significant connections found.', ...
        'HorizontalAlignment', 'center', 'Units', 'normalized');
    return;
end

srcs    = raw(:, 1);
tgts    = raw(:, 2);
weights = cell2mat(raw(:, 3));

%% Build weight matrix (rows = unique source cell types, cols = behaviors)
cellTypes = unique(srcs, 'stable');
nCT       = numel(cellTypes);
meanZ     = zeros(nCT, nB);

for ii = 1:numel(srcs)
    ci = find(strcmp(cellTypes, srcs{ii}), 1);
    bi = find(strcmp(behaviors,  tgts{ii}), 1);
    if ~isempty(ci) && ~isempty(bi)
        meanZ(ci, bi) = weights(ii);
    end
end

%% Sort cell types by profile similarity (hierarchical clustering)
if nCT > 1
    zN       = meanZ;
    rn       = sqrt(sum(zN .^ 2, 2));
    nz       = rn > 0;
    zN(nz,:) = zN(nz,:) ./ rn(nz);           % row-normalize for distance
    D        = pdist(zN, 'euclidean');
    tree     = linkage(D, 'average');
    ord      = optimalleaforder(tree, D);
    cellTypes = cellTypes(ord);
    meanZ     = meanZ(ord, :);
end

%% Remove cell types with no positive connections
hasConn   = any(meanZ > 0, 2);
cellTypes = cellTypes(hasConn);
meanZ     = meanZ(hasConn, :);
nCT       = numel(cellTypes);

if nCT == 0
    fig = figure('Color', 'w');
    axis off;
    title(titleStr, 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'tex');
    text(0.5, 0.5, 'No significant connections found.', ...
        'HorizontalAlignment', 'center', 'Units', 'normalized');
    return;
end

%% Scale factor: max ribbon half-width = 0.01 (matches original)
maxHW   = 0.01;
scaleHW = maxHW / max(meanZ(:));

%% Layout coordinates
xLeft  = 0;   xRight = 1;
yLeft  = linspace(0.08, 0.92, nCT);    % slightly reduced range for less spacing
yRight = linspace(0.15, 0.85, nB);

totalLeft  = sum(meanZ * scaleHW, 2);   % total stacked ribbon height per CT
totalRight = sum(meanZ * scaleHW, 1)';  % total stacked ribbon height per behavior

% Resolve vertical overlaps between right nodes (bottom-to-top sweep)
minGap = 0.02;   % minimum gap between adjacent right-node edges
for b = 2:nB
    prevTop = yRight(b-1) + totalRight(b-1)/2;
    curBot  = yRight(b)   - totalRight(b)/2;
    if curBot < prevTop + minGap
        yRight(b) = prevTop + minGap + totalRight(b)/2;
    end
end
% If the top node was pushed beyond the plot limits, shift all right nodes down
if nB > 0 && (yRight(nB) + totalRight(nB)/2) > 1.05
    overshoot = (yRight(nB) + totalRight(nB)/2) - 1.05;
    yRight    = yRight - overshoot;
end

%% ── Main Sankey figure ───────────────────────────────────────────────────────
fig  = figure('Color', 'w', 'Position', [600 100 900 1000]);
ax   = axes('Position', [0.22 0.05 0.56 0.90]);
hold on; axis off;
ax.XLim = [-0.05 1.35];
ax.YLim = [-0.05 1.05];

leftFill  = zeros(nCT, 1);
rightFill = zeros(nB,  1);

% Draw ribbons (one per cell-type × behavior pair with weight > 0)
for b = 1:nB
    for c = 1:nCT
        hw = meanZ(c, b) * scaleHW;
        if hw == 0 || meanZ(c, b) <= 0, continue; end

        % Stack bottom-to-top at left node
        ly0          = yLeft(c)  - totalLeft(c)/2  + leftFill(c);
        ly1          = ly0 + hw;
        leftFill(c)  = leftFill(c) + hw;

        % Stack bottom-to-top at right node
        ry0           = yRight(b) - totalRight(b)/2 + rightFill(b);
        ry1           = ry0 + hw;
        rightFill(b)  = rightFill(b) + hw;

        % Cubic Bézier S-curve ribbon
        t    = linspace(0, 1, 80);
        s    = t .^ 2 .* (3 - 2 * t);   % smoothstep
        yTop = ly1 + s .* (ry1 - ly1);
        yBot = ly0 + s .* (ry0 - ly0);

        fill([t, fliplr(t)], [yTop, fliplr(yBot)], behavColors(b, :), ...
            'EdgeColor', 'none', 'FaceAlpha', 0.55);
    end
end

% Left node bars (cell types)
nodeW = 0.012;
for c = 1:nCT
    hw = totalLeft(c) / 2;
    rectangle('Position', [xLeft - nodeW, yLeft(c) - hw, nodeW, totalLeft(c)], ...
        'FaceColor', [0.3 0.3 0.3], 'EdgeColor', 'none');
    text(xLeft - nodeW - 0.01, yLeft(c), cellTypes{c}, ...
        'HorizontalAlignment', 'right', 'FontSize', 12, 'Color', 'k');
end

% Right node bars (behaviors)
for b = 1:nB
    hw = totalRight(b) / 2;
    if hw <= 0, continue; end
    rectangle('Position', [xRight, yRight(b) - hw, nodeW, totalRight(b)], ...
        'FaceColor', behavColors(b, :), 'EdgeColor', 'none');
    text(xRight + nodeW + 0.01, yRight(b), strrep(behaviors{b}, '_', ' '), ...
        'HorizontalAlignment', 'left', 'FontSize', 12, 'FontWeight', 'bold', ...
        'Color', behavColors(b, :));
end

title(titleStr, 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'tex');

%% ── Ribbon-width legend (inset axes, lower-right of main figure) ─────────────
% Fixed reference probability values.
legendProbs = [0.10 0.25 0.50 0.75 1.00];
nLeg        = numel(legendProbs);

leg_pos = [0.80 0.03 0.17 0.24];
ax_l = axes('Parent', fig, 'Position', leg_pos);
hold(ax_l, 'on');
axis(ax_l, 'off');
ax_l.XLim = [0 1];
ax_l.YLim = [0 1];

% hw_scale converts a full ribbon height in Sankey data-coords to legend
% data-coords so the visual thickness is identical in both axes.
% The /2 accounts for the legend ribbon being drawn symmetrically around ly
% (from ly-lhw to ly+lhw, total = 2*lhw), whereas Sankey ribbons are drawn
% from ly0 to ly0+hw (total = hw).
sankey_ppu = ax.Position(4) / diff(ax.YLim);    % Sankey axes
leg_ppu    = leg_pos(4)     / diff(ax_l.YLim);  % legend axes
hw_scale   = sankey_ppu / leg_ppu;

lx0  = 0.05;  lx1 = 0.60;
lgap = 0.70 / nLeg / 2;   % half-spacing between entries

for k = 1:nLeg
    ly  = 0.12 + (k - 0.5) * lgap;
    lhw = legendProbs(k) * scaleHW * hw_scale / 2;
    fill([linspace(lx0, lx1, 40), linspace(lx1, lx0, 40)], ...
         [repmat(ly + lhw, 1, 40), repmat(ly - lhw, 1, 40)], ...
         [0 0 0], 'EdgeColor', 'none', 'FaceAlpha', 0.6, 'Parent', ax_l);
    text(lx1 + 0.06, ly, sprintf('%.2f', legendProbs(k)), ...
        'FontSize', 14, 'VerticalAlignment', 'middle', 'Parent', ax_l);
end

text(0.5, 0.6, 'p(behavior)', 'HorizontalAlignment', 'center', ...
    'FontSize', 14, 'FontWeight', 'bold', 'Parent', ax_l);

end
