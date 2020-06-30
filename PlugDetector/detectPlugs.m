% Takes a video file name as an input. The file should contain a video of
% droplets which will then be tracked. Returns a matrix containing each
% frame where a droplet is in full view.
% 
% USAGE: droplets = detectDroplets(fileName)
%        
%   fileName: A string or character array containing the fileName or path.
%       e.g. 'sample1.avi'

function plugs = detectPlugs(filename)
    %% Initialize Workspace
    % Creates video reader to read frames from video file
    reader = VideoReader(filename);
    % Frame entropy, indexed by frame number
    entropyValues = zeros(1,int32(reader.FrameRate*reader.Duration));
    % How close a frame needs to be to min entropy to be a candidate
    candidateRatio = .99;
    % Struct to contain plug frames and associated information
    plugs = struct( ...
        'plugID', {}, ...
        'frame', {}, ...
        'frameID', {}, ...
        'entropy', {});
    % Plug ID
    plugID = 0;
    % New plug flag
    newPlug = true;
    % Frame count
    frameCount = 0;
    
    %% Detect Candidate Frames
    % Iterate through video and find max entropy
    while hasFrame(reader)
        frameCount = frameCount + 1;
        entropyValues(frameCount) = entropy(rgb2gray(readFrame(reader))); % Assign entropy value
    end
    
    % Set the maximum entropy value
    maxEntropy = max(entropyValues);
    % Reset frame count
    frameCount = 0;
    
    % Collect candidate frames, those that are within % of max entropy
    for i = 1:size(entropyValues,2)
        frameCount = frameCount + 1;
        
        if entropyValues(frameCount) >= maxEntropy*candidateRatio
            if newPlug
                plugID = plugID + 1;
                newPlug = false;
            end
            
            plugs(end+1).plugID = plugID;
            plugs(end).frame = read(reader,frameCount);
            plugs(end).frameID = frameCount;
            plugs(end).entropy = entropyValues(frameCount);
        else
            newPlug = true;
        end
    end
end