global sigmas; % input noise level or input noise level map

addpath('utilities');

% Image locations
folderTest   = 'test_images';
ext          =  {'*.jpg','*.png','*.bmp'};

showResult  = 0;
pauseTime   = 0;


%%% load Flexible DnCNN (FDnCNN)
load('model/FDnCNN_color.mat'); 
net = vl_simplenn_tidy(net);


% load images paths
filepaths           =  [];
for i = 1 : length(ext)
    filepaths = cat(1,filepaths,dir(fullfile(folderTest, ext{i})));
end

clear addnoise
clear NoiseNames
NoiseNames{1} = 'Gaussian: sigma = 15';
NoiseNames{2} = 'Gaussian: sigma = 25';
NoiseNames{3} = 'Gaussian: sigma = 50';
NoiseNames{4} = 'Salt & pepper:  5%';
NoiseNames{5} = 'Poisson noise';
addnoise{1} = @(image) imnoise(image,'gaussian',0, (15/255)^2);
addnoise{2} = @(image) imnoise(image,'gaussian',0, (25/255)^2);
addnoise{3} = @(image) imnoise(image,'gaussian',0, (50/255)^2);
addnoise{4} = @(image) imnoise(image,'salt & pepper', 0.05);
addnoise{5} = @(image) im2double(imnoise(im2uint8(image),'poisson'));

psnr_FDnCNN = zeros(length(addnoise), 1, length(images)+1);


for noise = 1:length(addnoise)
    randn('seed',0); % for reproducibility
    disp('Noise('+string(noise)+'): '+NoiseNames{noise})
    for i = 1 : length(filepaths)
        image  = imread(fullfile(folderTest,filepaths(i).name));
        assert(size(image,3)==3, 'FDnCNN requires 3 channels (RGB)')

        [~,imageName,ext] = fileparts(filepaths(i).name);
        imageNames{i} = imageName;
        
        image = im2double(image);
        input = single(addnoise{noise}(image));

        % Estimate and set noise level map
        sigmas = (estimate_noise(input(:,:,1))+estimate_noise(input(:,:,2))+estimate_noise(input(:,:,3)))/3;

        % perform denoising
        res    = vl_simplenn(net,input,[],[],'conserveMemory',true,'mode','test'); % matconvnet default
        % res    = vl_ffdnet_concise(net, input);    % concise version of vl_simplenn for testing FFDNet
        % res    = vl_ffdnet_matlab(net, input); % use this if you did  not install matconvnet; very slow

        output = res(end).x;

        %%% calculate PSNR
        PSNRCur = psnr(image, im2double(output));

        if showResult
            imshow(cat(2,im2uint8(image),im2uint8(input),im2uint8(output)));
            title([filepaths(i).name,'    ',num2str(PSNRCur,'%2.2f'),'dB'])
            disp([filepaths(i).name,'    ',num2str(PSNRCur,'%2.2f'),'dB'])
            drawnow;
            pause(pauseTime)
        end
        psnr_FDnCNN(noise, 1, i) = PSNRCur;
    end
end
psnr_FDnCNN(:,:,end) = mean(squeeze(psnr_FDnCNN(:,:,1:end-1)),2);
resTable = array2table(squeeze(psnr_FDnCNN), 'VariableNames',[imageNames, {'Mean_PSNR'}],'RowNames',NoiseNames);
disp(resTable)
fprintf('\n');
