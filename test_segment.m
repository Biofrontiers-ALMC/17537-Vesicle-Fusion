clearvars
clc

reader = BioformatsImage('../data/Gessner_Vesicle Fusion Data/Cos7_mCh_Rab5_Halo_KDEL_002.nd2');


I = getPlane(reader, 1, 1, 1);

spotMask = identifySpots(I);

%imshow(I, [])
showoverlay(I, spotMask, 'opacity', 20)