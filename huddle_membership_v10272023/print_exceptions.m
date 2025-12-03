function print_exceptions(HuddleIdentity, outFile, file_name)
try
  unique_labels = [4, 6, 8.6, 10, 16]';
  row_sum = round(sum(HuddleIdentity, 2), 2);
  if any(unique_labels ~= unique(row_sum, 'sorted'))
    fprintf('bug not fixed')
  end
catch ME
  warning('Huddle Identity contains irational values.')
  fprintf(outFile, '%s\n', file_name);
  fprintf(outFile, '[%s]\n', join(string(unique(row_sum)), ','));
  % Find the elements of A that are not in B
  exceptionalElements = ~ismember(row_sum, unique_labels);
  % Find unique rows and their indices
  [uniqueRows, ~, idx] = unique(HuddleIdentity(exceptionalElements, :), 'rows', 'stable');
  % Count occurrences of each unique row
  counts = accumarray(idx, 1);
  % Count the exceptional numbers
  numExceptional = sum(exceptionalElements);
  % Display results
  for i = 1:size(uniqueRows, 1)
    fprintf(outFile, ['Row: ', num2str(uniqueRows(i, :)), ', Count: ', num2str(counts(i)), '\n']);
  end
  % Calculate the total number of elements in A
  totalNumbers = numel(row_sum);

  % Print the result
  fprintf(outFile, 'The count of exceptional numbers: %d / %d == %.2f%%\n', numExceptional, totalNumbers, numExceptional/totalNumbers*100);
end
end