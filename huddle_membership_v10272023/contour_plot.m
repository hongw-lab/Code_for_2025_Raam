
function [contour, top_areas, membershipCoding] = contour_plot(img_processed, sleap_frame, opt)
%%
tmp = bwconncomp(img_processed);
contour = zeros(size(img_processed), 'uint8');
[width, height] = size(img_processed);
% centers = round(squeeze(mean(sleap_frame)));
% using the body instead of the mean of 5 nodes
centers = round(squeeze(sleap_frame(5,:,:)));
if any(centers <= 0, 'all')
  centers(centers <= 0) = 1;
end
if any(centers > min(size(contour)), 'all')
  if any(centers(2,:) > width, 'all')
    centers(2, centers(2,:) > width) = width;
  end
  if any(centers(1,:) > height, 'all')
    centers(1, centers(1,:) > height) = height;
  end
end

centers_ind = sub2ind([width, height], centers(2,:), centers(1,:));
areas = tmp.PixelIdxList;
top_areas = zeros(1,4, 'uint16');
numMembers = opt.numMembers;
% Initialize the membership coding array
membershipCoding = zeros(1, nchoosek(numMembers, 2));
if ~isempty(areas)
  nArea = length(areas);
  top_areas_tmp = cellfun(@length, areas);
  [out, idx] = sort(top_areas_tmp,'descend');
  for a = 1:min(nArea, 4)
    top_areas(a) = out(a);
    connectionArray = ismember(centers_ind, areas{idx(a)});
    contour(areas{idx(a)}) = 60 + sum(connectionArray) * 40;
    
    % Get the number of members
    if sum(connectionArray) == 1
      % The coding 1 means there is no connection between this animal with
      % others. This is to preserve the errors that an animal had no space
      % assigned to it.
      index = 1;
      for i = 1:numMembers-1
        for j = i+1:numMembers
          if connectionArray(i) + connectionArray(j) == 1
            membershipCoding(index) = 1;
          end
          index = index + 1;
        end
      end
    elseif sum(connectionArray) > 1
      % Generate the membership coding
      index = 1;
      for i = 1:numMembers-1
        for j = i+1:numMembers
          if connectionArray(i) == 1 && connectionArray(j) == 1
            membershipCoding(index) = sum(connectionArray);
          end
          index = index + 1;
        end
      end
    end
  end
  %%
end
end



% function [contour, top_areas, in_n_out] = contour_plot(img_processed, loc)
% %%
% half_edge = 5;
% tmp = bwconncomp(img_processed);
% contour = zeros(size(img_processed), 'uint8');
% areas = tmp.PixelIdxList;
% top_areas = zeros(1,4, 'uint16');
% in_n_out = false;
% if ~isempty(areas)
%   nArea = length(areas);
%   top_areas_tmp = cellfun(@length, areas);
%   [out, idx] = sort(top_areas_tmp,'descend');
%   for a = 1:min(nArea, 4)
%     contour(areas{idx(a)}) = a*40;
%     top_areas(a) = out(a);
%   end
%   if any(loc-half_edge <=0)
%     loc(loc-half_edge <=0) = half_edge  + 1;
%   elseif any(loc+half_edge > size(contour))
%     if loc(1) + half_edge  > size(contour, 1)
%       loc(1) = size(contour, 1) - half_edge ;
%     end
%     if loc(2) + half_edge  > size(contour, 2)
%       loc(2) = size(contour, 2) - half_edge;
%     end
%   end
%   in_n_out = (contour(loc(2), loc(1)) == 40);
%   contour(loc(2)-half_edge :loc(2)+half_edge , loc(1)-half_edge:loc(1)+half_edge) = 200;
%   %%
% end
% end

