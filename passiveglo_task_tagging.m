function [] = passiveglo_task_tagging(path)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
ogen_files = dir([path '/sub-*/sub-*_ogen.nwb']);
for i = 1:numel(ogen_files)
    ogen_path = ogen_files(i).folder;
    ogen_nwb = nwbRead([ogen_files(i).folder '/' ogen_files(i).name]);
    passiveglo_data = ALLENINSTITUTE_PassiveGLOv2(ogen_nwb);
    save([ogen_path '/passiveglo_task_data.mat'], "-struct", "passiveglo_data");
end
end