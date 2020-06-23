%% YouTube data takeout statistics 2020-01-27

clear all; close all; clc
%% parameter
directory = {'TakeoutPhilipp_20200127'}
current_dir = 1;

%% import
videohistoryFile = '\YouTube\Verlauf\Wiedergabeverlauf.json';
searchhistoryFile = '\YouTube\Verlauf\Suchverlauf.json';
files = {videohistoryFile, searchhistoryFile};

disp('loading files..')
video_data  = get_from_json([directory{current_dir},videohistoryFile]);
search_data = get_from_json([directory{current_dir},searchhistoryFile]);

% data table blueprint
cols = {'date', 'videoEntries', 'number_of_videoEntries', 'MA_nVEntries', 'searchEntries', 'number_of_searchEntries'};
data = table(   'Size', [1, length(cols)], ...
                'VariableNames', cols, ...
                'VariableTypes', ["datetime", "cell", "uint64", "double", "cell", "uint64"] );

newest_entry = time_from_datapoint(video_data{1, 1});
oldest_entry = time_from_datapoint(video_data{end, 1});

if time_from_datapoint(search_data(1)) > newest_entry
    newest_entry = time_from_datapoint(search_data(1));
end
if time_from_datapoint(search_data(end)) < oldest_entry
    oldest_entry = time_from_datapoint(search_data(end));
end 

% initial values
disp('getting statistics of videos..')
datestr_buf = newest_entry;
videoEntryList = {};
searchEntryList = {};
nSEntries = 0;
nVEntries_buffer = [];
nVEntries_buffer_len = 30;
[number_of_entriesV, ~] = size(video_data);
for i = 1:number_of_entriesV
    % extract datapoint
    newRow = {};
    datapointV = video_data{i,1};
    [datestr, timestr] = time_from_datapoint(datapointV);

    % compare with last point
    videoEntryList = [videoEntryList; datapointV.title];
    if ~strcmp(datestr, datestr_buf)
        date = datetime(datestr, 'InputFormat', 'yyyy-MM-dd');

        nVEntries = length(videoEntryList);
        
        % moving average of video count per day
        nVEntries_buffer = [nVEntries_buffer, nVEntries];
        if length(nVEntries_buffer) > nVEntries_buffer_len
            nVEntries_buffer(1) = [];
        end
        moving_avergage_nVEntries = sum(nVEntries_buffer)/nVEntries_buffer_len;
        
        % build new table row as cell
        newRow = {date, videoEntryList, nVEntries, moving_avergage_nVEntries, searchEntryList, nSEntries};

        % write to data table
        data = [data; newRow];
        videoEntryList = {};
    end
    datestr_buf = datestr;
end

disp('adding search statistics..')
% insert search data in data table
datetime_buf = data.date(1);
[rows, ~] = size(data);
j = 1;
for i = 2:rows %first row naT
    searchEntryList = {};
    datapointS = search_data(j);
    [datestrS, timestrS] = time_from_datapoint(datapointS);
    while data.date(i) == datetime(datestrS, 'InputFormat', 'yyyy-MM-dd')
        datapointS = search_data(j);
        [datestrS, timestrS] = time_from_datapoint(datapointS);

        searchEntryList = [searchEntryList; datapointS.title];
        j = j+1;
    end
    data.searchEntries{i} = searchEntryList;
    data.number_of_searchEntries(i) = length(searchEntryList);
end
disp('statistics done..')
%% visulization & stats
figure('name', 'Videos Over Years')
subplot(2, 2, [1 2]);

hold on
bar(data.date, data.number_of_videoEntries)
plot(data.date, data.MA_nVEntries)
hold off

title('Watched YouTube videos per day')
legend('videos per day', sprintf('moving average (%d days)', nVEntries_buffer_len))
xlabel('date'); ylabel('number of YouTube videos per day') 

subplot(2, 2, [3 4])
bar(data.date, data.number_of_searchEntries)
title('YouTube-Searched per day')
xlabel('date'); ylabel('number of YouTube-Searches per day') 

% backup_fig(gcf, 'YTPerDayAnalysis', mfilename )

%% functions
function [date, time] = time_from_datapoint(datapoint)
    % extracts date and time from datestring
    % returns date and time as string
    time_str = datapoint.time;
    time_arr = split(time_str, ["T", "."]);
    
    time_cell = string(time_arr(1:2));
    [date, time] = time_cell{:};
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
