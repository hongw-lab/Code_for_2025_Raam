extract_event_frames
function extract_event_frames()
    % VIDEOS and ANNOTATION FILES (update paths as needed)
    videos = { ...
        'group30.avi'
        'group31.avi'
        'group33.avi'
        'group34.avi'
        'group35.avi'};
    
    annFiles = { ...
        'group30_temperature_code_ann.txt'
        'group31_temperature_code_ann.txt'
        'group33_temperature_code_ann.txt'
        'group34_temperature_code_ann.txt'
        'group35_temperature_code_ann.txt'};
    
    % For each video/annotation pair:
    for i = 1:numel(videos)
        videoFile = fullfile('../', videos{i});  % adjust path if needed
        annFile   = annFiles{i};
        
        % Create an output directory for the extracted event frames
        [~, vidName, ~] = fileparts(videoFile);
        outDir = fullfile(['./' vidName '_eventFrames/']);
        if ~exist(outDir, 'dir')
            mkdir(outDir);
        end
        
        % Read the annotation file
        [onsets, offsets, eventTypes] = readAnnotationFile_events(annFile);
        
        % Prepare VideoReader
        vReader = VideoReader(videoFile);
        
        % Loop through each event (annotation)
        for j = 1:numel(onsets)
            eventName = eventTypes{j};
            % Skip events that are 'other' (case-insensitive)
            if strcmpi(eventName, 'other') || strcmpi(eventName, '2') || strcmpi(eventName, '3') || strcmpi(eventName, '4')
                continue;
            end
            
            % For onset: use the start frame
            onsetFrame = onsets(j);
            % For offset: use the end frame
            offsetFrame = offsets(j);
            
            % Extract onset frame:
            vReader.CurrentTime = (onsetFrame - 1) / vReader.FrameRate;
            onsetImg = readFrame(vReader);
            outNameOnset = sprintf('%s_frame_%d_onset.png', eventName, onsetFrame);
            imwrite(onsetImg, fullfile(outDir, outNameOnset));
            
            % Extract offset frame:
            vReader.CurrentTime = (offsetFrame - 1) / vReader.FrameRate;
            offsetImg = readFrame(vReader);
            outNameOffset = sprintf('%s_frame_%d_offset.png', eventName, offsetFrame);
            imwrite(offsetImg, fullfile(outDir, outNameOffset));
        end
        
        % Optionally, display summary information
        fprintf('Finished extracting event frames for video %s.\n', vidName);
    end
end

function [onsets, offsets, eventTypes] = readAnnotationFile_events(filename)
    % READANNOTATIONFILE_EVENTS Reads an annotation file (Behavior Annotator style)
    % and returns vectors of onsets, offsets, and a cell array of event types.
    % It looks for lines after the header that contain three tokens: start, end, type.
    
    rawLines = readlines(filename);
    % Look for the header line "S1:	start	end	type" or similar
    headerIdx = find(contains(rawLines, 'start'), 1, 'first');
    if isempty(headerIdx)
        error('Could not find header line in annotation file: %s', filename);
    end
    % Actual data lines start a couple of lines later (adjust if needed)
    dataLines = rawLines(headerIdx+2:end);
    
    onsets = [];
    offsets = [];
    eventTypes = {};
    
    for i = 1:numel(dataLines)
        line = strtrim(dataLines(i));
        if isempty(line)
            continue;
        end
        % Parse lines like: start   end    type
        tokens = regexp(line, '^\s*(\d+)\s+(\d+)\s+(\S+)', 'tokens', 'once');
        if isempty(tokens)
            continue;
        end
        onsetVal = str2double(tokens{1});
        offsetVal = str2double(tokens{2});
        typeStr = tokens{3};
        
        onsets(end+1) = onsetVal; %#ok<AGROW>
        offsets(end+1) = offsetVal; %#ok<AGROW>
        eventTypes{end+1} = typeStr; %#ok<AGROW>
    end
end

