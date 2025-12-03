function labelHuddleGUI_temperature_and_checkpoint()
% LABELHUDDLEGUI_TEMPERATURE_AND_CHECKPOINT
%
% This GUI labels event frames (extracted via extract_event_frames) with
% temperature conversion and checkpoint logging. It now includes an area
% in each animal panel where the user can select an event name from a preset
% list (active_enter, active_leave, passive_enter, passive_leave, other, Undefined).
% If "Undefined" is selected, a custom edit field is enabled.
%
% The layout is organized as follows:
%   - Left side: Image display and title.
%   - Right side: Three panels:
%         Info Panel (top right): Info bar, frame quality popup, frame error checkbox.
%         Animal Panel Container (middle right): Four animal panels stacked vertically.
%         Navigation Panel (bottom right): Navigation buttons.
%
% Usage:
%   1) Run this script.
%   2) Select the folder containing event frames (and for saving checkpoint/log).
%   3) If a checkpoint exists, choose Continue or Override.
%   4) For each animal, select an event name from the popup. If "Undefined" is chosen,
%      type your custom event in the edit box.
%   5) Label frames, compute temperatures, and save the final labeledData.mat.

    %% 0) Select default folder for partial data, logs, and event frames
    defaultFolder = uigetdir('.', 'Select a folder for partial data & logs');
    if defaultFolder == 0
        error('User canceled folder selection.');
    end
    tempFile  = fullfile(defaultFolder, 'tempData.mat');
    finalFile = fullfile(defaultFolder, 'labeledData.mat');
    
    % Create a date-based log file (using date and time without colons)
    logFile = fullfile(defaultFolder, sprintf('log_%s.txt', datestr(now, 'yyyy-mm-dd HH-MM-SS')));
    
    %% 0.1 Initialize variables
    framesToLabel     = [];
    labeledData       = [];
    sourceFolder      = defaultFolder;
    currentFrameIndex = 1;
    allFrameIDs       = [];
    doContinue        = false;
    
    %% 0.2 Check for existing checkpoint
    if exist(tempFile,'file')
        choice = questdlg(sprintf('Checkpoint file found:\n%s\nContinue or Override?', tempFile), ...
                          'Checkpoint Found','Continue','Override','Continue');
        switch choice
            case 'Continue'
                S = load(tempFile, 'framesToLabel','sourceFolder','labeledData',...
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
                fprintf('User chose override. Re-building event frame list from scratch.\n');
            otherwise
                fprintf('User canceled => default to override.\n');
        end
    end
    
    %% 0.3 Build frames if not continuing from checkpoint
    if ~doContinue
        [framesToLabel, sourceFolder] = buildSampleFrameList(sourceFolder);
        numFrames = numel(framesToLabel);
        if numFrames < 1
            error('No event frames found to label.');
        end
        labeledData       = initializeLabeledData(numFrames);
        currentFrameIndex = 1;
        allFrameIDs       = [framesToLabel.frameNum];
    else
        numFrames = numel(framesToLabel);
        if numFrames < 1
            error('Loaded checkpoint has empty framesToLabel?');
        end
    end
    
    %% 1) Load colorbar_info for temperature conversion
    colorbarInfoPath = fullfile('colorbar_info.mat');
    if ~exist(colorbarInfoPath,'file')
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
    color_fun = cbStruct.color_fun;
    beta      = cbStruct.beta;
    
    %% 2) Create the GUI
    % Create a 1200x800 figure
    fig = figure('Name','Event Labeling (Temperature & Checkpoint)', ...
        'NumberTitle','off','Position',[100 100 1200 800], ...
        'MenuBar','none','ToolBar','none');
    
    % Left side: Image axes and title
    ax = axes('Parent',fig,'Units','pixels','Position',[20 150 640 600]);
    axis(ax,'image','off');
    titleHandle = uicontrol('Style','text','Parent',fig,...
        'Position',[20 770 640 25],...
        'String','Frame ???','FontSize',14,'HorizontalAlignment','left');
    
    % Right side is divided into 3 panels:
    % (A) Info Panel (top right)
    infoPanel = uipanel('Parent',fig, 'Units','pixels', 'Position',[680 650 500 130]);
    infoBarHandle = uicontrol('Style','edit','Parent',infoPanel,...
        'Units','pixels','Position',[10 10 480 80],...
        'Max',5,'Min',0,'Enable','inactive',...
        'BackgroundColor',[0.95 0.95 0.95],...
        'HorizontalAlignment','left',...
        'String','Welcome to the event labeling GUI.');
    % Also include frame quality and error checkbox inside infoPanel
    uicontrol('Style','text','Parent',infoPanel,...
        'Position',[10 100 100 20],'String','Frame quality:','HorizontalAlignment','left');
    frameQualityPop = uicontrol('Style','popupmenu','Parent',infoPanel,...
        'Position',[110 100 100 25],'String',{'good','bad'}, 'Value',1);
    frameErrorCheck = uicontrol('Style','checkbox','Parent',infoPanel,...
        'Position',[220 100 150 20],'String','Frame error?','Value',0);
    
    % (B) Animal Panel Container (middle right)
    animalContainer = uipanel('Parent',fig, 'Units','pixels', 'Position',[680 170 500 460]);
    maxAnimals = 4;
    animalPanel = gobjects(maxAnimals,1);
    inHuddleCheck = gobjects(maxAnimals,1);
    huddleCountEdit = gobjects(maxAnimals,1);
    errorCheckA = gobjects(maxAnimals,1);
    drawPolyBtn = gobjects(maxAnimals,1);
    pickEdgeBtn = gobjects(maxAnimals,1);
    removeEdgeBtn = gobjects(maxAnimals,1);
    clearPolyBtn = gobjects(maxAnimals,1);
    eventPopup = gobjects(maxAnimals,1);
    eventCustom = gobjects(maxAnimals,1);
    presetEvents = {'active_enter','active_leave','passive_enter','passive_leave','other','Undefined'};
    
    % Divide the animalContainer vertically into 4 panels
    panelHeight = 110;   % leave a small gap
    for a = 1:maxAnimals
        posY = 460 - a*panelHeight + 10;
        animalPanel(a) = uipanel('Parent', animalContainer, 'Units','pixels', ...
            'Position',[10 posY 480 100], 'Title',sprintf('Animal %d', a));
        % In-huddle checkbox and contact members (kept for compatibility)
        inHuddleCheck(a) = uicontrol('Style','checkbox','Parent',animalPanel(a),...
            'String','In huddle?','Value',0, 'Position',[10 60 80 20],...
            'Callback',@(src,evt)toggleInHuddle(a));
        uicontrol('Style','text','Parent',animalPanel(a),...
            'String','Contact members:', 'Position',[95 60 90 20], 'HorizontalAlignment','left');
        huddleCountEdit(a) = uicontrol('Style','edit','Parent',animalPanel(a),...
            'Position',[190 60 40 20],'String','0','Enable','off');
        errorCheckA(a) = uicontrol('Style','checkbox','Parent',animalPanel(a),...
            'String','Error?','Value',0, 'Position',[240 60 60 20]);
        % New event name selection controls:
        uicontrol('Style','text','Parent',animalPanel(a),...
            'String','Event:', 'Position',[10 35 50 20], 'HorizontalAlignment','left');
        eventPopup(a) = uicontrol('Style','popupmenu','Parent',animalPanel(a),...
            'String', presetEvents, 'Value',5, 'Position',[60 35 120 25],...
            'Callback', @(src,evt) eventPopupCallback(a));
        uicontrol('Style','text','Parent',animalPanel(a),...
            'String','Custom:', 'Position',[10 10 50 20], 'HorizontalAlignment','left');
        eventCustom(a) = uicontrol('Style','edit','Parent',animalPanel(a),...
            'Position',[60 10 120 25], 'String','', 'Enable','off');
        % Polygon and edge controls:
        drawPolyBtn(a) = uicontrol('Style','pushbutton','Parent',animalPanel(a),...
            'String','Draw poly','Position',[190 10 65 25],...
            'Callback',@(src,evt) drawAnimalPolygon(a));
        pickEdgeBtn(a) = uicontrol('Style','pushbutton','Parent',animalPanel(a),...
            'String','Pick edge','Position',[260 10 65 25],...
            'Callback',@(src,evt) selectContactEdge(a));
        removeEdgeBtn(a) = uicontrol('Style','pushbutton','Parent',animalPanel(a),...
            'String','Rem. edge','Position',[330 10 65 25],...
            'Callback',@(src,evt) removeContactEdge(a));
        clearPolyBtn(a) = uicontrol('Style','pushbutton','Parent',animalPanel(a),...
            'String','Clear poly','Position',[260 35 65 25],...
            'Callback',@(src,evt) clearAnimalPolygon(a));
    end
    
    % (C) Navigation Panel (bottom right)
    navPanel = uipanel('Parent',fig, 'Units','pixels', 'Position',[680 30 500 120]);
    prevBtn = uicontrol('Style','pushbutton','Parent',navPanel,...
        'String','Previous','Position',[10 50 80 40],'FontSize',10,'Callback',@previousFrameCallback);
    clearBtn = uicontrol('Style','pushbutton','Parent',navPanel,...
        'String','Clear Frame','Position',[100 50 80 40],'FontSize',10,'Callback',@clearFrameCallback);
    nextBtn = uicontrol('Style','pushbutton','Parent',navPanel,...
        'String','Save & Next','Position',[190 50 80 40],'FontSize',10,'Callback',@nextFrameCallback);
    computeTempBtn = uicontrol('Style','pushbutton','Parent',navPanel,...
        'String','Compute Temperature','Position',[280 50 120 40],'FontSize',10,'Callback',@computeTemperatureCallback);
    
    set(fig,'UserData', currentFrameIndex);
    polygonHandles = cell(maxAnimals,1);
    contactEdges = cell(maxAnimals,1);
    frameTemp = [];
    
    updateDisplay();
    
    %======================== NESTED FUNCTIONS =========================
    
    function updateDisplay()
        idx = get(fig, 'UserData');
        if idx < 1 || idx > numFrames, return; end
        thisFrame = framesToLabel(idx);
        colorFrame = imread(thisFrame.imgFile);
        [hh, ww, ~] = size(colorFrame);
        colorFlat = reshape(permute(colorFrame, [3,1,2]), 3, []);
        tempVals = color_fun(beta, single(colorFlat'));
        frameTemp = reshape(tempVals, [hh, ww]);
        cla(ax, 'reset');
        axis(ax, 'image', 'off');
        imshow(colorFrame, 'Parent', ax);
        
        [~, fileNoExt, fileExt] = fileparts(thisFrame.imgFile);
        if isfield(thisFrame, 'eventName')
            eventStr = thisFrame.eventName;
        else
            eventStr = 'unknown';
        end
        if thisFrame.isOnset
            eventTypeStr = 'onset';
        else
            eventTypeStr = 'offset';
        end
        set(fig, 'Name', sprintf('%s_frame_%d_%s%s', eventStr, thisFrame.frameNum, eventTypeStr, fileExt));
        set(titleHandle, 'String', sprintf('Frame #%d | Event=%s | (%s)', thisFrame.frameNum, eventStr, eventTypeStr));
        
        set(huddleCountEdit, 'String', '0');
        set(frameQualityPop, 'Value', 1);
        set(frameErrorCheck, 'Value', 0);
        
        for ai = 1:maxAnimals
            set(inHuddleCheck(ai), 'Value', 0);
            set(huddleCountEdit(ai), 'String', '0', 'Enable', 'off');
            set(errorCheckA(ai), 'Value', 0);
            set(eventPopup(ai), 'Value', 5);  % default "other"
            set(eventCustom(ai), 'Enable', 'off', 'String', '');
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
        
        setInfo('New event frame loaded. Ready to label.');
    end
    
    function setInfo(msg)
        set(infoBarHandle, 'String', msg);
        writeLog(msg);
    end
    
    function appendInfo(msg)
        oldStr = get(infoBarHandle, 'String');
        if ischar(oldStr)
            oldStr = cellstr(oldStr);
        end
        newStr = [oldStr; {msg}];
        set(infoBarHandle, 'String', newStr);
        writeLog(msg);
    end
    
    function writeLog(msg)
        fid = fopen(logFile, 'a');
        if fid > 0
            fprintf(fid, '[%s] %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), msg);
            fclose(fid);
        else
            warning('Could not open log file: %s', logFile);
        end
    end
    
    function saveCheckpoint(lastIndexValue)
        if ~exist(tempFile, 'file')
            save(tempFile, 'framesToLabel','sourceFolder','labeledData',...
                'lastIndexValue','allFrameIDs');
        else
            S = load(tempFile);
            if ~isfield(S, 'framesToLabel') || ~isfield(S, 'allFrameIDs')
                save(tempFile, 'framesToLabel','allFrameIDs','sourceFolder','-append');
            end
            save(tempFile, 'labeledData','lastIndexValue','-append');
        end
    end
    
    function previousFrameCallback(~,~)
        idx = get(fig, 'UserData');
        if idx > 1
            set(fig, 'UserData', idx - 1);
            updateDisplay();
        else
            appendInfo('Already at the first frame.');
        end
    end
    
    function clearFrameCallback(~,~)
        idx = get(fig, 'UserData');
        if idx < 1 || idx > numFrames, return; end
        labeledData(idx) = struct('frameNum',[],'huddleSize',[],...
            'animals',[], 'frameQuality','good','frameError',false);
        updateDisplay();
        saveCheckpoint(idx);
        appendInfo('Frame cleared. Partial data saved.');
    end
    
    function nextFrameCallback(~,~)
        idx = get(fig, 'UserData');
        if idx < 1 || idx > numFrames, return; end
        thisFrame = framesToLabel(idx);
        lab.frameNum = thisFrame.frameNum;
        lab.huddleSize = thisFrame.eventName;
        popStr = get(frameQualityPop, 'String');
        popVal = get(frameQualityPop, 'Value');
        lab.frameQuality = popStr{popVal};
        lab.frameError = (get(frameErrorCheck, 'Value') == 1);
        
        aArr = [];
        for ai = 1:maxAnimals
            aData.inHuddle = (get(inHuddleCheck(ai), 'Value') == 1);
            cVal = str2double(get(huddleCountEdit(ai), 'String'));
            if isnan(cVal), cVal = 0; end
            aData.huddleContactMembers = cVal;
            aData.errorFlag = (get(errorCheckA(ai), 'Value') == 1);
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
            % NEW: Get event name selection for this animal
            if ~isempty(eventPopup(ai)) && ishandle(eventPopup(ai))
                val = get(eventPopup(ai), 'Value');
                strs = get(eventPopup(ai), 'String');
                selEvent = strs{val};
                if strcmp(selEvent, 'Undefined')
                    customEvent = strtrim(get(eventCustom(ai), 'String'));
                    if isempty(customEvent)
                        aData.eventName = 'Undefined';
                    else
                        aData.eventName = customEvent;
                    end
                else
                    aData.eventName = selEvent;
                end
            else
                aData.eventName = '';
            end
            aArr = [aArr, aData]; %#ok<AGROW>
        end
        lab.animals = aArr;
        labeledData(idx) = lab;
        appendInfo('Frame data saved (partial).');
        if idx < numFrames
            set(fig, 'UserData', idx + 1);
            saveCheckpoint(idx + 1);
            updateDisplay();
        else
            appendInfo('All frames labeled. Saving final labeledData.mat...');
            save(finalFile, 'labeledData');
            if exist(tempFile, 'file')
                delete(tempFile);
            end
            close(fig);
        end
    end
    
    function toggleInHuddle(aIdx)
        val = get(inHuddleCheck(aIdx), 'Value');
        if val == 1
            set(huddleCountEdit(aIdx), 'String', '1', 'Enable', 'on');
        else
            set(huddleCountEdit(aIdx), 'String', '0', 'Enable', 'off');
        end
    end
    
    function drawAnimalPolygon(aIdx)
        appendInfo(sprintf('Drawing polygon for Animal #%d...', aIdx));
        figure(fig); axes(ax);
        if ~isempty(polygonHandles{aIdx}) && isvalid(polygonHandles{aIdx})
            delete(polygonHandles{aIdx});
        end
        polygonHandles{aIdx} = drawpolygon('Parent', ax, 'Color', 'b', 'LineWidth', 2);
        if ~isempty(contactEdges{aIdx})
            for ce = 1:numel(contactEdges{aIdx})
                if isvalid(contactEdges{aIdx}(ce).hLine)
                    delete(contactEdges{aIdx}(ce).hLine);
                end
            end
        end
        contactEdges{aIdx} = [];
        appendInfo(sprintf('Polygon drawn for Animal #%d.', aIdx));
    end
    
    function selectContactEdge(aIdx)
        appendInfo(sprintf('Selecting contact edge for Animal #%d...', aIdx));
        if isempty(polygonHandles{aIdx}) || ~isvalid(polygonHandles{aIdx})
            errordlg('Please draw a polygon first.', 'No Polygon');
            return;
        end
        polyPos = polygonHandles{aIdx}.Position;
        Nv = size(polyPos, 1);
        if Nv < 2
            errordlg('Polygon must have >=2 vertices.', 'Polygon Error');
            return;
        end
        figure(fig);
        [xClick, yClick] = ginput(2);
        if numel(xClick) < 2
            appendInfo('Edge selection canceled/invalid.');
            return;
        end
        idxPair = zeros(1,2);
        for k = 1:2
            dxy = polyPos - [xClick(k), yClick(k)];
            distSq = sum(dxy.^2,2);
            [~, iMin] = min(distSq);
            idxPair(k) = iMin;
        end
        idxPair = sort(idxPair);
        if idxPair(1) == idxPair(2)
            appendInfo(sprintf('Error: same point chosen: %d', idxPair(1)));
            return;
        end
        if ~isempty(contactEdges{aIdx})
            for ce = 1:numel(contactEdges{aIdx})
                if isequal(contactEdges{aIdx}(ce).verts, idxPair)
                    appendInfo(sprintf('Edge [%d->%d] already selected for Animal #%d.', idxPair(1), idxPair(2), aIdx));
                    return;
                end
            end
        end
        hold(ax, 'on');
        hLine = line([polyPos(idxPair(1),1), polyPos(idxPair(2),1)], ...
                     [polyPos(idxPair(1),2), polyPos(idxPair(2),2)], ...
                     'Color', 'r', 'LineWidth', 2);
        hold(ax, 'off');
        newEdge.verts = idxPair;
        newEdge.hLine = hLine;
        contactEdges{aIdx} = [contactEdges{aIdx}; newEdge];
        appendInfo(sprintf('Edge [%d->%d] added for Animal #%d.', idxPair(1), idxPair(2), aIdx));
    end
    
    function removeContactEdge(aIdx)
        appendInfo(sprintf('Removing contact edge for Animal #%d...', aIdx));
        if isempty(contactEdges{aIdx}) || isempty(polygonHandles{aIdx})
            errordlg('No polygon or edges to remove.', 'No Edges');
            return;
        end
        polyPos = polygonHandles{aIdx}.Position;
        figure(fig);
        [xClick, yClick] = ginput(2);
        if numel(xClick) < 2
            appendInfo('Remove edge canceled/invalid.');
            return;
        end
        idxPair = zeros(1,2);
        for k = 1:2
            dxy = polyPos - [xClick(k), yClick(k)];
            distSq = sum(dxy.^2,2);
            [~, iMin] = min(distSq);
            idxPair(k) = iMin;
        end
        idxPair = sort(idxPair);
        if idxPair(1) == idxPair(2)
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
                appendInfo(sprintf('Edge removed for Animal #%d (v%d->v%d).', aIdx, idxPair(1), idxPair(2)));
                break;
            end
        end
        if ~found
            appendInfo('No matching edge found to remove.');
        end
    end
    
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
            if N < 3
                appendInfo(sprintf('Animal %d polygon <3 vertices => skip.', ai));
                continue;
            end
            allEdges = [(1:N-1)', (2:N)'];
            if ~isequal(polyPos(1,:), polyPos(end,:))
                allEdges = [allEdges; [N,1]];
            end
            isContact = false(size(allEdges,1),1);
            if ~isempty(contactEdges{ai})
                for ee = 1:size(allEdges,1)
                    vv = sort(allEdges(ee,:));
                    for cc = 1:numel(contactEdges{ai})
                        if isequal(contactEdges{ai}(cc).verts, vv)
                            isContact(ee) = true;
                            break;
                        end
                    end
                end
            end
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
                if isContact(ee)
                    tag = 'Contact';
                else
                    tag = 'Non-contact';
                end
                appendInfo(sprintf('Animal #%d Edge [%d->%d] %s: %.1f degC',...
                    ai, i1, i2, tag, avgTemp));
            end
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
    
    % Callback for event popup: enable custom edit if "Undefined" is selected.
    function eventPopupCallback(aIdx)
        val = get(eventPopup(aIdx), 'Value');
        strs = get(eventPopup(aIdx), 'String');
        if strcmp(strs{val}, 'Undefined')
            set(eventCustom(aIdx), 'Enable', 'on');
        else
            set(eventCustom(aIdx), 'Enable', 'off');
            set(eventCustom(aIdx), 'String', '');
        end
    end

end

%% ========================================================================
%% SUBFUNCTIONS
%% ========================================================================
function [framesToLabel, folderName] = buildSampleFrameList(folderName)
% BUILD SAMPLE FRAME LIST for event frames.
% If folderName is provided and not empty, skip user prompt.
% Parse .PNG files in that folder with pattern:
%   ^([a-z_]+)_frame_(\d+)_(onset|offset)\.png$
    if ~exist('folderName','var') || isempty(folderName)
        folderName = uigetdir('.', 'Select the folder containing event frames');
        if folderName == 0
            error('User canceled folder selection in buildSampleFrameList.');
        end
    end
    fileList = dir(fullfile(folderName, '*.png'));
    if isempty(fileList)
        error('No PNG files found in folder: %s', folderName);
    end
    pattern = '^([a-z_]+)_frame_(\d+)_(onset|offset)\.png$';
    allEntries = [];
    for iF = 1:numel(fileList)
        fName = fileList(iF).name;
        fPath = fullfile(folderName, fName);
        tokens = regexp(fName, pattern, 'tokens', 'once');
        if isempty(tokens)
            fprintf('Skipping file (no match): %s\n', fName);
            continue;
        end
        eventName = tokens{1};
        frameStr = tokens{2};
        eventType = tokens{3};  % 'onset' or 'offset'
        frameNum = str2double(frameStr);
        isOnset = strcmp(eventType, 'onset');
        tmp.imgFile = fPath;
        tmp.frameNum = frameNum;
        tmp.eventName = eventName;
        tmp.isOnset = isOnset;
        allEntries = [allEntries; tmp]; %#ok<AGROW>
    end
    if isempty(allEntries)
        error('No files matched the pattern in folder: %s', folderName);
    end
    % framesToLabel = allEntries;
    [~, temp_idx] = sort([allEntries.frameNum]);
    framesToLabel = allEntries(temp_idx);
end

function framesSampled = sampleByHuddle(allEntries)
    % Not used for event frames; simply return all entries.
    framesSampled = allEntries;
end

function labeledData = initializeLabeledData(n)
    labeledData = repmat(struct('frameNum',[],'huddleSize',[],...
        'animals',[], 'frameQuality','good','frameError',false), 1, n);
end
