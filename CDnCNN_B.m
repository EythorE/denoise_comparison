addpath('utilities');

% Image locations
folderTest   = 'test_images';
ext          =  {'*.jpg','*.png','*.bmp'};

showResult  = 1;
pauseTime   = 0;


%%% load blind Gaussian denoising model (color image)
load('model/GD_Color_Blind.mat'); %%% for sigma in [0,55]
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

psnr_CDnCNN = zeros(length(addnoise), 1, length(images)+1);
imageNames = {};
for noise = 1:length(addnoise)
    randn('seed',0); % for reproducibility
    disp('Noise('+string(noise)+'): '+NoiseNames{noise})
    for i = 1 : length(filepaths)
        image  = imread(fullfile(folderTest,filepaths(i).name));
        [~,imageName,ext] = fileparts(filepaths(i).name);
        imageNames{i} = imageName;
        
        image = im2double(image);
        input = single(addnoise{noise}(image));
        res    = vl_simplenn(net,input,[],[],'conserveMemory',true,'mode','test');
        %res = simplenn_matlab(net, input); %%% use this if you did not install matconvnet.
        output = input - res(end).x;

        %%% calculate PSNR
        PSNRCur = psnr(image, im2double(output));
        if showResult
            imshow(cat(2,im2uint8(image),im2uint8(input),im2uint8(output)));
            title([filepaths(i).name,'    ',num2str(PSNRCur,'%2.2f'),'dB'])
            disp([filepaths(i).name,'    ',num2str(PSNRCur,'%2.2f'),'dB'])
            drawnow;
            pause(pauseTime)
        end
        psnr_CDnCNN(noise, 1, i) = PSNRCur;
    end
end
psnr_CDnCNN(:,:,end) = mean(squeeze(psnr_CDnCNN(:,:,1:end-1)),2);
resTable = array2table(squeeze(psnr_CDnCNN), 'VariableNames',[imageNames{1:3}, {'Mean_PSNR'}],'RowNames',NoiseNames);
disp(resTable)
fprintf('\n');
    