%% YouTube data takeout statistics 2020-01-27

clear all; clc
%% parameter
DIR_LIST            = { 'TakeoutPhilipp_20200127';
                        'TakeoutMarc_20200201'}
CURRENT_DIR         = 2;
BUF_LEN_VIDEO       = 30;
END_DATE            = '' % yyyy-mm-dd or '' for None
MAX_CHANNEL_COUNT   = 30
SORT_BY             = 'NUMBER'

%% import
videohistoryFile = '\YouTube\Verlauf\Wiedergabeverlauf.json';
searchhistoryFile = '\YouTube\Verlauf\Suchverlauf.json';
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

if time_from_datapoint(search_data(1)) > start_date
    start_date = time_from_datapoint(search_data(1));
end
if time_from_datapoint(search_data(end)) < end_date
    end_date = time_from_datapoint(search_data(end));
end

if ~strcmp(END_DATE,'')
    end_date = datetime(END_DATE, 'InputFormat', 'yyyy-MM-dd');
    disp('custom end date!')
end

disp('getting statistics of videos..')
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
date_dp_S = time_from_datapoint(search_data(n));
date = start_date;
while end_date < date && date <= start_date
    videoEntryList = {};
    searchEntryList = {};
    while date_dp_V == date && m < number_of_entriesV
        datapointV = video_data{m,1};
        try
            datapointVsubt = datapointV.subtitles;
            % if ~any(strcmp(channel_data, datapointVsubt.name))
            channel_data = [channel_data; datapointVsubt.name];

        catch ME
            channel_data = [channel_data; 'video_removed'];
        end
        date_dp_V = time_from_datapoint(datapointV);
        
        % fetch video entries
        videoEntryList = [videoEntryList; datapointV.title];
        
        m = m+1;
    end
    
    while date_dp_S == date && n < number_of_entriesS
        datapointS = search_data(n);
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
    moving_avergage_nVEntries = sum(nVEntries_buffer)/BUF_LEN_VIDEO;
    
    % build table buffer
    newRow = {  date, ...
                videoEntryList, nVEntries, moving_avergage_nVEntries, ...
                searchEntryList, nSEntries};
    datatable_buffer = [datatable_buffer; newRow];
    
    date = date-1; % previous date
end
%% postprocessing 
disp('postprocessing data..')
data = [data; datatable_buffer(2:end, :)];

channel_data_ctg = categorical(channel_data);
unique_channels = categories(channel_data_ctg);
unique_channels_fltd = {};

channel_count = countcats(channel_data_ctg);
channel_count_fltd = [];

for i = 1:length(unique_channels)
    if strcmp(unique_channels(i,1), 'video_removed')
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
% else
%     unique_channels_plot = unique_channels_fltd;
%     channel_count_plot = channel_count_fltd;
end

%% visulization & stats
disp('visualizing data..')
clf
subplot(2, 3, [1 2]);

hold on
bar(data.date, data.number_of_videoEntries)
plot(data.date, data.MA_nVEntries)
hold off

title('Watched YouTube videos per day')
legend('videos per day', sprintf('moving average (%d days)', BUF_LEN_VIDEO))
xlabel('date'); ylabel('number of YouTube videos per day') 

subplot(2, 3, [4 5])
bar(data.date, data.number_of_searchEntries)
title('YouTube-Searched per day')
xlabel('date'); ylabel('number of YouTube-Searches per day')

subplot(2, 3, [3 6])
bax = barh(categorical(unique_channels_plot), channel_count_plot);
xlabel('number of videos'); ylabel('channel name')
set(gca, 'FontSize', 5)
% set(gca, 'LabelFontSizeMultiplier', 0.5)
title('YouTube Channels', 'FontSize', 'default')

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
    
    number_of_entries = size(data);
end
