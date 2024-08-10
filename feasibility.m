clearvars
clc

reader = BioformatsImage('../data/Cos7_mCh_Rab5_Halo_KDEL_002.nd2');

LAP = LAPLinker;
LAP.LinkScoreRange = [0, 50];

vid = VideoWriter('test.avi');
vid.FrameRate = 7.5;
open(vid);

for iT = 1:50

    I = getPlane(reader, 1, 1, iT);

    % Try background subtraction
    I_clean = double(imtophat(I, strel('disk', 20)));

    %Spot detection
    dogImg = imgaussfilt(I_clean, 2) - imgaussfilt(I_clean, 10);

    spotMask = dogImg > 10;
    spotMask = bwareaopen(spotMask, 30);

    spotData = regionprops(spotMask, 'Centroid');

    LAP = assignToTrack(LAP, iT, spotData);

    Iout = im2double(I);
    
    Iout = insertShape(Iout, 'circle', [cat(1, spotData.Centroid) ones(numel(spotData), 1) * 3]);

    for id = LAP.activeTrackIDs

        ct = getTrack(LAP, id);

        if numel(ct.Frames) > 1
            Iout = insertShape(Iout, 'line', ct.Centroid);
            Iout = insertText(Iout, ct.Centroid(end, :), int2str(id));
        end     
        
    end

    writeVideo(vid, Iout)

end

close(vid)