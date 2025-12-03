% super_folder = 'Y:\Tara\Huddle_project\';
super_folder = '/run/user/1000/gvfs/smb-share:server=bc-fs01.ad.medctr.ucla.edu,share=honglab2/Tara/Huddle_project/';
subfolders_to_search = {'4Corner', 'first pilot', 'huddle_size', ...
  'mPFC_hm4di', 'SI', 'Therm_Titration'};

% This file shall only be run after check_E_file_exceptions, which moves
% all the mat files into a single folder.
opts.DelimitedTextImportOptions = 'LineEnding';
file_list = readcell('all_Es_path.txt', "Delimiter", "\n");
template_path = './';

%%
outFile = fopen('Es_error_reprocessing.txt', 'w');
all_exceptions = [];
for fId = 1:numel(file_list)
  file_path = file_list{fId};
  file_name = strsplit(file_path, '/');
  % result_path = [strjoin(file_name(1:end-1), '/') '/'];
  result_path = './mat_files/';
  file_name = file_name{end};

  unique_name = strsplit(file_name, '.mat');
  unique_name = unique_name{1};
  unique_name = [unique_name '_reprocessed_v1017'];
  annotate_name_v3 = [unique_name, '_member_specific_ann.txt'];
  E = load(['./mat_files/' file_name]);
  E = E.E;
  HuddleIdentity = E.HuddleIdentity;
  HuddleStates = E.HuddleStates;
  try
    if contains(file_name, 'pair')
      unique_labels = [2, 4];
      continue
    else
      unique_labels = [4, 6, 8.6, 10, 16]';
    end
    row_sum = round(sum(HuddleIdentity, 2), 2);
    unique_labels == unique(row_sum);
    membershipCoding = E.membershipCoding;
    participation_code = E.participationCoding;
    save([result_path unique_name '.mat'], 'E');
    producing_annotation_file(participationCoding, HuddleStates, template_path, result_path, annotate_name_v3);
  catch ME
    % If error happens, the code will go through the following process to
    % replace all irregular rows
    % Find the elements of A that are not in B
    exceptionalElements = ~ismember(row_sum, unique_labels);
    membershipCoding = E.membershipCoding;
    membershipCoding(exceptionalElements, :) = E.membershipCoding_raw(exceptionalElements, :);
    E.membershipCoding = membershipCoding;
    participation_code = [1 2 3; 1 4 5; 2 4 6; 3 5 6];
    participationCoding = zeros(length(membershipCoding), 4);
    for i = 1:4
      participationCoding(:, i) = sum(membershipCoding(:, participation_code(i,:)) > 1, 2) > 0;
    end
    %slightly different from participation coding above, keep for consistency w Qin code
    HuddleIdentity = get_huddle_identity(participationCoding, membershipCoding);
    % col 1=> no; col 2 => 2; col 3 => 2-2; col 4=> 3; col 5 => 4;
    HuddleStates = get_huddle_states(HuddleIdentity, membershipCoding);
    % First, check if there is any exception after this treatment
    print_exceptions(HuddleIdentity, outFile, file_name);
    % Then, produce the new files
    E.participationCoding = participationCoding;
    E.HuddleIdentity = HuddleIdentity;
    E.HuddleStates = HuddleStates;
    save([result_path unique_name '.mat'], 'E');
    producing_annotation_file(participationCoding, HuddleStates, template_path, result_path, annotate_name_v3);
  end
end
fclose(outFile)

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