% Image locations
folder   = 'results';
ext      =  'sigurros*.png';

folderResult= 'windowedResults';
if ~isdir(folderResult)
    mkdir(folderResult)
end

% Load all images
images = [];
filepaths = dir(fullfile(folder, ext));

clear image
for i = 1 : length(filepaths)
    [~,imageName,ext] = fileparts(filepaths(i).name);
    image.name = imageName;
    image.data = im2double(imread(fullfile(folder,filepaths(i).name)));
    images = cat(1, images, image);

end


image = images(1).data;

scale = 2;
box_corner = [210,225];
box_size = [100,100];
linewith = 2;
rgb = [200,0,100];


for im = 1:length(filepaths)
    image_out =  add_box(images(im).data, scale, box_corner, box_size, linewith ,rgb);
    imwrite(image_out, fullfile(folderResult, [images(im).name,'.png'] ));
end


function [image] = add_box(image, scale, box_corner, box_size, linewith ,rgb)
    bc = box_corner;
    bs = box_size;
    lw = linewith;
    
    inside = image(bc(1):bc(1)+bs(1),bc(2):bc(2)+bs(2),:);
    inside = imresize(inside,scale);
    padInside =  zeros(size(inside,1)+lw*2, size(inside,2)+lw*2, size(inside,3));
    
    for i = 1:length(rgb)
        padInside(:,:,i) = padarray(inside(:,:,i),[lw lw],rgb(i),'both');
        
        image(bc(1):bc(1)+lw,bc(2):bc(2)+bs(2),i) = rgb(i);
        image(bc(1):bc(1)+bs(1),bc(2)+bs(2):bc(2)+bs(2)+lw,i) = rgb(i);
        image(bc(1)+bs(1):bc(1)+bs(1)+lw,bc(2):bc(2)+bs(2)+lw,i) = rgb(i);
        image(bc(1):bc(1)+bs(1),bc(2):bc(2)+lw,i) = rgb(i);
    end
    
    image(1:1+size(padInside,1)-1,end-size(padInside,2)+1:end,:) = padInside;
end
