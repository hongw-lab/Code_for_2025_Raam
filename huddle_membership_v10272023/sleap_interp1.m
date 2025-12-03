function result = sleap_interp1(QSleap)

% interpolate and smooth all data
[frameCount, n_nodes, two_dim, n_mice] = size(QSleap);
result = zeros(frameCount, n_nodes, two_dim, n_mice);

for k=1:n_mice %size(QSleap,4)%each animal

  for i=1:n_nodes %each node

    for j=1:two_dim %each coordinate

      track = QSleap(:,i,j,k);
      bad = find(~isfinite(track)); %find indices of NaNs
      good = find(isfinite(track)); %find indices of known values

      if any(bad)
        replace_bad = interp1(good,track(good),bad,'linear'); %interpolate
        track(bad) = replace_bad; %fill in interpolated values

        % double check locs not addressed by interp1
        bad = find(isnan(track));
        good = find(isfinite(track));

        % skip the following check if nans are removed
        if any(bad)

          if ismember(1, bad) % check bad from head
            head = good(1);
            % fprintf(['nan found from frame 1 to %d are replaced ' ...
            % 'by frame %d \n'], head-1, head);
            track(1:head-1) = track(head);
          end

          if ismember(frameCount, bad)
            tail_good = good(end);
            % fprintf(['nan found from frame %d to %d are replaced ' ...
            % 'by frame %d \n'], tail_good+1, frameCount, tail_good);
            track(tail_good+1:end) = track(good(end));
          end

          if any(~isfinite(track))
            fprintf('-------\n\nSome place were not fixed \n\n -------');
          end

        end % end replacing bad in front or tail

      end % end checking bad

      result(:,i,j,k) = track;
      %smooth data, moving median filter, 5 frame window
      result(:,i,j,k) = smoothdata(result(:,i,j,k),'movmedian',5);
    end % end looping over x,z dimension

  end % end looping over nodes

end % end looping over mice

end % end of function