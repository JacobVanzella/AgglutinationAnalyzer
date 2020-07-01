% Takes a 4-D matrix of color images containing fluid droplets or plugs in
% a 2-phase flow regime. Returns objects of interest isolated from background.
% The edges of the objects are found, opened, filled, closed to remove
% extraneous edges, followed  by a bitwise AND to isolate the objects of
% interest in the original image.
% 
% USAGE: isolatedPlugs = isolatePlugs(frames)
%        [isolatedPlugs, label] = isolatePlugs(frames, label)
%        isolatedPlugs = isolatePlugs(frames, strel1, strel2)
%        [isolatedPlugs, label] = isolatePlugs(frames, label, strel1, strel2)
% 
%   frames: A 4-D matrix of color image frames where the fourth
%           dimension is the index of the image.
%   
%   label: A 1xM vector containing the object label ordered by frame
%       number.
%   
%   strel1: Structuring element used for image closing to fill edge gaps.
%       (Default: strel('disk',3))
%   
%   strel2: Structuring element used for image opening to remove extraneous
%       edges. (Default: strel('line',50,90))

function [isolatedPlugs, plugID] = isolatePlugs(frames, plugID, strel1, strel2)
    %% Handle function call
    % Exit call on invalid input
    if size(frames,3) ~= 3
        error("Invalid frame matrix, must be m x n x 3 x w");
    end
    
    % Handle input arguments
    switch nargin
        case {1, 2}
            se1 = strel('disk',4);
            se2 = strel('line',50,90);
        case {3, 4}
            se1 = strel1;
            se2 = strel2;
    end
    
    % Handle output arguments
    if nargout == 1; doLabel = false; else; doLabel = true; end
    
    %% Isolate plugs
    isolatedPlugs = zeros(size(frames),'uint8'); % Preallocate isolatedPlugs
    entropyPlugs = zeros(size(frames,4)); % Preallocate isolated entropyPlugs
    for i = 1:size(frames,4)
        % Get edges using Sobel
        edges = edge(rgb2gray(frames(:,:,:,i)),'Sobel');
        % Close edges to eliminate small gaps
        closedEdges = imclose(edges(:,:),se1);
        % Fill holes to create continuous logical image of object
        filledEdges = imfill(closedEdges(:,:),'holes');
        % Open image to remove extraneous edges and convert to unt8
        openedFilledEdges = im2uint8(imopen(filledEdges(:,:),se2));
        
        % Bit-wise AND mask with original image to isolate object
        isolatedPlugs(:,:,:,i) = bitand(frames(:,:,:,i),openedFilledEdges,'uint8');
        % Record entropy of isolated plug
        entropyPlugs(i) = entropy(isolatedPlugs(:,:,:,i));
    end
    
    %% Remove low entropy frames that do not contain full object
    for i = size(isolatedPlugs,4):-1:1
        % Trim low entropy frames
        if entropyPlugs(i) < 1
            isolatedPlugs(:,:,:,i) = [];
            entropyPlugs(i) = [];
            
            if doLabel
                plugID(i) = [];
            end
        end
    end
end