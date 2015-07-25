function cascadeToolFig = cascadeTrainer(varargin)
% CASCADETRAINER: Select and manage rectangular ROIs in images
%
% Interactive App for managing the selection and positioning of rectangular
% ROIs in a list of images, and for specifying ground truth for training
% algorithms.
%
%   * Add/remove/rotate/sort images
%   * Add/remove/reposition/delete/copy/paste ROIs
%   * Generate/export structure of image names and ROI positions
%   * Save/restore sessions
%   * Keyboard shortcuts designed to facilitate the process
%
% If you plan on training a detector, or have other uses for
% multiple-ROI selection and management, this tool is for you!
%
% USAGE:
% cascadeTrainer  Launches an App ready for loading of images and
%                  specification of ROIs
%
% cascadeTrainer('sample.mat') OR cascadeTrainer('sample')
%                  Reads previous session information and uses it to
%                  initialize relevant aspects of the cascadeTrainer.
%                  (This can be very useful for continuing a training
%                  session!)
%
% cascadeTrainer(MYSTRUCT)
%                  Where MYSTRUCT is a structure with exactly two fields:
%                  *   imageFilename (with the names of images in the
%                  training set), and
%                  *   objectBoundingBoxes (containing image-by-image
%                  pre-selected ROI bounding boxes). Note that saving a
%                  session generates a struct of this form in your base
%                  workspace. You can also extract it from a MAT-File
%                  session using MYSTRUCT = CTS.ImageInfo.
%
% SAVING:
%                  Saving stores image lists, sorts, and ROI positions (to
%                  both base workspace, and to a MAT file).
%
% INSTALLATION NOTES:
%                  Note that the zip file includes an mlappinstall file.
%                  You can use this App in the standard fashion, or
%                  double-click the mlappinstall file to install
%                  cascadeTrainer as an App on your App Toolbar.
%
%              Comments, suggestions welcome!
%
% Written by Brett Shoelson, PhD
% <http://www.mathworks.com/matlabcentral/fileexchange/authors/911>
% brett.shoelson@mathworks.com
%
% See also: trainCascadeObjectDetector, vision.CascadeObjectDetector

% Thanks to: Mike Agostini, Nikki Corriel, Reeve Goodenough, Witek
% Jachimczyk, Valerie Leung, Dima Lisin, Roland Michaely, Manju Narayana,
% and Johanna Pingel for their input, design considerations, and code
% review.
%
% UPDATES:
% V2.0
%    Includes a tab for exposing the functionality of the
%    trainCascadeObjectDetector function in the Computer Vision System
%    Toolbox.
%    ALSO: Fixes a bug with image deletion (listboxtop problem, and CTS
%    update CTS problem.)
% 03/11/13: Modified tab highlight behavior (yellow)
% 05/02/13: Now saves negative-image list from session to session. (Thanks
%           to John at Tufts for the suggestion!)
% 08/08/13: "ROI-deleted" changed to "ROI-masked"
% 08/16/13: Fixed loss-of-focus issue with image-to-scan listbox.
% 10/21/13: Bug fix on image update.
% 10/24/13: Added autoROI for automatic full-frame ROI insertion (Hotkey:
%           CTRL-4). Also added the ability to position autoROIs for ALL
%           selected images. (Thanks to "Niall" for the FEX suggestion.)
% 12/05/13: Fixed a bug in reversed order of height/width inputs.
% 1/25/14:  Fixed a bug with negative path-name saving (typo); also save
%           training parameters for resetting uicontrols on load.
% 4/30/14:  Fixed a bug with saving.
% 7/17/14:  Fixed a bug when 'Use ROI-Masked' is selected but no other
%           negative images are specified.
% 11/03/14: Added "PasteROIsThrough" function to facilitate pasting copied
%           ROIs through a span of images (frames?). Also added "GoTo"
%           button/function. RENAMED TO cascadeTrainer.
%
% Copyright 2012-14 The MathWorks, Inc.

tmp = findall(0,'name','Cascade Trainer');
singleton = true;

if ~nargin
	if ~isempty(tmp)
		figure(tmp)
		return
	end
else
	if singleton
		delete(findall(0,'name','Cascade Trainer')); %Singleton
	end
end

% SESSION/SAVING INFORMATION:
CTS = struct('SessionName','Untitled',...
	'DateModified',datestr(now),...
	'ImageInfo',...
	struct('imageFilename','',...
	'objectBoundingBoxes',[]));

% INITIALIZATIONS/DEFAULTS:
% Share in main workspace
[autoObjTrainWidth,cascadeTool,cascadeToolFig,copiedROIs,current,detectorBox,...
	deletedImages,falseAlarmRateSlider,featureTypeButtons,featureType,...
	imageList,imageListbox,imagesToSearchListbox,...
	negativeImageListbox,NegativeSamplesFactorSlider,...
	numberROIs,NumCascadeStagesSlider,numROIsListbox,objTrainHeight,...
	objTrainHeightText,objTrainWidth,objTrainWidthText,pathToSession,...
	truePositiveRateSlider,usePosAsNegBox] = ...
	deal([]);

ROIInProgress = false;
sessionName = 'Untitled';

% % Notification tone
% [wav,freq] = audioread('notify.wav');
% notification = audioplayer(wav,freq);
% NOTE: Opting to use the standard beep instead

% Color Scheme
colors = bone(20);
colors = colors(8:end,:);
bgc = colors(4,:);

if isempty(cascadeTool)
	cascadeTool = figure(...
		'numbertitle', 'off',...
		'WindowStyle','normal',...
		'name', 'Cascade Trainer',...
		'units', 'pixels',...
		'color', bgc,...
		'position', ceil(get(0,'screensize') .*[1 45 1 0.78] ),...[1 1 0.975 0.855]
		'visible','off',...
		'menubar', 'none',...
		'toolbar','none',...
		'CloseRequestFcn',@closeApp);
	hz = zoom;
	zoom off
	hp = pan;
	pan off
	% This construct is disallowed in R2014b:
	%     set([hz hp],...
	%         'ActionPreCallback',@panzoomPreCallback,...% set all delButton Visibility
	%         'ActionPostCallback',@panzoomPostCallback) % update delButton Visibility
	% Use this instead:
	set(hz,...
		'ActionPreCallback',@panzoomPreCallback,...% set delButtom Visibility
		'ActionPostCallback',@panzoomPostCallback) % update delButton Visibility
	set(hp,...
		'ActionPreCallback',@panzoomPreCallback,...% set delButtom Visibility
		'ActionPostCallback',@panzoomPostCallback) % update delButton Visibility
end
borderColor = get(cascadeTool,'defaultuipanelbackgroundcolor');

% UITOOLBAR
ht                       = uitoolbar(cascadeTool);
icon                    = imread('matlabicon.png');
uitoggletool(ht,...
	'CData',               icon,...
	'oncallback',          @acknowledgements);
icon                     = im2double(imread('tool_zoom_in.png'));
icon(icon==0)            = NaN;
uitoggletool(ht,...
	'CData',               icon,...
	'ClickedCallback',     @zoomIt,...
	'tooltipstring',       'ZOOM On/Off',...
	'separator',           'on');
icon                     = im2double(imread('tool_hand.png'));
icon(icon==0)            = NaN;
uitoggletool(ht,...
	'CData',               icon,...
	'ClickedCallback',     @panIt,...
	'tooltipstring',       'Toggle panning');
addROIIcon = imread('addROI.png');
uitoggletool(ht,...
	'CData',               addROIIcon,...
	'oncallback',          @defineROI,...
	'tag',                 'DefineROITool',...
	'tooltipstring',       'Add ROI: CTRL-r',...
	'separator',           'on');
addROIIcon = imread('addMultipleROIs.png');
uitoggletool(ht,...
	'CData',               addROIIcon,...
	'oncallback',          @defineMultipleROIs,...
	'tag',                 'DefineROITool',...
	'tooltipstring',       'Add Multiple ROIs: CTRL-m',...
	'separator',           'on');
icon = imread('copyROIs.png');
uitoggletool(ht,...
	'CData',               icon,...
	'oncallback',          @copyROIs,...
	'tooltipstring',       'Copy ROI(s): CTRL-1');
icon = imread('pasteROIs.png');
uitoggletool(ht,...
	'CData',               icon,...
	'oncallback',          @pasteROIs,...
	'tooltipstring',       'Paste ROI(s): CTRL-2');
icon = imread('pasteROIsThrough.png');
uitoggletool(ht,...
	'CData',               icon,...
	'oncallback',          @pasteROIsThrough,...
	'tooltipstring',       'Paste ROI(s) Through Image: CTRL-t');
icon = imread('deleteROIs.png');
uitoggletool(ht,...
	'CData',               icon,...
	'oncallback',          @deleteROIs,...
	'tooltipstring',       'Delete ALL ROI(s): CTRL-3');
icon = imread('fullMarquee.png');
uitoggletool(ht,...
	'CData',               icon,...
	'oncallback',          @autoROI,...
	'tooltipstring',       'Add full-frame ROI: CTRL-4');
icon = imread('gotoIcon.png');
uitoggletool(ht,...
	'CData',               icon,...
	'oncallback',          @gotoImage,...
	'tooltipstring',       'Go To Image: CTRL-g',...
	'separator',           'on');
icon = imread('RotateL_small.png');
uitoggletool(ht,...
	'CData',               icon,...
	'oncallback',          {@rotateImage,+90},...
	'tooltipstring',       'Rotate Left',...
	'separator',           'on');
icon = imread('RotateR_small.png');
uitoggletool(ht,...
	'CData',               icon,...
	'oncallback',          {@rotateImage,-90},...
	'tooltipstring',       'Rotate Right');
icon = imread('saveicon.png');
uitoggletool(ht,...
	'CData',               icon,...
	'oncallback',          @saveSession,...
	'tooltipstring',       'Save/Export Session: CTRL-s',...
	'separator',           'on');

% UIMENUS
parentFigure = ancestor(cascadeTool,'figure');

% FILE Menu
f = uimenu(parentFigure,'Label','File');
uimenu(f,...
	'Label','Load Session...',...
	'callback',@loadSession);
uimenu(f,...
	'Label','Load from Struct...',...
	'callback',@loadStruct);
uimenu(f,...
	'Label','Save/Export Session',...
	'callback',@saveSession);
uimenu(f,...
	'Label','Save/Export Session As...',...
	'callback',@saveSessionAs);
uimenu(f,...
	'Label','Add Images',...
	'callback',{@promptForImages,'Add Images to Train'});
uimenu(f,...
	'Label','Close cascadeTrainer',...
	'callback',@closeApp);

% OPTIONS Menu
f = uimenu(parentFigure,...
	'Label','Options');
uimenu(f,...
	'Label','Verify Commands',...
	'checked','on',...
	'tag','Verify',...
	'callback',@toggleMenuItem);
uimenu(f,...
	'Label','Turn Sounds Off',...
	'checked','off',...
	'tag','TurnOffSounds',...
	'callback',@toggleMenuItem);

% ROIs Menu
f = uimenu(parentFigure,...
	'Label','Shortcuts');
uimenu(f,...
	'Label','Add Images',...
	'callback',{@promptForImages,'Add Images to Train'},...
	'accelerator','a');
uimenu(f,...
	'Label','Add ROI',...
	'callback',@defineROI,...
	'accelerator','r');
uimenu(f,...
	'Label','Add Multiple ROIs',...
	'callback',@defineMultipleROIs,...
	'accelerator','m');
