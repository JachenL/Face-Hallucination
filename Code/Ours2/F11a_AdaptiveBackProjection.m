%09/28/12
%Chih-Yuan Yang
%The adaptive kernelmap has to be passed from the caller, or generated by img_lr
function img_bp = F11a_AdaptiveBackProjection(img_lr, img_hr, Gau_sigma, iternum,bReport,kernelmap)
    [h_hr] = size(img_hr,1);
    [h_lr] = size(img_lr,1);
    zooming = h_hr/h_lr;
    
    if nargin < 6
        %generate the kernelmap
        %compute the similarity from low
        coef = 10;
        sqrt_low = IF1_SimilarityEvaluation(img_lr);
        similarity_low = exp(-sqrt_low*coef);
        %model the directional Gaussian kernel
        [h w] = size(similarity_low);
        options = optimset('Display','iter','TolFun',0.001,'TolX',0.1);
        initial_sigmax = 1;
        initial_sigmay = 1;
        initial_theta = 0;
        initial_variable = [initial_sigmax, initial_sigmay, initial_theta];
        
        kernel = zeros(8);      %the number depends on te zooming
        kernelmap = zeros(8,8,h,w);
        for rl=1:h
            for cl=1:w
                %solve the optimization problem for each position
                zvalue16points = similarity_low(rl,cl,:);
                [x fval]= fminsearch(@(x) IF3_OptProblem(x,zvalue16points), initial_variable, options);
                sigma_x = x(1);
                sigma_y = x(2);
                theta = x(3);
                
                a = cos(theta)^2/2/sigma_x^2 + sin(theta)^2/2/sigma_y^2;
                b = -sin(2*theta)/4/sigma_x^2 + sin(2*theta)/4/sigma_y^2 ;
                c = sin(theta)^2/2/sigma_x^2 + cos(theta)^2/2/sigma_y^2;
    
                %create the kernel map by parameter a b c
                for s = 1:12
                    yi = s-6.5;
                    for t = 1:12
                        xi = t-6.5;
                        kernel(s,t) = exp(-(a*xi^2 + 2*b*xi*yi + c*yi^2));
                    end
                end
                sumvalue = sum(kernel(:));
                kernel_normal = kernel / sumvalue;
                kernelmap(:,:,rl,cl) = kernel_normal;
            end
        end
    end
    for i=1:iternum
        img_lr_gen = F19_GenerateLRImage_BlurSubSample(img_hr,zooming,Gau_sigma);
        diff_lr = img_lr - img_lr_gen;
        term_diff_lr_SSD = sum(sum(diff_lr.^2));
        %here, change the kernel pixel by pixel
        diff_hr = Upsample(diff_lr,zooming, kernelmap);
%        diff_hr = imresize(diff_lr,zooming,'bilinear');
        img_hr = img_hr + diff_hr;
        img_lr_new = F19_GenerateLRImage_BlurSubSample(img_hr,zooming,Gau_sigma);
        diff_lr_new = img_lr - img_lr_new;       
        term_diff_lr_SSD_afteronebackprojection = sum(sum(diff_lr_new.^2));
        if bReport
            fprintf('backproject iteration=%d, term_before=%0.1f, term_after=%0.1f\n', ...
            i,term_diff_lr_SSD,term_diff_lr_SSD_afteronebackprojection);        
        end        
    end
    img_bp = img_hr;
end
%model kernelmap as Gaussian?
function diff_hr = Upsample(diff_lr,zooming, kernelmap)
    [h w] = size(diff_lr);
    for r=1:h
        for c=1:w
            
        end
    end
end
function SqrtData = IF1_SimilarityEvaluation(Img_in)
    [h w] = size(Img_in);
    SqrtData = zeros(h,w,16);
    
    f3x3 = ones(3);
    for i = 1:16
        [DiffOp N] = IF2_RetGradientKernel16(i);        %this may be better if there are 32 samples
        if N == 1
            Diff = imfilter(Img_in,DiffOp{1},'symmetric');
        else
            Diff1 = imfilter(Img_in,DiffOp{1},'symmetric');
            Diff2 = imfilter(Img_in,DiffOp{2},'symmetric');
            Diff = (Diff1+Diff2)/2;
        end
        Sqr = Diff.^2;
        Sum = imfilter(Sqr,f3x3,'replicate');
        Mean = Sum/9;
        SqrtData(:,:,i) = sqrt(Mean);
    end
