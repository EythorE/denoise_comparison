global sigmas; % input noise level or input noise level map

addpath('utilities');

% Image locations
folderTest   = 'test_images';
folderCorrupt = 'corrupt_images';
ext          =  {'*.jpg','*.png','*.bmp'};

showResult  = 1;
pauseTime   = 0;


%%% load Flexible DnCNN (FDnCNN)
load('model/FDnCNN_color.mat'); 
net = vl_simplenn_tidy(net);


% load images paths
filepaths           =  [];
for i = 1 : length(ext)
    filepaths = cat(1,filepaths,dir(fullfile(folderTest, ext{i})));
end

filepathsC =  [];
for i = 1 : length(ext)
    filepathsC = cat(1,filepathsC,dir(fullfile(folderCorrupt, ext{i})));
end


for i = 1 : length(filepaths)
    figure
    image  = imread(fullfile(folderTest,filepaths(i).name));
    assert(size(image,3)==3, 'FDnCNN requires 3 channels (RGB)')

    [~,imageName,ext] = fileparts(filepaths(i).name);
    imageNames{i} = imageName;

    image = im2double(image);
    input = single(imnoise(image,'gaussian',0, (25/255)^2));

    % Estimate and set noise level map
    sigmas = (estimate_noise(input(:,:,1))+estimate_noise(input(:,:,2))+estimate_noise(input(:,:,3)))/3;

    % perform denoising
    res    = vl_simplenn(net,input,[],[],'conserveMemory',true,'mode','test'); % matconvnet default
    % res    = vl_ffdnet_concise(net, input);    % concise version of vl_simplenn for testing FFDNet
    % res    = vl_ffdnet_matlab(net, input); % use this if you did  not install matconvnet; very slow

    output = res(end).x;

%%% calculate PSNR

    if showResult
        imshow(cat(2,im2uint8(input),im2uint8(output)));
        drawnow;
        pause(pauseTime)
    end
end

for i = 1 : length(filepathsC)
    figure
    image  = imread(fullfile(folderCorrupt,filepathsC(i).name));
    assert(size(image,3)==3, 'FDnCNN requires 3 channels (RGB)')

    [~,imageName,ext] = fileparts(filepathsC(i).name);
    imageNames{i} = imageName;

    image = im2double(image);
    input = single(image);

    % Estimate and set noise level map
    sigmas = (estimate_noise(input(:,:,1))+estimate_noise(input(:,:,2))+estimate_noise(input(:,:,3)))/3;

    % perform denoising
    res    = vl_simplenn(net,input,[],[],'conserveMemory',true,'mode','test'); % matconvnet default
    % res    = vl_ffdnet_concise(net, input);    % concise version of vl_simplenn for testing FFDNet
    % res    = vl_ffdnet_matlab(net, input); % use this if you did  not install matconvnet; very slow

    output = res(end).x;

%%% calculate PSNR

    if showResult
        imshow(cat(2,im2uint8(input),im2uint8(output)));
        drawnow;
        pause(pauseTime)
    end
end
