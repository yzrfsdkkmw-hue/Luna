%% CALC1_SYMBOL_FIELD_EMBED_TEST_V1.m
% First experiment:
% Embed human mathematical Calculus-1 symbols into images,
% while measuring whether the original visual field is preserved.
%
% Main equation:
%   H(x,y) = (1-alpha*M(x,y))*C(x,y) + alpha*M(x,y)*S(x,y)
%
% Use:
%   Put this .m file in a clean folder with 3-10 PNG/JPG images.
%   Run:
%       CALC1_SYMBOL_FIELD_EMBED_TEST_V1

clear; clc; close all;

fprintf("CALC1_SYMBOL_FIELD_EMBED_TEST_V1\n");
fprintf("================================\n\n");

outDir = "1111_CALC1_SYMBOL_FIELD_TEST";
if ~exist(outDir, "dir")
    mkdir(outDir);
end

alphaList = [0.18 0.28 0.38];
targetCount = 6;
canvasSize = 900;
symbolScale = 0.16;
rng(7);

symbolBlocks = {
    'f(x)', ...
    'f''(x)=lim_{\Deltax\to0} [f(x+\Deltax)-f(x)]/\Deltax', ...
    '\int_a^b f(x)\,dx', ...
    'T_n(x)=\sum_{k=0}^n f^{(k)}(a)(x-a)^k/k!', ...
    '\frac{dy}{dx}', ...
    '\lim_{x\to a} f(x)=L', ...
    'x,\ f,\ a,\ b,\ c,\ +='
};

imgFiles = [dir("*.png"); dir("*.jpg"); dir("*.jpeg"); dir("*.tif"); dir("*.tiff")];

keep = true(numel(imgFiles),1);
for i = 1:numel(imgFiles)
    n = string(imgFiles(i).name);
    if startsWith(n, "1111_") || startsWith(n, "2222_") || contains(n, "CONTACT", "IgnoreCase", true)
        keep(i) = false;
    end
end
imgFiles = imgFiles(keep);

if isempty(imgFiles)
    error("No input images found. Put PNG/JPG images in the same folder and run again.");
end

[~, order] = sort([imgFiles.bytes], "descend");
imgFiles = imgFiles(order);
imgFiles = imgFiles(1:min(targetCount, numel(imgFiles)));

fprintf("Found %d input images.\n", numel(imgFiles));

resultRows = {};
row = 0;

for idx = 1:numel(imgFiles)
    inName = string(imgFiles(idx).name);
    fprintf("\n[%d/%d] %s\n", idx, numel(imgFiles), inName);

    C0 = imread(inName);
    C = toRGBDouble(C0);
    C = resizeToCanvas(C, canvasSize);

    L = luminanceRGB(C);
    G = gradientMag(L);
    G = safeNorm01(G);

    salience = safeNorm01(0.55*G + 0.45*abs(L - median(L(:))));
    [cy, cx] = chooseEmbeddingCenter(salience, L);

    for aIdx = 1:numel(alphaList)
        alpha = alphaList(aIdx);
        sym = symbolBlocks{mod(idx + aIdx - 2, numel(symbolBlocks)) + 1};

        [S, M] = renderSymbolLayer(size(C,1), size(C,2), cx, cy, sym, symbolScale);
        Scolored = colorizeSymbol(S, C, cx, cy);

        M3 = repmat(M, [1 1 3]);
        H = (1 - alpha*M3).*C + alpha*M3.*Scolored;
        H = min(max(H,0),1);

        Lh = luminanceRGB(H);
        Gh = gradientMag(Lh);

        mseVal = mean((C(:)-H(:)).^2);
        psnrVal = -10*log10(max(mseVal, eps));
        fieldCorr = corrSafe(L(:), Lh(:));
        gradientCorr = corrSafe(G(:), safeNorm01(Gh(:)));
        symbolCoverage = mean(M(:) > 0.05);

        inside = M > 0.15;
        outside = imdilateFallback(inside, 9) & ~inside;
        if any(inside(:)) && any(outside(:))
            readability = abs(mean(Lh(inside)) - mean(Lh(outside))) / (std(Lh(outside)) + 1e-6);
        else
            readability = NaN;
        end

        preservationScore = 0.50*fieldCorr + 0.35*gradientCorr + 0.15*min(psnrVal/40,1);
        testScore = 0.55*preservationScore + 0.45*min(readability/3,1);

        base = sprintf("%02d_alpha_%03d", idx, round(alpha*100));
        imwrite(C, fullfile(outDir, base + "_SOURCE.png"));
        imwrite(H, fullfile(outDir, base + "_EMBEDDED.png"));
        imwrite(M, fullfile(outDir, base + "_SYMBOL_MASK.png"));

        makeContactSheet(C, H, M, salience, sym, alpha, fullfile(outDir, base + "_CONTACT_SHEET.png"));

        row = row + 1;
        resultRows(row,:) = { ...
            char(inName), alpha, char(sym), cx, cy, ...
            mseVal, psnrVal, fieldCorr, gradientCorr, symbolCoverage, readability, preservationScore, testScore ...
        };

        fprintf("  alpha %.2f | preserve %.3f | readable %.3f | score %.3f\n", ...
            alpha, preservationScore, readability, testScore);
    end
