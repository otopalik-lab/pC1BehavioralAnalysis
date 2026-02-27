% This script regenerates all of the plots that comprise Figure 5

%% Settings for Saving Plots:

SaveFormat = '.png'; %can change this as desired (see 'save' function in MATLAB for available formats'
SavePath = '/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis/results/figure5'; % can change as desired

%% Load Data and Metadata to for Base Workspace:

addpath(genpath('/Users/otopalika/Documents/GitHub/pC1BehavioralAnalysis'));
load('MaleMaleData_new.mat'); % load workspace with pre-generated data and randomly selected trials (SSinds) for each stable split line, for reproducible figures:
selectedLines = table2struct(readtable('SSLines_withCelltypes.csv')); % Load line and celltype lists
lines = {selectedLines.Var1}; lines = lines([1 3:35]);
celltypes = {selectedLines.Var2}; celltypes = celltypes([1 3:35])

%% Fig 5A: Example of LED stimulus-aligned rasters of unilateral wing events, aggression events, and interfly distance for one example chamber:

plot_behavior_fullTimeseries('SS102671',{'unilateralwing', 'aggression'})

%% Figure 5B: Plot LED stimulus-aligned rasters, PSTHs, and Inter-fly Distances for Selected Lines

plot_behavior_STA('Empty Split',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS03661',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS03661',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS106638',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS102671',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS100424',{'unilateralwing', 'aggression'});
plot_behavior_STA('SS59911',{'unilateralwing', 'aggression'});

%% Figure 5C: Heatmaps of behavioral probabilities over time across all pC1 SS Lines for selected behavioral classes:

binsize = 1000; %in milliseconds
plot_PSTH_heatmap('all','proximal', binsize) %'proximal is equivalent to 'close' in the paper
plot_PSTH_heatmap('all','unilateralwing', binsize)  
plot_PSTH_heatmap('all','aggression',binsize)  

%% Figure 5D: 2-bin (30-sec each) Heatmaps of behavioral probabilities with p-value annotations all pC1 SS Lines for selected behavioral classes:

plot_2bin_heatmap('all','proximal') %'proximal is equivalent to 'close' in the paper
plot_2bin_heatmap('all','unilateralwing')
plot_2bin_heatmap('all','aggression')

%% Figure 5E: Sankey Diagrams for LED Stimulation and Post-Stimulation Periods:

% new change here


% Below is to train Claude:

%% Generate Behavioral Probilities for Sankey Diagram

% LED EPOCHS:
[LED_epochs,LED_durs] = detect_binarybouts(MaleMaleData(1).LED);
% Append a baseline period and generate stimulus and post-stimulus:
LED_on_epochs = [3600 5400; LED_epochs]; 
LED_off_epochs = [3600 5400; LED_epochs+1800]; 


% Classifiers to include in the heatmap:

% Selected (Main Figure):
%classifier_list = [find(strcmp(fieldNames,'aggression'))]; 

%classifier_list = [find(strcmp(fieldNames,'proximal')), find(strcmp(fieldNames,'unilateralwing')) find(strcmp(fieldNames,'aggression'))]% find(strcmp(fieldNames,'unilateralwing')) find(strcmp(fieldNames,'aggression'))];% find(strcmp(fieldNames,'aggression')) ]
classifier_list =   [find(strcmp(fieldNames,'proximal')), find(strcmp(fieldNames,'notmoving')), find(strcmp(fieldNames,'pursuit')),...
    find(strcmp(fieldNames,'approach')), find(strcmp(fieldNames,'fixation')), find(strcmp(fieldNames,'unilateralwing')), find(strcmp(fieldNames,'wingflick')), find(strcmp(fieldNames,'aggression')), find(strcmp(fieldNames,'boxing')), find(strcmp(fieldNames,'headbutt')), find(strcmp(fieldNames,'tussle'))];

colormap_choice = (flipud(gray));
binsize = 30000;
numbins = 60000/binsize;

% DEFINE LED EPOCHS:
[LED_epochs,LED_durs] = detect_binarybouts(MaleMaleData(1).LED);
% % Append a baseline period and generate stimulus and post-stimulus:
LED_epochs = [3600 5400; LED_epochs]; 
window = length(LED_epochs(1,1):LED_epochs(1,2)+30*FPS);

% Initialize 