end
function [DiffOp N] = IF2_RetGradientKernel16(dir)
    DiffOp = cell(2,1);
    f{1} = [0  0 0;
            0 -1 1;
            0  0 0];
    f{2} = [0  0 1;
            0 -1 0;
            0  0 0];
    f{3} = [0  1 0;
            0 -1 0;
            0  0 0];
    f{4} = [1  0 0;
            0 -1 0;
            0  0 0];
    f{5} = [0  0 0;
            1 -1 0;
            0  0 0];
    f{6} = [0  0 0;
            0 -1 0;
            1  0 0];
    f{7} = [0  0 0;
            0 -1 0;
            0  1 0];
    f{8} = [0  0 0;
            0 -1 0;
            0  0 1];
    switch dir
        case 1
            N = 1;
            DiffOp{1} = f{1};
            DiffOp{2} = [];
        case 2
            N = 2;
            DiffOp{1} = f{1};
            DiffOp{2} = f{2};
        case 3
            N = 1;            
            DiffOp{1} = f{2};
            DiffOp{2} = [];
        case 4
            N = 2;
            DiffOp{1} = f{2};
            DiffOp{2} = f{3};
        case 5
            N = 1;
            DiffOp{1} = f{3};
            DiffOp{2} = [];
        case 6
            N = 2;
            DiffOp{1} = f{3};
            DiffOp{2} = f{4};
        case 7
            N = 1;
            DiffOp{1} = f{4};
            DiffOp{2} = [];
        case 8
            N = 2;
            DiffOp{1} = f{4};
            DiffOp{2} = f{5};
        case 9
            N = 1;
            DiffOp{1} = f{5};
            DiffOp{2} = [];
        case 10
            N = 2;
            DiffOp{1} = f{5};
            DiffOp{2} = f{6};
        case 11
            DiffOp{1} = f{6};
            DiffOp{2} = [];
            N = 1;
        case 12
            N = 2;
            DiffOp{1} = f{6};
            DiffOp{2} = f{7};
        case 13
            N = 1;
            DiffOp{1} = f{7};
            DiffOp{2} = [];
        case 14
            N = 2;
            DiffOp{1} = f{7};
            DiffOp{2} = f{8};
        case 15
            DiffOp{1} = f{8};
            DiffOp{2} = [];
            N = 1;
        case 16
            N = 2;
            DiffOp{1} = f{8};
            DiffOp{2} = f{1};
    end
end
function value = IF3_OptProblem(x,zvalue16points)
    sigma_x = x(1);
    sigma_y = x(2);
    theta = x(3);
    a = cos(theta)^2/2/sigma_x^2 + sin(theta)^2/2/sigma_y^2;
    b = -sin(2*theta)/4/sigma_x^2 + sin(2*theta)/4/sigma_y^2 ;
    c = sin(theta)^2/2/sigma_x^2 + cos(theta)^2/2/sigma_y^2;
    
    value = 0;
    for i=1:16
        [xi yi] = IF4_GetXiYi(i);
        diff = zvalue16points(i) - exp(- (a*xi^2 + 2*b*xi*yi + c*yi^2));
        value = value + diff^2;
    end
end
function [xi yi] = IF4_GetXiYi(i)
    switch i
        case 1
            xi = 1;
            yi = 0;
        case 2
            xi = 1;
            yi = -0.5;
        case 3
            xi = 1;
            yi = -1;
        case 4
            xi = 0.5;
            yi = -1;
        case 5
            xi = 0;
            yi = -1;
        case 6
            xi = -0.5;
            yi = -1;
        case 7
            xi = -1;
            yi = -1;
        case 8
            xi = -1;
            yi = -0.5;
        case 9
            xi = -1;
            yi = 0;
        case 10
            xi = -1;
            yi = 0.5;
        case 11
            xi = -1;
            yi = 1;
        case 12
            xi = -0.5;
            yi = 1;
        case 13
            xi = 0;
            yi = 1;
        case 14
            xi = 0.5;
            yi = 1;
        case 15
            xi = 1;
            yi = 1;
        case 16
            xi = 1;
            yi = 0.5;
    end
end