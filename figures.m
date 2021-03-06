global sigmas; % for fdncnn
global netDnCNN;
global netFDnCNN;
load('model/GD_Color_Blind.mat');
netDnCNN = vl_simplenn_tidy(net);
load('model/FDnCNN_color.mat'); 
netFDnCNN = vl_simplenn_tidy(net);


% Image locations
folderTest   = 'test_images';
imageNames = {'airplane.png', 'monarch.png'};

% output folder
folderResult= 'results';
if ~isdir(folderResult)
    mkdir(folderResult)
end


showResult = true;
pauseTime = 5;


% Load all images
filepaths = [];
for i = 1 : length(imageNames)
    filepaths = cat(1,filepaths,dir(fullfile(folderTest, imageNames{i})));
end

images = [];
clear image
for i = 1 : length(filepaths)
    [~,imageName,ext] = fileparts(filepaths(i).name);
    image.name = imageName;
    image.data = im2double(imread(fullfile(folderTest,filepaths(i).name)));
    images = cat(1, images, image);
end


addnoise = {};

%addnoise{end+1}.method = @(image) imnoise(image,'gaussian',0, (25/255)^2);
%addnoise{end}.name = 'Gaussian25';

addnoise{end+1}.method = @(image) im2double(imnoise(im2uint8(image),'poisson'));
addnoise{end}.name = 'Poisson';

%addnoise{end+1}.method = @(image) imnoise(image,'salt & pepper', 0.05);
%addnoise{end}.name = 'SandP';




% all the denoisers
denoisers = fdenoisers();


for im = 1 : length(images)
    fprintf('\n\n')
    disp(['IMAGE: ', images(im).name])
    for no = 1 : length(addnoise)
        randn('seed',0); % for reproducibility
        input = addnoise{no}.method(images(im).data);
        PSNR = psnr(images(im).data, input);
        fprintf('\n')
        disp(['NOISE: ',addnoise{no}.name, ', PSNR: ',sprintf(' %2.2fdB', PSNR)]);
        imwrite(im2uint8(input), fullfile(folderResult, [images(im).name,'_', addnoise{no}.name,'.png']));
        
        if showResult
           shower =  im2uint8(input);
           showMethods = sprintf('-noisy %2.2fdB', PSNR);
        end
        
        for de = 1 : length(denoisers)
            
            output = denoisers{de}.method(input);
            PSNR = psnr(images(im).data, output);
            disp([denoisers{de}.name, ', PSNR: ',sprintf(' %2.2fdB', PSNR)])

            imwrite(im2uint8(output), fullfile(folderResult, [images(im).name,'_',addnoise{no}.name,'_',denoisers{de}.name,'.png'] ));

            if showResult
                shower = cat(2,shower,im2uint8(output));
                showMethods = strcat(showMethods,'-',denoisers{de}.name,sprintf(' %2.2fdB', PSNR),'-');
            end
            
        end
        
        if showResult
            figure;
            imshow(shower);
            title([images(im).name,', ',addnoise{no}.name,', ',showMethods])
            drawnow;
            pause(pauseTime)
        end
        
    end
end


% Denoising methods vvv
function denoisers = fdenoisers
    denoisers = {};
    
    %denoisers{end+1}.method = @(image) fAverage(image);
    denoisers{end+1}.method = @(image) fMedian(image);
    denoisers{end+1}.method = @(image) fWiener(image);
    %denoisers{end+1}.method = @(image) fROF(image);
    denoisers{end+1}.method = @(image) fTV_L1(image);
    %denoisers{end+1}.method = @(image) fNL_means(image); % slow AF
    denoisers{end+1}.method = @(image) fDnCNN(image);
    %denoisers{end+1}.method = @(image) fFDnCNN(image);
    
    for de = 1:length(denoisers)
        denoisers{de}.name = strtrim(evalc('disp(denoisers{de}.method)'));
        denoisers{de}.name = erase(denoisers{de}.name,'@(image)f');
        denoisers{de}.name = erase(denoisers{de}.name,'(image)');
    end
end

function [output] = fDnCNN(image)
    global netDnCNN;
    res     = vl_simplenn(netDnCNN,single(image),[],[],'conserveMemory',true,'mode','test');
    output  = im2double(image - res(end).x);
end

function [output] = fFDnCNN(image)
    global netFDnCNN;
    global sigmas;
    sigmas = (estimate_noise(image(:,:,1))+estimate_noise(image(:,:,2))+estimate_noise(image(:,:,3)))/3;
    res     = vl_simplenn(netFDnCNN,single(image),[],[],'conserveMemory',true,'mode','test');
    output  = im2double(res(end).x);
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