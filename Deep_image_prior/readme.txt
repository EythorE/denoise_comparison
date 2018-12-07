Not included in paper

Deep Image Prior
Method for image denoising using CNN is proposed by Ulyanov et al. [9], the proposed method
does not require any pre-training on a dataset of example images.
This methods proves to successfully denoise images using no prior information about the noise short of the degraded
image itself and the handcrafted network used for reconstruction. The code is provided by the
authors at https://dmitryulyanov.github.io/deep_image_prior.

Here the network is tested on the real world noisy image used in the paper.
(It is not used do to deep image prior requiring a gpu for reasonable computation time while the other methods where all computed on a cpu in a reasonable time)

