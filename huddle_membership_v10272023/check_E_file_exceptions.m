% super_folder = 'Y:\Tara\Huddle_project\';
super_folder = '/run/user/1000/gvfs/smb-share:server=bc-fs01.ad.medctr.ucla.edu,share=honglab2/Tara/Huddle_project/';
subfolders_to_search = {'4Corner', 'first pilot', 'huddle_size', ...
  'mPFC_hm4di', 'SI', 'Therm_Titration'};

search_again = false;
if search_again
  all_files = [];
  for folder_id = 1:numel(subfolders_to_search)
    subfolder = subfolders_to_search{folder_id};
    subfolder = [super_folder subfolder];
    fileList = searchFiles(subfolder);
    all_files = [all_files; fileList];
  end
  outputFile = fopen('all_Es_path.txt', 'w');
  for fId = 1:numel(all_files)
    fprintf(outputFile, [all_files{fId} '\n']);
  end
  fclose(outputFile);
  system('bash copy_files.sh')
else
  opts.DelimitedTextImportOptions = 'LineEnding';
  % all_files = readcell("all_Es_path.txt", "Delimiter","\n");
  all_files = dir('./mat_files/*mat');
end

percentage_of_exceptions = [];
all_exceptions = [];
unique_exceptions = [];
outFile = fopen('Es_error.txt', 'w');
for fId = 1:numel(all_files)
  file_path = all_files(fId).name;
  E = load(['./mat_files/' file_path]);
  E = E.E;
  HuddleIdentity = E.HuddleIdentity;
  try
    if contains(file_path, 'pair')
      unique_labels = [2, 4];
    else
      unique_labels = [4, 6, 8.6, 10, 16]';
    end
  row_sum = round(sum(HuddleIdentity, 2), 2);
  unique_labels == unique(row_sum);
  catch ME
    warning('Huddle Identity contains irational values.')
    fprintf(outFile, '%s\n', file_path);
    fprintf(outFile, '[%s]\n', join(string(unique(row_sum)), ','));
    % Find the elements of A that are not in B
    exceptionalElements = ~ismember(row_sum, unique_labels);
    % Find unique rows and their indices
    [uniqueRows, ~, idx] = unique(HuddleIdentity(exceptionalElements, :), 'rows', 'stable');
    all_exceptions = [all_exceptions; HuddleIdentity(exceptionalElements, :)];
    % Count occurrences of each unique row
    counts = accumarray(idx, 1);
    % Count the exceptional numbers
    numExceptional = sum(exceptionalElements);
    % Display results
    for i = 1:size(uniqueRows, 1)
        fprintf(outFile, ['Row: ', num2str(uniqueRows(i, :)), ', Count: ', num2str(counts(i)), '\n']);
    end
    % Calculate the total number of elements in A
    totalNumbers = numel(row_sum);
    
    % Print the result
    percentage_of_exceptions = [percentage_of_exceptions numExceptional/totalNumbers*100];
    fprintf(outFile, 'The count of exceptional numbers: %d / %d == %.2f%%\n', numExceptional, totalNumbers, numExceptional/totalNumbers*100);

  end
end
[unique_exceptions, ~, idx] = unique(all_exceptions, 'rows', 'sorted');
counts = accumarray(idx, 1);
fprintf(outFile, 'Summary\n')
for i = 1:size(unique_exceptions, 1)
    fprintf(outFile, ['Row: ', num2str(unique_exceptions(i, :)), ', Count: ', num2str(counts(i)), '\n']);
end
fclose(outFile);

function fileList = searchFiles(baseFolder)
% Initialize the list of files to an empty cell array
fileList = {};

% Get all the files and subfolders in the base folder
allFiles = dir(baseFolder);

% Filter out all the items that aren't directories
dirIdx = [allFiles.isdir];

% Get a list of subdirectories
subFolders = {allFiles(dirIdx).name};

% Exclude the pseudo folders '.' and '..'
subFolders(ismember(subFolders,{'.','..'})) = [];

% Now process each subfolder
for i = 1:length(subFolders)
  nextFolder = fullfile(baseFolder, subFolders{i});
  fileList = [fileList; searchFiles(nextFolder)];  %#ok<AGROW>
end

% Find files in the current folder that end with "_E.mat"
currentFolderFiles = dir(fullfile(baseFolder, '*_E.mat'));

% Filter out files that have "compiled_E.mat" at the end
validFiles = ~endsWith({currentFolderFiles.name}, 'compiled_E.mat');
currentFolderFiles = currentFolderFiles(validFiles);

% Append the valid files to the list
for i = 1:length(currentFolderFiles)
  fileList = [fileList; fullfile(baseFolder, currentFolderFiles(i).name)];
end
end

