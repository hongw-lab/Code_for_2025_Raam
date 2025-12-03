result_path = ['annotate_files/'];
honglab2_path = '/run/user/1000/gvfs/smb-share:server=bc-fs01.ad.medctr.ucla.edu,share=honglab2/';
video_path = [honglab2_path 'Tara/Quadrant_therm/mPFC_hm4di/2023'];
% sleap_path = [honglab2_path 'Tara/S4C_SLEAP_ProjectFiles/predictions/hm4di/huddle/'];
% video_path = 'Y:\Tara\Quadrant_therm\mPFC_hm4di\2023';

annotate_super_path = video_path;
% Specify the path to the template file
% '.' means local path; feel free to update the template file
template_path = ['.' filesep];
num_events = 6;
num_mice = 4;
% Specifying the session names if there are any
condition_list = {'Day3_CNOSAL'};
expInfo_list = {'Group1', 'Group2a', 'Group3'};
S = [];
SQ = [];
overlap_with_huddle = [];
for cId = 1:length(condition_list)
  condition = condition_list{cId};
  for eId = 1:length(expInfo_list)
    expInfo_i = expInfo_list{eId};
    unique_name = [condition '_' expInfo_i];
    manual_annotation_path = [result_path expInfo_i '_' condition '_raw_video_ann.txt'];
    E_path = [result_path 'Day3_oldcontour_Naren.mat'];
    E_new_path = [result_path unique_name '_E_v09152023_closer_30f.mat'];
    % contour_annotation_path = [result_path filesep unique_name '_member_specific_ann.txt'];
    contour_annotation_path = [result_path unique_name '_huddle_ann_v0915.txt'];
    annotate_name = [unique_name '_compare_0918.txt'];
    E = load(E_path);
    E = E.D3{1, eId};
    E_new = load(E_new_path);
    E_new = E_new.E;
    overlap_with_huddle.(unique_name) = [];
    overlap_in_session = [];

    % per session, we are going to print the template at the top
    fid_template = fopen([template_path 'template.txt'], 'r');
    file = fopen([result_path annotate_name], 'w');
    tline = fgetl(fid_template);
    while ischar(tline)
      fprintf(file, '%s\n', tline);
      tline = fgetl(fid_template);
    end
    fclose(fid_template);

    event_names = {'huddle', 'active_enter', 'passive_enter', ...
      'active_leave', 'passive_leave', 'other'};

    % Merging the two annotations
    for mId = 1:num_mice
      S{mId} = BehavStruExtract(manual_annotation_path, mId);
      behav_manual = behav_reader(S{mId}, event_names);
      SQ{mId} = BehavStruExtract(contour_annotation_path, mId);
      behav_mat = behav_reader(SQ{mId}, event_names);
      behav_mat(:, 2:end) = behav_manual(:, 2:end);
      overlap_in_session(mId,:) = behav_mat(:,2:num_events - 1)' * behav_mat(:,1);
      % Removing overlap from huddle array
      behav_mat(:,1) = behav_mat(:,1) - sum(behav_mat(:, 2:end), 2) > 0;
      % Writing the 'other'
      behav_mat(:,end) = all(behav_mat(:, 1:num_events-1) == 0, 2);
      behav_mat = [zeros(1, num_events); behav_mat; zeros(1, num_events)];
      behav_diff_mat = diff(behav_mat);
      [eventIdx, onsets, ~] = find(behav_diff_mat' == 1);
      [~, offsets, ~] = find(behav_diff_mat' == -1);
      offsets = offsets - 1;
      % print the headline
      fprintf(file, sprintf(['\nS%d: start    end     type' ...
        '\n-----------------------------\n'], mId))

      for eId = 1:length(eventIdx)
        event = event_names{eventIdx(eId)};
        onset = onsets(eId);
        offset = offsets(eId);
        fprintf(file, '%8d %7d    %s \n', onset, offset, event);
      end
    end
    overlap_with_huddle.(unique_name) = overlap_in_session;
    % To produce the huddle state trace
    event_names = {'other', 'two', 'twoTwo', 'three', 'four'};
    trace_id = mId + 1;
    fprintf(file, sprintf(['\nS%d: start    end     type' ...
      '\n-----------------------------\n'], trace_id))
    HuddleStates = E_new.HuddleStates;
    behav_mat = HuddleStates;
    behav_mat = [zeros(1, 5); behav_mat; zeros(1, 5)];
    behav_diff_mat = diff(behav_mat);
    [eventIdx, onsets, ~] = find(behav_diff_mat' == 1);
    [~, offsets, ~] = find(behav_diff_mat' == -1);
    offsets = offsets - 1;
    for eId = 1:length(eventIdx)
      event = event_names{eventIdx(eId)};
      onset = onsets(eId);
      offset = offsets(eId);
      fprintf(file, '%8d %7d    %s \n', onset, offset, event);
    end

    % To paste Naren's Huddle_states
    trace_id = trace_id + 1;
    HuddleStates = E.HuddleStates;
    fprintf(file, sprintf(['\nS%d: start    end     type' ...
      '\n-----------------------------\n'], trace_id))
    behav_mat = HuddleStates;
    behav_mat = [zeros(1, 5); behav_mat; zeros(1, 5)];
    behav_diff_mat = diff(behav_mat);
    [eventIdx, onsets, ~] = find(behav_diff_mat' == 1);
    [~, offsets, ~] = find(behav_diff_mat' == -1);
    offsets = offsets - 1;
    for eId = 1:length(eventIdx)
      event = event_names{eventIdx(eId)};
      onset = onsets(eId);
      offset = offsets(eId);
      fprintf(file, '%8d %7d    %s \n', onset, offset, event);
    end

    % To print the difference
    trace_id = trace_id + 1;
    fprintf(file, sprintf(['\nS%d: start    end     type' ...
      '\n-----------------------------\n'], trace_id))
    event_names = {'other', 'extra', 'less'};
    Extra = sum(E.HuddleStates(:,2:end) < E_new.HuddleStates(:,2:end), 2);
    Less = sum(E.HuddleStates(:,2:end) > E_new.HuddleStates(:,2:end), 2);
    Less(Extra ~= 0) = 0;
    other = (Extra + Less) == 0;
    behav_mat = [other Extra Less];
    behav_mat = [zeros(1, 3); behav_mat; zeros(1, 3)];  
    behav_diff_mat = diff(behav_mat);
    [eventIdx, onsets, ~] = find(behav_diff_mat' == 1);
    [~, offsets, ~] = find(behav_diff_mat' == -1);
    offsets = offsets - 1;
    for eId = 1:length(eventIdx)
      event = event_names{eventIdx(eId)};
      onset = onsets(eId);
      offset = offsets(eId);
      fprintf(file, '%8d %7d    %s \n', onset, offset, event);
    end
    fclose(file)
  end
end

save([result_path 'overlap_with_huddle.mat'], 'overlap_with_huddle');
function behav = behav_reader(S_i, event_names)
num_events = length(event_names);
behav = zeros(length(S_i.LogicalVecs{1}), num_events);
% load a single animal's behav traces into an array
for evId = 1:num_events
  event_name = event_names{evId};
  if any(strcmpi(S_i.EventNames, event_name))
    evmapId = find(strcmpi(S_i.EventNames, event_name));
    behav(:, evId) = S_i.LogicalVecs{1,evmapId};
  end
end
end