uimenu(f,...
	'Label','Copy ROI(s)',...
	'callback',@copyROIs,...
	'accelerator','1');%c is reserved
uimenu(f,...
	'Label','Paste ROI(s)',...
	'callback',@pasteROIs,...
	'accelerator','2');%v is reserved
uimenu(f,...
	'Label','Paste ROI(s) Through',...
	'callback',@pasteROIsThrough,...
	'accelerator','t');%v is reserved
uimenu(f,...
	'Label','Add full-frame ROI',...
	'callback',@autoROI,...
	'accelerator','4');
uimenu(f,...
	'Label','Delete ALL ROIs',...
	'callback',@deleteROIs,...
	'accelerator','3');
uimenu(f,...
	'Label','Next Image',...
	'callback',{@advanceImage,+1},...
	'accelerator','n');
uimenu(f,...
	'Label','Previous Image',...
	'callback',{@advanceImage,-1},...
	'accelerator','p');
uimenu(f,...
	'Label','Toggle Zoom',...
	'callback','zoom',...
	'accelerator','z');
uimenu(f,...
	'Label','Save/Export Session',...
	'callback',@saveSession,...
	'accelerator','s');
uimenu(f,...
	'Label','Go To Image',...
	'callback',@gotoImage,...
	'accelerator','g');

% CREATE MAIN FIGURE
if strcmp(get(cascadeTool,'type'),'figure')
	centerfig(cascadeTool);
end
% Default units
tmp = get(0,'screensize');
if tmp(3) > 1200
	defaultFontsize = 8;
else
	defaultFontsize = 7;
end
set(cascadeTool,...
	'DefaultUicontrolUnits','normalized',...
	'DefaultUicontrolFontSize',defaultFontsize);

% CREATE MAIN IMAGE PANEL
% CREATE IMAGE AXES
workingAx = axes('parent',cascadeTool,...
	'pos', [0.375 0.075 0.6 0.8375],...
	'visible','on',...
	'xtick',[],...
	'ytick',[],...
	'color',bgc,...
	'box','on',...
	'xcolor',borderColor,...
	'ycolor',borderColor);
defaultWorkingTitleFontsize = defaultFontsize+1;
workingTitle = annotation('textbox',[0.375 0.925 0.6 0.05],...
	'string','Add Images on Image/ROI Selection Tab to Begin/Continue.',...
	'color', [0.035 0.414 0.634],...
	'horizontalalignment','c',...
	'fontweight','b',...
	'fontsize',defaultWorkingTitleFontsize,...
	'Interpreter','none',...
	'VerticalAlignment','middle',...
	'backgroundcolor',bgc*1.3);
if verLessThan('matlab','8.4')
	currentImageNameHandle = findall(workingTitle,...
		'type','text');
else
	currentImageNameHandle = findall(workingTitle,...
		'type','textbox');
end
% Image Advancement Buttons
icon = imread('previousArrow.png');
advanceButtons(1) = uicontrol('parent',cascadeTool,...
	'style','pushbutton',...
	'string','',...
	'cdata',icon,...
	'pos',[0.675-0.015 0.015 0.025 0.035],...
	'callback',{@advanceImage,-1});
%
icon = imread('nextArrow.png');
advanceButtons(2) = uicontrol('parent',cascadeTool,...
	'style','pushbutton',...
	'string','',...
	'cdata',icon,...
	'pos',[0.675+0.015 0.015 0.025 0.035],...
	'callback',{@advanceImage,+1});
keypressString = uicontrol('parent',cascadeTool,...
	'style','text',...
	'foregroundcolor',[0.035 0.414 0.634],...
	'string','',...
	'fontname','arial',...
	'fontsize',8,...
	'fontweight','bold',...
	'horizontalalignment','left',...
	'backgroundcolor',bgc,...
	'position',[0.725 0.015 0.2 0.045]);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MAIN PANELS: SEGMENTATION
% Create Working TabPanels
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
requestedPanels = {{'Select Images/ROIs','Train Cascade Detector'},{'Run/Apply/Evaluate Detector'}};
[mainTabHandle,mainTabCardHandles,mainTabHandles] = ...
	tabPanel(cascadeTool,requestedPanels,...
	'panelpos',[0.025 0.13 0.325 0.865],...
	'tabpos','t',...
	'colors',[colors(1,:);colors(3,:);bgc*1.3;1.1*[0.46 0.52 0.60]],...%colors[colors(1,:);bgc*1.3;1.1*[0.46 0.52 0.60]],...%colors
	'tabHeight',45,...
	'highlightColor',[1 1 0],...
	'tabCardPVs',...
	{'bordertype','etchedin',...
	'fontsize',defaultFontsize,...
	'title',''},...
	'tabLabelPVs',{'fontsize',defaultFontsize+2,...
	'foregroundcolor','w'}); %#ok (unused output variables)
set(mainTabHandles{1}(1),...
	'tooltipstring','Select images and regions with which to train Cascade Detector');
set(mainTabHandles{1}(2),...
	'tooltipstring','Train Cascade Detector');
set(mainTabHandles{2}(1),...
	'tooltipstring','Run/Apply Cascade Detector');
iptaddcallback(mainTabHandles{1}(1),...
	'callback',@refreshDisplay);
iptaddcallback(mainTabHandles{1}(2),...
	'callback',@requestGroundTruth);
if iscell(requestedPanels{1})
	for tier = 1:size(requestedPanels,2)
		for rank = 1:numel(requestedPanels{tier})
			setupPanel(requestedPanels{tier}(rank),tier,rank);
		end
	end
else
	tier = 1;
	for rank = 1:numel(requestedPanels)
		setupPanel(requestedPanels(rank),tier,rank)
	end
end
commentPanel = uipanel(cascadeTool,...
	'bordertype','etchedin',...
	'backgroundcolor',get(cascadeTool,'color'),...
	'position',[0.025 0.02 0.325 0.1]);
commentBox = uicontrol(commentPanel,...
	'style','listbox',...
	'position',[0.01 0 0.98 1],...
	'backgroundcolor',get(cascadeTool,'color'),...
	'foregroundcolor','k',...
	'fontsize',defaultFontsize+2,...
	'max',10,'min',1,...
	'horizontalalignment','l',...
	'string',[]);
set(cascadeTool,...
	'visible','on',...
	'handlevisibility','callback');

% Was data requested?
if nargin > 0
	switch class(varargin{1})
		case 'struct'
			try
				loadStruct(varargin{1});
				throwComment('Successfully loaded data from specified structure');
			catch %#ok
				throwComment('Unable to load specified structure',1,1);
			end
		case 'char'
			try
				sessionName = varargin{1};
				loadSession(sessionName);
				throwComment(sprintf('Successfully restored session ''%s'', saved on %s, from file ''%s.mat''',CTS.SessionName,CTS.DateModified,sessionName));
			catch %#ok
				throwComment('Unable to load specified file. Valid .MAT file as from a previous session required.',1,1);
			end
		otherwise
			class(varargin{1})
	end
end
% This is necessary to properly clear the path when cascadeTrainer is used
% as an app, and to avoid spitting out an unwanted output if no output
% argument is requested.
if nargout < 1
	clear cascadeToolFig
else
	cascadeToolFig = cascadeTool;
end
% I don't know why this isn't working:
% hlink = linkprop([imageListbox,numROIsListbox],{'value','listboxtop'});
% hlink = linkprop([imageListbox,numROIsListbox],'listboxtop');
% addlistener(imageListbox,'ListboxTop','PostSet',...
%             @(varargin) updatenumROIsListbox);

