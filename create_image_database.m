function create_image_database(query,path)
% Download full size images from Google image search. Saves image files
% locally. Do not print or republish images without permission.
%
% Based on Python code by Craig Quiter at https://gist.github.com/crizCraig/2816295
%
% Requires the JSONLab package, available from
% http://www.mathworks.com/matlabcentral/fileexchange/33381-jsonlab-a-toolbox-to-encodedecode-json-files-in-matlaboctave
%
% USAGE
% >> search('dog')
% >> search('landscape')
%

current_dir = pwd;
path_to_jsonlab = strcat(current_dir,'/jsonlab');
addpath(path_to_jsonlab);

error(nargchk(1,2,nargin));
if nargin < 2, path = ''; end
 
baseurl = ['https://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=' query '&start=%d'];
baseurl = strrep(baseurl, ' ', '%%20');
basepath = fullfile(path,query);
if ~exist(basepath,'dir')
mkdir(basepath)
end
start = 0;
while start < 60 % Google will only return a max of 60 results
 
json = loadjson(urlread(sprintf(baseurl,start)));
for ii = 1:length(json.responseData.results)
imageinfo = json.responseData.results(ii);
url = imageinfo{1,1}.unescapedUrl;
try
image = imread(url);
catch %#ok
fprintf('Could not download %s\n',url);
continue
end
try
imwrite(image, fullfile(basepath, sprintf('%s%02d.jpg',query,start+ii)));
catch %#ok
fprintf('Could not save %s\n', url);
continue
end
end
disp(start)
start = start + 4; % 4 images per page
% be nice to Google!
pause(0.5)
end
 
% end