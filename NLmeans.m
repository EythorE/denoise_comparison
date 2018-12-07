addpath('testnlm');

% Image locations
folderTest   = 'test_images';
ext          =  {'*.jpg','*.png','*.bmp'};

showResult  = 0;
pauseTime   = 0;

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

psnr_NLmeans = zeros(length(addnoise), 1, length(images)+1);


for noise = 1:length(addnoise)
    randn('seed',0); % for reproducibility
    disp('Noise('+string(noise)+'): '+NoiseNames{noise})
    for i = 1 : length(filepaths)
        image  = imread(fullfile(folderTest,filepaths(i).name));
        [~,imageName,ext] = fileparts(filepaths(i).name);
        imageNames{i} = imageName;
        
        image = im2double(image);
        input = single(addnoise{noise}(image));
        
        output=zeros(size(image));

        % Non-Local Means Filter
        % https://se.mathworks.com/matlabcentral/fileexchange/13176-non-local-means-filter?s_tid=prof_contriblnk
        % noise estimation https://se.mathworks.com/matlabcentral/fileexchange/36941-fast-noise-estimation-in-images?s_tid=FX_rc2_behav
        % paper https://www.iro.umontreal.ca/~mignotte/IFT6150/Articles/Buades-NonLocal.pdf

        ksize = 5; % similarity window
        ssize = 11; % search window
        half_ksize = floor(ksize/2);
        half_ssize = floor(ssize/2);

        for layer=1:3
            noise_estimate = estimate_noise(input(:,:,layer));
            output(:,:,layer) = NLmeansfilter((input(:,:,layer)), half_ssize, half_ksize, noise_estimate);
        end

        %%% calculate PSNR
        [PSNRCur] = Cal_PSNRSSIM(im2uint8(image),im2uint8(output),0,0);

        if showResult
            imshow(cat(2,im2uint8(image),im2uint8(input),im2uint8(output)));
            title([filepaths(i).name,'    ',num2str(PSNRCur,'%2.2f'),'dB'])
            disp([filepaths(i).name,'    ',num2str(PSNRCur,'%2.2f'),'dB'])
            drawnow;
            pause(pauseTime)
        end

        psnr_NLmeans(noise, 1, i) = PSNRCur;
    end
end

psnr_NLmeans(:,:,end) = mean(squeeze(psnr_NLmeans(:,:,1:end-1)),2);
resTable = array2table(squeeze(psnr_NLmeans), 'VariableNames',[imageNames, {'Mean_PSNR'}],'RowNames',NoiseNames);
disp(resTable)