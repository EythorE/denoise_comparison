% Compare all methods 
disp('Faster methods')
run faster_methods

% Using convolutional networks
run utilities/matconvnet-1.0-beta25/matlab/vl_setupnn.m
disp('CDnCNN_B')
tic
run CDnCNN_B 
toc % 168.621113 seconds.
disp('FDnCNN')
tic
run FDnCNN
toc % 160.310870 seconds.

% Run Non-local means (very slow)
disp('Non-local means')
run NLmeans


fprintf('\n\nRESULTS:\n');
psnrAll = cat(2, psnr_all, psnr_NLmeans, psnr_CDnCNN, psnr_FDnCNN);
psnrAll = round(psnrAll,2);
denoiserNames_all = [denoiserNames, {'NL-means'}, {'CDnCNN'}, {'FDnCNN'}];
for noise = 1:length(addnoise)
    disp('Noise('+string(noise)+'): '+NoiseNames{noise})
    resTable = array2table(squeeze(psnrAll(noise,:,:)), 'VariableNames',[extractfield(images,'name'), {'Mean_PSNR'}],'RowNames',denoiserNames_all);
    disp(resTable)
    fprintf('\n');
end
