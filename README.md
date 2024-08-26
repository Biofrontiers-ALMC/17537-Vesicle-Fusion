# Finding endosome fusions

The goal of this project was to identify endosome fusion events.

## Code description

The code works by first identifying endosomes in images using the difference of Gaussians filter. The endosomes were then tracked over the video, and the resulting data was filtered to keep tracks that were at least 4 frames long. Fusion events were then identified by looking for tracks which ended within 20 pixels of another particle.

### Known limitations

* Endosomes moving very close to/on top of each other but not actually fusing might result in a false positive (there is no easy way to distinguish this visually) 
* A endosomes photobleaching/leaving the field of view near another particle might result in a false positive.
* Fast moving endosomes (> 15 pixels per frame) might not be properly tracked.

## How to use

### Requirements

* MATLAB (R2023b or later) with the following toolboxes:
  * Computer Vision Toolbox
  * Image Processing Toolbox
  * Parallel Processing Toolbox
  * [Bioformats Image Toolbox](https://github.com/Biofrontiers-ALMC/bioformats-matlab/releases/tag/v1.2.3) (v 1.2.3 or later)
  * [Cell Tracking Toolbox](https://github.com/Biofrontiers-ALMC/cell-tracking-toolbox/releases/tag/v2.1.1) (v 2.1.1 or later)

**Note:** The first two toolboxes are shipped with MATLAB and can be installed using the MATLAB installer. The latter two can be downloaded using the links above. After downloading, simply open the *.mltbx files with MATLAB to install.

### Overview

The code is broken up into two classes:
1. ``EndosomeTracker`` for identification and tracking of endosomes.
2. ``FusionFinder`` for identifying fusion events.

### Example scruot

An example script is provided in ``run_example.m``.

### Tracking endosomes

To track endosomes:

1. Create a new EndosomeTracker object
   ```matlab
   ET = EndosomeTracker
   ```

2. Set parameters (if necessary)
   ```matlab
   ET.SpotQuality = 8

   %Enable parallel processing
   ET.ParallelProcess = true
   ```

3. Process your movies
   ```matlab
   process(ET)
   ```

#### Output

EndosomeTracker will output the following:
* AVI-file showing identified spots and their tracked positions. I recommend viewing this with Fiji/ImageJ to see what is happening frame-by-frame.
* MAT-file with the tracked data

### Finding fusion events

1. Create a new FusionFinder object
   ```matlab
   F = FusionFinder
   ```

2. Set parameters (if necessary)
   ```matlab
   %Enable parallel processing
   F.ParallelProcess = true
   ```

3. Process files
   ```matlab
   process(F)
   ```

#### Output

FusionFinder will output the following:
* AVI-file showing filtered tracks (longer than 4 frames). I recommend viewing this with Fiji/ImageJ to see what is happening frame-by-frame.
* MAT-file ('_events.mat') with the fusion events.

The fusion events are stored in a struct named ``fusionEvents``. There are three fields:

- ``particleID`` is ID of the endosome which disappears
- ``fusedInto`` is ID of the nearby endosome
* ``frame`` is the frame in which the fusion occurs

To get number of fusion events you can use

```matlab
nEvents = numel(fusionEvents)
```

## Frequently Asked Questions (FAQs)

1. What value should I set for the ``MaxAllowedDisplacement``?
   
   ``MaxAllowedDisplacement`` should be set to the average maximum displacement of an endosome between two frames. One way to estimate this is to open the movie in ImageJ/Fiji and use the line tool to estimate the distance moved between frames.

   Generally, if the results show tracks too many endosomes "switching" IDs, it's likely this value is too high (it's linking unrelated particles). However, if a single endosome is being assigned a new ID every frame, then the value is too low.

2. How do I enable parallel processing?
   
   Parallel processing uses your computer's multiple CPU cores to process multiple files at once. This _may_ speed up the process, provided you have sufficient RAM to hold all the data.

   Parallel processing is available for both the ``EndosomeTracker`` and ``FusionFinder`` classes. To enable, set the property ``ParallelProcess`` to ``true``.

   Example:
   ```matlab
   ET = EndosomeTracker;
   ET.ParallelProcess = true;
   ```

## Reporting issues

If you encounter any issues or difficulties:

* Send an email to biof-imaging@colorado.edu
* Create an [issue](https://github.com/Biofrontiers-ALMC/17537-Vesicle-Fusion/issues)

## Acknowledge us

See [here](https://biof-imagewiki.colorado.edu/books/facility-guidelines/page/recognizing-the-core) for guidelines.