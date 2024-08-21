function spotMask = identifySpots(imageIn)

   % Try background subtraction
    %I_clean = double(imtophat(imageIn, strel('disk', 20)));

    %Spot detection
    dogImg = imgaussfilt(imageIn, 2) - imgaussfilt(imageIn, 7);

    spotMask = dogImg > 8;
    spotMask = bwareaopen(spotMask, 30);