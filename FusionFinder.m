classdef FusionFinder
    %FUSIONFINDER  Find endosome fusion events
    %
    %  F = FUSIONFINDER creates a new object that will parse through track data
    %  and identify potential fusion events.

    properties

        ParallelProcess = false;
        ParallelRequestedWorkers = 4;

    end

    methods

        function findFusions(obj, varargin)
            %FINDFUSIONS  Process MAT-file to find fusion events
            %
            %  FINDFUSIONS(OBJ) will open a dialog box to allow files to be
            %  selected manually. Note using this method only allows files
            %  to be selected from the same directory. To process files in
            %  different directories, see below.
            %
            %  FINDFUSIONS(OBJ, FN) will process specified files. FN must be
            %  either a character array with a path to a file or a cell of
            %  arrays with paths to multiple files.
            %
            %  FINDFUSIONS(OBJ, DIR) will process all MAT-files in the
            %  specified folder DIR.
            %
            %  FINDFUSIONS(OBJ, ..., OUTPUTDIR) will save all outputs into
            %  the directory specified. If OUTPUTDIR is not set, the output
            %  will be saved to the save directory as the input files.
            %
            %  Note that this function handles the files and any parallel
            %  processing. Actual processing code is in the function
            %  processFile.
            %
            %  See also: FusionFinder/findEventsInFile

            %Parse inputs
            if isempty(varargin)

                [fileList, filePath] = uigetfile(...
                    {'*.mat', 'MATLAB MAT-files (*.mat)'; ...
                    '*.*', 'All files (*.*)'}, 'Select file(s)', ...
                    'multiSelect', 'on');

                if isequal(fileList, 0)
                    %Cancel button pressed
                    return
                end

                files = cell(1, numel(fileList));

                for iFile = 1:numel(fileList)
                    files{iFile} = fullfile(filePath, fileList{iFile});
                end

            elseif ischar(varargin{1})

                %Check if the input is a filename or a directory
                if exist(varargin{1}, 'dir')
                    fileList = dir(fullfile(varargin{1}, '*.mat'));

                    if isempty(fileList)

                        error('No MAT files found in directory %s.', varargin{1})

                    end

                    files = cell(1, numel(fileList));

                    for iFile = 1:numel(fileList)
                        files{iFile} = fullfile(fileList(iFile).folder, fileList(iFile).name);
                    end

                elseif exist(varargin{1}, 'file')
                    files = {varargin{1}};
                else
                    error('FusionFinder:process:InvalidFileOrDir', 'Could not find file or folder: %s', ...
                        varargin{1})
                end

            elseif iscell(varargin{1})

                %Assume that it is a list of files
                files = varargin{1};

            else
                error('FusionFinder:process:InvalidInput', ...
                    'Unexpected input type. Expected either no input, a char/string, or a cell of chars.')
            end

            if numel(varargin) == 2
                outputDir = varargin{2};

                if ~exist(outputDir, 'dir')
                    mkdir(outputDir)
                end
            else
                outputDir = NaN;
            end

            if obj.ParallelProcess && numel(files) > 1
                M = obj.ParallelRequestedWorkers;
            else
                M = 0;
            end

            %Process files
            parfor (iFile = 1:numel(files), M)

                FusionFinder.findEventsInFile(files{iFile}, outputDir)

            end
        end
    end

    methods (Static)

        function findEventsInFile(file, outputDir)

            [fpath, fn, fext] = fileparts(file);

            fprintf('[%s] Started processing file %s\n', ...
                datetime, fn)

            load(file)

            %Check if the file has the required variables
            if ~exist('LAP', 'var')
                fprintf('[%s] File %s does not have tracked data. Skipping.\n', ...
                    datetime, fn)
                return
            end

            nd2Filepath = fullfile(LAP.tracks.FileMetadata.Filepath, ...
                LAP.tracks.FileMetadata.Filename);

            %Load in reader
            reader = BioformatsImage(nd2Filepath);
            ROI = opts.ROI;

            tracks = LAP.tracks;



            if isnan(outputDir)
                outputDir = fpath;
            end

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

            vid = VideoWriter(fullfile(outputDir, [fn, '_filtered.avi']));
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

            %fusionEvents = struct('particleID', [], 'fusedInto', [], 'frame', []);
            fusionEvents = [];

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
                        if isempty(fusionEvents)
                            eventIdx = 1;
                        else
                            eventIdx = numel(fusionEvents) + 1;
                        end
                        fusionEvents(eventIdx).particleID = filteredTracks.Tracks(iRow).ID;
                        fusionEvents(eventIdx).fusedInto = filteredTracks.Tracks(idxFusionCandidate).ID;
                        fusionEvents(eventIdx).frame = idxLastFrame;
                    end
                end
            end

            %See if there is another particle near the end of this particle's last
            %known position. TODO: Find gaps in middle of track

            save(fullfile(outputDir, [fn, '_events.mat']), 'fusionEvents')

            fprintf('[%s] Completed processing file %s\n', ...
                datetime, fn)

        end
    end

end