function producing_annotation_file(participationCoding, HuddleStates, template_path, result_path, annotate_name)

event_names = {'huddle', 'other'};
fid_template = fopen([template_path 'template.txt'], 'r');
file = fopen([result_path annotate_name], 'w');
tline = fgetl(fid_template);
while ischar(tline)
  fprintf(file, '%s\n', tline);
  tline = fgetl(fid_template);
end
fclose(fid_template);

for memberIdx = 1:size(participationCoding, 2)
  huddle_vec = participationCoding(:, memberIdx);
  % Decide if you need to filter again below
  % huddle_vec = removing_label_with_short_durations(huddle_vec, threshold);
  % HuddleIdentity_filtered(:,memberIdx) = huddle_vec;
  other_vec = ~ huddle_vec;
  behav_mat = [huddle_vec, other_vec];
  behav_mat = [0 0; behav_mat; 0 0];
  behav_diff_mat = diff(behav_mat);
  [eventIdx, onsets, ~] = find(behav_diff_mat' == 1);
  [~, offsets, ~] = find(behav_diff_mat' == -1);
  offsets = offsets - 1;

  % print the head line
  fprintf(file, sprintf(['\nS%d: start    end     type' ...
    '\n-----------------------------\n'], memberIdx))

  for eId = 1:length(eventIdx)
    event = event_names{eventIdx(eId)};
    onset = onsets(eId);
    offset = offsets(eId);
    fprintf(file, '%8d %7d    %s \n', onset, offset, event);
  end

end % end output trace per mouse;

% To produce the huddle state trace
overall_event_names = {'other', 'two', 'twoTwo', 'three', 'four'};
trace_id = memberIdx + 1;
fprintf(file, sprintf(['\nS%d: start    end     type' ...
  '\n-----------------------------\n'], trace_id))
% HuddleStates = E_new.HuddleStates;
behav_mat = HuddleStates;
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

fclose(file);
end