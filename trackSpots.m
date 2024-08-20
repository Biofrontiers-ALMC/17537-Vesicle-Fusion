clearvars
clc

reader = BioformatsImage('../data/Gessner_Vesicle Fusion Data/Cos7_mCh_Rab5_Halo_KDEL_002.nd2');

LAP = LAPLinker;
LAP.LinkScoreRange = [0, 30];
LAP.MaxTrackAge = 0;

vid = VideoWriter('test.avi');
vid.FrameRate = 7.5;
open(vid);

fprintf('Starting %s\n', datetime)

for iT = 1:reader.sizeT

    I = getPlane(reader, 1, 1, iT);

    spotMask = identifySpots(I);

    spotData = regionprops(spotMask, 'Centroid');

    LAP = assignToTrack(LAP, iT, spotData);

    Iout = im2double(I);
    
    Iout = insertShape(Iout, 'circle', [cat(1, spotData.Centroid) ones(numel(spotData), 1) * 3]);

    for id = LAP.activeTrackIDs

        ct = getTrack(LAP, id);

        if numel(ct.Frames) > 1
            Iout = insertShape(Iout, 'line', ct.Centroid);
            %Iout = insertText(Iout, ct.Centroid(end, :), int2str(id));
        end     
        
    end

    writeVideo(vid, Iout)

end

close(vid)

tracks = LAP.tracks;

save(sprintf('test_%s.mat', strrep(char(datetime), ':', '_')), 'reader', 'tracks')
fprintf('Completed %s\n', datetime)
