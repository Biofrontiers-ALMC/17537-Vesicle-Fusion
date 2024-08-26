classdef EndosomeTracker
    %ENDOSOMETRACKER  Identify and track endosomes
    %
    %  ET = ENDOSOMETRACKER creates a new object that can be used to
    %  process movies with fluorescently-labeled endosomes. Parallel
    %  processing is supported.
    %
    %  EndosomeTracker properties:
    %    SpotQuality - Higher values leads
    %    MaxAllowedDisplacement
    %    ParallelProcess
    %    ROI - (optional)
    %
    %  EndosomeTracker methods:
    %    process - Process file(s)
    %
    %  Example:
    %    %Create a new EndosomeTracker object
    %    ET = EndosomeTracker
    %
    %    %Change parameters as necessary
    %    ET.SpotQuality = 10
    %
    %    %Process all files in a directory
    %    process(ET, 'path/to/data')

    properties
        
        SpotQuality = 8;  %Quality of valid spots. Higher values leads to less number of spots.
        MaxAllowedDisplacement = 15;  %Max motion of a particle in pixels.

        ParallelProcess = false;  %Set to true to use parallel processing
        ParallelRequestedWorkers = 4;

        ROI = []; %ROI to process [Xmin, Ymin, width, height]. Leave empty to process whole image.

    end


    methods

        function process(obj, varargin)
            %PROCESS  Identify and track endosomes in files
            %
            %  PROCESS(OBJ) will open a dialog box to allow files to be
            %  selected manually. Note using this method only allows files
            %  to be selected from the same directory. To process files in
            %  different directories, see below.
            %
            %  PROCESS(OBJ, FN) will process specified files. FN must be
            %  either a character array with a path to a file or a cell of
            %  arrays with paths to multiple files.
            %
            %  PROCESS(OBJ, DIR) will process all ND2 files in the
            %  specified folder DIR.
            %
            %  PROCESS(OBJ, ..., OUTPUTDIR) will save all outputs into the
            %  directory specified. If OUTPUTDIR is not set, the output
            %  will be saved to the save directory as the input files.
            %
            %  Note that this function handles the files and any parallel
            %  processing. Actual processing code is in the function
            %  processFile.
            %
            %  See also: EndosomeTracker/processFile

            %Parse inputs
            if isempty(varargin)

                [fileList, filePath] = uigetfile(...
                    {'*.nd2; *.tif; *.tiff', 'Supported image files (*.nd2, *.tif, *.tiff)'; ...
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
                    fileList = dir(fullfile(varargin{1}, '*.nd2'));

                    files = cell(1, numel(fileList));

                    for iFile = 1:numel(fileList)
                        files{iFile} = fullfile(fileList(iFile).folder, fileList(iFile).name);
                    end
                elseif exist(varargin{1}, 'file')

                    files = {varargin{1}};

                else
                    error('EndosomeTracker:process:InvalidFileOrDir', 'Could not find file or folder: %s', ...
                        varargin{1})
                end

            elseif iscell(varargin{1})

                %Assume that it is a list of files
                files = varargin{1};

            else
                error('EndosomeTracker:process:InvalidInput', ...
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

            %Compile options
            opts.ROI = obj.ROI;
            opts.MaxAllowedDisplacement = obj.MaxAllowedDisplacement;
            opts.SpotQuality = obj.SpotQuality;

            %Process files
            parfor (iFile = 1:numel(files), M)

                EndosomeTracker.processFile(files{iFile}, outputDir, opts)

            end

        end

    end

    methods (Static)

        function processFile(inputFile, outputDir, opts)
            %PROCESSFILE  Process a file
            %
            %  This function handles the actual file processing.

            try
                reader = BioformatsImage(inputFile);
            catch
                fprintf('[%s] Error reading file %s\n', ...
                    datetime, inputFile)
                return
            end

            if isempty(opts.ROI)
                ROI = [1 1 reader.height, reader.width];
            else
                ROI = [512 1666 250 350];
            end

            [fpath, fn, fext] = fileparts(inputFile);

            if isnan(outputDir)
                outputDir = fpath;
            end

            LAP = LAPLinker;
            LAP.LinkScoreRange = [0, opts.MaxAllowedDisplacement];
            LAP.MaxTrackAge = 2;
            LAP = updateMetadata(LAP, 'Filename', [fn, fext]);
            LAP = updateMetadata(LAP, 'Filepath', fpath);
            LAP = updateMetadata(LAP, 'ROI', opts.ROI);

            vid = VideoWriter(fullfile(outputDir, [fn, '.avi']));
            vid.FrameRate = 7.5;
            open(vid);

            fprintf('[%s] Started processing file %s\n', ...
                    datetime, fn)

            for iT = 1:reader.sizeT

                I = getPlane(reader, 1, 1, iT, 'ROI', ROI);

                I_clean = medfilt2(I, [3 3]);
                I_clean = double(imtophat(I_clean, strel('disk', 20)));

                spotMask = EndosomeTracker.identifySpots(I_clean, opts.SpotQuality);

                spotData = regionprops(spotMask, 'Centroid', 'BoundingBox');

                LAP = assignToTrack(LAP, iT, spotData);

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


            save(fullfile(outputDir, [fn, '.mat']), 'LAP', 'opts')

            fprintf('[%s] Completed processing file %s\n', ...
                    datetime, fn)

        end

        function spotMask = identifySpots(imageIn, spotQuality)
            %IDENTIFYSPOTS  Find spots using different of Gaussians
            %
            %  MASK = IDENTIFYSPOTS(I, QUALITY) returns a binary mask of
            %  spots found in image I. QUALITY is the spot quality - higher
            %  numbers will result in less spots.

            %Spot detection
            dogImg = imgaussfilt(imageIn, 2) - imgaussfilt(imageIn, 7);

            spotMask = dogImg > spotQuality;

            %Remove any small spots
            spotMask = bwareaopen(spotMask, 30);

        end

    end
end