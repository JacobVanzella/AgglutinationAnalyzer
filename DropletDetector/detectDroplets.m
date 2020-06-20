% Takes a video file name as an input. The file should contain a video of
% droplets which will then be tracked. Returns a matrix containing each
% frame where a droplet is in full view.
% 
% USAGE: droplets = detectDroplets(fileName)
%        droplets = detectDroplets(fileName, areaThreshold)
%        droplets = detectDroplets(fileName, areaThreshold, filtering)
%        droplets = detectDroplets(fileName, areaThreshold, filtering, display)
%        
%   fileName: A string or character array. e.g. 'sample1.avi'
% 
%   areaThreshold: An interger value that determines the minimum area
%       droplets that should be considered. e.g. areaThreshold = 10 returns
%       all droplets identified to have area of 10 pixels or greater.
%       (Default: 250000)
% 
%   filtering: Boolean value, if true applies filtering to remove small
%       particles from detection, if false filtering will not occur
%       (faster). (Default: false)
% 
%   display: Boolean value, if true shows video results as output is being
%       calculated, if false video is not shown (faster). (Default: false)
% 
% This code was adapted from the MathWorks Help Center page:
% https://www.mathworks.com/help/vision/examples/motion-based-multiple-object-tracking.html

function droplets = detectDroplets(fileName, areaThreshold, filter, display)
% Handles number of input arguments
switch nargin
    case 1
        areaThreshold = 250000; filter = false; display = false;
    case 2
        filter = false; display = false;
    case 3
        display = false;
end

% Predeclare global variables 

% Create System objects used for reading video, detecting moving objects,
% and displaying the results.
obj = setupSystemObjects(fileName);

tracks = initializeTracks(); % Create an empty array of tracks.
droplets = initializeDroplets(); % Create an empty array of droplets.

nextID = 1; % ID of the next track.
dropID = 0; % ID of the next droplet.
frameID = 0; % ID of the current frame.

% Detect moving objects, and track them across video frames.
while hasFrame(obj.reader)
    frameID = frameID + 1;
    frame = readFrame(obj.reader);
    [areas,centroids, bboxes, mask] = detectObjects(frame);
    predictNewLocationsOfTracks();
    [assignments, unassignedTracks, unassignedDetections] = detectionToTrackAssignment();
    
    if sum(areas >= areaThreshold); updateAssignedDroplets(); end
    
    updateAssignedTracks();
    updateUnassignedTracks();
    deleteLostTracks();
    createNewTracks();
    
    if display; displayTrackingResults(); end
