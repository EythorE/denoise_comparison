addpath('utilities');
addpath('TVL1denoise');
addpath('ROFdenoise');
addpath('testnlm');

displayImages = false;
pauseTime = 0;

% Image locations
folderTest   = 'test_images';
ext          =  {'*.jpg','*.png','*.bmp'};

% Load all images
filepaths = [];
images = [];
for i = 1 : length(ext)
    filepaths = cat(1,filepaths,dir(fullfile(folderTest, ext{i})));
end
images = [];
clear image
for i = 1 : length(filepaths)
    [~,imageName,ext] = fileparts(filepaths(i).name);
    image.name = imageName;
    image.data = im2double(imread(fullfile(folderTest,filepaths(i).name)));
    images = cat(1, images, image);
end

% Noise methods
% J = imnoise(I,'gaussian',0,var_gauss); variance = (sigma/255)^2
% J = imnoise(I,'salt & pepper', ratio_SandP);
% % Input pixel values are interpreted as
% % means of Poisson distributions scaled up by 1e12.
% J = imnoise(I,'poisson');
% % Output pixel will be generated from a 
% % Poisson distribution with mean of input pixel
% J = imnoise(im2uint8(image),'poisson')


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


denoisers = fdenoisers();
clear denoiserNames
for de = 1:length(denoisers)
    denoiserNames{de} = strtrim(evalc('disp(denoisers(de))'));
    denoiserNames{de} = erase(denoiserNames{de},'@(image)f');
    denoiserNames{de} = erase(denoiserNames{de},'(image)');
end
    
psnr_all = zeros(length(addnoise), length(denoisers), length(images)+1);

for noise = 1:length(addnoise)
    randn('seed',0); % for reproducibility
    disp('Noise '+string(noise)+'/'+length(addnoise)+'         '+NoiseNames{noise})
    for de = 1:length(denoisers)
        for im = 1:length(images)
            input = addnoise{noise}(images(im).data);
            output = denoisers{de}(input);
            
            % [PSNR_Cur,SSIM_Cur] = Cal_PSNRSSIM(images(im).data, im2uint8(output),0,0);
            % PSNR_Cur = psnr(im2uint8(images(im).data), im2uint8(output), 255)
            psnr_all(noise ,de, im) = psnr(images(im).data, output);
            if displayImages
                imshow(cat(2,im2uint8(images(im).data),im2uint8(input),im2uint8(output)));
                title({string(denoiserNames(de))+',    '+string(NoiseNames{noise}),...
                      strcat(images(im).name, sprintf(',    %2.2fdB',psnr_all(noise ,de, im)))});
                pause(pauseTime)
            end
        end
        psnr_all(noise,:,end) = mean(squeeze(psnr_all(noise,:,1:end-1)),2);
    end
    resTable = array2table(squeeze(psnr_all(noise,:,:)), 'VariableNames',[extractfield(images,'name'), {'Mean_PSNR'}],'RowNames',denoiserNames);
    disp(resTable)
    fprintf('\n');
end


function method = fdenoisers
    method{1} = @(image) fAverage(image); %3.471s
    method{2} = @(image) fMedian(image); %4.017s
    method{3} = @(image) fWiener(image); %3.238s
    method{4} = @(image) fROF(image); %7.353s
    method{5} = @(image) fTV_L1(image); %105.698s
    %method{6} = @(image) fNL_means(image); % slow
    %method{7} = @(image) fWavelet(image);% for some reason worse than average
end

function [output] = fWiener(image)
    window_size = [5 5];
    output=zeros(size(image));
    for layer=1:3
        output(:,:,layer) = wiener2(image(:,:,layer), window_size);
    end
end

function [output] = fWavelet(image)
    wname = 'bior3.5';
    level = 5;
    sorh = 's';
    output = zeros(size(image));
    for layer = 1:3
        [C,S] = wavedec2(image(:,:,layer),level,wname);
        thr = wthrmngr('dw2ddenoLVL','penalhi',C,S,3);
        [output(:,:,layer),cfsDEN,dimCFS] = wdencmp('lvd',C,S,wname,level,thr,sorh);
    end
end

function [output] = fTV_L1(image)
    lambda = 1;
    iterations = 100;
    output=zeros(size(image));
    for layer=1:3
        output(:,:,layer) = TVL1denoise(image(:,:,layer), lambda, iterations);
    end
end

function [output] = fROF(image)
    lambda = 1;
    output=zeros(size(image));
    for layer=1:3
        output(:,:,layer) = ROFdenoise(image(:,:,layer), lambda);
    end
end

function [output] = fNL_means(image)
    ksize = 5; % similarity window
    ssize = 11; % search window
    half_ksize = floor(ksize/2);
    half_ssize = floor(ssize/2);
    output=zeros(size(image));
    for layer=1:3
        noise_estimate = estimate_noise(image(:,:,layer));
        output(:,:,layer) = NLmeansfilter((image(:,:,layer)), half_ssize, half_ksize, noise_estimate);
    end
end

function [output] = fAverage(image)
    window_size = 3;
    output = imfilter(image,fspecial('average',window_size));
end

function [output] = fMedian(image)
    window_size = [3 3];
    output=zeros(size(image));
    for layer=1:3
        output(:,:,layer) = medfilt2(image(:,:,layer),window_size);
    end
end