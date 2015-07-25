% TestClassifier.m
%  close all;
clear all;

[FileName,PathName] = uigetfile('*','Select Image to Test');
image_path = strcat(PathName,FileName);
img_to_test = imread(image_path);

% --happy DETECTOR -- %
% XML File name
apple_xml_file = 'apple.xml';
apple_detector = vision.CascadeObjectDetector(apple_xml_file,'MinSize',[100 100]);

% Find bbox of any detected objects
apple_bbox = step(apple_detector,img_to_test);

% remove any bounding boxes where the red is not the dominant color
apple_nDetected = size(apple_bbox,1);
counter = 0;
for i = 1:apple_nDetected
roi = img_to_test(apple_bbox(i,2):apple_bbox(i,2)+apple_bbox(i,4),...
        apple_bbox(i,1):apple_bbox(i,1)+apple_bbox(i,3),:);

    roi = (rgb2ycbcr(roi));
    roi=roi(:,:,3);
% YCBCR_mask = YCBCR(:,:,3)>143;

    [row, col] = size(roi);
    amount_red = sum(sum(roi>156)); %amount of red pixels
    red_ratio = amount_red/(row*col);
    if red_ratio < 0.54 ;
        %remove bounding box if less than 0.58 the pixels are red
        counter = counter+1;
        to_delete(counter) = i;        
    end    
end
% delete columns that don't meet red threshold
try
apple_bbox(to_delete,:) = [];
end
apple_nDetected = size(apple_bbox,1);


% Show the results
figure();
imshow(img_to_test);
hold on;

for ii = 1:apple_nDetected
patch([apple_bbox(ii,1),apple_bbox(ii,1)+apple_bbox(ii,3),apple_bbox(ii,1)+apple_bbox(ii,3),apple_bbox(ii,1),apple_bbox(ii,1)],...
[apple_bbox(ii,2),apple_bbox(ii,2),apple_bbox(ii,2)+apple_bbox(ii,4),apple_bbox(ii,2)+apple_bbox(ii,4),apple_bbox(ii,2)],...
'r','facealpha',0.5);
text(apple_bbox(ii,1),apple_bbox(ii,2)+20,'Apple')
end



% --SCISSORS DETECTOR -- %
% XML File name
scissors_xml_file = 'scissors.xml';
scissors_detector = vision.CascadeObjectDetector(scissors_xml_file,'MinSize',[60 60]);

% Find bbox of any detected objects
scissors_bbox = step(scissors_detector,img_to_test);

% remove any bounding boxes where the red is not the dominant color
scissors_nDetected = size(scissors_bbox,1);
counter = 0;
for i = 1:scissors_nDetected

    
    scissors_roi = imresize(rgb2gray(img_to_test(scissors_bbox(i,2):scissors_bbox(i,2)+scissors_bbox(i,4),...
        scissors_bbox(i,1):scissors_bbox(i,1)+scissors_bbox(i,3),:)),[40 40]);
            
    edge_scissors =edge(scissors_roi);

    % A pair of scissors should have some gray coloring in this region of
    % interest
    if sum(sum(edge_scissors(:,1:20))) < 25
        %remove bounding box if edge detection shows no edges in the left
        %half of the image
        counter = counter+1;
        scissors_delete(counter) = i;
    end
end
% delete columns that don't meet our criteria for scissors
try
scissors_bbox(scissors_delete,:) = [];
end
scissors_nDetected = size(scissors_bbox,1);


for ii = 1:scissors_nDetected
patch([scissors_bbox(ii,1),scissors_bbox(ii,1)+scissors_bbox(ii,3),scissors_bbox(ii,1)+scissors_bbox(ii,3),scissors_bbox(ii,1),scissors_bbox(ii,1)],...
[scissors_bbox(ii,2),scissors_bbox(ii,2),scissors_bbox(ii,2)+scissors_bbox(ii,4),scissors_bbox(ii,2)+scissors_bbox(ii,4),scissors_bbox(ii,2)],...
'c','facealpha',0.5);
text(scissors_bbox(ii,1),scissors_bbox(ii,2)+20,'Scissors')
end


% --FACE DETECTOR -- %

% Unsurprisingly, happy faces and upset faces often overlap - to solve this
% problem, we compare a face to a known template. Whichever has the higher
% score is labeled as that type of face.

% XML File name
happy_xml_file = 'happy_faces.xml';
happy_faces_detector = vision.CascadeObjectDetector(happy_xml_file,'MinSize',[70 70]);

% Find bbox of any detected objects
happy_bbox = step(happy_faces_detector,img_to_test);


% XML File name
upset_xml_file = 'upset_faces.xml';
upset_faces_detector = vision.CascadeObjectDetector(upset_xml_file,'MinSize',[70 70]);

