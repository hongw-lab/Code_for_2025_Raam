function HuddleIdentity = get_huddle_identity(participationCoding, membershipCoding)

% Exception treatment 1
% If there is a transitioning period, for example, from 2-1-1-2 to 2-2-1-2
% to 2-2-1-1, let's stop the new joiner until that moment.
locs = find((max(membershipCoding,[], 2)==2) & (sum(participationCoding, 2) == 3));
for loc_i = 1:numel(locs)
  loc = locs(loc_i);
  membershipCoding(loc, :) = membershipCoding(loc-1, :);
  participationCoding(loc, :) = participationCoding(loc-1, :);
end

% exception treatment 2
% If there is a transitioning period form 2-1-1-2 to 2-2-1-2
% to 2-2-2-2, let's stop the new joiner until that moment
% The special exception is for D15 Group3 at frame 78459
locs = find((sum(membershipCoding==2, 2)>=3));
for loc_i = 1:numel(locs)
  loc = locs(loc_i);
  membershipCoding(loc, :) = membershipCoding(loc-1, :);
  participationCoding(loc, :) = participationCoding(loc-1, :);
end

% % exception treatment 3
% % If there is a transitioning period from 1-3-3-3 to 3-3-3-3 to 3-3-3-1
% % Let's stop the new joiner until that moment
% % The special exception is for Temp=10 group 1 at frame 27427
% locs = find((sum(membershipCoding==3, 2) ~= 3) & (sum(membershipCoding==3, 2) > 0));
% for loc_i = 1:numel(locs)
%   loc = locs(loc_i);
%   membershipCoding(loc, :) = membershipCoding(loc-1, :);
%   participationCoding(loc, :) = participationCoding(loc-1, :);
% end
% 
% % exce[topm treatment 4
% locs = find((sum(membershipCoding==4, 2) ~= 4) & (sum(membershipCoding==4, 2) > 0));
% for loc_i = 1:numel(locs)
%   loc = locs(loc_i);
%   membershipCoding(loc, :) = membershipCoding(loc-1, :);
%   participationCoding(loc, :) = participationCoding(loc-1, :);
% end


HuddleIdentity = double(participationCoding);
HuddleIdentity = HuddleIdentity .* double(max(membershipCoding, [], 2));
HuddleIdentity(HuddleIdentity<=0) = 1;
% The customer requires special change to encode membership into
% Huddle identity, like 2.1 for two in a group and 2.2 for the res two
locs = find(all(HuddleIdentity==2, 2));
for loc_i = 1:numel(locs)
  loc = locs(loc_i);
  HuddleIdentity(loc, 1) = 2.1;
  partner = find(membershipCoding(loc, 1:3)==2) + 1; % determining which animal is animal 1 huddling
  the_other_pair = find(membershipCoding(loc, 1:3)~=2)+1;
  HuddleIdentity(loc, partner) = 2.1;
  HuddleIdentity(loc, the_other_pair(1)) = 2.2;
  HuddleIdentity(loc, the_other_pair(2)) = 2.2;
end

try
  unique_labels = [4, 6, 8.6, 10, 16]';
  unique_labels == unique(sum(HuddleIdentity, 2));
catch ME
  warning('Huddle Identity contains irational values.')
  % disp(HuddleIdentity_single_trace);
end