function spotMask = identifySpots(imageIn)

   % Try background subtraction
    I_clean = double(imtophat(imageIn, strel('disk', 20)));

    %Spot detection
    dogImg = imgaussfilt(I_clean, 2) - imgaussfilt(I_clean, 8);

    spotMask = dogImg > 8;
    spotMask = bwareaopen(spotMask, 30);