end

varNames = { ...
    'image','alpha','symbol','center_x','center_y', ...
    'mse','psnr','field_corr','gradient_corr','symbol_coverage', ...
    'readability_proxy','preservation_score','test_score' ...
};

T = cell2table(resultRows, 'VariableNames', varNames);
writetable(T, fullfile(outDir, "1111_calc1_symbol_embedding_metrics.csv"));

[~, bestIdx] = sort(T.test_score, "descend");
bestIdx = bestIdx(1:min(10,height(T)));
bestT = T(bestIdx,:);
writetable(bestT, fullfile(outDir, "2222_best_trials.csv"));

fid = fopen(fullfile(outDir, "1111_report.txt"), "w");
fprintf(fid, "CALC1_SYMBOL_FIELD_EMBED_TEST_V1\n");
fprintf(fid, "================================\n\n");
fprintf(fid, "Purpose:\n");
fprintf(fid, "First controlled experiment for embedding Calculus-1 human mathematical symbols into visual fields.\n\n");
fprintf(fid, "Equation:\n");
fprintf(fid, "H(x,y) = (1-alpha*M(x,y))*C(x,y) + alpha*M(x,y)*S(x,y)\n\n");
fprintf(fid, "Meaning:\n");
fprintf(fid, "C = original image field\n");
fprintf(fid, "S = rendered mathematical symbol layer\n");
fprintf(fid, "M = symbol mask / allowed embedding region\n");
fprintf(fid, "H = embedded output image\n\n");
fprintf(fid, "Metrics:\n");
fprintf(fid, "field_corr       = luminance preservation\n");
fprintf(fid, "gradient_corr    = structure/edge preservation\n");
fprintf(fid, "readability      = symbol contrast proxy\n");
fprintf(fid, "test_score       = readable + non-destructive embedding score\n\n");
fprintf(fid, "Best trials:\n");
for i = 1:height(bestT)
    fprintf(fid, "%02d | image=%s | alpha=%.2f | score=%.4f | preserve=%.4f | readable=%.4f | symbol=%s\n", ...
        i, string(bestT.image{i}), bestT.alpha(i), bestT.test_score(i), ...
        bestT.preservation_score(i), bestT.readability_proxy(i), string(bestT.symbol{i}));
end
fclose(fid);

zipFile = "1111_CALC1_SYMBOL_FIELD_TEST.zip";
if exist(zipFile, "file")
    delete(zipFile);
end
zip(zipFile, outDir);

fprintf("\nDONE.\n");
fprintf("Output folder: %s\n", outDir);
fprintf("ZIP created:   %s\n", zipFile);

%% ========================= LOCAL FUNCTIONS =========================

function C = toRGBDouble(A)
    A = im2double(A);
    if ndims(A) == 2
        C = repmat(A, [1 1 3]);
    elseif size(A,3) == 4
        alpha = A(:,:,4);
        rgb = A(:,:,1:3);
        bg = zeros(size(rgb));
        C = rgb.*alpha + bg.*(1-alpha);
    else
        C = A(:,:,1:3);
    end
    C = min(max(C,0),1);
end

function C2 = resizeToCanvas(C, canvasSize)
    [h,w,~] = size(C);
    scale = canvasSize / max(h,w);
    newH = max(1, round(h*scale));
    newW = max(1, round(w*scale));
    Csmall = imresize(C, [newH newW]);

    C2 = zeros(canvasSize, canvasSize, 3);
    y0 = floor((canvasSize-newH)/2)+1;
    x0 = floor((canvasSize-newW)/2)+1;
    C2(y0:y0+newH-1, x0:x0+newW-1, :) = Csmall;
end

function L = luminanceRGB(C)
    L = 0.2126*C(:,:,1) + 0.7152*C(:,:,2) + 0.0722*C(:,:,3);
end