function extract_huddle_frames()
    % Define your videos and corresponding annotation files:
    videos = { ...
        'group30.avi'
        'group31.avi'
        'group33.avi'
        'group34.avi'
        'group35.avi'};
    
    annFiles = { ...
        'group30_temperature_code_ann.txt'
        'group31_temperature_code_ann.txt'
        'group33_temperature_code_ann.txt'
        'group34_temperature_code_ann.txt'
        'group35_temperature_code_ann.txt'};
    
    % Parameters
    n    = 2;     % number of seconds from onset/offset
    fps  = 30;    % frames per second of your videos
    minBoutFrames = 2 * n * fps;  % 2*n seconds in frames (e.g., 2*2*30=120)
    
    % Loop over each video/annotation pair
    for i = 1:numel(videos)
        videoFile = ['../' videos{i}];
        annFile   = annFiles{i};
        
        % Create a folder to store extracted frames
        [~, vidName, ~] = fileparts(videoFile);
        outDir = ['./' vidName '_frames/'];
        if ~exist(outDir, 'dir')
            mkdir(outDir);
        end
        
        % Read the annotation data (onset, offset, huddleSize)
        [onsets, offsets, huddleSizes] = readAnnotationFile(annFile);
        
        % Initialize counters for how many frames per huddle size
        % If you only expect 2,3,4, 'other', you can track those specifically:
        countByHuddle = containers.Map;
        
        % Prepare the video reader
        vReader = VideoReader(videoFile);
        
        % We will build a table of your final summary if you like:
        % frame, onset+n sec, offset-n sec, huddle size
        summaryData = {};
        
        for b = 1:numel(onsets)
            onsetFrame = onsets(b);
            offsetFrame = offsets(b);
            hSize = huddleSizes{b};  % might be 'other','2','3','4', etc.
            
            boutLength = offsetFrame - onsetFrame + 1;  % total frames in the bout
            if boutLength < minBoutFrames
                % Skip because this bout is shorter than 2n seconds
                continue
            end
            
            % We want to grab 1) onset + n seconds  and  2) offset - n seconds
            % in frames
            onsetTargetFrame = onsetFrame + n*fps;
            offsetTargetFrame = offsetFrame - n*fps;
            
            % -- Frame 1: onset + n sec --
            % Move video reader to that frame/time
            vReader.CurrentTime = (onsetTargetFrame-1) / fps;
            frameImg = readFrame(vReader);
            
            % Generate a file name
            outNameOnset = sprintf('huddlesize_%s_frame_%d_onsetplus_%d_sec.png', ...
                hSize, onsetTargetFrame, n);
            imwrite(frameImg, fullfile(outDir, outNameOnset));
            
            % Keep track in summary
            summaryData(end+1,:) = {onsetTargetFrame, onsetFrame + n*fps, offsetFrame - n*fps, hSize}; %#ok<AGROW>
            incrementCounter(countByHuddle, hSize);
            
            % -- Frame 2: offset - n sec --
            vReader.CurrentTime = (offsetTargetFrame-1) / fps;
            frameImg = readFrame(vReader);
            
            outNameOffset = sprintf('huddlesize_%s_frame_%d_offsetminus_%d_sec.png', ...
                hSize, offsetTargetFrame, n);
            imwrite(frameImg, fullfile(outDir, outNameOffset));
            
            % Keep track in summary
            summaryData(end+1,:) = {offsetTargetFrame, onsetFrame + n*fps, offsetFrame - n*fps, hSize};
            incrementCounter(countByHuddle, hSize);
        end
        
        % Convert summaryData to a table if desired:
        % columns: {frameIndex, onsetPlusN, offsetMinusN, huddleSize}
        summaryTable = cell2table(summaryData, ...
            'VariableNames', {'frameIndex','onsetPlusN','offsetMinusN','huddleSize'});
        
        % Save table
        writetable(summaryTable, fullfile(outDir,[vidName '_extractedFrames_summary.csv']));
        
        % Display or store the count of frames for each huddle size
        disp(['Results for ' vidName ':']);
        huddleKeys = countByHuddle.keys;
        for k = 1:numel(huddleKeys)
            fprintf('  HuddleSize=%s: %d frames saved\n', huddleKeys{k}, countByHuddle(huddleKeys{k}));
        end
        disp('----------------------------------');
    end
end

function [onsets, offsets, huddleSizes] = readAnnotationFile(filename)
    % Reads a Behavior Annotator style annotation file and
    % returns arrays of numeric onsets, offsets, and a cell array of huddle sizes.
    %
    % In your file, 'S1: start    end     type' lines precede the actual data,
    % then each data line has the form:
    %    <startFrame> <endFrame> <type>
    %
    % The type can be numeric (2,3,4) or the word 'other'.

    rawLines = readlines(filename);
    
    % Find where actual annotated lines begin
    % We'll look for the line that starts with 'S1: start' or '-----------------------------'
    dataStartIdx = find(contains(rawLines, 'S1: start'), 1, 'first');
    if isempty(dataStartIdx)
        % Or use the separator line
        dataStartIdx = find(contains(rawLines, '---'), 1, 'first');
        if isempty(dataStartIdx)
            error('Could not find data start in annotation file: %s', filename);
        end
    end
    
    % Usually, the actual data lines start a couple lines after that.
    % Let’s skip 2 lines for safety
    dataLines = rawLines(dataStartIdx+2 : end);
    
    onsets = [];
    offsets = [];
    huddleSizes = {};
    
    for i = 1:numel(dataLines)
        line = strtrim(dataLines(i));
        if isempty(line)
            continue;
        end
        % Try to parse lines like: "   1      67    3"
        tokens = regexp(line, '^\s*(\d+)\s+(\d+)\s+(\S+)', 'tokens', 'once');
        if ~isempty(tokens)
            onsetVal  = str2double(tokens{1});
            offsetVal = str2double(tokens{2});
            hSizeStr  = tokens{3};  % could be '2','3','4','other'
            
            onsets(end+1)       = onsetVal;                 %#ok<AGROW>
            offsets(end+1)      = offsetVal;                %#ok<AGROW>
            huddleSizes{end+1}  = hSizeStr;                 %#ok<AGROW>
        end
    end
end

function incrementCounter(mapObj, key)
    % Helper function to increment counts in a containers.Map
    if ~isKey(mapObj, key)
        mapObj(key) = 0;
    end
    mapObj(key) = mapObj(key) + 1;
end
