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
    % Use first frame of video as template to compare future frames against
    template = rgb2gray(readFrame(reader));
    reader.CurrentTime = 0;
    % Template auto-correlation coefficient
    TMM = template - mean2(template);
    templateACC = sum(sum(TMM.*TMM));
    % Frame correlation to template values, indexed by frame number
    corr2Values = zeros(1,int32(reader.FrameRate*reader.Duration));
    % How close a frame needs to be to minCorr2 to be a candidate
    candidateRatio = 1.1;
    % Struct to contain plug frames and associated information
    plugs = struct( ...
        'plugID', {}, ...
        'frame', {}, ...
        'frameID', {}, ...
        'corrCoef', {});
    % Plug ID
    plugID = 0;
    % New plug flag
    newPlug = true;
    % Frame count
    frameCount = 0;
    
    %% Detect Candidate Frames
    % Iterate through video and find min correlation with template
    while hasFrame(reader)
        frameCount = frameCount + 1;
        currentFrame = rgb2gray(readFrame(reader)); % Read frame in gray scale
        
        % Get cross correlation coefficient
        CMM = currentFrame - mean2(currentFrame);
        corr2CurrentFrame = sum(sum(TMM.*CMM))/sqrt(templateACC*sum(sum(CMM.*CMM)));
        
        corr2Values(frameCount) = corr2CurrentFrame; % Assign correlation value
    end
    
    % Set the minimum correlation value
    minCorr2 = min(corr2Values);
    % Reset frame count
    frameCount = 0;
    
    % Collect candidate frames, those that are within % of min correlation
    for i = 1:size(corr2Values,2)
        frameCount = frameCount + 1;
        
        if corr2Values(frameCount) <= minCorr2*candidateRatio
            if newPlug
                plugID = plugID + 1;
                newPlug = false;
            end
            
            plugs(end+1).plugID = plugID;
            plugs(end).frame = read(reader,frameCount);
            plugs(end).frameID = frameCount;
            plugs(end).corrCoef = corr2Values(frameCount);
        else
            newPlug = true;
        end
    end
end