clear xlabel_list significant_lines_allbehaviors_LEDOFF significant_lines_allbehaviors_LEDON behav_probs_LEDON behav_probs_LEDOFF
counter = 1;
sig_pvals_mat = zeros(33, length(classifier_list)*2); %initialize matrix for p value annotations!

for b = classifier_list 
    
    %Initialize output matrices:
    LEDon_mat = NaN(17,34); %for PSTH method 17, for Pct Time method 51
    LEDoff_mat = NaN(17,34);
    

    SS_PSTHs_allLines = []; %initialize matrix to hold psth across lines;
    clear significant_lines;
    for i= 1:34 % loop through lines
        event_times_all = []; % initialize vector to hold event times for that behavioral classifier        
        SS_byfly_PSTHs_all = [];
        pcttime_bytrial_on = [];
        pcttime_bytrial_off = [];
        for k = 1:17 % get 17 trials for each line (some lines only have 17)
            ind = SSinds(i,k); % each ind is a trial
            event_times_byfly = [];
            for j = LEDStims % loop through stimuli 5 to 7 (higher LED powers)
               behav_temp = MaleMaleData(ind).(fieldNames{b});
               
               % Uncomment for Percent Time Method
               % allframes_on = find(behav_temp(LED_epochs(j,1):LED_epochs(j,2))==1); % LED ON
               % allframes_off = find(behav_temp(LED_epochs(j,2):LED_epochs(j,2)+30*FPS)==1); % LED OFF
               % nframes_on = length(allframes_on);
               % nframes_off = length(allframes_off);
               % pcttime_on = (nframes_on/length(LED_epochs(j,1):LED_epochs(j,2)));
               % pcttime_off = (nframes_off/length(LED_epochs(j,2):LED_epochs(j,2)+30*FPS));
               % pcttime_bytrial_on = [pcttime_bytrial_on; pcttime_on];
               % pcttime_bytrial_off = [pcttime_bytrial_off; pcttime_off];

               % Uncomment if want to do PSTH method
               event_times= find(behav_temp(LED_epochs(j,1):LED_epochs(j,2)+30*FPS)==1); % choose 60 window starting at LED onset, to 30s after LED offset
               event_times_all = [event_times_all event_times]; 
               event_times_byfly = [event_times_byfly event_times];
            end 
            
            % Uncomment for PSTH Method:
            [SS_byfly_psth_temp,edges] = psth(event_times_byfly,binsize,60,3,window);
            SS_byfly_PSTHs_all(k,:) = SS_byfly_psth_temp; % mean PSTH for 17 flies for a given line
        end
        % Split LED on and LED off into separate matrices for
        % statistics:
        % for PSTH method, uncomment:
        LEDon_mat(:,i) = SS_byfly_PSTHs_all(:,1);
        LEDoff_mat(:,i) = SS_byfly_PSTHs_all(:,2);
        [SS_psth_temp,edges] = psth(event_times_all,binsize,60,17*3,window);% mean PSTH for a line
        SS_PSTHs_allLines(i,:) = SS_psth_temp./60; % mean PSTHs for each line
        
        % Uncomment for Percent Time Method
        % LEDon_mat(:,i) = pcttime_bytrial_on;
        % LEDoff_mat(:,i) = pcttime_bytrial_off;
    end
    
    % Build probability matrices for Sankey Diagram:

    behav_probs_LEDON(:,counter) = SS_PSTHs_allLines(:,1);
    behav_probs_LEDOFF(:,counter) = SS_PSTHs_allLines(:,2);
    counter = counter+1;

end

%% Prep Data for Sankey Diagram (use p(behaviors) and only include sig p values):

classifier_list =   [find(strcmp(fieldNames,'proximal')), find(strcmp(fieldNames,'notmoving')), find(strcmp(fieldNames,'pursuit')),...
    find(strcmp(fieldNames,'approach')), find(strcmp(fieldNames,'fixation')), find(strcmp(fieldNames,'unilateralwing')), find(strcmp(fieldNames,'wingflick')), find(strcmp(fieldNames,'aggression')), find(strcmp(fieldNames,'boxing')), find(strcmp(fieldNames,'headbutt')), find(strcmp(fieldNames,'tussle'))];