% BEGIN NESTED SUBFUNCTIONS
% (Listed alphabetically for convenience)

	function acknowledgements(varargin)
		% BDS
		set(gcbo,'state','off')
		acknowledgementString = {'Thanks to Mike Agostini, Nikki Corriel, Reeve Goodenough,';
			'Witek Jachimczyk, Valerie Leung, Dima Lisin, Roland Michaely, Manju Narayana, and';
			'Johanna Pingel for their input, design considerations, and code review.'};
		throwComment(acknowledgementString{1})
		throwComment(acknowledgementString{2})
		throwComment(acknowledgementString{3},1,1)
	end %acknowledgements

	function advanceImage(varargin)
		% Which tab are we on?
		%requestedPanels = {{'Select Images/ROIs','Train Cascade Detector'},{'Run/Apply/Evaluate Detector'}};
		[~,~,tabName] = tabPanel(mainTabHandle);
		increment = varargin{3};
		if strcmp(tabName,'Select Images/ROIs')
			if ROIInProgress
				throwComment('Please ESCAPE from ROI selection first!',1,1);
				return
			end
			updateStatus
			if numel(current.selectedValues) > 1
				throwComment('Valid only when a single image is selected in the listbox.',1,1);
				return
			end
			if isempty(current.currentImageList)
				throwComment('Please select image(s) first.',1,1)
				return
			end
			if increment == 1
				newInd = min(current.selectedValues+1,size(current.currentImageList,1));
			elseif increment == -1
				newInd = max(current.selectedValues-1,1);
			else
				newInd = increment; %goto
			end
			set([imageListbox,numROIsListbox],'value',newInd,'listboxtop',newInd);
			drawnow;
			refreshDisplay;
		elseif strcmp(tabName,'Run/Apply/Evaluate Detector')
			currInd = get(imagesToSearchListbox,'value');
			if increment == 1
				newInd = min(currInd+1,size(get(imagesToSearchListbox,'string'),1));
			elseif increment == -1
				newInd = max(currInd-1,1);
			end
			set(imagesToSearchListbox,'value',newInd);
			applyDetector
		else %('Train Cascade Detector')
			nis = get(negativeImageListbox,'string');
			numNeg = size(nis,1);
			nis = max(1,min(numNeg,get(negativeImageListbox,'value')+increment));
			set(negativeImageListbox,'value',nis);
			showNegativeImage;
		end
	end %advanceImage

	function applyDetector(varargin)
		detectorRequested = get(detectorBox,'string');
		%         insertRect = vision.ShapeInserter('Shape','Rectangles',...
		%             'Fill',true,...
		%             'FillColor','Custom',...
		%             'CustomFillColor',[255 255 0],...
		%             'Opacity',0.5);
		ims = get(imagesToSearchListbox,'string');
		if isempty(ims)
			return
		end
		val = get(imagesToSearchListbox,'value');
		if numel(val)~=1
			return
		end
		imRequested = deblank(ims(val,:));
		[img,map] = imread(imRequested);
		if ~isempty(map)
			img = ind2rgb(img,map);
		end
		imshow(img,'parent',workingAx); % display the detected stop sign
		if isempty(detectorRequested)
			set(workingTitle,'string',...
				sprintf('%s:\n%s',...
				deblank(ims(val,:)),'(You haven''t selected a detector!)'));
			return
		end
		detector = vision.CascadeObjectDetector(detectorRequested);
		bbox = step(detector, img); %detect object
		nDetected = size(bbox,1);
		for ii = 1:nDetected
			patch([bbox(ii,1),bbox(ii,1)+bbox(ii,3),bbox(ii,1)+bbox(ii,3),bbox(ii,1),bbox(ii,1)],...
				[bbox(ii,2),bbox(ii,2),bbox(ii,2)+bbox(ii,4),bbox(ii,2)+bbox(ii,4),bbox(ii,2)],...
				'c','facealpha',0.5);
		end
		[~,detectorName] = fileparts(detector.ClassificationModel);
		[~,imname] = fileparts(imRequested);
		throwComment(sprintf('Applying detector %s to image %s',detectorName,imname));
		set(workingTitle,'string',...
			sprintf('%s:\n%0.0f Objects Detected!',...
			deblank(ims(val,:)),nDetected))
		% Force focus back to selection box
		% (I don't know why focus is sometimes lost, sometimes not. But
		% this seems to fix it.)
		uicontrol(imagesToSearchListbox);
	end %applyDetector

	function autoROI(varargin)
		try % if called from menubar
			set(gcbo,'state','off');
		end
		% Defensive programming
		isValid = checkForValidImage;
		if ~isValid
			return
		end
		enableButtons('off');
		inds = current.selectedValues;
		for ii = 1:numel(inds)
			updateStatus
			if strcmp(current.currentImageName,'Add Images on Training Set Tab to Begin/Continue.')
				throwComment('First select and display an image!',1,1);
				return
			elseif strcmp(current.currentImageName,'Drag cursor to define ROI')
				throwComment('Already waiting for ROI')
				return
			end
			axes(workingAx)
			image = imread(current.currentImageName);
			ROI = addROI(workingAx,[0.5 0.5 size(image,2)+0.5 size(image,1)+0.5]);
			updateCBsForROI(ROI)
			if ii < numel(inds)
				set([imageListbox,numROIsListbox],'value',inds(ii+1),'listboxtop',inds(ii+1));
			end
			drawnow;
			refreshDisplay;
		end
		enableButtons('on')
		setappdata(cascadeTool,'IsSaved',false)
		% BDS: return focus to listbox?
	end %autoROI

	function autoSize(obj,varargin)
		if get(obj,'value')
			set([objTrainHeightText,...
				objTrainHeight,...
				objTrainWidthText,...
				objTrainWidth],...
				'enable','off')
		else
			set([objTrainHeightText,...
				objTrainHeight,...
				objTrainWidthText,...
				objTrainWidth],...
				'enable','on')
		end
	end %autoSize

	function isValid = checkForValidImage(varargin)
		% Check to make sure the current "imageName" (as specified by the
		% title string) is valid WITHOUT updating status
		currentImageList = get(imageListbox,'string');
		currentImageName = get(currentImageNameHandle,'string');
		% This odd bit of code is necessary because the annotation textbox
		% automatically wraps long filenames into multi-cell strings, which
		% then appear to be invalid.
		if size(currentImageName,1) > 1
			set(workingTitle,'fontsize',1);
			currentImageName = get(currentImageNameHandle,'string');
			set(workingTitle,'fontsize',defaultWorkingTitleFontsize);
		end
		isValid = ismember(currentImageName,currentImageList);
	end %checkForValidImage

	function closeApp(varargin)
		% Prompt for save
		isSaved = getappdata(cascadeTool,'IsSaved');
		if ~isempty(isSaved) && ~isSaved
			saveSessionPrompt = questdlg('Save Cascade Training Session?', ...
				'Save and Export Session?','YES','No','Cancel','YES');
		else
			saveSessionPrompt = 'No';
		end
		if strcmp(saveSessionPrompt,'Cancel')
			return
		elseif strcmp(saveSessionPrompt,'YES')
			saveSession;
		end
		if ~strcmp(saveSessionPrompt,'No') && isempty(sessionName)
			return
		end
		%See note at updateCTS:
		setappdata(cascadeTool,'ignoreUpdateRequest',true)
		closereq;
	end %closeApp

	function copyROIs(varargin)
		try
			set(gcbo,'state','off')
		end
		% Defensive programming
		isValid = checkForValidImage;
		if ~isValid
			throwComment('Please select an image first!',1,1);
			return
		end
		copiedROIs = CTS.ImageInfo(current.currentCTSIndex).objectBoundingBoxes;
	end %copyROIs

	function createROIMaskedImage(tmpdir,trainStruct)
		[image,map] = imread(trainStruct.imageFilename);
		if ~isempty(map)
			image = ind2rgb(image,map);
		end
		[~,fn,ext] = fileparts(trainStruct.imageFilename);
		[sx,sy,sz] = size(image);
		mask = false([sx,sy]);
		ROIs = trainStruct.objectBoundingBoxes;
		for ii = 1:size(ROIs,1)
			bb = ROIs(ii,:);
			mask = mask | poly2mask([bb(1) bb(1)+bb(3) bb(1)+bb(3) bb(1)],...
				[bb(2) bb(2) bb(2)+bb(4) bb(2)+bb(4)],sx,sy);
		end
		for ii = 1:sz
			tmp = image(:,:,ii);
			tmp(mask) = 0;
			image(:,:,ii) = tmp;
		end
		imwrite(image,fullfile(tmpdir,[fn '_ROIMasked',ext]))
	end %createROIMaskedImage

	function defineMultipleROIs(varargin)
		try % if called from menubar
			set(gcbo,'state','off');
		end
		% Defensive programming
		isValid = checkForValidImage;
		if ~isValid
			return
		end
		enableButtons('off');
		updateStatus
		if strcmp(current.currentImageName,'Add Images on Training Set Tab to Begin/Continue.')
			throwComment('First select and display an image!',1,1);
			return
		elseif strcmp(current.currentImageName,'Drag cursor to define ROI')
			throwComment('Already waiting for ROI')
			return
		end
		axes(workingAx)
		ROI = 1;
		while ~isempty(ROI)
			ROIInProgress = true;
			%Disallow advancing while defining ROIs
			set(advanceButtons,'enable','off');
			oldString = get(workingTitle,'string');
			set(workingTitle,...
				'string','Drag cursor to define ROIs. (ESCAPE TO STOP.)');
			ROI = addROI;
			set(workingTitle,...
				'string',oldString);
			if isempty(ROI)
				ROIInProgress = false;
				enableButtons('on')
				return
			end
			updateCBsForROI(ROI)
			setappdata(cascadeTool,'IsSaved',false)
		end
		enableButtons('on')
		% BDS: return focus to listbox?
	end %defineMultipleROIs

	function defineROI(varargin)
		try % if called from menubar
			set(gcbo,'state','off');
		end
		% Defensive programming
		isValid = checkForValidImage;
		if ~isValid
			return
		end
		enableButtons('off');
		updateStatus
		if strcmp(current.currentImageName,'Add Images on Training Set Tab to Begin/Continue.')
			throwComment('First select and display an image!',1,1);
			return
		elseif strcmp(current.currentImageName,'Drag cursor to define ROI')
			throwComment('Already waiting for ROI')
			return
		end
		axes(workingAx)
		oldString = get(workingTitle,'string');
		set(workingTitle,...
			'string','Drag cursor to define ROI.');
		ROI = addROI;
		set(workingTitle,...
			'string',oldString);
		enableButtons('on')
		if isempty(ROI)
			return
		end
		updateCBsForROI(ROI)
		setappdata(cascadeTool,'IsSaved',false)
		% BDS: return focus to listbox?
	end %defineROI

	function deleteROIs(varargin)
		try
			set(gcbo,'state','off')
		end
		if nargin == 0 || (nargin > 0 && ishandle(varargin{1}))
			opt = 'Verify';
		else
			opt = varargin{1};
		end
		% Delete ALL ROIs
		if strcmp(opt,'Verify')
			verified = verifyCommand('Pressing CONTINUE will remove all ROIs this image!');
		else
			verified = true;
		end
		if verified
			CTS.ImageInfo(current.currentCTSIndex).objectBoundingBoxes = [];
			refreshDisplay;
			current.numROIs(current.currentListboxIndex) = 0;
			set(numROIsListbox,'string',current.numROIs);
		end
		setappdata(cascadeTool,'IsSaved',false)
	end %deleteROIs

	function deleteSelectedImages(varargin)
		% varargin{3} indicates which listbox to remove image(s) from
		opt = varargin{3};
		switch opt
			case 'To Train'
				vals = get(imageListbox,'value');
				currString = get(imageListbox,'string');
			case 'To Search'
				vals = get(imagesToSearchListbox,'value');
				currString = get(imagesToSearchListbox,'string');
			case 'Negative Images'
				vals = get(negativeImageListbox,'value');
				currString = get(negativeImageListbox,'string');
		end
		if isempty(vals) || isempty(currString)
			return
		end
		verified = verifyCommand(sprintf('Pressing CONTINUE will remove %d images from your queue!',numel(vals)));
		if ~verified
			return
		end
		switch opt
			case 'To Train'
				updateStatus
				if numel(current.selectedValues) == 0 || isempty(current.currentImageList)
					return
				end
				deletedImages = current.currentImageList(current.selectedValues,:);
				current.currentImageList(current.selectedValues,:) = [];
				current.numROIs(current.selectedValues) = [];
				set([imageListbox,numROIsListbox],...
					'listboxtop',1,...
					'value',1);
				drawnow;
				set(imageListbox,...
					'string',current.currentImageList);
				set(numROIsListbox,...
					'string',current.numROIs);
				setappdata(cascadeTool,'ignoreUpdateRequest',false)
				updateCTS('deleteImages');
				if ~isempty(current.currentImageList)
					refreshDisplay;
				else
					cla(workingAx)
					set(workingAx,...
						'visible','on',...
						'xtick',[],...
						'ytick',[],...
						'color',colors(4,:),...
						'box','on',...
						'xcolor',borderColor,...
						'ycolor',borderColor);
					set(workingTitle,...
						'string','Add Images on Training Set Tab to Begin/Continue.')
					set(keypressString,...
						'string','');
				end
			case 'To Search'
				newString = currString;
				if isempty(currString)
					return
				end
				newString(vals,:) = [];
				set(imagesToSearchListbox,...
					'listboxtop',1,...
					'value',1);
				drawnow;
				set(imagesToSearchListbox,'string',newString);
			case 'Negative Images'
				newString = currString;
				if isempty(currString)
					return
				end
				newString(vals,:) = [];
				drawnow;
				set(negativeImageListbox,...
					'listboxtop',1,...
					'value',1);
				set(negativeImageListbox,'string',newString);
		end
		setappdata(cascadeTool,'IsSaved',false)
		drawnow;
		setappdata(cascadeTool,'IsSaved',false)
	end %deleteSelectedImages

	function enableButtons(varargin)
		allButtons = findall(cascadeTool,...
			'style','pushbutton');
		set(allButtons,...
			'enable',varargin{1});
	end %enableButtons

	function explainUsePosAsNeg(varargin)
		tmp = findall(0,'name','Positives as Negatives');
		if isempty(tmp)
			figure('windowstyle','normal',...
				'numbertitle','off',...
				'name','Positives as Negatives',...
				'menubar','none',...
				'units','normalized',...
				'color','w',...
				'pos',[0.25 0.3 0.5 0.5])
		else
			figure(tmp);
			clf(tmp)
		end
		str = {'''Include ROI-masked positives as negatives'' means that images used for';
			'specifying ROIs in a positive manner will also be used as';
			'negative images, after ROIs specified in the image are masked.'
			'';
			'For example, if you were to train a stop-sign detector with the image';
			'on the left below, the image on the right would be added to the set of';
			'negative training images.'};
		uicontrol('units','normalized',...
			'style','text',...
			'backgroundcolor','w',...
			'pos',[0.05 0.6 0.9 0.35],...
			'fontsize',16,...
			'string',str)
		axes('units','normalized',...
			'pos',[0.05 0.05 0.425 0.5]);
		tmp = imread('posStopSigns.png');
		imshow(tmp)
		axes('units','normalized',...
			'pos',[0.525 0.05 0.425 0.5]);
		tmp = imread('negStopSigns.png');
		imshow(tmp)
	end %explainUsePosAsNeg

	function rpos = getPos(ROI)
		rpos = iptgetapi(ROI);
		rpos = feval(rpos.getPosition);
	end %getPos

	function gotoImage(targetImage,varargin)
		try
			set(gcbo,'state','off')
		end
		if ~isa(targetImage,'double') && isnan(str2double(targetImage))
			prompt = {'Go To Image:'};
			def = {''};
			answer = inputdlg(prompt,'Go To:',[1 30],def);
			targetImage = str2double(answer{1});
			if isempty(targetImage)
				return
			end
		end
		targetImage = max(1,targetImage);
		targetImage = min(targetImage,size(current.currentImageList,1));
		advanceImage([],[],targetImage);%
	end % gotoImage

	function imageClicked(varargin)
		st = get(cascadeTool,'SelectionType');
		if strcmp(st,'normal')
			defineROI;
		elseif strcmp(st,'alt')
			advanceImage([],[],1);
		end
	end %imageClicked

	function loadSession(varargin)
		isSaved = getappdata(cascadeTool,'IsSaved');
		if ~isempty(isSaved) && ~isSaved
			saveSessionPrompt = questdlg(sprintf('WARNING!!!: This will clear the (UNSAVED) current session.\n\nSave Cascade Training Session?'), ...
				'Save and Export Session?','YES, save and load!','No, continue without saving!','Cancel','YES, save and load!');
		else
			saveSessionPrompt = 'No, continue without saving!';
		end
		if strcmp(saveSessionPrompt,'Cancel')
			return
		elseif strcmp(saveSessionPrompt,'YES')
			saveSession;
		end
		
		if nargin > 0 && ischar(varargin{1})
			previousSession = load(varargin{1});
		else
			[sessionName,pathToSession] = uigetfile('*.mat',...
				'Select saved training session',...
				'multiselect','off');
			if ~ischar(sessionName)
				return
			end
			[~,sessionName,ext]=fileparts(sessionName);
			if sessionName == 0
				return
			end
			previousSession = load(fullfile(pathToSession,[sessionName,ext]));
			setappdata(cascadeTool,'startingLocation',pathToSession);
		end
		try
			CTS = previousSession.CTS;
			try
				set(imageListbox,...
					'string',previousSession.current.currentImageList,...
					'value',previousSession.current.selectedValues);
			end
			try
				set(numROIsListbox,...
					'string',previousSession.current.numROIs,...
					'value',previousSession.current.selectedValues);
			end
			try
				set(negativeImageListbox,...
					'string',previousSession.current.currentNegativeImageList);
			end
			set(workingTitle,'string',previousSession.current.currentImageName);
			if isfield(previousSession,'trainingParameters')
				trainingParameters = previousSession.trainingParameters;
				set(usePosAsNegBox,'value',trainingParameters.usePosAsNeg);
				set(falseAlarmRateSlider,'value',trainingParameters.FalseAlarmRate);
				set(truePositiveRateSlider,'value',trainingParameters.TruePositiveRate);
				set(NumCascadeStagesSlider,'value',trainingParameters.NumCascadeStages);
				set(NegativeSamplesFactorSlider,'value',trainingParameters.NegativeSamplesFactor);
				set(objTrainWidth,'string',trainingParameters.objTrainWidthVal);
				set(objTrainHeight,'string',trainingParameters.objTrainHeightVal);
				set(autoObjTrainWidth,'value',trainingParameters.autoObjTrainWidthVal);
				for jj = 1:numel(featureType)
					set(featureType(jj),'value',trainingParameters.featureTypeValue{jj})
				end
			end
			refreshDisplay;
			throwComment(sprintf('Successfully restored session ''%s'', saved on %s, from file ''%s.mat''',CTS.SessionName,CTS.DateModified,sessionName));
		catch %#ok
			throwComment('Unable to load specified file. Valid .MAT file as from a previous session required.',1,1);
		end
		setappdata(cascadeTool,'IsSaved',true)
	end %loadSession

	function loadStruct(varargin)
		% Load from the struct only, ignoring current-session information
		isSaved = getappdata(cascadeTool,'IsSaved');
		if ~isempty(isSaved) && ~isSaved
			saveSessionPrompt = questdlg(sprintf('WARNING!!!: This will clear the (UNSAVED) current session.\n\nSave Cascade Training Session?'), ...
				'Save and Export Session?','YES, save and load!','No, continue without saving!','Cancel','YES, save and load!');
		else
			saveSessionPrompt = 'No, continue without saving!';
		end
		if strcmp(saveSessionPrompt,'Cancel')
			return
		elseif strcmp(saveSessionPrompt,'YES')
			saveSession;
		end
		try
			updateStatus
			fcn = @(x) isstruct(x) &&...
				isfield(x,'imageFilename') &&...
				isfield(x,'objectBoundingBoxes') &&...
				size(fieldnames(x),1)==2;
			if isstruct(varargin{1})
				tvar = varargin{1};
			else
				tvar = uigetvariables('Pick a valid structure:',[],fcn);
				if isempty(tvar)
					return
				end
			end
			if iscell(tvar)
				tvar = tvar{1};
			end
			set(imageListbox,'string',{tvar.imageFilename}');
			nums = zeros(numel(tvar),1);
			for ii = 1:numel(tvar)
				nums(ii) = size(tvar(ii).objectBoundingBoxes,1);
				CTS.ImageInfo(ii).objectBoundingBoxes = tvar(ii).objectBoundingBoxes;
				CTS.ImageInfo(ii).imageFilename = tvar(ii).imageFilename;
			end
			set(numROIsListbox,...
				'string',nums)
			set([imageListbox,numROIsListbox],'value',1,'listboxtop',1);
			set(workingTitle,...
				'string',tvar(1).imageFilename)
			refreshDisplay
			throwComment('Successfully loaded data from specified structure');
		catch %#ok
			throwComment('Unable to load specified structure',1,1);
		end
	end %loadStruct

	function panIt(varargin)
		try
			set(gcbo,'state','off')
		end
		pan;
	end %panIt

	function panzoomPostCallback(varargin)
		switch get(cascadeTool,'SelectionType')
			case{'open','alt'}  % open: double click, alt: right mouse click: context menu
				imgDisplayed = findall(workingAx,'type','image');
				set(workingAx,'XLim',get(imgDisplayed,'XData')+.5*[-1 1],...
					'YLim',get(imgDisplayed,'YData')+.5*[-1 1])
		end
		xl = get(workingAx,'xlim'); % get axes x limits
		yl = get(workingAx,'ylim'); % get axes y limits
		delButtons = findall(cascadeTool,...
			'type','text',...
			'tag','delButton'); % find all ROI delete buttons
		if ~isempty(delButtons)
			X = get(delButtons,'Pos');
			if iscell(X)
				X = cell2mat(X);
			end
			VisOff = (X(:,1) < xl(1)) | (X(:,1) > xl(2))... check if x within xlim
				| (X(:,2) < yl(1)) | (X(:,2) > yl(2));  %   check if y within ylim
			set(delButtons(VisOff),...
				'visible','off') % set invisible all delButton outside xlim or ylim
			set(delButtons(~VisOff),...
				'visible','on') % set visible if inside
		end
	end %panzoomPostCallback

	function panzoomPreCallback(varargin)
		delButtons = findall(cascadeTool,...
			'type','text',...
			'tag','delButton'); % find all ROI delete buttons
		set(delButtons,...
			'visible','on') % set visible if inside
	end %panzoomPreCallback

	function pasteROIs(varargin)
		try
			set(gcbo,'state','off')
		end
		% Defensive programming
		isValid = checkForValidImage;
		if ~isValid
			throwComment('Please select an image first!',1,1);
			return
		end
		for ii = 1:size(copiedROIs,1)
			ROI = addROI(workingAx,copiedROIs(ii,:));
			updateCBsForROI(ROI)
		end
		setappdata(cascadeTool,'IsSaved',false)
	end %pasteROIs

	function pasteROIsThrough(varargin)
		try
			set(gcbo,'state','off')
		end
		% Defensive programming
		isValid = checkForValidImage;
		if ~isValid
			throwComment('Please select an image first!',1,1);
			return
		end
		if isempty(copiedROIs)
			beep;
			throwComment('You haven''t copied any ROIs!',1,1);
			return
		end
		prompt = {'Paste copied ROIs FROM image number:','Paste copied ROIs THROUGH image number:'};
		def = {num2str(current.currentListboxIndex+1),''};
		answer = inputdlg(prompt,'RELATIVE TO CURRENT SORT...',[1 50],def);
		if isempty(answer)
			return
		end
		if isempty(str2double(answer{2}))
			beep;
			throwComment('You must specify an image number to stop pasting on!',1,1);
			return
		end
		targetImage = str2double(answer{1});
		gotoImage(targetImage)
		endImage = min(str2double(answer{2}),size(current.currentImageList,1));
		for jj = targetImage:endImage
			for ii = 1:size(copiedROIs,1)
				ROI = addROI(workingAx,copiedROIs(ii,:));
				updateCBsForROI(ROI)
			end
			if current.currentListboxIndex < endImage
				advanceImage([],[],1);
			end
		end
		%advanceImage([],[],-1); %Back up to last-pasted image
		setappdata(cascadeTool,'IsSaved',false)
	end %pasteROIsThrough

	function promptForImages(varargin)
		% VARGIN{3} should be an instructional string:
		opt = varargin{3};
		if ~ismember(opt,{'Add Directory to Train',...
				'Add Directory to Search',...
				'Add Images to Train',...
				'Add Images to Search',...
				'Add Negative Images',...
				'Add Negative Directory',...
				'From Tab 1'})
			error('cascadeTrainer/promptForImages: Unsupported instruction string.')
		end
		% New imgformats returns extensions...list of image extensions suitable for
		% specification in DIR2
		[formats,extensions] = imgformats;
		try
			startingLocation = getappdata(cascadeTool,'startingLocation');
		catch
			startingLocation = pwd;
		end
		% Get list to which search results are to be appended
		switch opt
			case {'Add Directory to Train','Add Images to Train'}
				currList = get(imageListbox,'string');
			case {'Add Directory to Search','Add Images to Search','From Tab 1'}
				currList = get(imagesToSearchListbox,'string');
			case {'Add Negative Images','Add Negative Directory'}
				currList = get(negativeImageListbox,'string');
		end
		% Prompt for images
		switch opt
			case {'Add Images to Train','Add Images to Search','Add Negative Images'}
				[filenames,pathname] = uigetfile(formats,...
					'Select training image(s)',...
					startingLocation,...
					'multiselect','on');
				if ~ischar(pathname)
					return
				end
				if ~isa(filenames,'cell')
					filenames = {filenames};
				end
				%pathname = [relfile(pathname),filesep];
				newList = [repmat(pathname,numel(filenames),1),char(filenames')];
				setappdata(cascadeTool,'startingLocation',pathname);
			case {'Add Directory to Train','Add Directory to Search','Add Negative Directory'}
				imageDirectory = uigetdir(startingLocation,'Select Image-Containing Directory');
				if ~ischar(imageDirectory)
					return
				end
				%imageDirectory = relfile(imageDirectory);
				startingLocation = strfind(imageDirectory,filesep);
				startingLocation = imageDirectory(1:startingLocation(end)-1);
				setappdata(cascadeTool,'startingLocation',startingLocation);
				% Non-recursive search for all image images in specified directory:
				% NOTE: there's a bug in dir2--it crashes if
				% numel(extensions) > 21; here's a workaround:
				filenames = [dir2(imageDirectory,extensions(1:20));dir2(imageDirectory,extensions(21:end))];
				newList = [repmat([imageDirectory,filesep],numel(filenames),1)  char({filenames.name})];
			case 'From Tab 1'
				newList = get(imageListbox,'string');
		end
		oldNumIms = size(currList,1);
		% Disallow duplicates!
		[dupes,~,ind2] = intersect(currList,newList,'rows');
		if ~isempty(ind2)
			disp('These files were disallowed (they are already in your queue:)')
			disp(dupes)
			if numel(ind2) > 1
				throwComment(sprintf('Ignoring %d selected images that are already in your queue. (Duplicates not permitted.)',numel(ind2)),1,1);
			else
				throwComment(sprintf('Ignoring one selected image that is already in your queue. (Duplicates not permitted.)'),1,1);
			end
			newList(ind2,:) = [];
		end
		% Concatenate current and new image lists
		tmpImageList = '';
		if ~isempty(currList) && ~isempty(newList)
			tmpImageList = char(currList,newList);
		elseif ~isempty(currList) && isempty(newList)
			tmpImageList = currList;
		elseif isempty(currList) && ~isempty(newList)
			tmpImageList = newList;
		end
		% Now update appropriate listbox
		switch opt
			case {'Add Directory to Train','Add Images to Train'}
				imageList = tmpImageList;
				set(imageListbox,'string',imageList);
				numROIs  = [str2num(get(numROIsListbox,'string'));...
					zeros(size(newList,1),1)];%#ok str2num required for multi-string usage
				set(numROIsListbox,'string',numROIs);
				% Update CTS
				for ii = 1:size(newList,1)
					oldNumIms = oldNumIms + 1;
					CTS.ImageInfo(oldNumIms).imageFilename = deblank(newList(ii,:));
				end
				if strcmp(get(workingTitle,'string'),...
						'Add Images on Training Set Tab to Begin/Continue.')
					% First time...prompt the user to start selecting regions
					set(workingTitle,'string',...
						'Now select an image to begin, and define ROIs (Ctrl-R) in each image.')
					set([imageListbox,numROIsListbox],'value',[])
				end
			case {'Add Directory to Search','Add Images to Search','From Tab 1'}
				set(imagesToSearchListbox,'string',tmpImageList);
			case {'Add Negative Images','Add Negative Directory'}
				set(negativeImageListbox,'string',tmpImageList);
		end
		% Bookkeeping, display refresh
		setappdata(cascadeTool,'IsSaved',false)
		refreshDisplay
	end %promptForImages

	function refreshDisplay(varargin)
		updateStatus
		if isempty(current.currentImageList)
			set(workingTitle,'string','Add Images on Image/ROI Selection Tab to Begin/Continue.')
			return
		end
		%BDS: IMSHOW here calls an unwanted instance of updateCTS (due to
		%the deletion of the ROIs. To avoid that, I am setting a flag
		%('ignoreUpdateRequest') that updateCTS can check for...
		setappdata(cascadeTool,'ignoreUpdateRequest',true)
		set(numROIsListbox,'value',current.selectedValues)
		set(numROIsListbox,'listboxtop',get(imageListbox,'listboxtop'));
		if numel(current.selectedValues) ~= 1
			return
		end
		% Here, we get the current information directly from the listboxes
		% because the title hasn't been updated yet. We'll use this to
		% update the title string.
		try
			imSelected = current.currentImageList(current.selectedValues,:);
		catch %#ok
			try
				imSelected = current.currentImageList{current.selectedValues};
			catch %#ok
				error('cascadeTrainer: Unable to open requested image.')
			end
		end
		imSelected = deblank(imSelected);
		if iscell(imSelected)
			imSelected = imSelected{1};
		end
		set(workingTitle,'string',imSelected);
		updateStatus
		[tmp,map] = imread(imSelected);
		if ~isempty(map)
			tmp = ind2rgb(tmp,map);
		end
		imgDisplayed = imshow(tmp,...
			'parent',workingAx);
		%reshapeBox
		set(keypressString,...
			'string',sprintf('Click on image = Ctrl-R (Draw ROI);\nRight-Click on image = Ctrl-N (Next Image)'));
		set(imgDisplayed,...
			'buttondownfcn',@imageClicked)%@defineROI
		setappdata(cascadeTool,'ignoreUpdateRequest',false)
		throwComment(sprintf('Displaying image %d of %d (relative to current sort).',...
			current.selectedValues,size(current.currentImageList,1)));
		% Reconstruct ROIs
		numROIs = current.numROIs(current.selectedValues);
		if numROIs ~= 0
			%savedROIs = CTS.ImageInfo(strcmp({CTS.ImageInfo.imageFilename}',imSelected)).objectBoundingBoxes;
			savedROIs = CTS.ImageInfo(current.currentCTSIndex).objectBoundingBoxes;
			for ii = 1:size(savedROIs,1)
				ROI = addROI(workingAx,savedROIs(ii,:));
				updateCBsForROI(ROI,'Regenerate') %No update of CTS required
			end
		end
		setappdata(cascadeTool,'IsSaved',false)
	end %refreshDisplay

	function requestGroundTruth(varargin)
		updateStatus
		if isempty(current.currentImageList)
			set(workingTitle,...
				'string','First specify Ground Truth using Image/ROI Selection Tab.')
			return
		else
			set(workingTitle,...
				'string','Follow steps 1, 2, and 3 on the left to train your detector!')
		end
	end %requestGroundTruth

	function ROIMoved(varargin)
		%addNewPositionCallback specifies operation on 4-element vector p
		updateCTS('ROIChange');
		setappdata(cascadeTool,'IsSaved',false)
	end %ROIMoved

	function ROISelected(varargin)
		selectedValues = get(numROIsListbox,'value');
		set(imageListbox,'value',selectedValues)
		set(imageListbox,'listboxtop',get(numROIsListbox,'listboxtop'));
		refreshDisplay;
	end %ROISelected

	function rotateImage(varargin)
		try
			set(gcbo,'state','off')
		end
		verified = verifyCommand('This will overwrite your image with a rotated version.');
		if ~verified
			return
		end
		updateStatus
		rotationValue = varargin{3};
		[image,map] = imread(current.currentImageName);
		if ~isempty(map)
			image = ind2rgb(image,map);
		end
		
		imwrite(imrotate(image,...
			rotationValue),...
			current.currentImageName);
		refreshDisplay;
	end %rotateImage

	function saveSession(varargin)
		try
			set(gcbo,'state','off')
		end
		updateStatus
		%Save the structure of information to the base workspace
		%(without overwriting previously-saved version)
		varnames = evalin('base', 'who');
		if isempty(sessionName)||~ischar(sessionName)
			sessionName = 'Untitled';
		end
		if strcmp(sessionName,'Untitled')
			sessionName = inputdlg({'File Name:'},'SaveAs',1,{sessionName});
		end
		if isempty(sessionName)
			return
		end
		if iscell(sessionName)
			sessionName = sessionName{1};
		end
		if length(sessionName) > 4 && strcmp(sessionName(end-3:end),'.mat')
			sessionName = sessionName(1:end-4);
		end
		myVarname = genvarname(sessionName, varnames);
		if iscell(myVarname)
			myVarname = myVarname{1};
		end
		assignin('base',myVarname,CTS.ImageInfo);
		% Update CTS
		CTS.SessionName = sessionName;
		CTS.DateModified = datestr(now);
		fname = [sessionName '.mat'];
		%
		trainingParameters.usePosAsNeg = get(usePosAsNegBox,'value');
		trainingParameters.FalseAlarmRate = get(falseAlarmRateSlider,'value');
		trainingParameters.TruePositiveRate = get(truePositiveRateSlider,'value');
		trainingParameters.NumCascadeStages = round(get(NumCascadeStagesSlider,'value'));
		trainingParameters.NegativeSamplesFactor = round(get(NegativeSamplesFactorSlider,'value'));
		trainingParameters.objTrainWidthVal = str2double(get(objTrainWidth,'string'));
		trainingParameters.objTrainHeightVal = str2double(get(objTrainHeight,'string'));
		trainingParameters.autoObjTrainWidthVal = get(autoObjTrainWidth,'value');
		trainingParameters.featureTypeValue = get(featureType,'value');
		%
		%save(fullfile(pathToSession,fname),'CTS','current')
		save(fullfile(pwd,fname),'CTS','current','trainingParameters')
		setappdata(cascadeTool,'IsSaved',true)
		throwComment(sprintf('Session saved as %s',fname))
		throwComment(sprintf('Image structure saved to base workspace as %s',myVarname));
		disp('')
		disp('%%%%%')
		fprintf('Session saved as %s\n',fname)
		fprintf('Image structure saved to base workspace as %s\n',myVarname)
		disp('%%%%%')
		disp('')
	end %saveSession

	function saveSessionAs(varargin)
		try
			set(gcbo,'state','off')
		end
		options.Resize ='on';
		if isempty(sessionName)||~ischar(sessionName)
			sessionName = 'Untitled';
		end
		requestedVarname = inputdlg({'Enter name of session:'},...
			'Save Cascade Training Session',1,{sessionName},options);
		if isempty(requestedVarname)
			return
		end
		if iscell(requestedVarname)
			requestedVarname = requestedVarname{1};
		end
		updateStatus
		%Save the structure of information to the base workspace
		%(without overwriting previously-saved version)
		varnames = evalin('base', 'who');
		myVarname = genvarname(requestedVarname, varnames);
		if iscell(myVarname)
			myVarname = myVarname{1};
		end
		assignin('base',myVarname,CTS.ImageInfo);
		%
		CTS.SessionName = requestedVarname;
		CTS.DateModified = datestr(now);
		fname = [requestedVarname '.mat'];
		fileExists  = exist(fname,'file') == 2;
		if fileExists
			saveOpt = inputdlg({sprintf('SAVE AS: (Note that file %s already exists!)',fname)},'SaveAs',1,{fname});
			if isempty(saveOpt)
				return
			end
			fname = saveOpt{1};
		end
		%
		trainingParameters.usePosAsNeg = get(usePosAsNegBox,'value');
		trainingParameters.FalseAlarmRate = get(falseAlarmRateSlider,'value');
		trainingParameters.TruePositiveRate = get(truePositiveRateSlider,'value');
		trainingParameters.NumCascadeStages = round(get(NumCascadeStagesSlider,'value'));
		trainingParameters.NegativeSamplesFactor = round(get(NegativeSamplesFactorSlider,'value'));
		trainingParameters.objTrainWidthVal = str2double(get(objTrainWidth,'string'));
		trainingParameters.objTrainHeightVal = str2double(get(objTrainHeight,'string'));
		trainingParameters.autoObjTrainWidthVal = get(autoObjTrainWidth,'value');
		trainingParameters.featureTypeValue = get(featureType,'value');
		%
		save(fname,'CTS','current','trainingParameters')
		setappdata(cascadeTool,'IsSaved',true)
		throwComment(sprintf('Session saved as %s',fname))
		throwComment(sprintf('Image structure saved to base workspace as %s',myVarname));
		disp('')
		disp('%%%%%')
		fprintf('Session saved as %s\n',fname)
		fprintf('Image structure saved to base workspace as %s\n',myVarname)
		disp('%%%%%')
		disp('')
	end %saveSessionAs

	function selectDetector(varargin)
		pathname = getappdata(cascadeTool,'pathToDetector');
		if isempty(pathname)
			pathname = pwd;
		end
		setappdata(cascadeTool,'pathToDetector',pathname);
		%
		pretrained = {...
			'FrontalFaceCART';...
			'FrontalFaceLBP';...
			'ProfileFace';...
			'Mouth';...
			'Nose';...
			'EyePairBig';...
			'EyePairSmall';...
			'RightEye';...
			'LeftEye';...
			'RightEyeCART';...
			'LeftEyeCART';...
			'UpperBody'};
		%
		str = dir([pathname,filesep,'*.xml']);
		allStrings = char({'... (BROWSE)',str.name,char(pretrained)});
		tmp = listdlg('PromptString','Select Detector:',...
			'SelectionMode','single',...
			'ListString',allStrings,...
			'InitialValue',[]);
		if isempty(tmp)
			return
		end
		switch tmp
			case 1 %...
				[filename,pathname] = uigetfile('*.xml',...
					'Select Detector',...
					pathname,...
					'multiselect','off');
				if ~filename
					return
				end
				filename = fullfile(pathname,filename);
			otherwise
				filename = deblank(allStrings(tmp,:));
		end
		set(detectorBox,'string',filename);
	end %selectDetector

	function setupPanel(requestedPanel,tier,rank)
		parent = mainTabCardHandles{tier}(rank);
		bgc = get(parent,'backgroundcolor');
		tmp = rgb2gray(bgc);
		if tmp(1) > 0.4
			txtc = [0 0 0];
		else
			txtc = [1 1 1];
		end
		switch requestedPanel{1}
			case 'Select Images/ROIs'
				[objpos,objdim] = distributeObjects(3,0.025,0.975,0);%0.725
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','Add Images',...
					'fontsize',9,...
					'fontweight','bold',...
					'position',[objpos(1) 0.015 objdim 0.05],...
					'callback',{@promptForImages,'Add Images to Train'});
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','Add Directory',...
					'fontsize',9,...
					'fontweight','bold',...
					'position',[objpos(2) 0.015 objdim 0.05],...
					'callback',{@promptForImages,'Add Directory to Train'});
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','Remove Images',...
					'fontsize',9,...
					'fontweight','bold',...
					'position',[objpos(3) 0.015 objdim 0.05],...
					'callback',{@deleteSelectedImages,'To Train'});
				imageListPanel = uipanel(...
					'parent',parent,...
					'pos',[0.025,0.09,0.95,0.875],...
					'backgroundcolor',bgc,...
					'foregroundcolor',txtc,...
					'borderType','etchedin');
				imageListbox = uicontrol('parent',imageListPanel,...
					'style','listbox',...
					'position',[0 0 0.85 0.95],...
					'string',imageList,...
					'callback',@refreshDisplay,...
					'max',10,...
					'min',1);
				numROIsListbox = uicontrol('parent',imageListPanel,...
					'style','listbox',...
					'position',[0.85 0 0.15 0.95],...
					'string',numberROIs,...
					'callback',@ROISelected,...
					'listboxtop',1,...
					'max',10,...
					'min',1);
				uicontrol('parent',imageListPanel,...
					'style','pushbutton',...
					'string','Image Name',...
					'fontsize',10,...
					'fontweight','bold',...
					'position',[0 0.95 0.8 0.05],...
					'callback',@sortByImageName);
				uicontrol('parent',imageListPanel,...
					'style','pushbutton',...
					'string','# ROIs',...
					'fontsize',10,...
					'fontweight','bold',...
					'position',[0.8 0.95 0.2 0.05],...
					'callback',@sortByNumROIs);
			case 'Train Cascade Detector'
				startAcross = 0.025;endAcross = 0.975;
				[objpos,objdim] = distributeObjects(2,startAcross,endAcross,0.01);%0.725
				uicontrol('parent',parent,...
					'style','text',...
					'string','1: Specify Negative Images',...
					'foregroundcolor',[0.035 0.414 0.634],...
					'backgroundcolor',bgc,...
					'fontsize',defaultFontsize + 5,...
					'position',[objpos(1) 0.935 endAcross-objpos(1) 0.06]);
				[vobjpos, vobjdim] = distributeObjects(3,0.9425,0.655,0.01);
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','ADD DIR',...
					'fontsize',defaultFontsize + 1,...
					'fontweight','bold',...
					'position',[objpos(1) vobjpos(1) 0.175 vobjdim],...
					'callback',{@promptForImages,'Add Negative Directory'});
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','ADD',...
					'fontsize',defaultFontsize + 1,...
					'fontweight','bold',...
					'position',[objpos(1) vobjpos(2) 0.175 vobjdim],...
					'callback',{@promptForImages,'Add Negative Images'});
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','REMOVE',...
					'fontsize',defaultFontsize + 1,...
					'fontweight','bold',...
					'position',[objpos(1) vobjpos(3) 0.175 vobjdim],...
					'callback',{@deleteSelectedImages,'Negative Images'});%@deleteNegativeImages
				uicontrol('parent',parent,...
					'style','text',...
					'string','...and/or use ROI-Masked positives as negatives:',...
					'foregroundcolor','k',...
					'backgroundcolor',bgc,...
					'fontsize',defaultFontsize + 2,...
					'position',[objpos(1) 0.5775 1-2*objpos(1) 0.06]);
				negativeImageListbox = uicontrol('parent',parent,...
					'style','listbox',...
					'position',[objpos(1)+0.19 0.625+0.03 endAcross-(objpos(1)+0.19) 0.2875],...
					'string',imageList,...
					'callback',@showNegativeImage,...
					'max',10,...
					'min',1);
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','?',...
					'fontsize',defaultFontsize + 1,...
					'position',[objpos(1) 0.56 0.035 0.035],...
					'callback',@explainUsePosAsNeg);
				usePosAsNegBox = uicontrol('parent',parent,...
					'style','checkbox',...
					'string','Auto-include ROI-masked positives as negatives?',...
					'fontsize',defaultFontsize + 2,...
					'backgroundcolor',bgc,...
					'position',[0.0625 0.565 endAcross-0.0625 0.025],...
					'value',1);
				uicontrol('parent',parent,...
					'style','text',...
					'string','2: Select Parameters for Training Detector',...
					'foregroundcolor',[0.035 0.414 0.634],...
					'backgroundcolor',bgc,...
					'fontsize',defaultFontsize + 5,...
					'position',[objpos(1) 0.475 endAcross-objpos(1) 0.06]);%0.46
				tts = sprintf('False alarm rate acceptable at each stage.\nThe value must be greater than 0 and less\nthan or equal to 1. The overall target false\nalarm rate of the resulting detector is\nFalseAlarmRate^NumCascadeStages. Lower value\nof FalseAlarmRate may result in fewer false\ndetections, but in longer training and\ndetection times.\n\nDefault: 0.5\n\n(Right-click slider bar to reset default.)');
				[falseAlarmRateSlider,~,falseAlarmRateEdt] = ...
					sliderPanel(parent,...
					{'backgroundcolor',bgc,...
					'title','Per-Stage False Alarm Rate',...
					'pos',[objpos(1) 0.3775 objdim 0.1],...
					'units','normalized'},...
					{'backgroundcolor',colors(5,:),...
					'min',0,...
					'max',0.75,...
					'value',0.50000,...
					'callback',@showOverallRate,...
					'sliderstep',[0.001 0.005],...
					'tag','falseAlarmRateSldr',...
					'tooltipstring',tts},...
					{'backgroundcolor',colors(5,:),...
					'fontsize',defaultFontsize},...
					{'backgroundcolor',bgc,...
					'fontsize',defaultFontsize},...
					'%0.5f');%#ok
				tts = sprintf('Minimum true positive rate required at each\nstage. The value must be greater than 0 and\nless than or equal to 1. The overall target\ntrue positive rate of the resulting detector\nis TruePositiveRate^NumCascadeStages.\nIncreasing this value may increase the number\nof correct detections, at the cost of\nincreased training time.\n\nDefault: 0.995\n\n(Right-click slider bar to reset default.)');
				[truePositiveRateSlider,~,truePositiveRateEdt] = ...
					sliderPanel(parent,...
					{'backgroundcolor',bgc,...
					'title','Per-Stage True Positive Rate',...
					'pos',[objpos(2) 0.3775 objdim 0.1],...
					'units','normalized'},...
					{'backgroundcolor',colors(5,:),...
					'min',0.8,...
					'max',1,...
					'value',0.99500,...
					'callback',@showOverallRate,...
					'sliderstep',[0.0001 0.005],...
					'tag','truePositiveRateSldr',...
					'tooltipstring',tts},...
					{'backgroundcolor',colors(5,:),...
					'fontsize',defaultFontsize},...
					{'backgroundcolor',bgc,...
					'fontsize',defaultFontsize},...
					'%0.5f');%#ok
				tts = sprintf('The number of cascade stages to train.\nIncreasing the number of stages may\nresult in a more accurate detector, but will\nincrease the training time. More stages may\nrequire more training images.\n\nDefault: 20\n\n(Right-click slider bar to reset default.)');
				[NumCascadeStagesSlider,~,NumCascadeStagesEdt] = ...
					sliderPanel(parent,...
					{'backgroundcolor',bgc,...
					'title','Number of Cascade Stages',...
					'pos',[objpos(1) 0.2625 objdim 0.1],...
					'units','normalized'},...
					{'backgroundcolor',colors(5,:),...
					'min',1,...
					'max',50,...
					'value',20,...
					'callback',@showOverallRate,...
					'sliderstep',[1 5]/49,...
					'tag','numCascadeStagesSlider',...
					'tooltipstring',tts},...
					{'backgroundcolor',colors(5,:),...
					'fontsize',defaultFontsize},...
					{'backgroundcolor',bgc,...
					'fontsize',defaultFontsize},...
					'%0.0f');%#ok
				featureTypeButtons = uibuttongroup(parent,...
					'Position',[objpos(2) 0.2625 objdim 0.1],...
					'backgroundcolor',bgc,'title','Feature Type');
				% Create radio buttons in the button group.
				allFeatureTypes = {'Haar','LBP','HOG'};
				tmp = {'Haar-like features';
					'Local Binary';
					'Histogram of Oriented Gradients (DEFAULT)'};
				featureType = zeros(numel(allFeatureTypes),1);
				[objpos2,objdim2] = distributeObjects(numel(allFeatureTypes),0.025,0.95,0.015);
				for ii = 1:numel(allFeatureTypes)
					featureType(ii) = uicontrol('parent',featureTypeButtons,'Style','Radio','String',allFeatureTypes{ii},...
						'pos',[objpos2(ii) 0.4 objdim2 0.4],'HandleVisibility','off',...
						'backgroundcolor',bgc,'fontsize',defaultFontsize,'value',ii==3,...
						'tooltipstring',tmp{ii});
				end
				tts = sprintf('A real-valued scalar which determines the \nnumber of negative samples used at a stage as\na multiple of the number of positive samples.\n\nDefault: 2\n\n(Right-click slider bar to reset default.)');
				[NegativeSamplesFactorSlider,~,NegativeSamplesFactorEdt] = ...
					sliderPanel(parent,...
					{'backgroundcolor',bgc,...
					'title','Negative Samples Factor',...
					'pos',[objpos(1) 0.1475 objdim 0.1],...
					'units','normalized'},...
					{'backgroundcolor',colors(5,:),...
					'min',1,...
					'max',10,...
					'value',2,...
					'callback','',...
					'sliderstep',[1 10]/9,...
					'tag','NegativeSamplesFactorSldr',...
					'tooltipstring',tts},...
					{'backgroundcolor',colors(5,:),...
					'fontsize',defaultFontsize},...
					{'backgroundcolor',bgc,...
					'fontsize',defaultFontsize},...
					'%0.0f');%#ok
				objectTrainingSizePanel = uipanel(parent,...
					'bordertype','etchedin',...
					'backgroundcolor',bgc,...get(parent,'backgroundcolor')
					'position',[objpos(2) 0.1475 objdim 0.1],...
					'title','Object Training Size');
				tts = sprintf('Object Training Size is a 2-element vector [height, width] specifying\nthe size to which objects will be resized\nduring the training, or the string ''Auto''. If\n''Auto'' is used, the function will determine\nthe size automatically based on the median\nwidth-height ratio of the positive instances.\nIncreasing the size may improve detection\naccuracy, but will also increase training and\ndetection times.\n\nDefault: ''Auto''');
				objTrainHeightText = uicontrol('parent',objectTrainingSizePanel,...
					'style','text',...
					'string','HEIGHT',...
					'backgroundcolor',bgc,...
					'enable','off',...
					'horizontalalignment','left',...
					'fontsize',defaultFontsize+1,...
					'position',[0.05 0.45 0.25 0.4],...
					'tooltipstring',tts);
				objTrainHeight = uicontrol('parent',objectTrainingSizePanel,...
					'style','edit',...
					'string',24,...
					'enable','off',...
					'position',[0.35 0.5 0.25 0.4],...
					'tooltipstring',tts);
				objTrainWidthText = uicontrol('parent',objectTrainingSizePanel,...
					'style','text',...
					'string','WIDTH',...
					'backgroundcolor',bgc,...
					'enable','off',...
					'horizontalalignment','left',...
					'fontsize',defaultFontsize+1,...
					'position',[0.05 0.05 0.25 0.4],...
					'tooltipstring',tts);
				objTrainWidth = uicontrol('parent',objectTrainingSizePanel,...
					'style','edit',...
					'string',24,...
					'enable','off',...
					'position',[0.35 0.025 0.25 0.4],...
					'tooltipstring',tts);
				autoObjTrainWidth = uicontrol('parent',objectTrainingSizePanel,...
					'style','checkbox',...
					'string','AUTO',...
					'backgroundcolor',bgc,...
					'value',1,...
					'callback',@autoSize,...
					'fontsize',defaultFontsize+1,...
					'position',[0.625 0.025 0.325 0.4],...
					'tooltipstring',tts);
				uicontrol('parent',parent,...
					'style','text',...
					'string','3: Train Detector!',...
					'foregroundcolor',[0.035 0.414 0.634],...
					'backgroundcolor',bgc,...
					'fontsize',defaultFontsize + 5,...
					'position',[objpos(1) 0.06 endAcross-objpos(1) 0.06]);
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','Train Detector!',...
					'fontsize',14,...
					'position',[objpos(1) 0.015 endAcross-objpos(1) 0.05],...
					'callback',@trainDetector);
			case 'Run/Apply/Evaluate Detector'
				startAcross = 0.025;endAcross = 0.975;
				objpos = distributeObjects(2,startAcross,endAcross,0.01);%0.725
				uicontrol('parent',parent,...
					'style','text',...
					'string','1: Select Detector',...
					'foregroundcolor',[0.035 0.414 0.634],...
					'backgroundcolor',bgc,...
					'fontsize',defaultFontsize + 5,...
					'position',[objpos(1) 0.935 endAcross-objpos(1) 0.06]);
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','Select ...',...
					'fontsize',defaultFontsize + 1,...
					'fontweight','bold',...
					'position',[objpos(1) 0.8825 0.175 0.06],...
					'callback',@selectDetector);
				detectorBox = uicontrol('parent',parent,...
					'style','edit',...
					'string','',...
					'fontsize',defaultFontsize,...
					'position',[objpos(1)+0.19 0.8825 endAcross-(objpos(1)+0.19) 0.06]);
				uicontrol('parent',parent,...
					'style','text',...
					'string','2: Select Image(s) to Search',...
					'foregroundcolor',[0.035 0.414 0.634],...
					'backgroundcolor',bgc,...
					'fontsize',defaultFontsize + 5,...
					'position',[objpos(1) 0.8 endAcross-objpos(1) 0.06]);
				[vobjpos,vobjdim] = distributeObjects(4,0.7975,0.54,0.01);%0.725
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','From Tab 1',...
					'fontsize',defaultFontsize,...
					'fontweight','bold',...
					'position',[objpos(1) vobjpos(1) 0.175 vobjdim],...
					'callback',{@promptForImages,'From Tab 1'});
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','ADD DIR',...
					'fontsize',defaultFontsize + 1,...
					'fontweight','bold',...
					'position',[objpos(1) vobjpos(2) 0.175 vobjdim],...
					'callback',{@promptForImages,'Add Directory to Search'});
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','ADD',...
					'fontsize',defaultFontsize + 1,...
					'fontweight','bold',...
					'position',[objpos(1) vobjpos(3) 0.175 vobjdim],...
					'callback',{@promptForImages,'Add Images to Search'});
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','REMOVE',...
					'fontsize',defaultFontsize + 1,...
					'fontweight','bold',...
					'position',[objpos(1) vobjpos(4) 0.175 vobjdim],...
					'callback',{@deleteSelectedImages,'To Search'});%@deleteImagesToSearch
				imagesToSearchListbox = uicontrol('parent',parent,...
					'style','listbox',...
					'position',[objpos(1)+0.19 0.555-0.015 endAcross-(objpos(1)+0.19) 0.2575],...
					'string',imageList,...
					'max',10,...
					'min',1,...
					'callback',@applyDetector);
				uicontrol('parent',parent,...
					'style','pushbutton',...
					'string','(Re-)Run Detector!',...
					'fontsize',14,...
					'position',[objpos(1) 0.015 endAcross-objpos(1) 0.05],...
					'callback',@applyDetector);
		end
		assignin('base','imageListbox',imageListbox)
		assignin('base','numROIsListbox',numROIsListbox)
	end %setupPanel

	function showNegativeImage(varargin)
		s = warning; %Current state
		warning('off');%#ok
		nis = get(negativeImageListbox,'string');
		nis = nis(get(negativeImageListbox,'value'),:);
		imshow(nis,'parent',workingAx);
		set(workingTitle,'string',nis);
		warning(s);
	end %showNegativeImage

	function showOverallRate(varargin)
		FalseAlarmRate = get(falseAlarmRateSlider,'value');
		if FalseAlarmRate == 0
			FalseAlarmRate = eps;
			throwComment('Using EPS for False Alarm Rate!',1,1);
		end
		TruePositiveRate = get(truePositiveRateSlider,'value');
		NumCascadeStages = round(get(NumCascadeStagesSlider,'value'));
		throwComment('If all stages are trained successfully, this setting will provide an');
		ofar = FalseAlarmRate^NumCascadeStages;
		otpr = TruePositiveRate^NumCascadeStages;
		switch get(varargin{1},'tag')
			case 'falseAlarmRateSldr'
				%Overall false alarm rate:
				throwComment(sprintf('                  OVERALL False Alarm Rate of %0.9f.',ofar));
			case 'truePositiveRateSldr'
				%Overall true positive rate:
				throwComment(sprintf('                  OVERALL True Positive Rate of %0.9f.',otpr));
			case 'numCascadeStagesSlider'
				throwComment(sprintf('                  OVERALL False Alarm Rate of %0.9f.',ofar));
				throwComment(sprintf('                  OVERALL True Positive Rate of %0.9f.',otpr));
		end
	end %showOverallRate

	function sortByImageName(varargin)
		updateStatus
		if isempty(current.currentImageList)
			return
		end
		[newList,inds] = sortrows(current.currentImageList);
		if strcmp(newList,current.currentImageList) % List is currently in ascending order
			inds = flipud(inds);
		end
		newInd = find(ismember(inds,current.currentListboxIndex));
		setappdata(cascadeTool,'IsSaved',false)
		set(imageListbox,...
			'string',current.currentImageList(inds,:))
		set(numROIsListbox,...
			'string',current.numROIs(inds));
		set([imageListbox,numROIsListbox],...
			'value',newInd);
		throwComment(sprintf('Displaying image %d of %d (relative to current sort).',...
			newInd,size(current.currentImageList,1)));
		setappdata(cascadeTool,...
			'IsSaved',false)
	end %sortByImageName

	function sortByNumROIs(varargin)
		updateStatus
		if isempty(current.currentImageList)
			return
		end
		[newList,inds] = sortrows(current.numROIs);
		if isequal(newList,current.numROIs)% List is currently in ascending order
			inds = flipud(inds);
		end
		newInd = find(ismember(inds,current.currentListboxIndex));
		setappdata(cascadeTool,...
			'IsSaved',false)
		set(imageListbox,...
			'string',current.currentImageList(inds,:))
		set(numROIsListbox,...
			'string',current.numROIs(inds));
		set([imageListbox,numROIsListbox],...
			'value',newInd);
		throwComment(sprintf('Displaying image %d of %d. (Relative to current sort.)',newInd,size(current.currentImageList,1)));
		setappdata(cascadeTool,'IsSaved',false)
	end %sortByNumROIs

	function throwComment(commentString,beepOn,append)
		soundsOff = get(findobj(cascadeTool,'tag','TurnOffSounds'),'checked');
		if nargin < 2
			beepOn = 0;
		end
		if nargin < 3
			append = 1;
		end
		if append
			currString = get(commentBox,'string');
			currString = char(cellstr({currString;commentString}));
			if all(double(currString(1,:)== 32))
				currString = currString(2:end,:);
			end
			set(commentBox,...
				'string',currString);
		else
			set(commentBox,...
				'string',commentString);
		end
		tmp = size(get(commentBox,'string'),1);
		set(commentBox,...
			'listboxtop',tmp,...
			'value',tmp);
		if beepOn  && ~strcmp(soundsOff,'on')
			beep; %notification.play
		end
		drawnow;
	end %throwComment

	function toggleMenuItem(varargin)
		item = varargin{1};
		%checked = '';
		switch get(item,'type')
			case 'uimenu'
				checked = get(item,'checked');
				if strcmp(checked,'on')
					set(item,...
						'checked','off');
				else
					set(item,...
						'checked','on');
				end
		end
	end %toggleMenuItem

	function trainDetector(varargin)
		% Ensure that images have been specified on ROI Selection Tab
		if isempty(get(imageListbox,'string'))
			throwComment('You must have specified (or loaded) training data on the ROI Selection Tab before training!',1,1);
			return
		end
		if any(current.numROIs==0)
			throwComment('It appears that there is at least one untrained image in the Image List of the ROI Selection Tab.')
			throwComment('Please ensure that all "positive" images have at least one ROI, or delete them prior to training!',1,1);
			return
		end
		continueTraining = questdlg('Training could take a while...','Continue?','TRAIN DETECTOR','Cancel','TRAIN DETECTOR');
		if ~strcmp(continueTraining,'TRAIN DETECTOR')
			return
		end
		% Ensure that session is saved first
		isSaved = getappdata(cascadeTool,'IsSaved');
		if ~isSaved
			continueTraining = questdlg('To continue, I must save the current session. Would you like to continue?',...
				'Save and Continue?','CONTINUE','Cancel','CONTINUE');
			if ~strcmp(continueTraining,'CONTINUE')
				return
			end
			throwComment('Saving...')
			saveSession;
		end
		% What images have been specified for negative training?
		myList = get(negativeImageListbox,'string');
		usePosAsNeg = get(usePosAsNegBox,'value');
		if  isempty(myList) && ~usePosAsNeg
			throwComment('You must first specify negative images!',1,1);
			return
		end
		% First, get negative images from listbox
		throwComment('Building list of negative images...')
		tic; %timing overall training from this point
		% Create and append ROI-masked positive images, if requested
		if usePosAsNeg
			% Clear existing temporary directory of ROI-masked positive
			% images, if one exists
			pn = fileparts(which('cascadeTrainer'));
			tmpdir = fullfile(pn,'ROIMaskedPositives');
			deleteIt = '';
			if exist(tmpdir,'dir') %isdir(tmpdir)
				deleteIt = questdlg('Directory of ROI-Masked images already exists. Do you want to delete and recreate it?','Delete Positive-as-Negative Images?',...
					'DELETE and REBUILD','Use Existing','Cancel','DELETE and REBUILD');
				if strcmp(deleteIt,'DELETE and REBUILD')
					% DELETE
					throwComment('Deleting previous temporary directory of ROI-masked images.');
					rmdir(tmpdir,'s');
				end
			end
			if strcmp(deleteIt,'Cancel')
				throwComment('Aborting...',1,1);
				return
			end
			if ~strcmp(deleteIt,'Use Existing')
				rehash; %need to clear cache/flush queue so everything is okay for the subsequent mkdir command
				% REBUILD
				% Create a new temporary directory of ROI-masked positive images;
				mkdir(pn,'ROIMaskedPositives');
				% Create ROI-masked images in temporary directory
				newImWaitbar = waitbar(0,'Creating ROI-masked images');
				for ii = 1:numel(CTS.ImageInfo)
					createROIMaskedImage(tmpdir,CTS.ImageInfo(ii));
					waitbar(ii/numel(CTS.ImageInfo));
				end
				close(newImWaitbar);
			end
			% Now compile a list of ROI-masked images
			[~,extensions] = imgformats;
			% NOTE: there's a bug in dir2--it crashes if
			% numel(extensions) > 21; here's a workaround:
			%tmp = dir2(tmpdir,extensions);
			tmp = [dir2(tmpdir,extensions(1:20));dir2(tmpdir,extensions(21:end))];
			tmp = [repmat([tmpdir,filesep],numel(tmp),1),char({tmp.name}')];
			if isempty(tmp)
				error('It appears that directory %s exists, but contains no valid images!\nPlease delete that directory and regenerate positive-as-negative images!',tmpdir)
			end
			% Note: Zainb reported via the FEX that the program errors if
			% 'Auto-include masked positives' is checked but no other
			% negatives are specified. I think that the 'else' I added here
			% addresses that problem.
			if exist('myList','var') && ~isempty(myList)
				myList = char(myList,tmp);
			else
				myList = char(tmp);
			end
		end %if usePosAsNeg
		% Verify that all image names are valid
		% Note: I don't think this is necessary with the current DIR2
		% implementation.
		%         throwComment('Verifying that all specified negative images are valid...');
		%         tmp = imformats;
		%         tmp = [tmp.ext]';
		%         if iscellstr(myList)
		%             for ii = numel(myList):-1:1
		%                 [~,~,ext] = fileparts(myList{ii});
		%                 if ~ismember(ext(2:end),tmp)
		%                     myList(ii) = [];
		%                 end
		%             end
		%         end
		
		myList = cellstr(myList);
		FalseAlarmRate = get(falseAlarmRateSlider,'value');
		if FalseAlarmRate == 0
			FalseAlarmRate = eps;
			throwComment('Using EPS for False Alarm Rate!',1,1);
		end
		TruePositiveRate = get(truePositiveRateSlider,'value');
		NumCascadeStages = round(get(NumCascadeStagesSlider,'value'));
		FeatureType = get(get(featureTypeButtons,'SelectedObject'),'string');
		NegativeSamplesFactor = round(get(NegativeSamplesFactorSlider,'value'));
		objTrainWidthVal = str2double(get(objTrainWidth,'string'));
		objTrainHeightVal = str2double(get(objTrainHeight,'string'));
		autoObjTrainWidthVal = get(autoObjTrainWidth,'value');
		throwComment('Commencing training...')
		if autoObjTrainWidthVal
			trainCascadeObjectDetector([CTS.SessionName '.xml'], ...
				CTS.ImageInfo,...
				myList,...
				'FalseAlarmRate',        FalseAlarmRate,...
				'TruePositiveRate',      TruePositiveRate,...
				'NumCascadeStages',      NumCascadeStages,...
				'FeatureType',           FeatureType,...
				'NegativeSamplesFactor', NegativeSamplesFactor,...
				'ObjectTrainingSize',    'Auto');
		else
			trainCascadeObjectDetector([CTS.SessionName '.xml'], ...
				CTS.ImageInfo,...
				myList,...
				'FalseAlarmRate',        FalseAlarmRate,...
				'TruePositiveRate',      TruePositiveRate,...
				'NumCascadeStages',      NumCascadeStages,...
				'FeatureType',           FeatureType,...
				'NegativeSamplesFactor', NegativeSamplesFactor,...
				'ObjectTrainingSize',    [objTrainHeightVal,objTrainWidthVal]);
		end
		set(detectorBox,'string',[CTS.SessionName '.xml'])
		t = toc;
		if usePosAsNeg
			try
				rmdir(tmpdir,'s');
				throwComment('Temporary directory of ROI-Masked positive images masked.')
			end
		end
		throwComment(sprintf('Training is done in %0.2f minutes',t/60));
	end %trainDetector

	function updateCBsForROI(ROI,opt)
		if nargin < 2
			opt = 'updateRequired';
		end
		%Refresh on MOVE:
		ROI.addNewPositionCallback(@ROIMoved);
		%Refresh on DELETE:
		%  (Can't add a deletion callback to an ROI directly;
		%   I'll add it to a child corner-marker):
		ROI = findall(ROI,...
			'tag','maxx maxy corner marker');
		iptaddcallback(ROI,...
			'Delete',{@updateCTS,'deleteROI'});
		%Refresh CTS structure
		if strcmp(opt,'updateRequired')
			updateCTS('ROIChange')
		end
		setappdata(cascadeTool,'IsSaved',false)
	end

	function updateCTS(varargin)
		%BDS: Ignore call to updateCTS generated by IMSHOW-mediated deletion
		%of ROIs
		ignoreRequest = getappdata(cascadeTool,'ignoreUpdateRequest');
		if ignoreRequest && numel(current.selectedValues) < 2
			return
		end
		
		% BDS: Note that my implementation might be a bit inefficient here.
		% I run this every time an ROI is created, moved, or deleted, and
		% each call recalculates all current positions and updates the CTS
		% structure and the NumROIsListbox. But this was easier than
		% implementing logic to detect the changes, and it is fast enough
		% to not worry about.
		if nargin == 1
			option = varargin{1};
		elseif nargin == 3
			option = varargin{3};
		end
		updateStatus
		if strcmp(current.currentImageName,'Drag cursor to define ROI.')
			current.currentImageName = deblank(current.currentImageList(current.selectedValues,:));
		end
		switch option
			case 'ROIChange'
				CTS.ImageInfo(current.currentCTSIndex).objectBoundingBoxes = [];
				for ii = 1:numel(current.currentROIs)
					CTS.ImageInfo(current.currentCTSIndex).objectBoundingBoxes(ii,:) = getPos(current.currentROIs(ii));
				end
				current.numROIs(current.currentListboxIndex,:) = numel(current.currentROIs);%num2str(numel(current.currentROIs));
				set(numROIsListbox,'string',current.numROIs);
			case 'deleteROI'
				current.numROIs(current.currentListboxIndex) = numel(current.currentROIs)-1;
				set(numROIsListbox,'string',current.numROIs);
				
				%CTS.ImageInfo(current.currentCTSIndex).objectBoundingBoxes(strcmp(get(current.currentROIs,'BeingDeleted'),'on'),:) = [];
				% NOTE: Getting this to always select the correct ROI to
				% delete after additions and removals was tricky. This
				% seems to be working:
				delInd = find(ismember(CTS.ImageInfo(current.currentCTSIndex).objectBoundingBoxes,...
					getPos(current.currentROIs(strcmp(get(current.currentROIs,'BeingDeleted'),'on'))),'rows'));
				if ~isempty(delInd) %10/21/13 This fixes a bug...
					% Updating the image engages the 'beingDeleted'
					% property, which calls the image's DeleteFcn...which triggers
					% updateCTS('deleteROI'); so we end up here.
					CTS.ImageInfo(current.currentCTSIndex).objectBoundingBoxes(delInd,:) = [];
					current.currentROIs(delInd,:) = [];
				end
			case 'deleteImages'
				inds = ismember(cellstr({CTS.ImageInfo.imageFilename})',deletedImages);
				CTS.ImageInfo(inds) = [];
		end
		setappdata(cascadeTool,'IsSaved',false)
	end %updateCTS

	function updateStatus(varargin)
		% Compile all current status information into a single structure.
		% Get INDICES OF ALL LISTBOX-SELECTED IMAGES
		current.selectedValues = get(imageListbox,'value');
		current.currentImageList = get(imageListbox,'string');
		current.currentNegativeImageList = get(negativeImageListbox,'string');
		current.numROIs  = str2num(get(numROIsListbox,'string'));%#ok
		
		% Get NAME OF CURRENTLY SELECTED IMAGE from annotation box
		current.currentImageName = get(currentImageNameHandle,'string');
		% This odd bit of code is necessary because the annotation textbox
		% automatically wraps long filenames into multi-cell strings, which
		% then appear to be invalid.
		if size(current.currentImageName,1) > 1
			set(workingTitle,'fontsize',1);
			current.currentImageName = get(currentImageNameHandle,'string');
			set(workingTitle,'fontsize',defaultWorkingTitleFontsize);
		end
		if isa(current.currentImageName,'cell')
			current.currentImageName = current.currentImageName{1};
		end
		if ~isempty(strfind(current.currentImageName,'Drag cursor to define ROI'))
			current.currentImageName = deblank(current.currentImageList(current.selectedValues,:));
		end
		current.currentROIs = findall(cascadeTool,'tag','imrect');
		% Get INDICES OF CURRENTLY DISPLAYED IMAGE
		current.currentListboxIndex = find(strcmp(cellstr(current.currentImageList),...
			current.currentImageName));
		current.currentCTSIndex = find(strcmp({CTS.ImageInfo.imageFilename},...
			current.currentImageName));
		setappdata(cascadeTool,'IsSaved',false)
	end %updateStatus

	function verified = verifyCommand(verifyString)
		verify = get(findobj(cascadeTool,'tag','Verify'),'checked');
		verified = true;
		if strcmp(verify,'off')
			return
		end
		msgOff = '(Uncheck OPTIONS->"Verify Commands" to suppress this message.)';
		verifyString = sprintf('%s\n\n%s',verifyString,msgOff);
		verified = questdlg(verifyString,...
			'!! Warning !!','CONTINUE','Cancel','CONTINUE');
		verified = strcmp(verified,'CONTINUE');
	end %verifyCommand

	function zoomIt(varargin)
		try
			set(gcbo,'state','off')
		end
		zoom;
	end %zoomIt

end %NESTED SUBFUNCTIONS