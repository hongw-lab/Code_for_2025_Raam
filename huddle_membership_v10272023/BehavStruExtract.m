function [Behavior, Annotation] = BehavStruExtract(behav_A_path, n)
% input annotation txt file path and animal# in this pair (1 or 2)
% output behavior & annotation of F structure

behav_A = behaviorData('load', behav_A_path); 


    %% construt behavior struct
    all_behavs = behav_A.getNames();
    n_behavs = length(all_behavs); % do not count 'other' 
    Behavior.EventNames = all_behavs(1:end);
    Behavior.EventNames = all_behavs(1:end);
    Behavior.LogicalVecs = cell(1, n_behavs);
    Behavior.OnsetTimes = cell(1, n_behavs);
    Behavior.OffsetTimes = cell(1, n_behavs);
    Behavior.LogicalVecs = cell(1, n_behavs);
    Behavior.OnsetTimes = cell(1, n_behavs);
    Behavior.OffsetTimes = cell(1, n_behavs);
    % animal 1
    behav_A.setStrm(n);
    for i = 1:n_behavs 
        this_b_name = all_behavs{i};
        Behavior.LogicalVecs{i} = (behav_A.getLbls() == (i));
        btypes = behav_A.getTypes();
        btype_ids = find(btypes == (i)); % 1 is 'other', skip
        bstart = [];
        bend = [];
        for j = btype_ids
            bstart = [bstart, behav_A.getStart(j)];
            bend = [bend, behav_A.getEnd(j)];
        end
        Behavior.OnsetTimes{i} = bstart;
        Behavior.OffsetTimes{i} = bend;
    end


    Annotation.annBD = behav_A;
    
    
    
        
        


end