%LED ON
clear links
counter = 1;
for i = 1:length(classifier_list)
    sig_lines_byclass = cell2mat(significant_lines_allbehaviors_LEDON(i));
    for j = 1:length(sig_lines_byclass)
        sig_line_num = sig_lines_byclass(j);
        links{counter,1} = char(labels(sig_line_num));
        links{counter,2} = char(fieldNames(classifier_list(i)));
        links{counter,3} = behav_probs_LEDON(sig_line_num,i);
        counter = counter+1;
    end
end

cxn_array = links;
save('allBehaviors_LEDON_p01_cxn_array.mat', 'cxn_array')

%LED OFF
clear links
counter = 1;
for i = 1:length(classifier_list)
    sig_lines_byclass = cell2mat(significant_lines_allbehaviors_LEDOFF(i));
    for j = 1:length(sig_lines_byclass)
        sig_line_num = sig_lines_byclass(j);
        links{counter,1} = char(labels(sig_line_num));
        links{counter,2} = char(fieldNames(classifier_list(i)));
        links{counter,3} = behav_probs_LEDOFF(sig_line_num,i);
        counter = counter+1;
    end
end

cd '/Users/otopalika/Documents/GitHub/P1ScreenAnalysis/results/MaleMaleAssay/Revision_Figures/SankeyDiagrams'
cxn_array = links;
save('allBehaviors_LEDOFF_p01_cxn_array.mat', 'cxn_array')


%LED ON NORMALIZED 0-1:
rescaled_LEDON_mat = zeros(size(behav_probs_LEDON));
for i = 1:size(behav_probs_LEDON,2)
    rescaled_LEDON_mat(:,i) = rescale(behav_probs_LEDON(:,i));
end
clear links
counter = 1;
for i = 1:length(classifier_list)
    sig_lines_byclass = cell2mat(significant_lines_allbehaviors_LEDON(i));
    for j = 1:length(sig_lines_byclass)
        sig_line_num = sig_lines_byclass(j);
        links{counter,1} = char(labels(sig_line_num));
        links{counter,2} = char(fieldNames(classifier_list(i)));
        links{counter,3} = rescaled_LEDON_mat(sig_line_num,i);
        counter = counter+1;
    end
end

cxn_array = links;
save('allBehaviors_LEDON_p01_normalized_cxn_array.mat', 'cxn_array')

%LED OFF NORMALIZED 0-1:
rescaled_LEDOFF_mat = zeros(size(behav_probs_LEDOFF));
for i = 1:size(behav_probs_LEDOFF,2)
    rescaled_LEDOFF_mat(:,i) = rescale(behav_probs_LEDOFF(:,i));
end
clear links
counter = 1;
for i = 1:length(classifier_list)
    sig_lines_byclass = cell2mat(significant_lines_allbehaviors_LEDOFF(i));
    for j = 1:length(sig_lines_byclass)
        sig_line_num = sig_lines_byclass(j);
        links{counter,1} = char(labels(sig_line_num));
        links{counter,2} = char(fieldNames(classifier_list(i)));
        links{counter,3} = rescaled_LEDOFF_mat(sig_line_num,i);
        counter = counter+1;
    end
end


cd '/Users/otopalika/Documents/GitHub/P1ScreenAnalysis/results/MaleMaleAssay/Revision_Figures/SankeyDiagrams'
cxn_array = links;
save('allBehaviors_LEDOFF_p01_normalized_cxn_array.mat', 'cxn_array')

%% Define raw data from workspace:

load('allBehaviors_LEDOFF_p01_cxn_array.mat');
raw = cxn_array;

%% --- COLORS & BEHAVIORS ---
behaviors   = {'proximal', 'notmoving', 'pursuit', 'approach', 'fixation', 'unilateralwing', 'wingflick', 'boxing','headbutt', 'tussle'};
behavColors = [0.9961 0.3804 0.0000;
               0.2745 0.3922 1.0000;
               0.8627 0.1490 0.4980;
               0.0000, 0.7490, 0.6863;
               0.9843, 0.7647, 0.0000;
               0.5569, 0.1686, 0.8863;
               0.4706, 0.8235, 0.0863;
               0.9412, 0.1765, 0.1765;
               0.2000, 0.7216, 0.9608;
               0.9608, 0.7020, 0.2314];

%behaviors   = {'wing extensions', 'aggression'};
%behavColors = [0.2745 0.3922 1.0000;
%               0.8627 0.1490 0.4980];

