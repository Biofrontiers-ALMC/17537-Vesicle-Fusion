clearvars
clc

ET = EndosomeTracker;
ET.ROI = [512 1666 250 350];
ET.ParallelProcess = true;

process(ET, '../data/Gessner_Vesicle Fusion Data', '../processed/20240826')

%%

F = FusionFinder;
findFusions(F, 'D:\Projects\ALMC Tickets\T17537\processed\20240826')