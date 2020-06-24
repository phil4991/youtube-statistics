%% YouTube data takeout statistics 2020-01-27

clear all; clc; close all;
%% parameter
DIR_LIST            = { 'data\TakeoutPhilipp_20200127\YouTube';
                        'data\TakeoutPhilipp_20200623\YouTube und YouTube Music';
                        'data\TakeoutMarc_20200201\YouTube';
                        'data\Takeout\YouTube'}
CURRENT_DIR         = 3
BUF_LEN_VIDEO       = 30
END_DATE            = '2014-11-01'        % yyyy-mm-dd or '' for None
MAX_CHANNEL_COUNT   = 10
SORT_BY             = 'NUMBER'  % NUMBER or NAME

%% import
tic
videohistoryFile = '\Verlauf\Wiedergabeverlauf.json';
searchhistoryFile = '\Verlauf\Suchverlauf.json';
files = {videohistoryFile, searchhistoryFile};

disp('loading files..')
video_data  = get_from_json([DIR_LIST{CURRENT_DIR},videohistoryFile]);
search_data = get_from_json([DIR_LIST{CURRENT_DIR},searchhistoryFile]);

% data table blueprint
cols = {'date', 'videoEntries', 'number_of_videoEntries', 'MA_nVEntries', 'searchEntries', 'number_of_searchEntries'};
data = table(   'Size', [1, length(cols)], ...
                'VariableNames', cols, ...
                'VariableTypes', ["datetime", "cell", "uint64", "double", "cell", "uint64"] );

start_date = time_from_datapoint(video_data{1, 1}); 
end_date = time_from_datapoint(video_data{end, 1});

if time_from_datapoint(search_data{1}) > start_date
    start_date = time_from_datapoint(search_data{1});
end
if time_from_datapoint(search_data{end}) < end_date
    end_date = time_from_datapoint(search_data{end});
end

if ~strcmp(END_DATE,'')
    end_date = datetime(END_DATE, 'InputFormat', 'yyyy-MM-dd');
    disp('custom end date!')
end

disp('getting daily statistics of videos..')
% initial values
datatable_buffer = {};

channel_data = {};

nSEntries = 0;
nVEntries_buffer = [];

[number_of_entriesV, ~] = size(video_data);
[number_of_entriesS, ~] = size(search_data);

