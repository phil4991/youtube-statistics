%% YouTube data takeout statistics 2020-01-27

clear all; close all; clc
%% parameter
directory = {'TakeoutPhilipp_20200127'}
current_dir = 1;

%% import
videohistoryFile = '\YouTube\Verlauf\Wiedergabeverlauf.json';
searchhistoryFile = '\YouTube\Verlauf\Suchverlauf.json';
files = {videohistoryFile, searchhistoryFile};

disp('lodaing files..')
video_data  = get_from_json([directory{current_dir},videohistoryFile]);
search_data = get_from_json([directory{current_dir},searchhistoryFile]);

% data table blueprint
cols = {'date', 'videoEntries', 'searchEntries', 'number_of_videoEntries'};
data = table(   'Size', [1, length(cols)], ...
                'VariableNames', cols, ...
                'VariableTypes', ["datetime", "cell", "cell", "uint64"] );

end_date = time_from_datapoint(video_data{1, 1});
start_date = time_from_datapoint(video_data{end, 1});

if time_from_datapoint(search_data(1)) > end_date
    end_date = time_from_datapoint(search_data(1));
end
if time_from_datapoint(search_data(end)) < start_date
    start_date = time_from_datapoint(search_data(end));
end 

% initial values
disp('getting statistics..')
datestr_buf = end_date;
videoEntryList = {};
searchEntryList = {};
[number_of_entries, ~] = size(video_data);
date = end_date;
date_buf = [];
idx = 1;
while start_date <= date && date <= end_date
    newRow = {};
    
    % extract datapoints from both datasets
    datapointV = video_data{idx,1};
    datapointS = search_data(idx);
    
    [datestrV, timestrV] = time_from_datapoint(datapointV);
    [datestrS, timestrS] = time_from_datapoint(datapointS);
    
    videoEntryList = [videoEntryList; datapointV.title];
    searchEntryList = [searchEntryList; datapointS.title];
    
    % compare with last point
    if all()
        nEntries = length(videoEntryList);
        newRow = {date, videoEntryList, searchEntryList, nEntries};

        % write to data table
        data = [data; newRow];
        videoEntryList = {};
    end
    datestr_buf = datestr;
end

% insert search data in data table
[rows, ~] = size(data);
for i = 1:rows
    [datestr, timestr] = time_from_datapoint(datapoint);
end
%% visulization & stats
figure('name', 'Videos Over Years')
subplot(1, 2, [1 2])
bar(data.date, data.number_of_videoEntries)
xlabel('date')
ylabel('number of YouTube videos per day') 

% backup_fig(gcf, 'VideosPerDay', mfilename )

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