%% --- COMPUTE MEAN Z-SCORE PER (celltype, behavior) ---
srcs   = raw(:,1);
tgts   = raw(:,2);
zscores = cell2mat(raw(:,3));

cellTypes = unique(srcs, 'stable');
% Get unique cell types
%cellTypes = unique(srcs);

% Fill z-score matrix directly from raw data
nCT = numel(cellTypes);
nB  = numel(behaviors);
meanZ = zeros(nCT, nB);   % rows = cell types, cols = behaviors
for i = 1:numel(srcs)
    ci = strcmp(cellTypes, srcs{i});
    bi = strcmp(behaviors, tgts{i});
    meanZ(ci, bi) = zscores(i);
end

%% --- SORT CELL TYPES BY PROFILE SIMILARITY (hierarchical clustering) ---
% Use correlation distance on the meanZ profiles; fall back to Euclidean
% if a cell type has all-zero entries (not connected to any behavior)
zNorm = meanZ;
rowNorms = sqrt(sum(zNorm.^2, 2));
zeroRows = rowNorms == 0;
zNorm(~zeroRows,:) = zNorm(~zeroRows,:) ./ rowNorms(~zeroRows);

D    = pdist(zNorm, 'euclidean');
tree = linkage(D, 'average');
ord  = optimalleaforder(tree, D);   % minimizes adjacent-leaf distance

cellTypes = cellTypes(ord);
meanZ     = meanZ(ord, :);


%% --- THRESHOLD ---
zThresh = 0;   % connections with z-score below this will not be plotted

% Remove cell types with no connections above threshold
hasConn = any(meanZ >= zThresh, 2);
cellTypes = cellTypes(hasConn);
meanZ     = meanZ(hasConn, :);
nCT       = numel(cellTypes);

%% --- LAYOUT ---
% Scale factor: max ribbon half-width in y-units
maxHW   = 0.01;   % max half-width of a ribbon
scaleHW = maxHW / max(meanZ(:));

xLeft  = 0;   % x position of cell type nodes
xRight = 1;   % x position of behavior nodes

% Y positions: evenly spaced
yLeft  = linspace(0, 1, nCT);   % one per cell type
yRight = linspace(0.15, 0.85, nB); % one per behavior

%% --- DRAW DENDROGRAM IN SEPARATE FIGURE ---
% figure('Color','w','Position',[100 100 400 1000]);
% ax_d = axes('Position',[0.05 0.05 0.60 0.90]);
% dendrogram(tree, 0, 'Orientation','left', 'Reorder', ord);
% ax_d.YDir = 'reverse';
% set(ax_d,'XDir','reverse','TickDir','out','FontSize',8);
% xlabel('Distance');
% Replace numeric leaf labels with cell type names
% ax_d.YTickLabel = cellTypes(str2double(ax_d.YTickLabel));

%% --- DRAW SANKEY ---
figure('Color','w','Position',[600 100 900 1000]);
ax = axes('Position',[0.22 0.05 0.56 0.90]); hold on; axis off;
ax.XLim = [-0.05 1.35];
ax.YLim = [-0.05 1.05];

% Track current vertical fill position for each node (to stack ribbons)
leftFill  = zeros(nCT, 1);   % offset tracker for left side of each CT node
rightFill = zeros(nB, 1);    % offset tracker for right side of each behavior node

% Pre-compute total ribbon height at each node to center stacks
totalLeft  = sum(meanZ * scaleHW, 2);   % per cell type
totalRight = sum(meanZ * scaleHW, 1)';  % per behavior

% Draw ribbons
for b = 1:nB
    for c = 1:nCT
        hw = meanZ(c,b) * scaleHW;
        if hw == 0 || meanZ(c,b) < zThresh, continue; end

        % Left node: center at yLeft(c), stack ribbons
        ly0 = yLeft(c)  - totalLeft(c)/2  + leftFill(c);
        ly1 = ly0 + hw;
        leftFill(c) = leftFill(c) + hw;

        % Right node: center at yRight(b), stack ribbons
        ry0 = yRight(b) - totalRight(b)/2 + rightFill(b);
        ry1 = ry0 + hw;
        rightFill(b) = rightFill(b) + hw;

        % Bezier ribbon via many x-slices
        t   = linspace(0, 1, 80);
        xB  = t;  % x goes from 0 to 1
        % smooth S-curve via cubic Bezier x-control
        s   = t.^2 .* (3 - 2*t);   % smoothstep

        yTop = ly1 + s .* (ry1 - ly1);
        yBot = ly0 + s .* (ry0 - ly0);

        col = behavColors(b,:);
        fill([xB, fliplr(xB)], [yTop, fliplr(yBot)], col, ...
            'EdgeColor','none','FaceAlpha',0.55);
    end
