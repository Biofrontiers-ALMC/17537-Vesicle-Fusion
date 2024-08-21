clearvars
clc

load('test_21-Aug-2024 08_53_24.mat')
ROI = [512 1666 250 350];

%% First filter tracks

trackID_to_delete = [];

nFrames = zeros(1, tracks.NumTracks);
for iT = 1:tracks.NumTracks

    ct = getTrack(tracks, iT);

    nFrames(iT) = numel(ct.Frames);

    if numel(ct.Frames) <= 4
        trackID_to_delete(end + 1) = iT;
    end

end

filteredTracks = tracks;
for ii = 1:numel(trackID_to_delete)
    filteredTracks = deleteTrack(filteredTracks, trackID_to_delete(ii));
end

%Remake a video

vid = VideoWriter('20240821_filteredTracks.avi');
vid.FrameRate = 7.5;
open(vid);

for iT = 1:reader.sizeT

    I = getPlane(reader, 1, 1, iT, 'ROI', ROI);

    I_clean = medfilt2(I, [3 3]);
    I_clean = double(imtophat(I_clean, strel('disk', 20)));

    Iout = (I_clean - min(I_clean(:)))/(max(I_clean(:)) - min(I_clean(:)));

    for idx = 1:filteredTracks.NumTracks

        id = filteredTracks.Tracks(idx).ID;

        ct = getTrack(filteredTracks, id);

        frameIdx = find(ct.Frames == iT, 1, 'first');

        if ~isempty(frameIdx)

            Iout = insertShape(Iout, 'filled-circle', [ct.Centroid(frameIdx, :), 3]);
            Iout = insertText(Iout, ct.Centroid(frameIdx, :), int2str(id), 'BoxOpacity', 0, 'FontColor', 'white');

            if frameIdx > 1

                Iout = insertShape(Iout, 'line', ct.Centroid(1:frameIdx, :));

            end
        end
    end

    writeVideo(vid, Iout)
end

close(vid)

%% Try and identify fusion events

trackPositions = nan(filteredTracks.NumTracks, filteredTracks.MaxFrame, 2);

for idx = 1:filteredTracks.NumTracks

    id = filteredTracks.Tracks(idx).ID;

    ct = getTrack(filteredTracks, id);

    centroids = cat(1, ct.Centroid);
    centroids = reshape(centroids, 1, [], 2);
    trackPositions(idx, ct.Frames, :) = centroids;

end

%%

fusionEvents = struct('particleID', [], 'fusedInto', [], 'frame', []);

for iRow = 1:size(trackPositions, 1)

    %Find where track ends
    idxFirstFrame = find(~isnan(trackPositions(iRow, :, 1)), 1, 'first');
    idxLastFrame = find(isnan(trackPositions(iRow, idxFirstFrame:end, 1)), 1, 'first');

    idxLastFrame = idxLastFrame + idxFirstFrame - 2;

    if idxLastFrame < size(trackPositions, 2) 

        lastPosition = trackPositions(iRow, idxLastFrame, :);

        %Grab all other known particle positions
        otherParticlePositions = trackPositions(:, idxLastFrame, :);

        %Calculate distance
        distances = sqrt(sum((lastPosition - otherParticlePositions).^2, 3));

        idxFusionCandidate = find((distances > 0) & (distances <= 20), 1, 'first');

        if ~isempty(idxFusionCandidate)
            eventIdx = numel(fusionEvents) + 1;
            fusionEvents(eventIdx).particleID = filteredTracks.Tracks(iRow).ID;
            fusionEvents(eventIdx).fusedInto = filteredTracks.Tracks(idxFusionCandidate).ID;
            fusionEvents(eventIdx).frame = idxLastFrame;
        end
    end
end

%See if there is another particle near the end of this particle's last
%known position. TODO: Find gaps in middle of track

save('20240821_fusionEvents.mat', 'fusionEvents')