m = 1;
date_dp_V = time_from_datapoint(video_data{m,1});
n = 1;
date_dp_S = time_from_datapoint(search_data{n,1});
date = start_date;
while end_date < date && date <= start_date
    i = 1;
    videoEntryList = struct('videoEntries', {},'channels', {}); 
    while date_dp_V == date && m < number_of_entriesV
        datapointV = video_data{m,1};
        try
                videoEntryList = [videoEntryList; struct('videoEntries', {datapointV.title},'channels', {datapointV.subtitles.name})]; 
        catch ME
                videoEntryList = [videoEntryList; struct('videoEntries', {'video_removed'},'channels', {'Channel_not_available'})]; 
        end
        
        date_dp_V = time_from_datapoint(datapointV);
        m = m+1; i = i+1;
    end
    
    channel_data = [channel_data; {videoEntryList.channels}'];
    
    searchEntryList = {};
    while date_dp_S == date && n < number_of_entriesS
        datapointS = search_data{n};
        date_dp_S = time_from_datapoint(datapointS);
        
        % fetch search entries
        searchEntryList = [searchEntryList; datapointS.title];
        
        n = n+1;
    end
    % get stats of current day
    nVEntries = length(videoEntryList);
    nSEntries = length(searchEntryList);

    % moving average of video count per day
    nVEntries_buffer = [nVEntries_buffer, nVEntries];
    if length(nVEntries_buffer) > BUF_LEN_VIDEO
        nVEntries_buffer(1) = [];
    end
    moving_avergage_nVEntries = sum(nVEntries_buffer)/length(nVEntries_buffer);
    
    % build table buffer
    newRow = {  date, ...
                videoEntryList, nVEntries, moving_avergage_nVEntries, ...
                searchEntryList, nSEntries};
    datatable_buffer = [datatable_buffer; newRow];
    
    date = date-1; % previous date
end
data = [data; datatable_buffer(2:end, :)];
size_data = size(data);

%% dataset stats
disp('getting dataset statistics..')

keywords = {};
titles = {};
for j = 2:size_data(1)
     title_buffer = data.videoEntries{j, 1};
     for k = 1:length(title_buffer)
         % split words of video title in cell array
%          words_in_title = split(, ' ');
         titles = [titles; lower(title_buffer(k,1).videoEntries)];
%          keywords = [keywords; lower(words_in_title(1:end-1, 1))];
     end
end

%% postprocessing 
disp('postprocessing history data..')

% daily data postprocessing
% #########################################################################
channel_data_ctg = categorical(channel_data);
unique_channels = categories(channel_data_ctg);
unique_channels_fltd = {};

channel_count = countcats(channel_data_ctg);
channel_count_fltd = [];

for i = 1:length(unique_channels)
    if strcmp(unique_channels(i,1), 'Channel_not_available')
        continue
    end
    if channel_count(i,1) > MAX_CHANNEL_COUNT
        channel_count_fltd = [channel_count_fltd; channel_count(i,1)];
        unique_channels_fltd = [unique_channels_fltd; unique_channels(i,1)];
    end
end

if strcmp(SORT_BY, 'NAME')
    [unique_channels_plot, sort_idx] = sort(unique_channels_fltd);
    channel_count_plot = channel_count_fltd(sort_idx);
elseif strcmp(SORT_BY, 'NUMBER')
    disp('sorting by number..')
    [channel_count_plot, sort_idx] = sort(channel_count_fltd);
    unique_channels_plot = unique_channels_fltd(sort_idx);
end

% dataset postprocessing
% #########################################################################
disp('postprocessing word cloud data..')
keywordsDoc = tokenizedDocument(titles);

% clean tokenzied data
keywordsDoc = removeStopWords(keywordsDoc);
keywordsDoc = erasePunctuation(keywordsDoc, 'TokenTypes', {'punctuation','other', 'digits', 'letters'});
keywordsDoc = removeShortWords(keywordsDoc, 2);
keywords_filtered = removeWords(keywordsDoc, ["angesehen", "videoremoved", "video", "official", "feat", "ft", "prod", "ep"]);


%% visulization & stats
disp('visualizing word cloud data..')
figure('Name','Title Analysis')
wordcloud(keywords_filtered);

disp('visualizing history data..')
figure('Name','Video History Analysis')
subplot(2, 3, [1 2]);
hold on
bar(data.date, data.number_of_videoEntries)
plot(data.date, data.MA_nVEntries)
hold off

title('YouTube-Videos per day')
legend('videos per day', sprintf('moving average (%d days)', BUF_LEN_VIDEO))
xlabel('date'); ylabel('number of YouTube videos per day') 

subplot(2, 3, [4 5])
bar(data.date, data.number_of_searchEntries)
title('YouTube-Searches per day')
xlabel('date'); ylabel('number of YouTube-Searches per day')

subplot(2, 3, [3 6])
bar_labels = categorical(unique_channels_plot, unique_channels_plot);

hold on
% barh(bar_labels, channel_count_plot);
for i = 1:length(channel_count_plot)
    bax=barh(bar_labels(i),channel_count_plot(i));
    if channel_count_plot(i) > 0.9*max(channel_count_plot)
        set(bax,'FaceColor','k');
    else
        set(bax,'FaceColor','b');
    end
end
hold off

set(gca, 'FontSize', 5)
xlabel('number of videos'); ylabel('channel name')
title(sprintf('YouTube Channels (min. %d)', BUF_LEN_VIDEO), 'FontSize', 'default')

toc
% backup_fig(gcf, 'YTPerDayAnalysis', mfilename )

%% functions
function [date, date_time] = time_from_datapoint(datapoint)
    % extracts date and time from datestring
    % returns date and time as string

    time_str = datapoint.time;
    time_arr = split(time_str, ["T", "."]);
    
    time_cell = string(time_arr(1:2));
    [date, date_time] = time_cell{:};
    
    % conversion to type datetime
    date = datetime(date, 'InputFormat', 'yyyy-MM-dd');
end

function [data, number_of_entries] = get_from_json(fpath)
    % returns cell array with json data and number of entries
    %
    fid = fopen(fpath);
    file_data = fread(fid, inf);
    json_string = char(file_data');
    data = jsondecode(json_string);
    fclose(fid);
    
    if ~iscell(data)
        data = num2cell(data);
    end
    number_of_entries = size(data);
end
