result_path = ['E:\Huddle_project\mPFC_hm4di\2023\'];
video_path = 'E:\Huddle_project\mPFC_hm4di\2023';
annotate_super_path = video_path;
% Specify the path to the template file
% '.' means local path; feel free to update the template file
template_path = ['.' filesep];
event_names = {'huddle', 'active_enter', 'passive_enter', ...
  'active_leave', 'passive_leave', 'other'};

overall_event_names = {'other', 'two', 'twoTwo', 'three', 'four'};
num_events = 6;
num_mice = 4;
% Specifying the session names if there are any
% condition_list = {'Day3_CNOSAL','Day5_SALCNO'};
% expInfo_list = {'Group1', 'Group3'};
condition_list = {'Day5_SALCNO'};
expInfo_list = {'Group1','Group2a','Group3'};

S = [];
SQ = [];
overlap_with_huddle = [];
for cId = 1:length(condition_list)
  condition = condition_list{cId};


  for eId = 1:length(expInfo_list)
    expInfo_i = expInfo_list{eId};
    unique_name = [condition '_' expInfo_i];
    % The path to the manual anotation
    manual_annotation_path = [annotate_super_path filesep condition ...
      filesep expInfo_i '_' condition '_raw_video_ann.txt'];
    % contour_annotation_path = [result_path filesep unique_name '_member_specific_ann.txt'];
    % The path to Qin's annotation path
    contour_annotation_path = [result_path condition '\' unique_name '_member_specific_ann.txt'];
    annotate_name = [unique_name '_add_human_annotation.txt'];
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

    % Merging the two annotations
    for mId = 1:num_mice
      S{mId} = BehavStruExtract(manual_annotation_path, mId);
      behav_manual = behav_reader(S{mId}, event_names); % The manual annotation
      SQ{mId} = BehavStruExtract(contour_annotation_path, mId);
      behav_mat = behav_reader(SQ{mId}, event_names); % Qin's
      behav_mat(:, 2:num_events-1) = behav_manual(:, 2:num_events-1);
      overlap_in_session(mId,:) = behav_mat(:,2:num_events - 1)' * behav_mat(:,1);
      % Removing overlap from huddle array
      behav_mat(:,1) = behav_mat(:,1) - sum(behav_mat(:, 2:num_events-1), 2) > 0;
      % Writing the 'other'
      behav_mat(:,end) = all(behav_mat(:, 1:num_events-1) == 0, 2);
      behav_mat = [zeros(1, num_events); behav_mat; zeros(1, num_events)];
      behav_diff_mat = diff(behav_mat);
      [eventIdx, onsets, ~] = find(behav_diff_mat' == 1);
      [~, offsets, ~] = find(behav_diff_mat' == -1);
      offsets = offsets - 1;

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
    trace_id = mId + 1;
    SQ{trace_id} = BehavStruExtract(contour_annotation_path, trace_id);
    behav_mat = behav_reader(SQ{trace_id}, overall_event_names);
    fprintf(file, sprintf(['\nS%d: start    end     type' ...
      '\n-----------------------------\n'], trace_id))
    % HuddleStates = E_new.HuddleStates;
    % behav_mat = HuddleStates;
    zero_padding = zeros(1, length(overall_event_names));
    behav_mat = [zero_padding; behav_mat; zero_padding];
    behav_diff_mat = diff(behav_mat);
    [eventIdx, onsets, ~] = find(behav_diff_mat' == 1);
    [~, offsets, ~] = find(behav_diff_mat' == -1);
    offsets = offsets - 1;
    for eId = 1:length(eventIdx)
      event = overall_event_names{eventIdx(eId)};
      onset = onsets(eId);
      offset = offsets(eId);
      fprintf(file, '%8d %7d    %s \n', onset, offset, event);
    end % end printing the fifth trace of overall huddle states
    clear SQ
    fclose(file);
  end % end experiments for a condition

end % end a condition

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