function G = gradientMag(L)
    kx = 0.5*[-1 0 1];
    ky = kx';
    Lx = conv2(L, kx, "same");
    Ly = conv2(L, ky, "same");
    G = sqrt(Lx.^2 + Ly.^2);
end

function X = safeNorm01(X)
    X = double(X);
    mn = min(X(:));
    mx = max(X(:));
    if mx > mn
        X = (X-mn)/(mx-mn);
    else
        X = zeros(size(X));
    end
end

function c = corrSafe(a,b)
    a = double(a(:)); b = double(b(:));
    ok = isfinite(a) & isfinite(b);
    a = a(ok); b = b(ok);
    if numel(a) < 3 || std(a) == 0 || std(b) == 0
        c = NaN;
    else
        cc = corrcoef(a,b);
        c = cc(1,2);
    end
end

function [cy,cx] = chooseEmbeddingCenter(salience, L)
    [h,w] = size(salience);
    margin = round(0.18*min(h,w));
    mask = false(h,w);
    mask(margin:h-margin, margin:w-margin) = true;

    s = salience;
    s(~mask) = 0;
    target = abs(s - 0.55);
    target(~mask) = Inf;

    valid = mask & L > 0.05 & L < 0.95;
    target(~valid) = Inf;

    if all(isinf(target(:)))
        cx = round(w/2);
        cy = round(h/2);
        return;
    end

    [~, idx] = min(target(:));
    [cy,cx] = ind2sub(size(target), idx);
end

function [S, M] = renderSymbolLayer(h, w, cx, cy, sym, symbolScale)
    fig = figure("Visible","off", "Color", "black", "Position", [100 100 w h]);
    ax = axes(fig, "Position", [0 0 1 1]);
    axis(ax, [0 w 0 h]);
    axis(ax, "off");
    hold(ax, "on");

    fontSize = max(22, round(symbolScale * min(h,w)));
    text(ax, cx, h-cy, sym, ...
        "Color", "white", ...
        "FontSize", fontSize, ...
        "FontWeight", "bold", ...
        "HorizontalAlignment", "center", ...
        "VerticalAlignment", "middle", ...
        "Interpreter", "tex");

    frame = getframe(fig);
    A = im2double(frame.cdata);
    close(fig);

    if size(A,1) ~= h || size(A,2) ~= w
        A = imresize(A, [h w]);
    end

    Sgray = luminanceRGB(A);
    M = safeNorm01(Sgray);
    M = M.^0.8;
    S = repmat(M, [1 1 3]);
end

function Scolored = colorizeSymbol(S, C, cx, cy)
    [h,w,~] = size(C);
    rr = max(12, round(0.08*min(h,w)));
    y1 = max(1, cy-rr); y2 = min(h, cy+rr);
    x1 = max(1, cx-rr); x2 = min(w, cx+rr);
    patch = C(y1:y2, x1:x2, :);

    localMean = squeeze(mean(mean(patch,1),2));
    if mean(localMean) < 0.45
        col = [1 1 1];
    else
        col = [0.05 0.05 0.05];
    end

    Scolored = zeros(size(C));
    for k = 1:3
        Scolored(:,:,k) = S(:,:,1) * col(k);
    end
end

function B = imdilateFallback(A, radius)
    k = ones(radius, radius);
    B = conv2(double(A), k, "same") > 0;
end

function makeContactSheet(C, H, M, salience, sym, alpha, outPath)
    fig = figure("Visible","off", "Color", "white", "Position", [100 100 1400 820]);

    subplot(2,3,1); imshow(C); title("Original field C(x,y)");
    subplot(2,3,2); imshow(H); title("Embedded H(x,y)");
    subplot(2,3,3); imshow(M,[]); title("Symbol mask M(x,y)");

    subplot(2,3,4); imshow(salience,[]); title("Salience / placement field");
    subplot(2,3,5); imshow(abs(luminanceRGB(H)-luminanceRGB(C)),[]); title("|H-C| change map");

    subplot(2,3,6);
    axis off;
    text(0.02, 0.78, "Equation:", "FontSize", 14, "FontWeight", "bold");
    text(0.02, 0.62, "H=(1-\alpha M)C+\alpha MS", "FontSize", 13);
    text(0.02, 0.42, "Symbol:", "FontSize", 14, "FontWeight", "bold");
    text(0.02, 0.28, sym, "FontSize", 13, "Interpreter", "tex");
    text(0.02, 0.10, sprintf("alpha = %.2f", alpha), "FontSize", 13);

    exportgraphics(fig, outPath, "Resolution", 160);
    close(fig);
end