end

    function obj = setupSystemObjects(str)
        % Initialize Video I/O
        % Create objects for reading a video from a file, drawing the tracked
        % objects in each frame, and playing the video.
        
        % Create a video reader.
        obj.reader = VideoReader(str);
        
        % Create two video players, one to display the video,
        % and one to display the foreground mask.
        obj.maskPlayer = vision.VideoPlayer('Position', [740, 400, 700, 400]);
        obj.videoPlayer = vision.VideoPlayer('Position', [20, 400, 700, 400]);
        
        % Create System objects for foreground detection and blob analysis
        
        % The foreground detector is used to segment moving objects from
        % the background. It outputs a binary mask, where the pixel value
        % of 1 corresponds to the foreground and the value of 0 corresponds
        % to the background.
        
        obj.detector = vision.ForegroundDetector('NumGaussians', 3, ...
            'NumTrainingFrames', 40, 'MinimumBackgroundRatio', 0.5);
        
        % Connected groups of foreground pixels are likely to correspond to moving
        % objects.  The blob analysis System object is used to find such groups
        % (called 'blobs' or 'connected components'), and compute their
        % characteristics, such as area, centroid, and the bounding box.
        
        obj.blobAnalyser = vision.BlobAnalysis('BoundingBoxOutputPort', true, ...
            'AreaOutputPort', true, 'CentroidOutputPort', true, ...
            'MinimumBlobArea', 400);
    end

    function droplets = initializeDroplets()
        % Create an empty array of droplet frames
        droplets = struct( ...
            'id', {}, ...
            'bbox', {}, ...
            'totalVisibleCount', {}, ...
            'frame', {}, ...
            'frameID' ,{});
    end

    function tracks = initializeTracks()
        % create an empty array of tracks
        tracks = struct(...
            'id', {}, ...
            'bbox', {}, ...
            'kalmanFilter', {}, ...
            'age', {}, ...
            'totalVisibleCount', {}, ...
            'consecutiveInvisibleCount', {});
    end

    function [area,centroids, bboxes, mask] = detectObjects(frame)
        
        % Detect foreground.
        mask = obj.detector.step(frame);
        
        % Apply morphological operations to remove noise and fill in holes.
        if filter
            mask = imopen(mask, strel('rectangle', [20,20]));
            mask = imclose(mask, strel('rectangle', [30, 30]));
            mask = imfill(mask, 'holes');
        end
        
        % Perform blob analysis to find connected components.
        [area, centroids, bboxes] = obj.blobAnalyser.step(mask);
    end

    function predictNewLocationsOfTracks()
        for i = 1:length(tracks)
            bbox = tracks(i).bbox;
            
            % Predict the current location of the track.
            predictedCentroid = predict(tracks(i).kalmanFilter);
            
            % Shift the bounding box so that its center is at
            % the predicted location.
            predictedCentroid = int32(predictedCentroid) - bbox(3:4) / 2;
            tracks(i).bbox = [predictedCentroid, bbox(3:4)];
        end
    end

    function [assignments, unassignedTracks, unassignedDetections] = detectionToTrackAssignment()
        
        nTracks = length(tracks);
        nDetections = size(centroids, 1);
        
        % Compute the cost of assigning each detection to each track.
        cost = zeros(nTracks, nDetections);
        for i = 1:nTracks
            cost(i, :) = distance(tracks(i).kalmanFilter, centroids);
        end
        
        % Solve the assignment problem.
        costOfNonAssignment = 20;
        [assignments, unassignedTracks, unassignedDetections] = ...
            assignDetectionsToTracks(cost, costOfNonAssignment);
    end

    function updateAssignedDroplets()
        % Set the areas lower than the threshold to zero
        dropletAreas = areas;
        dropletAreas(dropletAreas<areaThreshold) = 0;
        
        % Add frames meeting criteria to the droplets structure
        for i = 1:size(dropletAreas,1)
            if dropletAreas(i) && bboxes(i,1) ~= 1 && bboxes(i,2) ~= 1 ...
                    && bboxes(i,1) + bboxes(i,3) < size(frame,2) ...
                    && bboxes(i,2) + bboxes(i,4) < size(frame,1)
                
                if dropID == 0
                    dropID = dropID + 1;
                elseif droplets(end).frameID < (frameID - 3)
                    dropID = dropID + 1;
                end
                
                droplets(end+1).id = dropID;
                droplets(end).bbox = bboxes(i,:);
                droplets(end).totalVisibleCount = dropletAreas(i);
                droplets(end).frame = frame;
                droplets(end).frameID = frameID;
            end
        end
    end

    function updateAssignedTracks()
        numAssignedTracks = size(assignments, 1);
        for i = 1:numAssignedTracks
            trackIdx = assignments(i, 1);
            detectionIdx = assignments(i, 2);
            centroid = centroids(detectionIdx, :);
            bbox = bboxes(detectionIdx, :);
            
            % Correct the estimate of the object's location
            % using the new detection.
            correct(tracks(trackIdx).kalmanFilter, centroid);
            
            % Replace predicted bounding box with detected
            % bounding box.
            tracks(trackIdx).bbox = bbox;
            
            % Update track's age.
            tracks(trackIdx).age = tracks(trackIdx).age + 1;
            
            % Update visibility.
            tracks(trackIdx).totalVisibleCount = ...
                tracks(trackIdx).totalVisibleCount + 1;
            tracks(trackIdx).consecutiveInvisibleCount = 0;
        end
    end

    function updateUnassignedTracks()
        for i = 1:length(unassignedTracks)
            ind = unassignedTracks(i);
            tracks(ind).age = tracks(ind).age + 1;
            tracks(ind).consecutiveInvisibleCount = ...
                tracks(ind).consecutiveInvisibleCount + 1;
        end
    end

    function deleteLostTracks()
        if isempty(tracks)
            return;
        end
        
        invisibleForTooLong = 20;
        ageThreshold = 8;
        
        % Compute the fraction of the track's age for which it was visible.
        ages = [tracks(:).age];
        totalVisibleCounts = [tracks(:).totalVisibleCount];
        visibility = totalVisibleCounts ./ ages;
        
        % Find the indices of 'lost' tracks.
        lostInds = (ages < ageThreshold & visibility < 0.6) | ...
            [tracks(:).consecutiveInvisibleCount] >= invisibleForTooLong;
        
        % Delete lost tracks.
        tracks = tracks(~lostInds);
    end

    function createNewTracks()
        centroids = centroids(unassignedDetections, :);
        bboxes = bboxes(unassignedDetections, :);
        
        for i = 1:size(centroids, 1)
            
            centroid = centroids(i,:);
            bbox = bboxes(i, :);
            
            % Create a Kalman filter object.
            kalmanFilter = configureKalmanFilter('ConstantVelocity', ...
                centroid, [200, 50], [100, 25], 100);
            
            % Create a new track.
            newTrack = struct(...
                'id', nextID, ...
                'bbox', bbox, ...
                'kalmanFilter', kalmanFilter, ...
                'age', 1, ...
                'totalVisibleCount', 1, ...
                'consecutiveInvisibleCount', 0);
            
            % Add it to the array of tracks.
            tracks(end + 1) = newTrack;
            
            % Increment the next id.
            nextID = nextID + 1;
        end
    end

    function displayTrackingResults()
        % Convert the frame and the mask to uint8 RGB.
        frame = im2uint8(frame);
        mask = uint8(repmat(mask, [1, 1, 3])) .* 255;
        
        minVisibleCount = 8;
        if ~isempty(tracks)
            
            % Noisy detections tend to result in short-lived tracks.
            % Only display tracks that have been visible for more than
            % a minimum number of frames.
            reliableTrackInds = ...
                [tracks(:).totalVisibleCount] > minVisibleCount;
            reliableTracks = tracks(reliableTrackInds);
            
            % Display the objects. If an object has not been detected
            % in this frame, display its predicted bounding box.
            if ~isempty(reliableTracks)
                % Get bounding boxes.
                bboxes = cat(1, reliableTracks.bbox);
                
                % Get ids.
                ids = int32([reliableTracks(:).id]);
                
                % Create labels for objects indicating the ones for
                % which we display the predicted rather than the actual
                % location.
                labels = cellstr(int2str(ids'));
                predictedTrackInds = ...
                    [reliableTracks(:).consecutiveInvisibleCount] > 0;
                isPredicted = cell(size(labels));
                isPredicted(predictedTrackInds) = {' predicted'};
                labels = strcat(labels, isPredicted);
                
                % Draw the objects on the frame.
                frame = insertObjectAnnotation(frame, 'rectangle', ...
                    bboxes, labels);
                
                % Draw the objects on the mask.
                mask = insertObjectAnnotation(mask, 'rectangle', ...
                    bboxes, labels);
            end
        end
        
        % Display the mask and the frame.
        obj.maskPlayer.step(mask);
        obj.videoPlayer.step(frame);
    end
end