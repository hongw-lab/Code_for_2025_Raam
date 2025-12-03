function status_pred_clean = removing_label_with_short_durations(status, threshold, using_closer_label_instead_of_smallest)
status_pred_clean = status;
if max(unique(status)) ~= 1
    range = max(unique(status)):-1:min(unique(status));
else
    range = [1, 0];
end

for label_i = 1:numel(range)
  label = range(label_i);
  status_diff = diff([0; status_pred_clean; 0]);
  time_starts = [find(status_diff ~= 0)];
  time_ends = [find(status_diff ~= 0)] - 1;
  time_starts = time_starts(1:numel(time_starts)-1);
  time_ends = time_ends(2:end);
  elapse = time_ends - time_starts + 1;
  locs = find(elapse < threshold);
  i_start = 1;
  % if the label is 0, representing no huddle, we check if it is at the
  % begining, if so, skip this
  if time_starts(locs) == 1
      i_start = 2;
  end
  for i = i_start:length(locs)
    loc = locs(i);
    if status_pred_clean(time_starts(loc)) == label
      label_pre = status_pred_clean(max(time_starts(loc) - 1, 1));
      label_aft = status_pred_clean(min(time_ends(loc) + 1, numel(status)));
      smaller_label = min(label_pre, label_aft);
      if abs(label_pre - label) < abs(label_aft - label)
        closer_label = label_pre;
      elseif abs(label_pre - label) == abs(label_aft - label)
        closer_label = smaller_label;
      else
        closer_label = label_aft;
      end
      if using_closer_label_instead_of_smallest
        status_pred_clean(time_starts(loc):time_ends(loc)) = closer_label;
      else
        status_pred_clean(time_starts(loc):time_ends(loc)) = smaller_label;
      end
    end
  end
end
end