% Find bbox of any detected objects
upset_bbox = step(upset_faces_detector,img_to_test);


happy_nDetected = size(happy_bbox,1);
upset_nDetected = size(upset_bbox,1);


% remove any bounding boxes where there is not a symmetric amount of edge
% features. Faces should be symmetric
face_counter = 0;
for i = 1:happy_nDetected
    roi = imresize(rgb2gray(img_to_test(happy_bbox(i,2):happy_bbox(i,2)+happy_bbox(i,4),...
        happy_bbox(i,1):happy_bbox(i,1)+happy_bbox(i,3),:)),[40 40]);

    roi_edge = edge(roi);

    left_edge_sum = sum(sum(roi_edge(:,1:20)));
    right_edge_sum  = sum(sum(roi_edge(:,21:40)));    
    
    if right_edge_sum < left_edge_sum*0.3 || left_edge_sum < right_edge_sum*0.3
        face_counter = face_counter+1;
       delete_face(face_counter) = i;   
    end
   
end
% delete columns that don't meet edge threshold
try
happy_bbox(delete_face,:) = [];
disp('here')
end
happy_nDetected = size(happy_bbox,1);


load('happy_template.mat')
load('angry_template.mat')
% create a method to find if happy and upset faces overlap
count1=0;
count2=0;

for i = 1:happy_nDetected
    overlap1 = zeros(size(img_to_test,1),size(img_to_test,2));
    overlap2 = zeros(size(img_to_test,1),size(img_to_test,2));
    
    for k = 1:upset_nDetected
        overlap1(happy_bbox(i,2):happy_bbox(i,2)+happy_bbox(i,4),...
            happy_bbox(i,1):happy_bbox(i,1)+happy_bbox(i,3))=1;
        overlap2(upset_bbox(k,2):upset_bbox(k,2)+upset_bbox(k,4),...
            upset_bbox(k,1):upset_bbox(k,1)+upset_bbox(k,3))=1;
        
        if sum(sum(overlap1+overlap2))>600
            %there are many overlapping  pixels - we have to use a template
            %to decideif it's happy or sad
            happy_roi = imresize(rgb2gray(img_to_test(upset_bbox(i,2):upset_bbox(i,2)+upset_bbox(i,4),...
                upset_bbox(i,1):upset_bbox(i,1)+upset_bbox(i,3),:)),[40 40]);
            
            %do cross correlation for happy and angry template
            happy_xcorr = xcorr2(double(happy_roi),double(happy_template));
            upset_xcorr = xcorr2(double(happy_roi),double(angry_template));
                        
            [max_happy, ~] = max(abs(happy_xcorr(:)));
            [max_upset, ~] = max(abs(upset_xcorr(:)));
           
                if max_happy > max_upset
                   % correlates closer to happy template
                   count1=count1+1;
                   delete_upset(count1) = k;
                    
                else
                   count2=count2+1;
                   delete_happy(count2) = i;                    
                    
                end            
            
        end
        
    end
    
end
% Delete whichever face correlated less
try
happy_bbox(delete_happy,:) = [];
end

try
upset_bbox(delete_upset,:) = [];
end

% recalculate amount of bounding boxes
happy_nDetected = size(happy_bbox,1);
upset_nDetected = size(upset_bbox,1);



happy_nDetected = size(happy_bbox,1);
for ii = 1:happy_nDetected
patch([happy_bbox(ii,1),happy_bbox(ii,1)+happy_bbox(ii,3),happy_bbox(ii,1)+happy_bbox(ii,3),happy_bbox(ii,1),happy_bbox(ii,1)],...
[happy_bbox(ii,2),happy_bbox(ii,2),happy_bbox(ii,2)+happy_bbox(ii,4),happy_bbox(ii,2)+happy_bbox(ii,4),happy_bbox(ii,2)],...
'y','facealpha',0.5);
text(happy_bbox(ii,1),happy_bbox(ii,2)+20,'Happy Face')
end



upset_nDetected = size(upset_bbox,1);
for ii = 1:upset_nDetected
patch([upset_bbox(ii,1),upset_bbox(ii,1)+upset_bbox(ii,3),upset_bbox(ii,1)+upset_bbox(ii,3),upset_bbox(ii,1),upset_bbox(ii,1)],...
[upset_bbox(ii,2),upset_bbox(ii,2),upset_bbox(ii,2)+upset_bbox(ii,4),upset_bbox(ii,2)+upset_bbox(ii,4),upset_bbox(ii,2)],...
'm','facealpha',0.3);
text(upset_bbox(ii,1),upset_bbox(ii,2)+20,'Upset Face')
end


