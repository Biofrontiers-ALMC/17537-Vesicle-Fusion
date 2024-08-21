clearvars
clc

reader = BioformatsImage('../data/Gessner_Vesicle Fusion Data/Cos7_mCh_Rab5_Halo_KDEL_002.nd2');

ROI = [512 1666 250 350];

vid = VideoWriter('spotDetectionTest_centroidsonly_inROI.avi');
vid.FrameRate = 7.5;
open(vid)

for iT = 1:reader.sizeT

    I = getPlane(reader, 1, 1, iT, 'ROI', ROI);

    I_clean = medfilt2(I, [3 3]);
    I_clean = double(imtophat(I_clean, strel('disk', 20)));

    spotMask = identifySpots(I_clean);

    spotData = regionprops(spotMask, 'Centroid');


    % imshow(I_clean, [])

    % spotMask = identifySpots(I);
    %
    % %imshow(I, [])
    %Iout = showoverlay(I_clean, spotMask, 'opacity', 20);

    Inorm = (I_clean - min(I_clean(:)))/(max(I_clean(:)) - min(I_clean(:)));

    Iout = insertShape(Inorm, 'filled-circle', [cat(1, spotData.Centroid), ones(numel(spotData), 1) * 3]);

    writeVideo(vid, Iout)

end
close(vid)