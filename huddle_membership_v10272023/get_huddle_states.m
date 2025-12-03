function HuddleStates = get_huddle_states(HuddleIdentity, membershipCoding)
HuddleStates(:,1) = all(HuddleIdentity==1, 2); %no huddle
HuddleStates(:,2) = sum(HuddleIdentity==2, 2) == 2; %2-1-1

% The exception case commented out below is fixed in get_huddle_identity
% HuddleStates(:,2) = (sum(HuddleIdentity==2, 2) >=2 & sum(HuddleIdentity==2, 2) <= 3); %2-1-1

HuddleStates(:,3) = all(round(HuddleIdentity)==2, 2); %2-2
HuddleStates(:,4) = any(HuddleIdentity==3, 2); %3-1
HuddleStates(:,5) = any(HuddleIdentity==4, 2); %4-0

if any(sum(HuddleStates, 2)~=1)
  error('There are exceptions in the results')
end
end