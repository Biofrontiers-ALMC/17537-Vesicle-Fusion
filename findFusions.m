clearvars
clc

load test.mat



%%
%Find tracks which end in the middle of the video
tracks = LAP.tracks;

validTrackIdxs = [];

for iTrack = 1:tracks.NumTracks

    ct = getTrack(tracks, iTrack);

    if ct.Frames(end) > 5 && ct.Frames(end) < 50 && numel(ct.Frames) > 10
        validTrackIdxs(end + 1) = iTrack;
    end

end
%%
%Now parse through tracks and see if there was another track nearby
for iVT = validTrackIdxs

    ct = getTrack(tracks, iVT);

    lastFrame = ct.Frames(end);

    for iTrack = 1:tracks.NumTracks

        if iTrack == iVT
            continue
        end

        ot = getTrack(tracks, iTrack);

        if ismember(lastFrame, ot.Frames)

            idx = find(ot.Frames == lastFrame, 1, 'first');

            %Skip if the fusion happens near the start of the track - this
            %is likely a mis-identification issue
            if idx < 2
                continue
            end

            ot_pos = ot.Centroid(idx, :);

            dist = sqrt(sum((ot_pos - ct.Centroid(end, :)).^2, 2));

            if dist <= 10

                vid = VideoWriter(sprintf('test_zoom_%d_%d.avi', ot.ID, ct.ID));
                vid.FrameRate = 1;
                open(vid)
                %Get 5 frames before and 5 frames after
                for iFrame = (lastFrame - 5):(lastFrame + 5)

                    I = imadjust(getPlane(reader, 1, 1, iFrame));
                    I = imtophat(I, strel('disk', 20));

                    idx_ot = find(ot.Frames == iFrame, 1, 'first');

                    if ~isempty(idx_ot)
                        I = insertShape(I, 'circle', [ot.Centroid(idx_ot, :), 12], 'color', 'blue');
                    end

                    idx_ct = find(ct.Frames == iFrame, 1, 'first');
                    if ~isempty(idx_ct)
                        I = insertShape(I, 'circle', [ct.Centroid(idx_ct, :), 12], 'color', 'red');
                    end

                    I = im2double(I);
                    writeVideo(vid, I);

                    
                end
                close(vid)

            end
        end

    end
end