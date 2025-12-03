function img_processed = img_processing(img, img_bg, threshold, opt)
img_blur = medfilt2(img, opt.blur_kernel);
% We first identify huge dark color blocks and delete the smaller blocks
binaryImage = imbinarize(uint8(img_bg-img_blur));
cc = bwconncomp(binaryImage);
numComponents = cc.NumObjects;
for i = 1:numComponents
  componentIndices = cc.PixelIdxList{i};
  componentArea = numel(componentIndices);

  % Remove components with area below the threshold (e.g., 400)
  if componentArea < 400
    binaryImage(componentIndices) = false;
    continue;
  end
  % Convert the pixel indices to a binary mask
  componentMask = false(size(binaryImage));
  componentMask(componentIndices) = true;

  % Fill holes within convex shapes
  filledComponentMask = imfill(componentMask, 'holes');

  % Update the binary image with the filled holes
  binaryImage(filledComponentMask) = true;
end
simple_thresh = median(img_blur(binaryImage),"all") + 10;
img_blur_masked2 = img_blur;
img_blur_masked2(img_blur_masked2 > simple_thresh)=255;

new_mask = img_blur_masked2 < simple_thresh;
cc = bwconncomp(new_mask);
numComponents = cc.NumObjects;
for i = 1:numComponents
  componentIndices = cc.PixelIdxList{i};
  componentArea = numel(componentIndices);

  % Remove components with area below the threshold (e.g., 400)
  if componentArea < 400
    new_mask(componentIndices) = false;
    continue;
  end
  % Convert the pixel indices to a binary mask
  componentMask = false(size(new_mask));
  componentMask(componentIndices) = true;

  % Fill holes within convex shapes
  filledComponentMask = imfill(componentMask, 'holes');

  % Update the binary image with the filled holes
  new_mask(filledComponentMask) = true;
end

img_processed = new_mask;
% function img_processed = img_processing(img, img_bg, threshold, opt)
% simple_thresh = 70;
% new_mask = imsharpen(img,'Radius',4,'Amount',1) < simple_thresh;
% for i = 1:opt.n_erode
%   new_mask = imerode(new_mask, opt.se_erode);
% end
% for i = 1:opt.n_dilate
%   new_mask = imdilate(new_mask, opt.se_dilate);
% end
% img_blur = medfilt2(img, opt.blur_kernel);
% new_mask = img_blur < simple_thresh;
% 
% cc = bwconncomp(new_mask);
% numComponents = cc.NumObjects;
% for i = 1:numComponents
%   componentIndices = cc.PixelIdxList{i};
%   componentArea = numel(componentIndices);
% 
%   % Remove components with area below the threshold (e.g., 400)
%   if componentArea < 400
%     new_mask(componentIndices) = false;
%     continue;
%   end
%   % Convert the pixel indices to a binary mask
%   componentMask = false(size(new_mask));
%   componentMask(componentIndices) = true;
% 
%   % Fill holes within convex shapes
%   filledComponentMask = imfill(componentMask, 'holes');
% 
%   % Update the binary image with the filled holes
%   new_mask(filledComponentMask) = true;
% end
% 
% % new_mask = bwconvhull(new_mask,'objects');
% img_processed = new_mask;


% function img_processed = img_processing(img, img_bg, threshold, opt)
% img_blur = medfilt2(img, opt.blur_kernel);
% 
% img_bi = abs(single(img_bg) + mean(single(img), 'all') - mean(single(img_bg), 'all') - single(img_blur))> threshold;
% 
% for i = 1:opt.n_erode
%   img_bi = imerode(img_bi, opt.se_erode);
% end
% for i = 1:opt.n_dilate
%   img_bi = imdilate(img_bi, opt.se_dilate);
% end
% img_processed = img_bi;
% end