end

% Draw node bars (left: cell types)
nodeW = 0.012;
for c = 1:nCT
    hw = totalLeft(c)/2;
    rectangle('Position',[xLeft-nodeW, yLeft(c)-hw, nodeW, totalLeft(c)], ...
        'FaceColor',[0.3 0.3 0.3],'EdgeColor','none');
    text(xLeft - nodeW - 0.01, yLeft(c), cellTypes{c}, ...
        'HorizontalAlignment','right','FontSize',8,'Color','k');
end

% --- (dendrogram drawn in separate figure above) ---

% Draw node bars (right: behaviors)
for b = 1:nB
    hw = totalRight(b)/2;
    rectangle('Position',[xRight, yRight(b)-hw, nodeW, totalRight(b)], ...
        'FaceColor', behavColors(b,:),'EdgeColor','none');
    text(xRight + nodeW + 0.01, yRight(b), behaviors{b}, ...
        'HorizontalAlignment','left','FontSize',10,'FontWeight','bold', ...
        'Color', behavColors(b,:));
end

% Legend
for b = 1:nB
    fill(nan, nan, behavColors(b,:), 'FaceAlpha',0.55, 'EdgeColor','none', ...
        'DisplayName', behaviors{b});
end
% legend('Location','southoutside','Orientation','horizontal','FontSize',9, ...
%     'Box','off');

title('LED ON: Cell Type Contributions to Behavioral Outputs', ...
    'FontSize',12,'FontWeight','bold');


%% Thickness legend in separate figure
% Match Sankey figure height (1000px) and axes proportion (0.90) so that
% 1 normalized y-unit = same number of pixels as in the Sankey axes
figure('Color','w','Position',[1100 100 200 1000]);
ax_leg = axes('Position',[0.05 0.05 0.90 0.90]); hold on; axis off;
ax_leg.XLim = [0 1];
ax_leg.YLim = [0 1];

legendZ  = [1 2 3 4 5 6];
nLeg     = numel(legendZ);
lgap     = 1 / (nLeg + 1);
lx0      = 0.05; lx1 = 0.55;

for k = 1:nLeg
    lhw = legendZ(k) * scaleHW;
    ly  = k * lgap;
    t   = linspace(0,1,40);
    fill([linspace(lx0,lx1,40), linspace(lx1,lx0,40)], ...
         [repmat(ly+lhw,1,40), repmat(ly-lhw,1,40)], [0 0 0], ...
         'EdgeColor','none','FaceAlpha',0.6,'Parent',ax_leg);
    text(lx1 + 0.05, ly, sprintf('z = %d', legendZ(k)), ...
        'FontSize',8,'VerticalAlignment','middle','Parent',ax_leg);
end
text(0.05, (nLeg+0.8)*lgap, 'z-score', ...
    'FontSize',9,'FontWeight','bold','Parent',ax_leg);

title('Cell Type Contributions to Behavioral Outputs')






%%





%% Plotting Dependencies and Parameters for Grouped Data:

% Get FieldNames
fieldNames = fieldnames(MaleMaleData); % Get FieldNames from struct:

% Get FPS:
FPS = MaleMaleData(1).FPS;

% Use 3 Highest LED Powers in assay for PSTH and Raster plots
LEDStims = [5:7]; % Stimulus periods to include (these are the three highest LED powers in the assay)

% Make Labels with SS line | Cell Types Format:
for i = 1:34 
    labels{i} = ([lines{i} ' | ' celltypes{i}]);
end

% Detect Epochs when LED on:
[LED_epochs,LED_durs] = detect_binarybouts(MaleMaleData(1).LED);
% Append a baseline period and generate stimulus and post-stimulus:
LED_on_epochs = [3600 5400; LED_epochs]; 

% List of randomly select 17 trials for each SS line
[m,numTrials] = size(SSinds); %indicies associated with each SS line (17 trials per line selected at random)





