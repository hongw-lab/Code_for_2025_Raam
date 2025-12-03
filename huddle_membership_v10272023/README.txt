The file to use is E_and_annotation_generator. This file produces E structure
and the annotation files.

Feel free to modify the template to add new behavior.

In load_options.m, we specify some of the options to use.

In import_human_labels_to_new_annotation.m, we import the manual annotations 
to the new annotation file.
Current major problem and examples:
1. How to address the overlap transitioning period.
For example, A-B for 10 sec then A-B-C for 1/2 seconds then B-C for 10 sec.
How to address this overlapping issue?
For example, A-B for 10 sec then A-B/C-D for 1/2 seconds then B0C for 10 sec.
How to address this transitioning issue?
09/17/2023 - Current strategies for the first one is reflected in the 
get_huddle_states.m The second one was not regorously discussed.
09/19/2023 - The strategy is updated by delaying the new joiner.

