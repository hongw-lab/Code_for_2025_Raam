% Please use run the file in its directory
% The super path directs to for honglab 2
honglab2_path = 'Y:\';
% All directories shall end with a SLASH
% The video path directs to the path where the avi videos are saved
% I would recommend downloading the videos to local to save computation time
video_path = 'E:\Huddle_project\Therm_Titration\males\first_round_bad_contrast';
% sleap path directs to thehat path of all the sleap h5 files
sleap_path = ['E:\S4C_SLEAP_ProjectFiles\predictions\therm_titration\males\bad_contrast\Analysis'];

% The following path is for linux use, Windows users does not need
% honglab2_path = '/run/user/1000/gvfs/smb-share:server=bc-fs01.ad.medctr.ucla.edu,share=honglab2/';
% video_path = [honglab2_path 'Tara/Quadrant_therm/mPFC_hm4di/2023'];
% sleap_path = [honglab2_path 'Tara/S4C_SLEAP_ProjectFiles/predictions/hm4di/huddle/'];

% The result path is where you would like to save the results; Be careful
% about overwriting
result_path = ['D:\annotation_results\'];
% Specify the path to the template file
% '.' means local path; feel free to update the template file
template_path = ['.' filesep];
% The event name from the template that we would like to predict by our
% code
event_names = {'huddle', 'other'};
% Specifying the session names if there are any

condition_list = {'20D'};
expInfo_list = {
'Group1'
'Group2'
'Group3'
'Group4'
'Group5'
'Group6'
    };

exceptionFile = fopen('Es_error_processing.txt', 'w');

% Options on the filter settings and more
load_options;
interval_threshold = opt.shortest_interval_threshold;
opt.numMembers = 4;
opt.if_generate_contours = false;
opt.read_whole_video_before_processing = true;
%% select corners of chamber
sizeOfQuadrant = [40, 40]; % length x width cm

h_scale = zeros(1, length(expInfo_list));
v_scale = zeros(1, length(expInfo_list));
%x = zeros(length(expInfo),1);
%y = zeros(length(expInfo),1);

for cId = 1:length(condition_list)
  condition = condition_list{cId};
  for eId = 1:length(expInfo_list)
    expInfo_i = expInfo_list{eId};

    QvideoPath = [video_path '\' condition '\' expInfo_i '\BehavCam_0\' expInfo_i '_behavCam.mp4'];
    QVideo = VideoReader(QvideoPath);

    % Open frame
    frame = read(QVideo, int16(QVideo.NumFrames/2));
    imshow(frame, 'InitialMagnification',10000);

    % Select x and y of L and R points
    % Select corners first, then midpoint
    [input_x, input_y] = ginput(4);
    corner_x = sort(input_x(1:4));
    corner_y = sort(input_y(1:4));
    h_scale(cId,eId) = sizeOfQuadrant(2)/(((corner_x(4) + corner_x(3))/2) - ((corner_x(2) + corner_x(1))/2));
    v_scale(cId,eId) = sizeOfQuadrant(1)/(((corner_y(4) + corner_y(3))/2) - ((corner_y(2) + corner_y(1))/2));

  end
end
%%
for cId = 1:length(condition_list)
  condition = condition_list{cId};
  for eId = 1:length(expInfo_list)
    expInfo_i = expInfo_list{eId};

    unique_name = [condition '_' expInfo_i];
    %unique_name = [expInfo_i '_' condition];
    % loading video files, be careful about the annotate name
    video_loc = [video_path '\' condition '\' expInfo_i '\BehavCam_0\' expInfo_i '_behavCam.mp4'];
    timeStamps_loc = [video_path '\' condition '\' expInfo_i '\BehavCam_0\timeStamps.csv'];
    sleap_loc = [sleap_path filesep condition '_' expInfo_i '.predictions_cleaned.analysis.h5'];
    %sleap_loc = [sleap_path filesep unique_name '.predictions.analysis.h5'];
    % name the output files properly
    contour_video_name = [unique_name '_contour.avi'];
    % After manually modifying the annotation files, please save them to
    % another copy for data safety
    annotate_name_v2 = [unique_name, '_member_specific_ann_v0919.txt'];
    E_name = [unique_name, '_E.mat'];

    tic
    fprintf('start reading files for %s => ', video_loc);
    v = VideoReader(video_loc);

    %% If the user need to follow with the true video sampling frequency
    opt.fs = get_sampling_rate(timeStamps_loc);
    opt.shortest_interval_threshold = int8(opt.fs);
    interval_threshold = opt.shortest_interval_threshold;

    %% The following 20 lines: this step identifies background and threshold values
    % using the first 10000 frames to synthesize the static background
    if opt.read_whole_video_before_processing
      full_video = read(v);
      if ~strcmp('Grayscale', v.VideoFormat)
        full_video = squeeze(full_video(:,:,1,:));
      end
      video = full_video(:,:,1:10000);
    else
      video = read(v, [1 10000]);
      video = squeeze(video(:,:,1,:));
    end
    frameCount = v.NumFrames; height = v.Height; width = v.Width;
    sleap = h5read(sleap_loc, '/tracks');
    sleap = sleap(:,:,:,1:opt.numMembers);
    % Here is the function to smooth sleap and fill the empty spaces
    sleap = sleap_interp1(sleap);
    % Start video processing
    img_bg_base = median(video, 3);
    bg_mean = mean(single(img_bg_base), 'all');
    bg_lower_mean = median(single(img_bg_base(img_bg_base < bg_mean)), 'all');
    bg_std = std(single(img_bg_base), [], 'all');
    img_bg = img_bg_base;
    img_threshold = max(opt.std_multiplier * bg_std, 60);
    %img_threshold = opt.std_multiplier * bg_std;
    img_bg(img_bg_base <= bg_mean - img_threshold) = ...
      max(bg_mean - img_threshold, 0);
    video_processed = zeros(height, width, frameCount, 'uint8');
    if opt.if_generate_contours
      video_contour = zeros(height, width, frameCount, 'uint8');
    end

    clear video

    %% video processing and area calculation
    area_array = zeros(frameCount, opt.n_members, 'uint16');
    membershipCoding = zeros(frameCount, nchoosek(opt.numMembers, 2), 'int8');
    parfor (k = 1:frameCount)
      if opt.read_whole_video_before_processing
        img = squeeze(full_video(:,:,k));
      else
        if strcmp('Grayscale', v.VideoFormat)
          img = read(v, k);
        else
          img = rgb2gray(read(v, k));
        end
      end
      img_binary = img_processing(img, img_bg, img_threshold, opt); %this step binarizes the pixels
      img_binary = cast(img_binary > 0, 'uint8');
      if opt.if_generate_contours
        [video_processed_contour(:,:,k), area_array(k,:), membershipCoding(k,:)] ...
          = contour_plot(img_binary, squeeze(sleap(k,:,:,:)), opt); %identifies huddle states
      else
        % [~, area_array(k,:)] = contour_plot_simple(img_binary);
        [~, area_array(k,:), membershipCoding(k,:)] ...
          = contour_plot(img_binary, squeeze(sleap(k,:,:,:)), opt);
      end
    end % end image synthesis

    if opt.if_generate_contours
      % add circles to the video
      video_new = zeros(height, width, 3, frameCount, 'uint8');
      for k = 1:frameCount
        tmp_frame = video_processed_contour(:,:,k);
        for ai = 1:size(sleap,4)
          tmp_frame  = insertShape(tmp_frame, ...
            'Circle', [squeeze(sleap(k,:,:,ai))'; 3,3,3,3,3]', ...
            'LineWidth', 1, 'Color', opt.colors{mod(ai, length(opt.colors))});
        end
        video_new(:,:,:,k) = tmp_frame;
      end
      vir = VideoWriter([result_path contour_video_name], 'Motion JPEG AVI');
      open(vir);
      writeVideo(vir, cast(video_new, 'uint8'));
      close(vir);
      clear video_new video_processed video_processed_contour
    end
    toc

    %% membership coding
    % The membership was coded in the style of
    % 1-2, 1-3, 1-4, 2-3, 2-4, 3-4
    % Thus, for animal 1, we need to check the columns of 1,2,3 and so for
    % the rest
    participation_code = [1 2 3; 1 4 5; 2 4 6; 3 5 6];

    participationCoding = zeros(length(membershipCoding), 1);
    for i = 1:opt.numMembers
      % here, Qin's participation coding is a bool array which indicates if
      % they are in the huddle, which is not the same as huddleIdentity but
      % can be converted.
      participationCoding(:, i) = sum(membershipCoding(:, participation_code(i,:)) > 1, 2) > 0;
    end

    %% Save Raw copies of huddle relevant information for debug in case
    E = {};
    E.Condition = condition;
    E.expInfo = expInfo_i;
    E.Sleap = sleap;

    Normsleap = [];
    Normsleap(:, :, 1, :) = sleap(:, :, 1, :) * h_scale(cId,eId);
    Normsleap(:, :, 2, :) = sleap(:, :, 2, :) * v_scale(cId,eId);
    E.NormSleap = Normsleap;

    E.participationCoding_raw = participationCoding; %participation codes that are only 0 and 1.
    E.membershipCoding_archive = membershipCoding; %pairwise huddling, 6 pairs, values are huddle size
    membershipCoding(membershipCoding==0) = 1;
    E.membershipCoding_raw = membershipCoding; %make sure membership coding does not have any 0
    template_path = ['.' filesep];
    % condition = 'Day3_CNOSAL';
    % expInfo_i='Group1';
    % unique_name = [condition '_' expInfo_i];
    annotate_name_v2 = [unique_name, '_member_specific_ann.txt'];
    %slightly different from participation coding above, keep for consistency w Qin code
    HuddleIdentity = get_huddle_identity(participationCoding, membershipCoding);
    % col 1=> no; col 2 => 2; col 3 => 2-2; col 4=> 3; col 5 => 4;
    HuddleStates = get_huddle_states(HuddleIdentity, membershipCoding);
    % To keep a record of the raw form of everything

    E.HuddleIdentity_raw = HuddleIdentity; %before filtering/smoothing
    E.HuddleStates_raw = HuddleStates; %before filtering/smoothing
    %% Filtering the arrays and finalizing the huddleStates and Identity
%     for memberIdx = 1:size(membershipCoding, 2)
%       membershipCoding(:, memberIdx) = removing_label_with_short_durations( ...
%         membershipCoding(:, memberIdx), ...
%         5, ...
%         opt.using_closer_label_instead_of_smallest);
%     end
    for memberIdx = 1:size(membershipCoding, 2)
      membershipCoding(:, memberIdx) = removing_label_with_short_durations( ...
        membershipCoding(:, memberIdx), ...
        interval_threshold, ...
        opt.using_closer_label_instead_of_smallest);
    end
    for i = 1:opt.numMembers
      participationCoding(:, i) = sum(membershipCoding(:, participation_code(i,:)) > 1, 2) > 0;
    end

    %slightly different from participation coding above, keep for consistency w Qin code
    HuddleIdentity = get_huddle_identity(participationCoding, membershipCoding);
    % col 1=> no; col 2 => 2; col 3 => 2-2; col 4=> 3; col 5 => 4;
    HuddleStates = get_huddle_states(HuddleIdentity, membershipCoding);

    %% Error correction function
    % If the smoothing method lead to weird errors, we are going to cover it
    % with the unfiltered traces
    try
      unique_labels = [4, 6, 8.6, 10, 16]';
      row_sum = round(sum(HuddleIdentity, 2), 2);
      unique_labels == unique(row_sum);
      if ismember(row_sum, unique_labels)
        ME = MException('MyComponent:noSuchVariable', ...
          'Some Variable Element %s not found',unique(row_sum));
        throw(ME)
      end
    catch ME
      % If error happens, the code will go through the following process to
      % replace all irregular rows
      % Find the elements of A that are not in B
      exceptionalElements = ~ismember(row_sum, unique_labels);
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
      print_exceptions(HuddleIdentity, exceptionFile, unique_name);
    end
    % Load the treated Codings to the E structure
    E.participationCoding = participationCoding;
    E.membershipCoding = membershipCoding;

    E.HuddleIdentity = HuddleIdentity; %final variable to use, vector for each animal denoting its huddle size
    E.HuddleStates = HuddleStates; %final variable to use, 5 logical vectors, one for each huddle state
    save([result_path E_name], 'E');
    %% producing annotation file
    producing_annotation_file(E.participationCoding, E.HuddleStates, template_path, result_path, annotate_name_v2);
  end
end % end looping over files
fclose(exceptionFile);
%% compile E structure and save for whole condition/day
for cId = 1:length(condition_list)
    condition = condition_list{cId};
    E = [];
    for i = 1:length(expInfo_list)
        unique_name = [condition '_' expInfo_list{i}];
        E_name = [unique_name, '_E.mat'];
        temp = load(['E:\Huddle_project\Therm_Titration\males\first_round_bad_contrast\20D\' E_name]);
        E{i} = temp.E;
        save(['D:\annotation_results\' condition '_compiled_E.mat'], 'E');
    end
end


