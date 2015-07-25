function roi = addROI(varargin)
% ADDROI: Create imrect with pushbutton- and context menu-deletion
%         and createPositionConstraint (disallows creating beyond image
%         edge)
%
% Calls IMRECT to generate a standard IMROI, but modifies the object's
% context menu, and adds a (simulated) pushbutton "x" for deleting the
% object. The creation of the imrect is also constrained to be within the
% bounds of the image (axis), and the setPositionConstraint constrains
% dragging to within the bounds of the axis by default.
%
% SYNTAX:
%   roi = addROI(parent) creates a new rectangular region of interest in
%   the axes specified by PARENT.
%
%   roi = addROI(parent,param,val,...) sets additional properties.
%         (See IMRECT for details.)
%
% Brett Shoelson, PhD
% brett.shoelson@mathworks.com
% 
% Note: Includes modification by Roland Michaely. (Better positioning, look
%       of "X" closing box.)
%
% See also: IMRECT, IMROI

% Modified 7/25/2014 to store ROI position in the appdata of the delButton.
% This facilitates detection of positions of multiple ROIs even after some
% may have been deleted.
% 
% EXAMPLE:
% h = [];
% for ii = 1:2,h = [h;addROI];end
% a  = findall(gcf,'tag','delButton')
% P1 = getappdata(a(1),'thisPosition')
% P2 = getappdata(a(2),'thisPosition')

%   Copyright 2010-2013 The MathWorks Inc.

roi = imrect(varargin{:});
if isempty(roi)
    % Escape character pressed
    return
end
roiPos = roi.getPosition;

% Simulate a "close ROI button" in the parent axes
parentAx = ancestor(get(roi,'parent'),'axes');
sz = 40;xOffset = 0;yOffset=0;
% I call this delButton, but it's really a text block/buttondownfcn.
% (uicontrols can't be children of axes.)
delButton = text('parent',parentAx,...
    'pos',[roiPos(1)+roiPos(3)+xOffset roiPos(2)+yOffset sz],... 
    'string','\fontsize{4} \bf\fontsize{6}X\rm\fontsize{4} ',...
    'tag','delButton',...
    'edgecolor','w',...
    'color','w',...
    'backgroundcolor',[0.7 0 0],...'r',...
    'horizontalalignment','center',...
    'buttondownfcn',@deleteROI);
setappdata(delButton,'thisPosition',roiPos);
roi.addNewPositionCallback(@repositionButton);

% Add a context menu for region deletion
% NOTE:ver AS OF R2014b, imrects are deletable by default!!!
if verLessThan('vision','6.1')
	l = findobj(roi,'type','line');
	uic = unique( cell2mat(get(l,'UIContextMenu')) );
	for u=1:numel(uic)
		uimenu( uic(u), 'Label', 'Delete', 'Callback', @deleteROI )
	end
end

% USER: Set position constraint here:
%fcn = makeConstrainToRectFcn('imrect',get(gca,'XLim'),get(gca,'YLim'));
fcn = makeConstrainToRectFcn('imrect',get(parentAx,'XLim'),get(parentAx,'YLim'));
setPositionConstraintFcn(roi,fcn);

% Here I create my own position constraint, so that the user cannot draw an
% ROI outside the bounds of the image. (The setPositionConstraintFcn
% disallows _moving_ the ROI beyond the edge of the image, but not
% _creating_ it beyond the edge.)
rp = roi.getPosition;
xl = get(parentAx,'xlim');
yl = get(parentAx,'ylim');
needsOverride = [rp(1) < xl(1), rp(1)+rp(3) > xl(2), rp(2) < yl(1), rp(2)+rp(4) > yl(2)];
if needsOverride(1) %Drawn beyond left axis edge
    roi.setPosition([xl(1) rp(2) rp(3)-(xl(1)-rp(1)) rp(4)])
    rp = roi.getPosition;
end
if needsOverride(2) %Drawn beyond right axis edge
    roi.setPosition([rp(1) rp(2) xl(2)-rp(1) rp(4)]);
    rp = roi.getPosition;
end
if needsOverride(3) %Drawn above top axis edge
    roi.setPosition([rp(1) yl(1) rp(3) rp(4)-(yl(1)-rp(2))]);
    rp = roi.getPosition;
end
if needsOverride(4) %Drawn below bottom axis edge
    roi.setPosition([rp(1) rp(2) rp(3) yl(2)-rp(2)])
end

% USER: Add (addditional) newPosition callbacks here:

% NESTED SUBFUNCTIONS
    function deleteROI(src,evt) %#ok
        delete(delButton)
        delete(roi);
    end

    function repositionButton(newPos) 
        set(delButton,'pos',[newPos(1)+newPos(3)+xOffset newPos(2)+yOffset sz])
		% check if upper left border is outside axes
		if newPos(1)+xOffset < min(get(parentAx,'xLim')) || ...
				newPos(1)+xOffset > max(get(parentAx,'xLim'))|| ...
				newPos(2)+yOffset < min(get(parentAx,'yLim'))|| ...
				newPos(2)+yOffset >max(get(parentAx,'yLim'))
			set(delButton,'Visible','off')
		else
			set(delButton,'Visible','on')
		end
		setappdata(delButton,'thisPosition',roi.getPosition);
    end

end % EOF
