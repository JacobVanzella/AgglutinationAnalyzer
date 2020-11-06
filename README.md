## AgglutinationAnalyzer
Agglutination droplet tracking and analysis.

This project should be broken into two main functional compenents, droplet tracking, and droplet analysis.
This is a computer vision project programmed in MATLAB.


## Choosing detection method:
# Entropy Detection
The entropy detection method is light and fast, it was made to process images in faster than real time. The disadvatage is that it isn't robust, lighting conditions must constant and a candidate frame ratio must be determined experimentally beforehand.

# Foreground Detection
The foreground detection method (adapted from [this](https://www.mathworks.com/help/vision/examples/motion-based-multiple-object-tracking.html) MathWorks example) has the advantage of being very robust to changes in both lighting and droplet size, easily extended to multidroplet frame support if needed. The disadvantage is that it's slow, very slow, 10x real time slow.
