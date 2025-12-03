function labelHuddleGUI_temperature_and_checkpoint()
% HUDDLE_LABELING_WITH_TEMPERATURE_CHECKPOINT
%
% Combines:
%   1) Checkpoint logic (tempData.mat) to "Continue" or "Override"
%   2) No second folder prompt if overriding
%   3) Logging all messages to log_{date}.txt
%   4) Temperature conversion using colorbar_info.mat
%   5) Polygon & edges labeling, "Compute Temperature," etc.
%
% Usage:
%   1) Run this script.
%   2) Select a folder -> if "tempData.mat" is there, choose "Continue" or "Override."
%   3) If "Continue," it loads everything (framesToLabel, labeledData, etc.).
%      If "Override," it calls buildSampleFrameList with the same folder (no second prompt).
%   4) The script logs all info bar messages to a date-stamped log file in the same folder.
%   5) On finishing the last frame, it saves "labeledData.mat," optionally removing "tempData.mat."

    %=== 0) Select a default folder for partial data + logging ===
    defaultFolder = uigetdir('.', 'Select a folder for partial data & logs');
    if defaultFolder == 0
        error('User canceled folder selection.');
    end

    % We'll store partial data in <defaultFolder>/tempData.mat
    % We'll store final data in   <defaultFolder>/labeledData.mat
    tempFile  = fullfile(defaultFolder, 'tempData.mat');
    finalFile = fullfile(defaultFolder, 'labeledData.mat');

    %=== 0.1) Create a date-based log file in that folder ===
    % e.g. log_2025-02-03.txt
    logFile = fullfile(defaultFolder, sprintf('log_%s.txt', datestr(now,'yyyy-mm-dd HH:MM:SS')));

    %=== Variables to hold frames & data ===
    framesToLabel       = [];
    labeledData         = [];
    sourceFolder        = defaultFolder;  % We'll pass it to buildSampleFrameList if needed
    currentFrameIndex   = 1;
    allFrameIDs         = [];
    doContinue          = false;

    %=== 0.2) Check if tempData.mat exists => ask "Continue" or "Override" ===
    if exist(tempFile,'file')
        choice = questdlg(sprintf('Checkpoint file found:\n%s\nContinue or Override?', tempFile), ...
                          'Checkpoint Found','Continue','Override','Continue');
        switch choice
            case 'Continue'
                % Load partial data from tempData.mat
                S = load(tempFile, ...
                    'framesToLabel','sourceFolder','labeledData',...
                    'lastIndexValue','allFrameIDs');
                if isfield(S,'framesToLabel'),   framesToLabel = S.framesToLabel; end
                if isfield(S,'sourceFolder'),    sourceFolder  = S.sourceFolder;  end
                if isfield(S,'labeledData'),     labeledData   = S.labeledData;   end
                if isfield(S,'allFrameIDs'),     allFrameIDs   = S.allFrameIDs;   end
                if isfield(S,'lastIndexValue') && ~isempty(S.lastIndexValue)
                    currentFrameIndex = S.lastIndexValue;
                end
                doContinue = true;
            case 'Override'
                fprintf('User chose override. We will re-build frames from scratch.\n');
            otherwise
                fprintf('User canceled => default to override.\n');
        end
    end

    %=== If not continuing, then build frames fresh from the same folder => no second prompt. ===
    if ~doContinue
        [framesToLabel, sourceFolder] = buildSampleFrameList(sourceFolder);
        numFrames = numel(framesToLabel);
        if numFrames < 1
            error('No frames found to label.');
        end
        labeledData       = initializeLabeledData(numFrames);
        currentFrameIndex = 1;
        allFrameIDs       = [framesToLabel.frameNum];
    else
        % We presumably have framesToLabel & labeledData loaded from tempFile
        numFrames = numel(framesToLabel);
        if numFrames < 1
            error('Loaded checkpoint has empty framesToLabel?');
        end
    end

    %=== 1) Load colorbar_info for temperature conversion ===
    colorbarInfoPath = fullfile('colorbar_info.mat');
    if ~exist(colorbarInfoPath,'file')
        % If colorbar_info.mat not in defaultFolder, ask user
        [fName,pName] = uigetfile({'*.mat'}, 'Select colorbar_info.mat');
        if fName==0
            error('User canceled colorbar_info selection.');
        end
        colorbarInfoPath = fullfile(pName, fName);
    end
    cbi = load(colorbarInfoPath);
    if ~isfield(cbi,'colorbar_info')
        error('colorbar_info.mat must contain a struct "colorbar_info".');
    end
    cbStruct = cbi.colorbar_info;
    if ~isfield(cbStruct,'color_fun') || ~isfield(cbStruct,'beta')
        error('colorbar_info must have fields "color_fun" and "beta".');
    end
    color_fun = cbStruct.color_fun;  % function handle
    beta      = cbStruct.beta;       % numeric parameters

    %=== 2) Create the GUI ===
    fig = figure('Name','Temperature Huddle Labeling (Checkpoint)', ...
        'NumberTitle','off','Position',[50 50 1500 800], ...
        'MenuBar','none','ToolBar','none');

    ax = axes('Parent',fig,'Units','pixels','Position',[50 120 640 600]);
    axis(ax,'image','off');

    infoBarHandle = uicontrol('Style','edit','Parent',fig,...
        'Units','pixels','Position',[700 120 400 100],...
        'Max',5,'Min',0,'Enable','inactive',...
        'BackgroundColor',[0.95 0.95 0.95],...
        'HorizontalAlignment','left',...
        'String','Welcome to the labeling GUI.');

    titleHandle = uicontrol('Style','text','Parent',fig,...
        'Position',[50 730 640 30],...
        'String','Frame ???','FontSize',12,'HorizontalAlignment','left');

    uicontrol('Style','text','Parent',fig,...
        'Position',[700 600 100 20],...
        'String','Huddle size:', 'HorizontalAlignment','left');
    huddleSizeEdit = uicontrol('Style','edit','Parent',fig,...
        'Position',[800 595 60 25],...
        'String','', 'BackgroundColor','white');

    uicontrol('Style','text','Parent',fig,...
        'Position',[700 560 100 20],...
        'String','Frame quality:', 'HorizontalAlignment','left');
    frameQualityPop = uicontrol('Style','popupmenu','Parent',fig,...
        'Position',[800 555 80 25],...
        'String',{'good','bad'}, 'Value',1);

    frameErrorCheck = uicontrol('Style','checkbox','Parent',fig,...
        'Position',[700 530 150 20],...
        'String','Frame error?','Value',0);

    prevBtn = uicontrol('Style','pushbutton','Parent',fig,...
        'String','Previous','Position',[700 50 80 40],...
        'Callback',@previousFrameCallback);

    clearBtn = uicontrol('Style','pushbutton','Parent',fig,...
        'String','Clear Frame','Position',[790 50 80 40],...
        'Callback',@clearFrameCallback);

    nextBtn = uicontrol('Style','pushbutton','Parent',fig,...
        'String','Save & Next','Position',[880 50 80 40],...
        'Callback',@nextFrameCallback);

    computeTempBtn = uicontrol('Style','pushbutton','Parent',fig,...
        'String','Compute Temperature','Position',[980 50 120 40],...
        'Callback',@computeTemperatureCallback);

    %=== Animal panels ===
    maxAnimals = 4;
    animalPanel     = gobjects(maxAnimals,1);
    inHuddleCheck   = gobjects(maxAnimals,1);
    huddleCountEdit = gobjects(maxAnimals,1);
    errorCheckA     = gobjects(maxAnimals,1);

    drawPolyBtn     = gobjects(maxAnimals,1);
    pickEdgeBtn     = gobjects(maxAnimals,1);
    removeEdgeBtn   = gobjects(maxAnimals,1);
    clearPolyBtn    = gobjects(maxAnimals,1);

    panelX = 1150; 
    panelYstart = 600; 
    panelH = 90; 
    gap = 5;

    for a = 1:maxAnimals
        pY = panelYstart - (a-1)*(panelH+gap);
        animalPanel(a) = uipanel('Parent',fig,...
            'Title',sprintf('Animal %d', a),...
            'Units','pixels','Position',[panelX pY 330 panelH]);

        inHuddleCheck(a) = uicontrol('Style','checkbox','Parent',animalPanel(a),...
            'String','In huddle?','Value',0,'Position',[10 55 80 20],...
            'Callback',@(s,e)toggleInHuddle(a));

        uicontrol('Style','text','Parent',animalPanel(a),...
            'String','Contact members:',...
            'Position',[95 55 90 20], 'HorizontalAlignment','left');
        huddleCountEdit(a) = uicontrol('Style','edit','Parent',animalPanel(a),...
            'Position',[190 55 40 20], 'String','0','Enable','off');

        errorCheckA(a) = uicontrol('Style','checkbox','Parent',animalPanel(a),...
            'String','Error?','Value',0,'Position',[240 55 60 20]);

        drawPolyBtn(a) = uicontrol('Style','pushbutton','Parent',animalPanel(a),...
            'String','Draw poly','Position',[10 15 65 25],...
            'Callback',@(s,e)drawAnimalPolygon(a));
        pickEdgeBtn(a) = uicontrol('Style','pushbutton','Parent',animalPanel(a),...
            'String','Pick edge','Position',[80 15 65 25],...
            'Callback',@(s,e)selectContactEdge(a));
        removeEdgeBtn(a) = uicontrol('Style','pushbutton','Parent',animalPanel(a),...
            'String','Rem. edge','Position',[150 15 65 25],...
            'Callback',@(s,e)removeContactEdge(a));
        clearPolyBtn(a) = uicontrol('Style','pushbutton','Parent',animalPanel(a),...
            'String','Clear poly','Position',[220 15 65 25],...
            'Callback',@(s,e)clearAnimalPolygon(a));
    end

    set(fig,'UserData', currentFrameIndex);

    polygonHandles = cell(maxAnimals,1);
    contactEdges   = cell(maxAnimals,1);
    frameTemp      = [];

    updateDisplay();

    %======================== NESTED FUNCTIONS =========================

    %% updateDisplay
    function updateDisplay()
        idx = get(fig,'UserData');
        if idx<1 || idx>numFrames, return; end

        thisFrame = framesToLabel(idx);
        colorFrame = imread(thisFrame.imgFile); 
        [hh, ww, ~] = size(colorFrame);

        colorFlat = reshape(permute(colorFrame,[3,1,2]), 3, []);
        tempVals  = color_fun(beta, single(colorFlat'));
        frameTemp = reshape(tempVals,[hh,ww]);

        cla(ax,'reset');
        axis(ax,'image','off');
        imshow(colorFrame,'Parent',ax);

        [~, fileNoExt, fileExt] = fileparts(thisFrame.imgFile);
        set(fig,'Name',[fileNoExt fileExt]);

        if isnumeric(thisFrame.huddleSize)
            hsStr = num2str(thisFrame.huddleSize);
        else
            hsStr = thisFrame.huddleSize;
        end
        offsetStr = 'offset-n sec';
        if thisFrame.isOnset, offsetStr='onset+n sec'; end

        set(titleHandle, 'String', ...
            sprintf('Frame #%d | Huddle=%s | (%s)', ...
            thisFrame.frameNum, hsStr, offsetStr));

        set(huddleSizeEdit,'String', hsStr);
        set(frameQualityPop,'Value',1);
        set(frameErrorCheck,'Value',0);

        for ai = 1:maxAnimals
            set(inHuddleCheck(ai),'Value',0);
            set(huddleCountEdit(ai),'String','0','Enable','off');
            set(errorCheckA(ai),'Value',0);

            if ~isempty(polygonHandles{ai}) && isvalid(polygonHandles{ai})
                delete(polygonHandles{ai});
            end
            polygonHandles{ai} = [];

            if ~isempty(contactEdges{ai})
                for ce = 1:numel(contactEdges{ai})
                    if isvalid(contactEdges{ai}(ce).hLine)
                        delete(contactEdges{ai}(ce).hLine);
                    end
                end
            end
            contactEdges{ai} = [];
        end

        setInfo('New frame loaded. Ready to label.');
    end

    %% setInfo -> overwrites info bar + logs
    function setInfo(msg)
        set(infoBarHandle,'String',msg);
        writeLog(msg);
    end

    %% appendInfo -> appends a new line in the info bar + logs
    function appendInfo(msg)
        oldStr = get(infoBarHandle,'String');
        if ischar(oldStr)
            oldStr = cellstr(oldStr);
        end
        newStr = [oldStr; {msg}];
        set(infoBarHandle,'String', newStr);
        writeLog(msg);
    end

    %% writeLog -> append a line to log_{date}.txt with timestamp
    function writeLog(msg)
        fid = fopen(logFile,'a');
        if fid>0
            fprintf(fid,'[%s] %s\n', datestr(now,'yyyy-mm-dd HH:MM:SS'), msg);
            fclose(fid);
        else
            warning('Could not open log file: %s', logFile);
        end
    end

    %% saveCheckpoint -> store partial data
    function saveCheckpoint(lastIndexValue)
        if ~exist(tempFile,'file')
            % first time => store everything
            save(tempFile, 'framesToLabel','sourceFolder','labeledData',...
                'lastIndexValue','allFrameIDs');
        else
            % subsequent => keep framesToLabel + allFrameIDs as is
            S = load(tempFile);
            if ~isfield(S,'framesToLabel') || ~isfield(S,'allFrameIDs')
                save(tempFile,'framesToLabel','allFrameIDs','sourceFolder','-append');
            end
            save(tempFile, 'labeledData','lastIndexValue','-append');
        end
    end

    %% previousFrameCallback
    function previousFrameCallback(~,~)
        idx = get(fig,'UserData');
        if idx>1
            set(fig,'UserData', idx-1);
            updateDisplay();
        else
            appendInfo('Already at the first frame.');
        end
    end

    %% clearFrameCallback
    function clearFrameCallback(~,~)
        idx = get(fig,'UserData');
        if idx<1 || idx>numFrames, return; end

        labeledData(idx) = struct('frameNum',[],'huddleSize',[],...
            'animals',[], 'frameQuality','good','frameError',false);
        updateDisplay();
        saveCheckpoint(idx);
        appendInfo('Frame cleared. Partial data saved.');
    end

    %% nextFrameCallback
    function nextFrameCallback(~,~)
        idx = get(fig,'UserData');
        if idx<1 || idx>numFrames, return; end

        thisFrame = framesToLabel(idx);
        lab.frameNum = thisFrame.frameNum;

        hsUser = get(huddleSizeEdit,'String');
        hsVal  = str2double(hsUser);
        if ~isnan(hsVal)
            lab.huddleSize = hsVal;
        else
            lab.huddleSize = hsUser;
        end

        popStr = get(frameQualityPop,'String');
        popVal = get(frameQualityPop,'Value');
        lab.frameQuality = popStr{popVal};
        lab.frameError   = (get(frameErrorCheck,'Value')==1);

        aArr = [];
        for ai = 1:maxAnimals
            aData.inHuddle = (get(inHuddleCheck(ai),'Value')==1);
            cVal = str2double(get(huddleCountEdit(ai),'String'));
            if isnan(cVal), cVal=0; end
            aData.huddleContactMembers = cVal;
            aData.errorFlag = (get(errorCheckA(ai),'Value')==1);

            if ~isempty(polygonHandles{ai}) && isvalid(polygonHandles{ai})
                aData.polygon = polygonHandles{ai}.Position;
            else
                aData.polygon = [];
            end

            if isempty(contactEdges{ai})
                aData.contactEdgesVerts = [];
            else
                vPairs = zeros(numel(contactEdges{ai}),2);
                for ce = 1:numel(contactEdges{ai})
                    vPairs(ce,:) = contactEdges{ai}(ce).verts;
                end
                aData.contactEdgesVerts = vPairs;
            end
            aArr = [aArr, aData]; %#ok<AGROW>
        end
        lab.animals = aArr;
        labeledData(idx) = lab;

        appendInfo('Frame data saved (partial).');

        if idx < numFrames
            set(fig,'UserData', idx+1);
            saveCheckpoint(idx+1);
            updateDisplay();
        else
            appendInfo('All frames labeled. Saving final labeledData.mat...');
            save(finalFile,'labeledData');
            if exist(tempFile,'file')
                delete(tempFile);
            end
            close(fig);
        end
    end

    %% toggleInHuddle
    function toggleInHuddle(aIdx)
        val = get(inHuddleCheck(aIdx),'Value');
        if val==1
            set(huddleCountEdit(aIdx),'String','1','Enable','on');
        else
            set(huddleCountEdit(aIdx),'String','0','Enable','off');
        end
    end

    %% drawAnimalPolygon
    function drawAnimalPolygon(aIdx)
        appendInfo(sprintf('Drawing polygon for Animal #%d...', aIdx));
        figure(fig); axes(ax);

        if ~isempty(polygonHandles{aIdx}) && isvalid(polygonHandles{aIdx})
            delete(polygonHandles{aIdx});
        end
        polygonHandles{aIdx} = drawpolygon('Parent',ax,'Color','b','LineWidth',2);

        if ~isempty(contactEdges{aIdx})
            for cE = 1:numel(contactEdges{aIdx})
                if isvalid(contactEdges{aIdx}(cE).hLine)
                    delete(contactEdges{aIdx}(cE).hLine);
                end
            end
        end
        contactEdges{aIdx} = [];
        appendInfo(sprintf('Polygon drawn for Animal #%d.', aIdx));
    end

    %% selectContactEdge
    function selectContactEdge(aIdx)
        appendInfo(sprintf('Selecting contact edge for Animal #%d...', aIdx));
        if isempty(polygonHandles{aIdx}) || ~isvalid(polygonHandles{aIdx})
            errordlg('Please draw a polygon first.','No Polygon');
            return;
        end

        polyPos = polygonHandles{aIdx}.Position;
        Nv = size(polyPos,1);
        if Nv<2
            errordlg('Polygon must have >=2 vertices.','Polygon Error');
            return;
        end

        figure(fig);
        [xClick,yClick] = ginput(2);
        if numel(xClick)<2
            appendInfo('Edge selection canceled/invalid.');
            return;
        end

        idxPair = zeros(1,2);
        for k=1:2
            dxy = polyPos - [xClick(k), yClick(k)];
            distSq = sum(dxy.^2,2);
            [~, iMin] = min(distSq);
            idxPair(k) = iMin;
        end
        idxPair = sort(idxPair);

        if idxPair(1)==idxPair(2)
            appendInfo(sprintf('Error: same point chosen: %d', idxPair(1)));
            return;
        end

        % Check duplicates
        if ~isempty(contactEdges{aIdx})
            for ce = 1:numel(contactEdges{aIdx})
                if isequal(contactEdges{aIdx}(ce).verts, idxPair)
                    appendInfo(sprintf('Edge [%d->%d] already selected for Animal #%d.', ...
                        idxPair(1), idxPair(2), aIdx));
                    return;
                end
            end
        end

        hold(ax,'on');
        hLine = line([polyPos(idxPair(1),1), polyPos(idxPair(2),1)], ...
                     [polyPos(idxPair(1),2), polyPos(idxPair(2),2)], ...
                     'Color','r','LineWidth',2);
        hold(ax,'off');

        newEdge.verts = idxPair;
        newEdge.hLine = hLine;
        contactEdges{aIdx} = [contactEdges{aIdx}; newEdge];
        appendInfo(sprintf('Edge [%d->%d] added for Animal #%d.', ...
            idxPair(1), idxPair(2), aIdx));
    end

    %% removeContactEdge
    function removeContactEdge(aIdx)
        appendInfo(sprintf('Removing contact edge for Animal #%d...', aIdx));
        if isempty(contactEdges{aIdx}) || isempty(polygonHandles{aIdx})
            errordlg('No polygon or edges to remove.','No Edges');
            return;
        end

        polyPos = polygonHandles{aIdx}.Position;
        figure(fig);
        [xClick,yClick] = ginput(2);
        if numel(xClick)<2
            appendInfo('Remove edge canceled/invalid.');
            return;
        end

        idxPair = zeros(1,2);
        for k=1:2
            dxy = polyPos - [xClick(k), yClick(k)];
            distSq = sum(dxy.^2,2);
            [~, iMin] = min(distSq);
            idxPair(k) = iMin;
        end
        idxPair = sort(idxPair);

        if idxPair(1)==idxPair(2)
            appendInfo(sprintf('Error: same vertex chosen %d.', idxPair(1)));
            return;
        end

        found = false;
        for ce = 1:numel(contactEdges{aIdx})
            if isequal(contactEdges{aIdx}(ce).verts, idxPair)
                if isvalid(contactEdges{aIdx}(ce).hLine)
                    delete(contactEdges{aIdx}(ce).hLine);
                end
                contactEdges{aIdx}(ce) = [];
                found = true;
                appendInfo(sprintf('Edge removed for Animal #%d (v%d->v%d).',...
                    aIdx, idxPair(1), idxPair(2)));
                break;
            end
        end
        if ~found
            appendInfo('No matching edge found to remove.');
        end
    end

    %% clearAnimalPolygon
    function clearAnimalPolygon(aIdx)
        appendInfo(sprintf('Clearing polygon for Animal #%d...', aIdx));
        if ~isempty(polygonHandles{aIdx}) && isvalid(polygonHandles{aIdx})
            delete(polygonHandles{aIdx});
        end
        polygonHandles{aIdx} = [];

        if ~isempty(contactEdges{aIdx})
            for ce = 1:numel(contactEdges{aIdx})
                if isvalid(contactEdges{aIdx}(ce).hLine)
                    delete(contactEdges{aIdx}(ce).hLine);
                end
            end
        end
        contactEdges{aIdx} = [];
        appendInfo(sprintf('Polygon cleared for Animal #%d.', aIdx));
    end

    %% computeTemperatureCallback
    function computeTemperatureCallback(~,~)
        if isempty(frameTemp)
            appendInfo('No temperature map available!');
            return;
        end
        appendInfo('=== Computing Temperature Info ===');
        [HH, WW] = size(frameTemp);

        for ai = 1:maxAnimals
            if isempty(polygonHandles{ai}) || ~isvalid(polygonHandles{ai})
                continue;
            end
            polyPos = polygonHandles{ai}.Position;
            N = size(polyPos,1);
            if N<3
                appendInfo(sprintf('Animal %d polygon <3 vertices => skip.', ai));
                continue;
            end

            % Build edges
            allEdges = [(1:N-1)', (2:N)'];
            if ~isequal(polyPos(1,:), polyPos(end,:))
                allEdges = [allEdges; [N,1]];
            end

            % Mark contact edges
            isContact = false(size(allEdges,1),1);
            if ~isempty(contactEdges{ai})
                for ee = 1:size(allEdges,1)
                    vv = sort(allEdges(ee,:));
                    for cc = 1:numel(contactEdges{ai})
                        if isequal(contactEdges{ai}(cc).verts,vv)
                            isContact(ee) = true;
                            break;
                        end
                    end
                end
            end

            % For each edge => improfile => mean
            for ee = 1:size(allEdges,1)
                i1 = allEdges(ee,1); i2 = allEdges(ee,2);
                x1 = polyPos(i1,1); y1 = polyPos(i1,2);
                x2 = polyPos(i2,1); y2 = polyPos(i2,2);

                x1c = min(max(x1,1),WW); x2c = min(max(x2,1),WW);
                y1c = min(max(y1,1),HH); y2c = min(max(y2,1),HH);
                lineVals = improfile(frameTemp, [x1c x2c],[y1c y2c]);
                if isempty(lineVals)
                    avgTemp = NaN;
                else
                    avgTemp = mean(lineVals,'omitnan');
                end
                if isContact(ee), tag='Contact'; else, tag='Non-contact'; end
                appendInfo(sprintf('Animal #%d Edge [%d->%d] %s: %.1f degC',...
                    ai, i1, i2, tag, avgTemp));
            end

            % interior => poly2mask => mean
            xP = polyPos(:,1); yP = polyPos(:,2);
            xP = min(max(xP,1),WW);
            yP = min(max(yP,1),HH);
            mask = poly2mask(xP,yP,HH,WW);
            insideVals = frameTemp(mask);
            avgBody = mean(insideVals,'omitnan');
            appendInfo(sprintf('Animal #%d Whole body: %.1f degC', ai, avgBody));
        end
        appendInfo('=== Done computing temperatures ===');
    end

end

%% ========================================================================
%% SUBFUNCTIONS
%% ========================================================================
function [framesToLabel, folderName] = buildSampleFrameList(folderName)
% BUILD SAMPLE FRAME LIST with optional folderName.
% If folderName is provided and not empty, we skip user prompt.
% Otherwise, we ask user. Then parse .PNG files in that folder with pattern:
%   huddlesize_<K>_frame_<F>_(onsetplus|offsetminus)_(<n>)_sec.png
% group by (huddleSize,isOnset) => pick up to 10 each.

    if ~exist('folderName','var') || isempty(folderName)
        folderName = uigetdir('.', 'Select the folder containing extracted frames');
        if folderName == 0
            error('User canceled folder selection in buildSampleFrameList.');
        end
    end

    fileList = dir(fullfile(folderName,'*.png'));
    if isempty(fileList)
        error('No PNG files found in folder: %s', folderName);
    end

    pattern = '^huddlesize_([^_]+)_frame_(\d+)_(onsetplus|offsetminus)_(\d+)_sec\.png$';
    allEntries = [];

    for iF = 1:numel(fileList)
        fName = fileList(iF).name;
        fPath = fullfile(folderName, fName);

        tokens = regexp(fName, pattern, 'tokens', 'once');
        if isempty(tokens)
            fprintf('Skipping file (no match): %s\n', fName);
            continue;
        end

        huddleStr   = tokens{1};
        frameStr    = tokens{2};
        onsetOffset = tokens{3};
        % nSecStr   = tokens{4}; % not used

        frameNum = str2double(frameStr);
        numericVal = str2double(huddleStr);
        if ~isnan(numericVal)
            hVal = numericVal;
        else
            hVal = huddleStr; % e.g. 'other'
        end
        isOnset = strcmp(onsetOffset,'onsetplus');

        tmp.imgFile    = fPath;
        tmp.frameNum   = frameNum;
        tmp.huddleSize = hVal;
        tmp.isOnset    = isOnset;

        allEntries = [allEntries; tmp]; %#ok<AGROW>
    end

    if isempty(allEntries)
        error('No files matched the pattern in folder: %s', folderName);
    end

    framesToLabel = sampleByHuddle(allEntries);
end

function framesSampled = sampleByHuddle(allEntries)
% Group by (huddleSize, isOnset), pick up to 10 each => random order.
    allEntries = allEntries(:);
    nE = numel(allEntries);
    allHuddleCell = cell(nE,1);
    for i = 1:nE
        val = allEntries(i).huddleSize;
        if isnumeric(val)
            allHuddleCell{i} = num2str(val);
        else
            allHuddleCell{i} = val; % 'other'
        end
    end

    [uniqueHStr, ~, hIdx] = unique(allHuddleCell);
    isOnsetList = [allEntries.isOnset]';

    framesSampled = [];
    for iH = 1:numel(uniqueHStr)
        groupIdx = (hIdx == iH);
        subOnset  = allEntries(groupIdx &  isOnsetList);
        subOffset = allEntries(groupIdx & ~isOnsetList);

        if ~isempty(subOnset)
            idxOn = randperm(numel(subOnset), min(10,numel(subOnset)));
            framesSampled = [framesSampled; subOnset(idxOn)]; %#ok<AGROW>
        end
        if ~isempty(subOffset)
            idxOff = randperm(numel(subOffset), min(10,numel(subOffset)));
            framesSampled = [framesSampled; subOffset(idxOff)]; %#ok<AGROW>
        end
    end

    % optional shuffle
    if ~isempty(framesSampled)
        framesSampled = framesSampled(randperm(numel(framesSampled)));
    end
end

function labeledData = initializeLabeledData(n)
% Return an empty labeledData struct array of size n
    labeledData = repmat(struct('frameNum',[],'huddleSize',[],...
        'animals',[], 'frameQuality','good','frameError',false),1,n);
end
