%clear;
close all;

addpath('PA1_dataset2_keyboard');
addpath('gco-v3.0\matlab');

M = 720;
N = 1280;
PicNum = 32;

%{
%% Step1. Image Alignment

ImageSet = zeros(PicNum, M, N);

img = imread('0.jpg');
wimage = rgb2gray(img);
ImageSet(1,:,:) = wimage;

for i = 2:32
    
    tmp = wimage;
    img = imread(strcat(int2str(i-1), '.jpg'));
    img = rgb2gray(img);

    [d1, l1]=iat_surf(img);
    [d2, l2]=iat_surf(tmp);
    [map, matches, imgInd, tmpInd]=iat_match_features_mex(d1,d2,.7);
    X1 = l1(imgInd,1:2);
    X2 = l2(tmpInd,1:2);
    %iat_plot_correspondences(img, tmp, X1', X2');

    % With Ransac
    X1h = iat_homogeneous_coords (X1');
    X2h = iat_homogeneous_coords (X2');
    [inliers, ransacWarp]=iat_ransac( X2h, X1h,'affine','tol',.05, 'maxInvalidCount', 10);
    %iat_plot_correspondences(img,tmp,X1(inliers,:)',X2(inliers,:)');

    [M,N] = size(tmp);
    [wimage, support] = iat_inverse_warping(img, ransacWarp, 'affine', 1:N, 1:M);
    %figure; imshow(tmp); figure; imshow(uint8(wimage));
 
    ImageSet(i,:,:) = wimage;
end
%}

%% Step 2 Focus Measure

IndexMap = zeros(M, N);
FM = zeros(PicNum, M, N);
Intensity = zeros(M, N);

% Calculating OTF
OTF = zeros(M,N);
sigma1 = 0.01;
sigma2 = 0.1;
var = 3.5;
for j = 1:M
    for k = 1:N
        kx = j * var*pi / M;
        ky = k * var*pi / N;
        OTF(j,k) = exp(-sigma1*(kx^2+ky^2)) - exp(-sigma2*(kx^2+ky^2));
    end
end

OTFhalf = zeros(M/2, N/2);
for j = 1:M/2
    for k = 1:N/2
        OTFhalf(j,k) = (OTF(2*j-1, 2*k-1) + OTF(2*j, 2*k-1) + OTF(2*j-1, 2*k) + OTF(2*j, 2*k)) / 4;
    end
end

OTF(1:M/2,1:N/2) = rot90(OTFhalf,2);
OTF(M/2+1:M,1:N/2) = flip(OTFhalf,2);
OTF(1:M/2,N/2+1:N) = flip(OTFhalf);
OTF(M/2+1:M,N/2+1:N) = OTFhalf;

OTF = rescale(OTF,0,255);
figure; imshow(uint8(OTF));

for i = 1:32
    img = squeeze(ImageSet(i,:,:));
    %XYZa = (PlaneSpeed(i+1,1:3) - 2*PlaneSpeed(i,1:3) + PlaneSpeed(i-1,1:3)) / (data.Time(i)-data.Time(i-1))^2;
    for j = 2:M-1
       for k = 2:N-1 
          Intensity(j,k) = (img(j+1,k) - 2*img(j,k) + img(j-1,k)) + (img(j,k+1) - 2*img(j,k) + img(j,k-1));
       end
    end
    
    ic = real(ifft2(fft2(Intensity.^2).*OTF));
    
    for j = 1:M
        for k = 1:N
            for l = -1:1
                if (j+l <= M) && (j+l >= 1) && (k+l <= N) && (k+l >= 1)
                    FM(i,j,k) = FM(i,j,k) + ic(j+l,k+l);
                end
            end
        end
    end
end
figure; imshow(uint8(rescale(squeeze(FM(1,:,:)),0,255)));
figure; imshow(uint8(rescale(squeeze(FM(32,:,:)),0,255)));

for i = 1:M
    for j = 1:N
        [Max, idx] = max(FM(:,i,j));
        IndexMap(i,j) = idx;
    end
end

figure; imshow(uint8(rescale(IndexMap,0,255)));
colormap(flipud(jet)); colorbar;