%% Figure 5B: Plot LED stimulus-aligned rasters, PSTHs, and Inter-fly Distances for Selected Lines

color_list = {'#648FFF', '#DC267F','#FE6100'};
classifier_list = [find(strcmp(fieldNames,'unilateralwing')) find(strcmp(fieldNames,'aggression')) ];


line_counter = 1;
for line_idx = [1 2 18 19 23 26 34]
counter = 1;
f=figure; clf
f.Position = [200*line_counter, 700, 200, 500]; 
for b = classifier_list
event_times_all = [];
%initalize counters:
for i = line_idx  
    p = 1;
    subplot(4,1,counter)
    for k = 1:numTrials % num trials for each line (I think)
        
        ind = SSinds(i,k); % to access one trial for that line
        for j = LEDStims            
           window = (LED_on_epochs(j,1)-30*60:LED_on_epochs(j,2)+30*60);
           behav_temp = MaleMaleData(ind).(fieldNames{b});         
           behav_temp = behav_temp(window); % only consider during specified peri-stimulus window
           event_times = [find(behav_temp == 1)]; %LED starts at 52200
           
            if p == 1
                area([30 60], [50 50], 'FaceColor', [0 0 0], 'FaceAlpha', 0.1, 'LineStyle', 'none'); hold on
            end
            hold on;
            plot(event_times./FPS, p*ones(length(event_times),1), '|', 'MarkerFaceColor', color_list{counter},'MarkerEdgeColor', color_list{counter}, 'MarkerSize', 1); hold on
            ylabel([fieldNames(b)], 'FontSize', 14)
            ylim([0 50])
            xlim([0 length(behav_temp)/FPS])
            event_times_all = [event_times_all event_times];
            p = p+1;
        end        
    end 
end
subplot(4,1,3)
if counter == 1
    area([30 60], [50 50], 'FaceColor', [0 0 0], 'FaceAlpha', 0.1, 'LineStyle', 'none'); hold on
end
[d,edges] = psth(event_times_all,500,60,p-1,length(window)); 
area(edges./1000, d./60,'FaceColor', color_list{counter}, 'EdgeColor', color_list{counter}, 'FaceAlpha', 0.2, 'LineWidth',1.5); hold on   
xlim([0 length(window)/FPS])
ylabel('P(Behavior)', 'FontSize', 14)
ylim([0 1])
%xlabel('Time (s)', 'FontSize', 14)
box off
counter = counter+1;
subplot(4,1,1); title(labels(line_idx))
end
for m = 1:2
    subplot(4,1,m)
    axis off
    box off
end

% Plot Inter-fly distance:
dist_traces = [];% traces span from LED start to 90 sec after LED
    for k = 1:17
        SS_mat = [];
        for j = LEDStims
           ind = SSinds(i,k);
           temp = MaleMaleData(ind).dist_ctr(:,LED_on_epochs(j,1)-30*60:LED_on_epochs(j,2)+30*60);
           SS_mat = [SS_mat; temp];
        end
        dist_traces = [dist_traces; SS_mat];
    end
subplot(4,1,4)
area([30 60], [50 50], 'FaceColor', [0 0 0], 'FaceAlpha', 0.1, 'LineStyle', 'none'); hold on
shplot((1:length(dist_traces))./60, mean(dist_traces), std(dist_traces)/sqrt(length(LEDStims)*17), 'Color', '#FE6100')
ylim([0 20])
xlim([0 90])
plot([0 90], [6 6], 'k--', 'LineWidth',1)
box off
ylabel('Distance (mm)', 'FontSize',14)
linename = (char(lines(i)));
cellname = char(celltypes(i)); cellname = erase(cellname, "\"); cellname = erase(cellname, " "); cellname = erase(cellname, ",");

if SavePlots
    cd(SavePath)
    saveas(f,[linename '_' cellname '_AlignedTimeseries_RastersPSTHDistance' SaveFormat])
end

line_counter = line_counter+1;

end  
%% Figure 5C: LED Stimulus-Aligned PSTH Heatmaps (1-sec bins) for Close, Wing Extension, and Aggression Behavioral Classes:







%% Figure 5C: LED ON/OFF (30-sec bins) PSTH Heatmaps with p-value annotations for Close, Wing Extension, and Aggression Behavioral Classes:








%% Figure 5D: Sankey Diagram forClose, Wing Extension, and Aggression Behavioral Classes: