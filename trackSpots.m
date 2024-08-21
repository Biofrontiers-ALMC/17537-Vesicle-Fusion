clearvars
clc

reader = BioformatsImage('../data/Gessner_Vesicle Fusion Data/Cos7_mCh_Rab5_Halo_KDEL_002.nd2');

ROI = [512 1666 250 350];

LAP = LAPLinker;
LAP.LinkScoreRange = [0, 15];
LAP.MaxTrackAge = 2;

vid = VideoWriter('20240821_tracking_test.avi');
vid.FrameRate = 7.5;
open(vid);

fprintf('Starting %s\n', datetime)

for iT = 1:reader.sizeT

    I = getPlane(reader, 1, 1, iT, 'ROI', ROI);

    I_clean = medfilt2(I, [3 3]);
    I_clean = double(imtophat(I_clean, strel('disk', 20)));

    spotMask = identifySpots(I_clean);

    spotData = regionprops(spotMask, 'Centroid', 'BoundingBox');

    LAP = assignToTrack(LAP, iT, spotData);

    Iout = im2double(I);

    Inorm = (I_clean - min(I_clean(:)))/(max(I_clean(:)) - min(I_clean(:)));
    Iout = insertShape(Inorm, 'filled-circle', [cat(1, spotData.Centroid), ones(numel(spotData), 1) * 3]);

    for id = LAP.activeTrackIDs

        ct = getTrack(LAP, id);

        if numel(ct.Frames) > 1
            Iout = insertShape(Iout, 'line', ct.Centroid);
        end     
        
    end

    writeVideo(vid, Iout)

end

close(vid)

tracks = LAP.tracks;

save(sprintf('test_%s.mat', strrep(char(datetime), ':', '_')), 'reader', 'tracks')
fprintf('Completed %s\n', datetime)
