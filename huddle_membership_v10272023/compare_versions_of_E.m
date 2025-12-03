percent_Naren = [];
HuddleIdentity_percent_Naren = [];
load('annotate_files/Day3_oldcontour_Naren.mat')
for group_id = 1:3 
  percent_Naren = [percent_Naren; sum(D3{1,group_id}.HuddleStates) / length(D3{1,group_id}.HuddleStates)];
  HuddleIdentity_percent_Naren = [HuddleIdentity_percent_Naren; sum(D3{1, group_id}.HuddleIdentity > 1) / length(D3{1, group_id}.HuddleIdentity)];
end
percent_Qin = [];
HuddleIdentity_percent_Qin = [];
load("annotate_files/Day3_CNOSAL_Group1_E_v09152023_closer_60f.mat")
percent_Qin = [percent_Qin; sum(E.HuddleStates) / length(E.HuddleStates)];
HuddleIdentity_percent_Qin = [HuddleIdentity_percent_Qin; sum(E.HuddleIdentity > 1) / length(E.HuddleIdentity)];
load("annotate_files/Day3_CNOSAL_Group2a_E_v09152023_closer_60f.mat")
percent_Qin = [percent_Qin; sum(E.HuddleStates) / length(E.HuddleStates)];
HuddleIdentity_percent_Qin = [HuddleIdentity_percent_Qin; sum(E.HuddleIdentity > 1) / length(E.HuddleIdentity)];
load("annotate_files/Day3_CNOSAL_Group3_E_v09152023_closer_60f.mat")
percent_Qin = [percent_Qin; sum(E.HuddleStates) / length(E.HuddleStates)];
HuddleIdentity_percent_Qin = [HuddleIdentity_percent_Qin; sum(E.HuddleIdentity > 1) / length(E.HuddleIdentity)];
percent_Naren = percent_Naren * 100;
percent_Qin = percent_Qin * 100;
HuddleIdentity_percent_Qin = HuddleIdentity_percent_Qin *100;
HuddleIdentity_percent_Naren = HuddleIdentity_percent_Naren * 100;
