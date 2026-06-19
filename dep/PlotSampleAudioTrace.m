function [] = PlotSampleTrace_SMS2(wavfile, timewindow)
% PLOTSAMPLETRACE plots aligned LED time series and audio colored by classification for specified
% Time window (seconds):

%% Load Data of Interest

%addpath(genpath('/Users/otopalika/Documents/GitHub/P1ScreenAnalysis')); %this is on adriane's computer...
[pathstr,wavname, ext] = fileparts(wavfile);
addpath(char(pathstr))
cd(char(pathstr))
folder = fullfile(wavfile, '..'); %parent folder of wavfile (experimental set)
filetype = fullfile(folder, '*.wav');
files = dir(char(filetype));
nfiles = length(files);

% Identify LED Channel and Signal:
for i = 1:nfiles
    if strfind(files(i).name, '_LED1')
        LED1_ind = i;
    end
end
[LED1,fs] = audioread(fullfile(files(LED1_ind).folder,files(LED1_ind).name));

% Identify Audio Channel and Signal:
rawsignal_ind = [];
for i = 1:nfiles
    if strfind(files(i).name, wavname)
        rawsignal_ind = i;
    end
end
if isempty(rawsignal_ind)
    error('PlotSampleAudioTrace: no WAV file matching "%s" found in:\n  %s', wavname, char(folder));
end
[raw,fs] = audioread(fullfile(files(rawsignal_ind).folder,files(rawsignal_ind).name));

% time vector:
t = [1:length(LED1)]./fs;

%% Plot a channel of interest aligned with LED1 (red) and classifications:
for i=rawsignal_ind %numfiles
    if files(i).isdir
        % Skip . and .. 
        continue;
    end
    fullFileName = fullfile(files(i).folder,files(i).name);
    %display(['Processing ', wavname '...']);
    [song,fs]=audioread(fullFileName);
end

% Add title that is just the date_channel_line:
[folderName, baseFileNameNoExt, extension] = fileparts(files(rawsignal_ind).name);

%% Now get classifiers for channel of interest:

%folder = pathstr'/Volumes/otopaliklab/BehaviorData/SongTorrent_Sternlab_Rig/3Classified/P1/20240701set1';
filetype = fullfile(folder, '*.csv');
files = dir(filetype);
nfiles = length(files);
% Load Classifications for this channel:
for i = 1:nfiles
    if strfind(files(i).name, baseFileNameNoExt)
        classifiers_ind = i;
    end
end
C = readtable(fullfile(folder, files(classifiers_ind).name)); % load .csv
% rid of dashes in predicted classes
for i = 1:length(C.Var5)
    C.Var5(i) = erase(C.Var5(i),'-');
end


% determine which bouts are which classes:

%initialize:
sine_temp = zeros(length(C.Var5),1);
pulse_temp = zeros(length(C.Var5),1);
ambient_temp = zeros(length(C.Var5),1);
other_temp = zeros(length(C.Var5),1);

for i = 1:length(C.Var5)
    if cell2mat(strfind(C.Var5(i), 'melsine')) == 1
        sine_temp(i) = 1;
    end
    if cell2mat(strfind(C.Var5(i), 'melpulse')) == 1
        pulse_temp(i) = 1;
    end  
    if cell2mat(strfind(C.Var5(i), 'ambient')) == 1
        ambient_temp(i) = 1;
    end
    if cell2mat(strfind(C.Var5(i), 'other')) == 1
        other_temp(i) = 1;
    end
end

% These are the rows in the .csv that correspond with the different
% classes:

sine_inds = find(sine_temp == 1);
pulse_inds = find(pulse_temp == 1);
ambient_inds = find(ambient_temp == 1);
other_inds = find(other_temp == 1);


% Initialize binary vectors with zeros:
songlabels = {'sine', 'pulse', 'ambient','other'};
binary_vectors = struct();

for i = 1:length(songlabels)
    binary_vectors.(songlabels{i}) = zeros(length(LED1), 1);
end


% Generate binary vectors for each class efficiently
indices = {sine_inds, pulse_inds, ambient_inds, other_inds};

for j = 1:length(songlabels)
    for i = 1:length(indices{j})
        binary_vectors.(songlabels{j})(C.Var2(indices{j}(i)):C.Var3(indices{j}(i))) = 1;
    end
end

%initialize pulse- and sine-only vectors:
pulse_vector = NaN(length(raw),1);
sine_vector = NaN(length(raw),1);
clean_raw_vector = raw;
other_inds = find(binary_vectors.other == 1);
ambient_inds = find(binary_vectors.ambient == 1);
p_inds = find(binary_vectors.pulse == 1);
s_inds = find(binary_vectors.sine == 1);

% build vectors:
for i = 1:length(p_inds)
    pulse_vector(p_inds(i),1) = raw(p_inds(i));
end
for i = 1:length(s_inds)
    sine_vector(s_inds(i),1) = raw(s_inds(i));
end
% clean up raw now:
% for i = 1:length(ambient_inds)
%     clean_raw_vector(ambient_inds(i),1) = NaN;
% end
for i = 1:length(other_inds)
    clean_raw_vector(other_inds(i),1) = 0;
end
%figure
%tiledlayout(2,1,'TileSpacing','loose')

%% Get actual LED power/area using measured calibration curve:

% During LED Pulses:
[LED_bouts, LED_durs] = detect_binarybouts(LED1);
%LEDLevels = round([LED1(LED_bouts(:,1)+10)],3); % Percents?
%LEDIntensities = [3.918918919, 3.918918919, 4.054054054, 4.189189189, 4.189189189,4.324324324,4.324324324,4.459459459,4.459459459,4.594594595,4.6,4.72972973]; % mW/cm^2
LEDIntensities = [3 5 10 15 20 25 30 35 40 50 60 70 80 90 100];
LEDPowers = [0
0.0270270270000000
0.0675675680000000
0.108108108000000
0.148648649000000
0.189189189000000
0.216216216000000
0.256756757000000
0.297297297000000
0.337837838000000
0.378378378000000
0.418918919000000
0.459459459000000
0.500000000000000
0.540540541000000
0.581081081000000
0.770270270000000
0.972972973000000
1.17567567600000
1.36486486500000
1.56756756800000
1.75675675700000
1.94594594600000
2.14864864900000
2.33783783800000
2.52702702700000
2.71621621600000
2.89189189200000
3.08108108100000
3.25675675700000
3.44594594600000
3.62162162200000
3.79729729700000];

LEDPct = [0
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
20
25
30
35
40
45
50
55
60
65
70
75
80
85
90
95
100];
LED_powers = [0.5*ones(1,20) ones(1,20) 2*ones(1,20) 3*ones(1,20) 4*ones(1,20)]; %
% fit relationship between LED power/area and Pct on controller:
P = polyfit(LEDPct,LEDPowers,1);
LEDPowers = P(1).*[LEDIntensities]+P(2);
% convert LED1 time series vector (in voltage) to power/area:
LED_vect = zeros(size(LED1));
for i = 1:length(LED_bouts)
    LED_vect(LED_bouts(i,1):LED_bouts(i,2)) = LED_powers(i);
end

%%
% nexttile
% plot(t,LED_vect,'k-', 'LineWidth', 1.2)
% xlim(timewindow)
% ylim([0 4])
% box off

%nexttile
plot(t,clean_raw_vector,'-','Color', [0 0 0 .8], 'LineWidth',1); hold on
plot(t, pulse_vector, 'r', 'LineWidth',1)
plot(t, sine_vector, 'b', 'LineWidth',1)
xlim(timewindow)
box off
ylim([-.25 .25])
%axis off
end