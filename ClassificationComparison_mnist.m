numExps = 1;
for dd = 1:numExps
    %% setup and load data
    dd
    load(strcat(dataset, '.mat'));
    [n, p] = size(X);
    [~, q] = size(Y);
    %ks = 2:min(10, p-1);
    ks = 2;
    
    %holdout an independent test set
    proportion = 0.2;
    nhold = floor(n*proportion); % 20%
    idxhold = ~crossvalind('HoldOut',Y,proportion,'classes', unique(Y), 'min', 2);
    Xhold = X(idxhold, :);
    X = X(~idxhold, :);
    Yhold = Y(idxhold, :);
    Y = Y(~idxhold, :);
    n = n - nhold; %this is our new n
    
    % create same splits to use every time and center
    kfold = 10;
    cvidx = crossvalind('kfold',Y,kfold,'classes', unique(Y), 'min', 2);
    for l = 1:kfold
        Xtrain = X(cvidx~=l, :); %lth training set
        Ytrain = Y(cvidx~=l, :);
        Xtest = X(cvidx==l, :); %lth testing set
        Ytest = Y(cvidx==l, :);
        [Xtrain,Xtest,Ytrain,Ytest] = center_data(Xtrain,Xtest,Ytrain,Ytest,'classification');
        Xtrains{l} = Xtrain; %lth centered training set
        Ytrains{l} = Ytrain;
        Xtests{l} = Xtest; %lth centered testing set
        Ytests{l} = Ytest;
    end
    
    % store the independent test set, and corresponding training set (non holdout data)
    % at the end of the train  and test cell arrays for convenience of
    % implementation
    [Xtrain,Xtest,Ytrain,Ytest] = center_data(X,Xhold,Y,Yhold,'classification');
    Xtrains{kfold+1} = Xtrain; %lth centered training set
    Ytrains{kfold+1} = Ytrain;
    Xtests{kfold+1} = Xtest; %lth centered testing set
    Ytests{kfold+1} = Ytest;
    % this way we will end up evaluating the independent set for every possible
    % model, which will take longer, but this is just easier. At the end, we
    % will choose the best model by looking only at the tests corresponding to
    % l = 1:kfold, and l=kfold+1 will give us the independent test error
    % corresponding to that model
    
    % p = gcp('nocreate'); % If no pool, do not create new one.
    % if isempty(p)
    %     parpool(6)
    % end
    %delete(gcp('nocreate'))
    for t = 1:length(ks) %dimensionality of reduced data
        k = ks(t)
        
        %% PCA
        for l = 1:kfold+1
            test_num = l;
            % get lth fold
            Xtrain = Xtrains{l};
            Ytrain = Ytrains{l};
            [ntrain, ~] = size(Ytrain);
            Xtest = Xtests{l};
            Ytest = Ytests{l};
            [ntest, ~] = size(Ytest);
            
            tic
            [Lpca, Zpca] = pca(Xtrain, 'NumComponents', k);
            Zpcas{l,t} = Zpca;
            Lpca = Lpca';
            % compute embedding for test data
            pcaXtest = Xtest*Lpca';
            pcaXtests{l,t} = pcaXtest;
            PCAtimes(l,t) = toc;
            % compute error
            B = mnrfit(Xtrain*Lpca',Ytrain, 'Model', 'nominal', 'Interactions', 'on');
            [~, Yhat] = max(mnrval(B,pcaXtest),[], 2);
            [~,pcaYtrain] = max(mnrval(B,Zpca),[], 2);
            PCArates(l,t) = 1 - sum(Yhat == Ytest) / ntest;
            PCArates_train(l,t) = 1 - sum(pcaYtrain == Ytrain) / ntrain;
            PCAvar(l,t) = norm(Xtest*Lpca'*Lpca, 'fro') / norm(Xtest, 'fro');
            PCAvar_train(l,t) = norm(Xtrain*Lpca'*Lpca, 'fro') / norm(Xtrain, 'fro');
        end
        
%         %% LRPCA
%         
%         Lambdas = [linspace(1, 0.5, 11), linspace(0.4, 0, 5)];
%         for l = 1:kfold+1
%             test_num = l
%             % get lth fold
%             Xtrain = Xtrains{l};
%             Ytrain = Ytrains{l};
%             [ntrain, ~] = size(Ytrain);
%             Xtest = Xtests{l};
%             Ytest = Ytests{l};
%             [ntest, ~] = size(Ytest);
%             
%             %solve
%             for ii = 1:length(Lambdas)
%                 Lambda = Lambdas(ii);
%                 
%                 if ii == 1
%                     [Zlspca, Llspca, B] = lrpca(Xtrain, Ytrain, Lambda, k, 0);    
%                 else
%                     [Zlspca, Llspca, B] = lrpca(Xtrain, Ytrain, Lambda, k, Llspca');
%                 end
%                 Llspca = Llspca';
%                 Ls{l,t,ii} = Llspca;
%                 %predict
%                 LSPCAXtest = Xtest*Llspca';
%                 LSPCAXtrain = Xtrain*Llspca';
%                 [~, LSPCAYtest] = max(LSPCAXtest*B(2:end,:) + B(1,:), [], 2);
%                 [~, LSPCAYtrain] = max(Xtrain*Llspca'*B(2:end,:) + B(1,:), [], 2);
%                 lspca_mbd_test{l,t,ii} =LSPCAXtest;
%                 lspca_mbd_train{l,t,ii} = Zlspca;
%                 % compute error
%                 err = 1 - sum(Ytest == LSPCAYtest) / ntest;
%                 train_err = 1 - sum(Ytrain == LSPCAYtrain) / ntrain;
%                 LSPCArates(l,t, ii) = err ;
%                 LSPCArates_train(l,t, ii) = train_err;
%                 LSPCAvar(l,t, ii) = norm(LSPCAXtest, 'fro') / norm(Xtest, 'fro');
%                 LSPCAvar_train(l,t, ii) = norm(Zlspca, 'fro') / norm(Xtrain, 'fro');
%             end
%         end
        
        %% LRPCA (MLE)
        for l = 1:kfold+1
            test_num = l
            % get lth fold
            Xtrain = Xtrains{l};
            Ytrain = Ytrains{l};
            [ntrain, ~] = size(Ytrain);
            Xtest = Xtests{l};
            Ytest = Ytests{l};
            [ntest, ~] = size(Ytest);
            
            [Zlspca, Llspca, B] = lrpca_MLE(Xtrain, Ytrain, k, 0);
            Llspca = Llspca';
            mle_Ls{l,t} = Llspca;
            %predict
            LSPCAXtest = Xtest*Llspca';
            LSPCAXtrain = Xtrain*Llspca';
            [~, LSPCAYtest] = max(LSPCAXtest*B(2:end,:) + B(1,:), [], 2);
            [~, LSPCAYtrain] = max(Xtrain*Llspca'*B(2:end,:) + B(1,:), [], 2);
            mle_lspca_mbd_test{l,t} =LSPCAXtest;
            mle_lspca_mbd_train{l,t} = Zlspca;
            % compute error
            err = 1 - sum(Ytest == LSPCAYtest) / ntest;
            train_err = 1 - sum(Ytrain == LSPCAYtrain) / ntrain;
            mle_LSPCArates(l,t) = err ;
            mle_LSPCArates_train(l,t) = train_err;
            mle_LSPCAvar(l,t) = norm(LSPCAXtest, 'fro') / norm(Xtest, 'fro');
            mle_LSPCAvar_train(l,t) = norm(Zlspca, 'fro') / norm(Xtrain, 'fro');
            
        end
        
        
%         %% kLRPCA
%         Lambdas = [linspace(1, 0.5, 11), linspace(0.4, 0, 5)];
%         for l = 1:kfold+1
%             test_num = l
%             % get lth fold
%             Xtrain = Xtrains{l};
%             Ytrain = Ytrains{l};
%             [ntrain, ~] = size(Ytrain);
%             Xtest = Xtests{l};
%             Ytest = Ytests{l};
%             [ntest, ~] = size(Ytest);
%             
%             for kk = 1:length(sigmas)
%                 sigma = sigmas(kk);
%                 for ii = 1:length(Lambdas)
%                     Lambda = Lambdas(ii);
%                     if ii == 1
%                         [ Zklspca, Lorth, B, Klspca] = klrpca(Xtrain, Ytrain, Lambda, sigma, k, 0, 0);
%                     else
%                         [ Zklspca, Lorth, B, Klspca] = klrpca(Xtrain, Ytrain, Lambda, sigma, k, Lorth, Klspca);
%                     end
%                     %Lorth = Lorth';
%                     embedFunc = @(data) klspca_embed(data, Xtrain, Lorth, sigma);
%                     kLs{l,t,ii,kk} = Lorth;
%                     kLSPCAXtest = embedFunc(Xtest);
%                     klspca_mbd_test{l,t,ii,kk} = kLSPCAXtest;
%                     kLSPCAXtrain = Zklspca;
%                     klspca_mbd_train{l,t,ii,kk} = Zklspca;
%                     [~, kLSPCAYtest] = max(kLSPCAXtest*B(2:end,:) + B(1,:), [], 2);
%                     [~, kLSPCAYtrain] = max(Zklspca*B(2:end,:) + B(1,:), [], 2);
%                     err = 1 - sum(Ytest == kLSPCAYtest)/ntest;
%                     train_err = 1 - sum(Ytrain == kLSPCAYtrain)/ntrain;
%                     kLSPCArates(l,t,ii,kk) = err ;
%                     kLSPCArates_train(l,t,ii,kk) = train_err;
%                     kLSPCAvar(l,t,ii,kk) = norm(kLSPCAXtest, 'fro') / norm(gaussian_kernel(Xtest,Xtrain,sigma), 'fro');
%                     kLSPCAvar_train(l,t,ii,kk) = norm(Zklspca, 'fro') / norm(Klspca, 'fro');
%                 end
%                 
%             end
%         end
        
%         %% kLRPCA (MLE)
%         for l = 1:kfold+1
%             test_num = l;
%             % get lth fold
%             Xtrain = Xtrains{l};
%             Ytrain = Ytrains{l};
%             [ntrain, ~] = size(Ytrain);
%             Xtest = Xtests{l};
%             Ytest = Ytests{l};
%             [ntest, ~] = size(Ytest);
%             
%             for kk = 1:length(sigmas)
%                 sigma = sigmas(kk);
%                 [ Zklspca, Lorth, B, Klspca] = klrpca_MLE(Xtrain, Ytrain, sigma, k, 0, 0);
%                 embedFunc = @(data) klspca_embed(data, Xtrain, Lorth, sigma);
%                 mle_kLs{l,t,kk} = Lorth;
%                 kLSPCAXtest = embedFunc(Xtest);
%                 mle_klspca_mbd_test{l,t,kk} = kLSPCAXtest;
%                 kLSPCAXtrain = Zklspca;
%                 mle_klspca_mbd_train{l,t,kk} = Zklspca;
%                 [~, kLSPCAYtest] = max(kLSPCAXtest*B(2:end,:) + B(1,:), [], 2);
%                 [~, kLSPCAYtrain] = max(Zklspca*B(2:end,:) + B(1,:), [], 2);
%                 err = 1 - sum(Ytest == kLSPCAYtest)/ntest;
%                 train_err = 1 - sum(Ytrain == kLSPCAYtrain)/ntrain;
%                 mle_kLSPCArates(l,t,kk) = err ;
%                 mle_kLSPCArates_train(l,t,kk) = train_err;
%                 mle_kLSPCAvar(l,t,kk) = norm(kLSPCAXtest, 'fro') / norm(gaussian_kernel(Xtest,Xtrain,sigma), 'fro');
%                 mle_kLSPCAvar_train(l,t,kk) = norm(Zklspca, 'fro') / norm(Klspca, 'fro');
%             end
%         end
        
        
%         %% KPCA
%         for l = 1:kfold+1
%             test_num = l;
%             % get lth fold
%             Xtrain = Xtrains{l};
%             Ytrain = Ytrains{l};
%             [ntrain, ~] = size(Ytrain);
%             Xtest = Xtests{l};
%             Ytest = Ytests{l};
%             [ntest, ~] = size(Ytest);
%             for jj = 1:length(sigmas)
%                 sigma = sigmas(jj);
%                 K = gaussian_kernel(Xtrain, Xtrain, sigma);
%                 Ktest = gaussian_kernel(Xtest, Xtrain, sigma);
%                 tic
%                 [Lkpca, Zkpca] = pca(K, 'NumComponents', k);
%                 kPCAtimes(l,t,jj) = toc;
%                 Zkpcas{l,t,jj} = Zkpca;
%                 Lkpca = Lkpca';
%                 % compute embedding for test data
%                 kpcaXtest = Ktest*Lkpca';
%                 kpcaXtests{l,t,jj} = kpcaXtest;
%                 % compute error
%                 B = mnrfit(Zkpca,Ytrain, 'Model', 'nominal', 'Interactions', 'on');
%                 [~, Yhat] = max(mnrval(B,kpcaXtest),[], 2);
%                 [~,kpcaYtrain] = max(mnrval(B,Zkpca),[], 2);
%                 kPCArates(l,t,jj) = 1 - sum(Yhat == Ytest) / ntest;
%                 kPCArates_train(l,t,jj) = 1 - sum(kpcaYtrain == Ytrain) / ntrain;
%                 kPCAvar(l,t,jj) = norm(kpcaXtest, 'fro') / norm(Ktest, 'fro');
%                 kPCAvar_train(l,t,jj) = norm(Zkpca, 'fro') / norm(K, 'fro');
%             end
%         end
        
        %% ISPCA
        %find basis
        for l = 1:kfold+1
            test_num = l;
            % get lth fold
            Xtrain = Xtrains{l};
            Ytrain = Ytrains{l};
            [ntrain, ~] = size(Ytrain);
            Xtest = Xtests{l};
            Ytest = Ytests{l};
            [ntest, ~] = size(Ytest);
            tic
            [Zispca, Lispca, B] = ISPCA(Xtrain,Ytrain,k);
            Zispcas{l,t} = Zispca;
            ISPCAtimes(l,t) = toc;
            % predict
            ISPCAXtest = Xtest*Lispca';
            ISPCAXtests{l,t} = ISPCAXtest;
            B = mnrfit(Xtrain*Lispca',Ytrain, 'Model', 'nominal', 'Interactions', 'on');
            [~,Yhat] = max(mnrval(B,ISPCAXtest),[], 2);
            [~, ISPCAYtrain] = max(mnrval(B,Zispca),[], 2);
            % compute error
            ISPCArates(l,t) = 1 - sum(Yhat == Ytest) / ntest;
            ISPCArates_train(l,t) = 1 - sum(ISPCAYtrain == Ytrain) / ntrain;
            ISPCAvar(l,t) = norm(Xtest*Lispca', 'fro') / norm(Xtest, 'fro');
            ISPCAvar_train(l,t) = norm(Xtrain*Lispca', 'fro') / norm(Xtrain, 'fro');
            ISPCAtimes(l,t) = toc;
        end
        
%         %% SPPCA
%         % solve
%         for l = 1:kfold+1
%             test_num = l;
%             % get lth fold
%             Xtrain = Xtrains{l};
%             Ytrain = Ytrains{l};
%             [ntrain, ~] = size(Ytrain);
%             Xtest = Xtests{l};
%             Ytest = Ytests{l};
%             [ntest, ~] = size(Ytest);
%             tic
%             Zsppcasin = {};
%             Lsppcasin = {};
%             SPPCAXtestin = {};
%             SPPCAYtestin = {};
%             SPPCAYtrainin = {};
%             sppca_err = [];
%             for count = 1%:10 %do 10 initializations and take the best b/c ends up in bad local minima a lot
%                 Ypm1 = Ytrain; Ypm1(Ypm1 == 2) = -1;
% %               [Zsppca, Lsppca, ~, W_x, W_y, var_x, var_y] = SPPCA_cf(Xtrain,Ypm1,k);
%                 [Zsppca, Lsppca, ~, W_x, W_y, var_x, var_y] = SPPCA(Xtrain,Ypm1,k,1e-6);
%                 Lsppca = Lsppca';
%                 Zsppcasin{count} = Zsppca;
%                 Lsppcasin{count} = Lsppca;
%                 SPPCAXtestin{count} = Xtest*Lsppca;
%                 B = mnrfit(Zsppca,Ytrain, 'Model', 'nominal', 'Interactions', 'on');
%                 [~,SPPCAYtestin{count}] = max(mnrval(B,SPPCAXtestin{count}),[], 2);
%                 [~,SPPCAYtrainin{count}] = max(mnrval(B,Zsppca),[], 2);
%                 sppca_err(count) =  (1 - sum(SPPCAYtrainin{count}==Ytrain)) / ntest;
%             end
%             [~, loc] = min(sppca_err);
%             Zsppca = Zsppcasin{loc};
%             Zsppcas{l,t} = Zsppca;
%             % Predict
%             SPPCAXtest = SPPCAXtestin{loc};
%             SPPCAXtests{l,t} = SPPCAXtest;
%             SPPCAYtest = SPPCAYtestin{loc};
%             SPPCAYtrain = SPPCAYtrainin{loc};
%             % compute error
%             B = mnrfit(Zsppca,Ytrain, 'Model', 'nominal', 'Interactions', 'on');
%             [~,SPPCAYtrain] = max(mnrval(B,Zsppca),[], 2);
%             [~,Yhat] = max(mnrval(B,SPPCAXtest),[], 2);
%             SPPCArates(l,t) = 1 - sum(Yhat == Ytest) / ntest;
%             SPPCArates_train(l,t) = 1 - sum(SPPCAYtrain == Ytrain) / ntrain;
%             Lsppca_orth = orth(Lsppca); %normalize latent directions for variation explained comparison
%             SPPCAvar(l,t) = norm(Xtest*Lsppca_orth, 'fro') / norm(Xtest, 'fro');
%             SPPCAvar_train(l,t) = norm(Xtrain*Lsppca_orth, 'fro') / norm(Xtrain, 'fro');
%             
%             SPPCAtimes(l,t) = toc;
%         end
        
        %% Barshan
        for l = 1:kfold+1
            test_num = l;
            % get lth fold
            Xtrain = Xtrains{l};
            Ytrain = Ytrains{l};
            [ntrain, ~] = size(Ytrain);
            Xtest = Xtests{l};
            Ytest = Ytests{l};
            [ntest, ~] = size(Ytest);
            tic
            barshparam = struct;
            %         if n>p
            %learn basis
            [Zspca Lspca] = SPCA(Xtrain', Ytrain', k);
            spcaXtest = Xtest*Lspca';
            % predict
            B = mnrfit(Zspca,Ytrain, 'Model', 'nominal', 'Interactions', 'on');
            [~,Yhat] = max(mnrval(B,spcaXtest),[], 2);
            %compute error
            SPCArates(l,t) = 1 - sum(Yhat == Ytest) / ntest;
            [~,SPCAYtrain] = max(mnrval(B,Zspca),[], 2);
            SPCArates_train(l,t) = 1 - sum(SPCAYtrain == Ytrain) / ntrain;
            SPCAvar(l,t) = norm(Xtest*Lspca', 'fro') / norm(Xtest, 'fro');
            SPCAvar_train(l,t) = norm(Xtrain*Lspca', 'fro') / norm(Xtrain, 'fro');
            %         else
            %             % kernel version faster in this regime
            %             barshparam.ktype_y = 'delta';
            %             barshparam.kparam_y = 1;
            %             barshparam.ktype_x = 'linear';
            %             barshparam.kparam_x = 1;
            %             [Zspca Lspca] = KSPCA(Xtrain', Ytrain', k, barshparam);
            %             Zspca = Zspca';
            %             %do prediction in learned basis
            %             betaSPCA = Zspca \ Ytrain;
            %             Ktrain = Xtrain*Xtrain';
            %             Ktest = Xtest*Xtrain';
            %             spcaXtest = Ktest*Lspca;
            %             spca_mbd_test{l,t} = spcaXtest;
            %             spca_mbd_train{l,t} = Zspca;
            %             B = mnrfit(Zspca,Ytrain, 'Model', 'nominal', 'Interactions', 'on');
            %             [~,Yhat] = max(mnrval(B,spcaXtest),[], 2);
            %             [~,SPCAYtrain] = max(mnrval(B,Zspca),[], 2);
            %             % compute error
            %             SPCArates(l,t) = 1 - sum(Yhat == Ytest) / ntest;
            %             SPCArates_train(l,t) = 1 - sum(SPCAYtrain == Ytrain) / ntrain;
            %             SPCAvar(l,t) = norm(spcaXtest, 'fro') / norm(Ktest, 'fro');
            %             SPCAvar_train(l,t) = norm(Zspca, 'fro') / norm(Ktrain, 'fro');
            %         end
            spcaXtests{l,t} = spcaXtest;
            Zspcas{l,t} = Zspca;
            Barshantimes(l,t) = toc;
        end
            
%             %% Perform Barshan's KSPCA based 2D embedding
%             %learn basis
%             for l = 1:kfold+1
%                 test_num = l;
%                 % get lth fold
%                 Xtrain = Xtrains{l};
%                 Ytrain = Ytrains{l};
%                 [ntrain, ~] = size(Ytrain);
%                 Xtest = Xtests{l};
%                 Ytest = Ytests{l};
%                 [ntest, ~] = size(Ytest);
%                 
%                 for jj = 1:length(sigmas)
%                     sigma = sigmas(jj);
%                     
%                     tic
%                     %calc with best param on full training set
%                     barshparam.ktype_y = 'delta';
%                     barshparam.kparam_y = 1;
%                     barshparam.ktype_x = 'rbf';
%                     barshparam.kparam_x = sigma;
%                     [Zkspca Lkspca] = KSPCA(Xtrain', Ytrain', k, barshparam);
%                     Zkspca = Zkspca';
%                     %do prediction in learned basis
%                     betakSPCA = Zkspca \ Ytrain;
%                     Ktrain = gaussian_kernel(Xtrain, Xtrain, sigma);
%                     Ktest = gaussian_kernel(Xtest, Xtrain, sigma);
%                     kspcaXtest = Ktest*Lkspca;
%                     kspca_mbd_test{l,t,jj} = kspcaXtest;
%                     kspca_mbd_train{l,t,jj} = Zkspca;
%                     B = mnrfit(Zkspca,Ytrain, 'Model', 'nominal', 'Interactions', 'on');
%                     [~,Yhat] = max(mnrval(B,kspcaXtest),[], 2);
%                     [~,kSPCAYtrain] = max(mnrval(B,Zkspca),[], 2);
%                     %compute error
%                     kSPCArates(l,t,jj) = 1 - sum(Yhat == Ytest) / ntest;
%                     kSPCArates_train(l,t,jj) = 1 - sum(kSPCAYtrain == Ytrain) / ntrain;
%                     kSPCAvar(l,t,jj) = norm(kspcaXtest, 'fro') / norm(Ktest, 'fro');
%                     kSPCAvar_train(l,t,jj) = norm(Zkspca, 'fro') / norm(Ktrain, 'fro');
%                     kBarshantimes(l,t,jj) = toc;
%                     kspcaXtests{l,t,jj} = kspcaXtest;
%                     Zkspcas{l,t,jj} = Zkspca;
%                 end
%             end
            
            %% LDA
            % solve
            for l = 1:kfold+1
                test_num = l;
                % get lth fold
                Xtrain = Xtrains{l};
                Ytrain = Ytrains{l};
                [ntrain, ~] = size(Ytrain);
                Xtest = Xtests{l};
                Ytest = Ytests{l};
                [ntest, ~] = size(Ytest);
                Mdl = fitcdiscr(Xtrain,Ytrain, 'DiscrimType', 'pseudolinear');
                LDAYtest = predict(Mdl,Xtest);
                % Predict
                LDAYtrain = predict(Mdl,Xtrain);
                %compute error
                LDArates(l,t) = 1 - sum(LDAYtest == Ytest) / ntest;
                LDArates_train(l,t) = 1 - sum(LDAYtrain == Ytrain) / ntrain;
                lin = Mdl.Coeffs(1,2).Linear / norm([Mdl.Coeffs(1,2).Const; Mdl.Coeffs(1,2).Linear]);
                const = Mdl.Coeffs(1,2).Const / norm([Mdl.Coeffs(1,2).Const; Mdl.Coeffs(1,2).Linear]);
                Zlda = Xtrain*lin + const;
                LDAXtest = Xtest*lin + const;
                LDAvar(l,t) = norm(LDAXtest, 'fro') / norm(Xtest, 'fro');
                LDAvar_train(l,t) = norm(Zlda, 'fro') / norm(Xtrain, 'fro');
            end
            
            %% Local Fisher Discriminant Analysis (LFDA)
            for l = 1:kfold+1
                test_num = l;
                % get lth fold
                Xtrain = Xtrains{l};
                Ytrain = Ytrains{l};
                [ntrain, ~] = size(Ytrain);
                Xtest = Xtests{l};
                Ytest = Ytests{l};
                [ntest, ~] = size(Ytest);
                K = Xtrain*Xtrain';
                Ktest = Xtest*Xtrain';
                [Llfda,~] = KLFDA(K,Ytrain,k, 'plain',9);
                %predict
                Llfda = orth(Llfda);
                Zlfda = K*Llfda;
                B = mnrfit(Zlfda,Ytrain, 'Model', 'nominal', 'Interactions', 'on');
                LFDAXtest = Ktest*Llfda;
                [~,Yhat] = max(mnrval(B,LFDAXtest),[], 2);
                [~,LFDAYtrain] = max(mnrval(B,Zlfda),[], 2);
                %compute error
                LFDArates(l,t) = 1 - sum(Yhat == Ytest) / ntest;
                LFDArates_train(l,t) = 1 - sum(LFDAYtrain == Ytrain) / ntrain;
                
                LFDAvar(l,t) = norm(LFDAXtest, 'fro') / norm(Ktest, 'fro');
                LFDAvar_train(l,t) = norm(Zlfda, 'fro') / norm(K, 'fro');
            end
            
%             %% Kernel Local Fisher Discriminant Analysis (KLFDA)
%             %choose kernel param
%             for l = 1:kfold+1
%                 test_num = l;
%                 % get lth fold
%                 Xtrain = Xtrains{l};
%                 Ytrain = Ytrains{l};
%                 [ntrain, ~] = size(Ytrain);
%                 Xtest = Xtests{l};
%                 Ytest = Ytests{l};
%                 [ntest, ~] = size(Ytest);
%                 
%                 for jj = 1:length(sigmas)
%                     sigma = sigmas(jj);
%                     %train
%                     K = gaussian_kernel(Xtrain, Xtrain, sigma);
%                     [Llfda,~] = KLFDA(K,Ytrain,k, 'plain');
%                     Llfda = orth(Llfda);
%                     Zlfda = K*Llfda;
%                     %predict
%                     Ktest = gaussian_kernel(Xtest, Xtrain, sigma);
%                     LFDAXtest = Ktest*Llfda;
%                     B = mnrfit(Zlfda,Ytrain, 'Model', 'nominal', 'Interactions', 'on');
%                     [~,Yhat] = max(mnrval(B,LFDAXtest),[], 2);
%                     [~,LFDAYtrain] = max(mnrval(B,Zlfda),[], 2);
%                     %compute error
%                     kLFDArates(l,t,jj) = 1 - sum(Yhat == Ytest) / ntest;
%                     kLFDArates_train(l,t,jj) = 1 - sum(LFDAYtrain == Ytrain) / ntrain;
%                     kLFDAvar(l,t,jj) = norm(LFDAXtest, 'fro') / norm(Ktest, 'fro');
%                     kLFDAvar_train(l,t,jj) = norm(Zlfda, 'fro') / norm(K, 'fro');
%                 end
%             end
            
            
        end
        

    
    %% compute avg performance accross folds
    
    avgPCA = mean(PCArates(1:end-1,:));
    avgPCA_train = mean(PCArates_train(1:end-1,:));
%     avgkPCA = mean(kPCArates(1:end-1,:,:));
%     avgkPCA_train = mean(kPCArates_train(1:end-1,:,:));
%     avgLSPCA = mean(LSPCArates(1:end-1,:,:));
%     avgLSPCA_train = mean(LSPCArates_train(1:end-1,:,:));
%     avgkLSPCA = mean(kLSPCArates(1:end-1,:,:,:));
%     avgkLSPCA_train = mean(kLSPCArates_train(1:end-1,:,:,:));
    avgLSPCAmle = mean(mle_LSPCArates(1:end-1,:), 1);
    avgLSPCAmle_train = mean(mle_LSPCArates_train(1:end-1,:), 1);
%     avgkLSPCAmle = mean(mle_kLSPCArates(1:end-1,:,:), 1);
%     avgkLSPCAmle_train = mean(mle_kLSPCArates_train(1:end-1,:,:), 1);
    avgSPCA = mean(SPCArates(1:end-1,:));
    avgSPCA_train = mean(SPCArates_train(1:end-1,:));
%     avgkSPCA = mean(kSPCArates(1:end-1,:,:));
%     avgkSPCA_train = mean(kSPCArates_train(1:end-1,:,:));
    avgISPCA = mean(ISPCArates(1:end-1,:));
    avgISPCA_train = mean(ISPCArates_train(1:end-1,:));
%     avgSPPCA = mean(SPPCArates(1:end-1,:));
%     avgSPPCA_train = mean(SPPCArates_train(1:end-1,:));
    avgLDA = mean(LDArates(1:end-1,:));
    avgLDA_train = mean(LDArates_train(1:end-1,:));
    avgLFDA = mean(LFDArates(1:end-1,:));
    avgLFDA_train = mean(LFDArates_train(1:end-1,:));
%     avgkLFDA = mean(kLFDArates(1:end-1,:,:));
%     avgkLFDA_train = mean(kLFDArates_train(1:end-1,:,:));
    %
    avgPCAvar = mean(PCAvar(1:end-1,:));
%     avgkPCAvar = mean(kPCAvar(1:end-1,:,:));
%     avgLSPCAvar = mean(LSPCAvar(1:end-1,:,:));
%     avgkLSPCAvar = mean(kLSPCAvar(1:end-1,:,:,:));
    avgLSPCAmlevar = mean(mle_LSPCAvar(1:end-1,:), 1);
%     avgkLSPCAmlevar = mean(mle_kLSPCAvar(1:end-1,:,:), 1);
    avgSPCAvar = mean(SPCAvar(1:end-1,:));
%     avgkSPCAvar = mean(kSPCAvar(1:end-1,:,:));
    avgISPCAvar = mean(ISPCAvar(1:end-1,:));
%     avgSPPCAvar = mean(SPPCAvar(1:end-1,:));
    avgLDAvar = mean(LDAvar(1:end-1,:));
    avgLFDAvar = mean(LFDAvar(1:end-1,:));
%     avgkLFDAvar = mean(kLFDAvar(1:end-1,:,:));
    %
    avgPCAvar_train = mean(PCAvar_train(1:end-1,:));
%     avgkPCAvar_train = mean(kPCAvar_train(1:end-1,:,:));
%     avgLSPCAvar_train = mean(LSPCAvar_train(1:end-1,:,:));
%     avgkLSPCAvar_train = mean(kLSPCAvar_train(1:end-1,:,:,:));
    avgLSPCAmlevar_train = mean(mle_LSPCAvar_train(1:end-1,:), 1);
%     avgkLSPCAmlevar_train = mean(mle_kLSPCAvar_train(1:end-1,:,:), 1);
    avgSPCAvar_train = mean(SPCAvar_train(1:end-1,:));
%     avgkSPCAvar_train = mean(kSPCAvar_train(1:end-1,:,:));
    avgISPCAvar_train = mean(ISPCAvar_train(1:end-1,:));
%     avgSPPCAvar_train = mean(SPPCAvar_train(1:end-1,:));
    avgLDAvar_train = mean(LDAvar_train(1:end-1,:));
    avgLFDAvar_train = mean(LFDAvar_train(1:end-1,:));
%     avgkLFDAvar_train = mean(kLFDAvar_train(1:end-1,:,:));
    
     %% Calc performance for best model and store
    
    % cv over subspace dim
    loc = find(avgPCA==min(avgPCA,[],'all'),1,'last');
    [~,kloc] = ind2sub(size(avgPCA), loc);
    kpca = ks(kloc);
    PCAval(dd) = PCArates(end,kloc);
    PCAvalVar(dd) = PCAvar(end,kloc);
    PCAval_train(dd) = PCArates_train(end,kloc);
    PCAvalVar_train(dd) = PCAvar_train(end,kloc);
    
%     loc = find(avgkPCA==min(avgkPCA,[],'all'),1,'last');
%     [~,kloc,sigloc] = ind2sub(size(avgkPCA), loc);
%     kpca = ks(kloc);
%     kPCAval(dd) = kPCArates(end,kloc,sigloc);
%     kPCAvalVar(dd) = kPCAvar(end,kloc,sigloc);
%     kPCAval_train(dd) = kPCArates_train(end,kloc,sigloc);
%     kPCAvalVar_train(dd) = kPCAvar_train(end,kloc,sigloc);
    
%     loc = find(avgLSPCA==min(avgLSPCA,[],'all'),1,'last');
%     [~,kloc,lamloc] = ind2sub(size(avgLSPCA), loc);
%     klspca = ks(kloc);
%     LSPCAval(dd) = LSPCArates(end,kloc,lamloc);
%     LSPCAvalVar(dd) = LSPCAvar(end,kloc,lamloc);
%     LSPCAval_train(dd) = LSPCArates_train(end,kloc,lamloc);
%     LSPCAvalVar_train(dd) = LSPCAvar_train(end,kloc,lamloc);
%     
    
%     loc = find(avgkLSPCA==min(avgkLSPCA,[],'all'),1,'last');
%     [~,klock,lamlock,siglock] = ind2sub(size(avgkLSPCA), loc);
%     kklspca = ks(klock);
%     kLSPCAval(dd) = kLSPCArates(end,klock,lamlock,siglock);
%     kLSPCAvalVar(dd) = kLSPCAvar(end,klock,lamlock,siglock);
%     kLSPCAval_train(dd) = kLSPCArates_train(end,klock,lamlock,siglock);
%     kLSPCAvalVar_train(dd) = kLSPCAvar_train(end,klock,lamlock,siglock);
    
    loc = find(avgLSPCAmle==min(avgLSPCAmle,[],'all'),1,'last');
    [~,kloc] = ind2sub(size(avgLSPCAmle), loc);
    klspcamle = ks(kloc);
    mle_LSPCAval(dd) = mle_LSPCArates(end,kloc);
    mle_LSPCAvalVar(dd) = mle_LSPCAvar(end,kloc);
    mle_LSPCAval_train(dd) = mle_LSPCArates_train(end,kloc);
    mle_LSPCAvalVar_train(dd) = mle_LSPCAvar_train(end,kloc); 
    
%     loc = find(avgkLSPCAmle==min(avgkLSPCAmle,[],'all'),1,'last');
%     [~,klock,siglock] = ind2sub(size(avgkLSPCAmle), loc);
%     kklspca = ks(klock);
%     mle_kLSPCAval(dd) = mle_kLSPCArates(end,klock,siglock);
%     mle_kLSPCAvalVar(dd) = mle_kLSPCAvar(end,klock,siglock);
%     mle_kLSPCAval_train(dd) = mle_kLSPCArates_train(end,klock,siglock);
%     mle_kLSPCAvalVar_train(dd) = mle_kLSPCAvar_train(end,klock,siglock);
    
    loc = find(avgISPCA==min(avgISPCA,[],'all'),1,'last');
    [~,kloc] = ind2sub(size(avgISPCA), loc);
    kispca = ks(kloc);
    ISPCAval(dd) = ISPCArates(end,kloc);
    ISPCAvalVar(dd) = ISPCAvar(end,kloc);
    ISPCAval_train(dd) = ISPCArates_train(end,kloc);
    ISPCAvalVar_train(dd) = ISPCAvar_train(end,kloc);
    
%     loc = find(avgSPPCA==min(avgSPPCA,[],'all'),1,'last');
%     [~,kloc] = ind2sub(size(avgSPPCA), loc);
%     ksppca = ks(kloc);
%     SPPCAval(dd) = SPPCArates(end,kloc);
%     SPPCAvalVar(dd) = SPPCAvar(end,kloc);
%     SPPCAval_train(dd) = SPPCArates_train(end,kloc);
%     SPPCAvalVar_train(dd) = SPPCAvar_train(end,kloc);
    
    loc = find(avgSPCA==min(avgSPCA,[],'all'),1,'last');
    [~,kloc] = ind2sub(size(avgSPCA), loc);
    kspca = ks(kloc);
    SPCAval(dd) = SPCArates(end,kloc);
    SPCAvalVar(dd) = SPCAvar(end,kloc);
    SPCAval_train(dd) = SPCArates_train(end,kloc);
    SPCAvalVar_train(dd) = SPCAvar_train(end,kloc);
    
%     loc = find(avgkSPCA==min(avgkSPCA,[],'all'),1,'last');
%     [~,kloc,sigloc] = ind2sub(size(avgkSPCA), loc);
%     kkspca = ks(kloc);
%     kSPCAval(dd) = kSPCArates(end,kloc,sigloc);
%     kSPCAvalVar(dd) = kSPCAvar(end,kloc,sigloc);
%     kSPCAval_train(dd) = kSPCArates_train(end,kloc,sigloc);
%     kSPCAvalVar_train(dd) = kSPCAvar_train(end,kloc,sigloc);
    
    loc = find(avgLDA==min(avgLDA,[],'all'),1,'last');
    [~,kloc] = ind2sub(size(avgLDA), loc);
    klda = ks(kloc);
    LDAval(dd) = LDArates(end,kloc);
    LDAvalVar(dd) = LDAvar(end,kloc);
    LDAval_train(dd) = LDArates_train(end,kloc);
    LDAvalVar_train(dd) = LDAvar_train(end,kloc);
    
    loc = find(avgLFDA==min(avgLFDA,[],'all'),1,'last');
    [~,kloc] = ind2sub(size(avgLFDA), loc);
    klfda = ks(kloc);
    LFDAval(dd) = LFDArates(end,kloc);
    LFDAvalVar(dd) = LFDAvar(end,kloc);
    LFDAval_train(dd) = LFDArates_train(end,kloc);
    LFDAvalVar_train(dd) = LFDAvar_train(end,kloc);
    
%     loc = find(avgkLFDA==min(avgkLFDA,[],'all'),1,'last');
%     [~,kloc,sigloc] = ind2sub(size(avgkLFDA), loc);
%     kklfda = ks(kloc);
%     kLFDAval(dd) = kLFDArates(end,kloc,sigloc);
%     kLFDAvalVar(dd) = kLFDAvar(end,kloc,sigloc);
%     kLFDAval_train(dd) = kLFDArates_train(end,kloc,sigloc);
%     kLFDAvalVar_train(dd) = kLFDAvar_train(end,kloc,sigloc);

    %fixed subspace dimension k=2
    
    kloc=1; %k=2
    
    kpca = ks(kloc);
    PCAval_fixed(dd) = PCArates(end,kloc);
    PCAvalVar_fixed(dd) = PCAvar(end,kloc);
    PCAval_fixed_train(dd) = PCArates_train(end,kloc);
    PCAvalVar_fixed_train(dd) = PCAvar_train(end,kloc);

%     loc = find(avgkPCA(:,kloc,:)==min(avgkPCA(:,kloc,:),[],'all'),1,'last');
%     [~,~,sigloc] = ind2sub(size(avgkPCA(:,kloc,:)), loc);
%     kpca = ks(kloc);
%     kPCAval_fixed(dd) = kPCArates(end,kloc,sigloc);
%     kPCAvalVar_fixed(dd) = kPCAvar(end,kloc,sigloc);
%     kPCAval_fixed_train(dd) = kPCArates_train(end,kloc,sigloc);
%     kPCAvalVar_fixed_train(dd) = kPCAvar_train(end,kloc,sigloc);
    
%     loc = find(avgLSPCA(:,kloc,:)==min(avgLSPCA(:,kloc,:),[],'all'),1,'last');
%     [~,kloc,lamloc] = ind2sub(size(avgLSPCA(:,kloc,:)), loc);
%     klspca = ks(kloc);
%     LSPCAval_fixed(dd) = LSPCArates(end,kloc,lamloc);
%     LSPCAvalVar_fixed(dd) = LSPCAvar(end,kloc,lamloc);
%     LSPCAval_fixed_train(dd) = LSPCArates_train(end,kloc,lamloc);
%     LSPCAvalVar_fixed_train(dd) = LSPCAvar_train(end,kloc,lamloc);
%     
%     
%     loc = find(avgkLSPCA(:,kloc,:,:)==min(avgkLSPCA(:,kloc,:,:),[],'all'),1,'last');
%     [~,klock,lamlock,siglock] = ind2sub(size(avgkLSPCA(:,kloc,:,:)), loc);
%     kklspca = ks(klock);
%     kLSPCAval_fixed(dd) = kLSPCArates(end,klock,lamlock,siglock);
%     kLSPCAvalVar_fixed(dd) = kLSPCAvar(end,klock,lamlock,siglock);
%     kLSPCAval_fixed_train(dd) = kLSPCArates_train(end,klock,lamlock,siglock);
%     kLSPCAvalVar_fixed_train(dd) = kLSPCAvar_train(end,klock,lamlock,siglock);
    
    klspca = ks(kloc);
    mle_LSPCAval_fixed(dd) = mle_LSPCArates(end,kloc);
    mle_LSPCAvalVar_fixed(dd) = mle_LSPCAvar(end,kloc);
    mle_LSPCAval_fixed_train(dd) = mle_LSPCArates_train(end,kloc);
    mle_LSPCAvalVar_fixed_train(dd) = mle_LSPCAvar_train(end,kloc);
    
%     loc = find(avgkLSPCAmle(:,kloc,:)==min(avgkLSPCAmle(:,kloc,:),[],'all'),1,'last');
%     [~,~,sigloc] = ind2sub(size(avgkLSPCAmle(:,kloc,:)), loc);
%     kklspca = ks(kloc);
%     mle_kLSPCAval_fixed(dd) = mle_kLSPCArates(end,kloc,sigloc);
%     mle_kLSPCAvalVar_fixed(dd) = mle_kLSPCAvar(end,kloc,sigloc);
%     mle_kLSPCAval_fixed_train(dd) = mle_kLSPCArates_train(end,kloc,sigloc);
%     mle_kLSPCAvalVar_fixed_train(dd) = mle_kLSPCAvar_train(end,kloc,sigloc);
    
    kispca = ks(kloc);
    ISPCAval_fixed(dd) = ISPCArates(end,kloc);
    ISPCAvalVar_fixed(dd) = ISPCAvar(end,kloc);
    ISPCAval_fixed_train(dd) = ISPCArates_train(end,kloc);
    ISPCAvalVar_fixed_train(dd) = ISPCAvar_train(end,kloc);
    
%     ksppca = ks(kloc);
%     SPPCAval_fixed(dd) = SPPCArates(end,kloc);
%     SPPCAvalVar_fixed(dd) = SPPCAvar(end,kloc);
%     SPPCAval_fixed_train(dd) = SPPCArates_train(end,kloc);
%     SPPCAvalVar_fixed_train(dd) = SPPCAvar_train(end,kloc);
%     
    kspca = ks(kloc);
    SPCAval_fixed(dd) = SPCArates(end,kloc);
    SPCAvalVar_fixed(dd) = SPCAvar(end,kloc);
    SPCAval_fixed_train(dd) = SPCArates_train(end,kloc);
    SPCAvalVar_fixed_train(dd) = SPCAvar_train(end,kloc);
    
%     loc = find(avgkSPCA(:,kloc,:)==min(avgkSPCA(:,kloc,:),[],'all'),1,'last');
%     [~,~,sigloc] = ind2sub(size(avgkSPCA(:,kloc,:)), loc);
%     kkspca = ks(kloc);
%     kSPCAval_fixed(dd) = kSPCArates(end,kloc,sigloc);
%     kSPCAvalVar_fixed(dd) = kSPCAvar(end,kloc,sigloc);
%     kSPCAval_fixed_train(dd) = kSPCArates_train(end,kloc,sigloc);
%     kSPCAvalVar_fixed_train(dd) = kSPCAvar_train(end,kloc,sigloc);
    
    klda = ks(kloc);
    LDAval_fixed(dd) = LDArates(end,kloc);
    LDAvalVar_fixed(dd) = LDAvar(end,kloc);
    LDAval_fixed_train(dd) = LDArates_train(end,kloc);
    LDAvalVar_fixed_train(dd) = LDAvar_train(end,kloc);
    
    klfda = ks(kloc);
    LFDAval_fixed(dd) = LFDArates(end,kloc);
    LFDAvalVar_fixed(dd) = LFDAvar(end,kloc);
    LFDAval_fixed_train(dd) = LFDArates_train(end,kloc);
    LFDAvalVar_fixed_train(dd) = LFDAvar_train(end,kloc);
    
%     loc = find(avgkLFDA==min(avgkLFDA,[],'all'),1,'last');
%     [~,~,sigloc] = ind2sub(size(avgkLFDA), loc);
%     kklfda = ks(kloc);
%     kLFDAval_fixed(dd) = kLFDArates(end,kloc,sigloc);
%     kLFDAvalVar_fixed(dd) = kLFDAvar(end,kloc,sigloc);
%     kLFDAval_fixed_train(dd) = kLFDArates_train(end,kloc,sigloc);
%     kLFDAvalVar_fixed_train(dd) = kLFDAvar_train(end,kloc,sigloc);
    
    %track vals from all exps
%     LSPCAval_track(dd,:,:,:) = LSPCArates;
%     LSPCAvalVar_track(dd,:,:,:) = LSPCAvar;
%     kLSPCAval_track(dd,:,:,:,:) = kLSPCArates;
%     kLSPCAvalVar_track(dd,:,:,:,:) = kLSPCAvar;
%     LSPCAval_track_train(dd,:,:,:) = LSPCArates_train;
%     LSPCAvalVar_track_train(dd,:,:,:) = LSPCAvar_train;
%     kLSPCAval_track_train(dd,:,:,:,:) = kLSPCArates_train;
%     kLSPCAvalVar_track_train(dd,:,:,:,:) = kLSPCAvar_train;
    
end
%% save all data
save(strcat(dataset, '_results_dim'))

%% mnist scatter
set(0,'defaultAxesFontSize',25)
markers = 's*'
idx = mod(1:ntest, 30)==9;
%idx = rand(ntest,1)>0.97;

% a = rand(20,2) * 2 - 1; 
% [~, idx] = max(abs(normc(LSPCAXtest')'*a'));
idx = [285,100,41,61,293,173,590,437,589,425,489,319,544,566,616,617,421,204,156,283,340,394,434];
mask1 = zeros(ntest,1); mask1(idx) = 1;

% a = rand(20,2) * 2 - 1; 
% [~, idx] = max(abs(normc(LFDAXtest')'*a'));
idx = [362,367,370,357,314,342,338,365,334,337,287,276,266,280,288,290,279,419,554,469,581,388,113,86,364,539,526];
mask2 = zeros(ntest,1); mask2(idx) = 1;

figure(1)
clf
imgScatter(LSPCAXtest, Ytest, markers, abs(reshape(Xhold', 28, 28, ntest)), mask1, 3, 3)
title('LSPCA', 'fontsize', 25)
figure(2)
clf
imgScatter(LFDAXtest, Ytest, markers, abs(reshape(Xhold', 28, 28, ntest)), mask2, 0.06, 0.06)
axis([-0.5,0.5,-0.1,0.6]); axis square
title('LFDA', 'fontsize', 25)

% idx = rand(ntest,1)>0.98;
% imgScatter(LSPCAXtest, abs(reshape(Xhold', 28, 28, ntest)), idx, 3, 3)
% title('LSPCA')
% imgScatter(LFDAXtest, abs(reshape(Xhold', 28, 28, ntest)), idx, 0.03, 0.03)
% axis([-0.05,0.2,-0.15,0.2]); axis square
% title('LFDA')

%% print mean performance with std errors
m = mean(PCAval);
v = mean(PCAvalVar);
sm = std(PCAval);
sv = std(PCAvalVar);
sprintf('PCAerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)

m = mean(ISPCAval);
v = mean(ISPCAvalVar);
sm = std(ISPCAval);
sv = std(ISPCAvalVar);
sprintf('ISPCAerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)

% m = mean(SPPCAval);
% v = mean(SPPCAvalVar);
% sm = std(SPPCAval);
% sv = std(SPPCAvalVar);
% sprintf('SPPCAerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)

m = mean(SPCAval);
v = mean(SPCAvalVar);
sm = std(SPCAval);
sv = std(SPCAvalVar);
sprintf('Barshanerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)

m = mean(LDAval);
v = mean(LDAvalVar);
sm = std(LDAval);
sv = std(LDAvalVar);
sprintf('LDAerr: $%0.3f \\pm %0.3f $ & $%0.3f \\pm %0.3f$', m, sm, v, sv)

m = mean(LFDAval);
v = mean(LFDAvalVar);
sm = std(LFDAval);
sv = std(LFDAvalVar);
sprintf('LFDAerr: $%0.3f \\pm %0.3f $ & $%0.3f \\pm %0.3f$', m, sm, v, sv)

% m = mean(LSPCAval);
% v = mean(LSPCAvalVar);
% sm = std(LSPCAval);
% sv = std(LSPCAvalVar);
% sprintf('LSPCAerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)

m = mean(mle_LSPCAval);
v = mean(mle_LSPCAvalVar);
sm = std(mle_LSPCAval);
sv = std(mle_LSPCAvalVar);
sprintf('mle_LSPCAerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)

% m = mean(kPCAval);
% v = mean(kPCAvalVar);
% sm = std(kPCAval);
% sv = std(kPCAvalVar);
% sprintf('kPCAerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)
% 
% m = mean(kSPCAval);
% v = mean(kSPCAvalVar);
% sm = std(kSPCAval);
% sv = std(kSPCAvalVar);
% sprintf('kBarshanerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)
% 
% m = mean(kLFDAval);
% v = mean(kLFDAvalVar);
% sm = std(kLFDAval);
% sv = std(kLFDAvalVar);
% sprintf('kLFDAerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)
% 
% m = mean(kLSPCAval);
% v = mean(kLSPCAvalVar);
% sm = std(kLSPCAval);
% sv = std(kLSPCAvalVar);
% sprintf('kLSPCAerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)
% 
% m = mean(mle_kLSPCAval);
% v = mean(mle_kLSPCAvalVar);
% sm = std(mle_kLSPCAval);
% sv = std(mle_kLSPCAvalVar);
% sprintf('mle_kLSPCAerr: $%0.3f \\pm %0.3f$ & $%0.3f \\pm %0.3f$', m, sm, v, sv)



%



% %% plot error - var tradeoff curves

% 

% % for t = 1:length(ks)

% figure()

% hold on

% plot(mean(PCAvalVar_fixed), mean(PCAval_fixed), 'sr', 'MarkerSize', 30, 'LineWidth', 2)

% % plot(mean(kPCAvalVar_fixed), mean(kPCAval_fixed), 'sr', 'MarkerSize', 20, 'LineWidth', 2)

% plot(squeeze(mean(LSPCAvalVar_track(:,end,1,:))), squeeze(mean(LSPCAval_track(:,end,1,:))), 'r.:', 'LineWidth', 2, 'MarkerSize', 20)

% plot(squeeze(mean(kLSPCAvalVar_track(:,end,1,:,end))), squeeze(mean(kLSPCAval_track(:,end,1,:,end))), 'b.-', 'LineWidth', 2, 'MarkerSize', 20)

% plot(mean(mle_LSPCAvalVar_fixed), mean(mle_LSPCAval_fixed), 'r>', 'LineWidth', 2, 'MarkerSize', 20)

% plot(mean(mle_kLSPCAvalVar_fixed), mean(mle_kLSPCAval_fixed), 'b^', 'LineWidth', 2, 'MarkerSize', 20)

% plot(mean(ISPCAvalVar_fixed), mean(ISPCAval_fixed), 'm+', 'MarkerSize', 20, 'LineWidth', 2)

% plot(mean(SPPCAvalVar_fixed), mean(SPPCAval_fixed), 'xc', 'MarkerSize', 20, 'LineWidth', 3)

% plot(mean(SPCAvalVar_fixed), mean(SPCAval_fixed), 'pk', 'MarkerSize', 20, 'LineWidth', 2)

% plot(mean(kSPCAvalVar_fixed), mean(kSPCAval_fixed), '<', 'MarkerSize', 20, 'LineWidth', 2)

% plot(mean(LDAvalVar_fixed), mean(LDAval_fixed), 'k*', 'MarkerSize', 20, 'LineWidth', 2)

% plot(mean(LFDAvalVar_fixed), mean(LFDAval_fixed), 'h', 'MarkerSize', 20, 'LineWidth', 2)

% plot(mean(kLFDAvalVar_fixed), mean(kLFDAval_fixed), 'ok', 'MarkerSize', 20, 'LineWidth', 3)

% 

% xlabel('Variation Explained', 'fontsize', 25)

% %title('Test', 'fontsize', 25)

% ylabel('MSE', 'fontsize', 25)

% %title(sprintf('k = %d', ks(t)), 'fontsize', 30)

% set(gca, 'fontsize', 25)

% lgd = legend('PCA', 'LSPCA', 'kLSPCA', 'LSPCA (MLE)', 'kLSPCA (MLE)', 'ISPCA', 'SPPCA', 'Barshan', 'kBarshan', 'LDA', 'LFDA', 'kLFDA', 'Location', 'best'); lgd.FontSize = 15;

% %lgd = legend('LSPCA', 'R4', 'PLS', 'SPPCA', 'Barshan', 'SSVD', 'PCA', 'Location', 'southeast'); lgd.FontSize = 15;

% %ylim([0, 0.12])

% %set(gca, 'YScale', 'log')

% xlim([0,1])

% 

% 

% %% plot error - var tradeoff curves

% 

% % for t = 1:length(ks)

% figure()

% hold on

% plot(mean(PCAvalVar_fixed_train), mean(PCAval_fixed_train), 'sr', 'MarkerSize', 30, 'LineWidth', 2)

% % plot(mean(kPCAvalVar_fixed), mean(kPCAval_fixed), 'sr', 'MarkerSize', 20, 'LineWidth', 2)

% plot(squeeze(mean(LSPCAvalVar_track_train(:,end,1,:))), squeeze(mean(LSPCAval_track_train(:,end,1,:))), 'r.:', 'LineWidth', 2, 'MarkerSize', 20)

% plot(squeeze(mean(kLSPCAvalVar_track_train(:,end,1,:,end))), squeeze(mean(kLSPCAval_track_train(:,end,1,:,end))), 'b.-', 'LineWidth', 2, 'MarkerSize', 20)

% plot(mean(mle_LSPCAvalVar_fixed_train), mean(mle_LSPCAval_fixed_train), 'r>', 'LineWidth', 2, 'MarkerSize', 20)

% plot(mean(mle_kLSPCAvalVar_fixed_train), mean(mle_kLSPCAval_fixed_train), 'b^', 'LineWidth', 2, 'MarkerSize', 20)

% plot(mean(ISPCAvalVar_fixed_train), mean(ISPCAval_fixed_train), 'm+', 'MarkerSize', 20, 'LineWidth', 2)

% plot(mean(SPPCAvalVar_fixed_train), mean(SPPCAval_fixed_train), 'xc', 'MarkerSize', 20, 'LineWidth', 3)

% plot(mean(SPCAvalVar_fixed_train), mean(SPCAval_fixed_train), 'pk', 'MarkerSize', 20, 'LineWidth', 2)

% plot(mean(kSPCAvalVar_fixed_train), mean(kSPCAval_fixed_train), '<', 'MarkerSize', 20, 'LineWidth', 2)

% plot(mean(LDAvalVar_fixed_train), mean(LDAval_fixed_train), 'k*', 'MarkerSize', 20, 'LineWidth', 2)

% plot(mean(LFDAvalVar_fixed_train), mean(LFDAval_fixed_train), 'h', 'MarkerSize', 20, 'LineWidth', 2)

% plot(mean(kLFDAvalVar_fixed_train), mean(kLFDAval_fixed_train), 'ok', 'MarkerSize', 20, 'LineWidth', 3)

% 

% xlabel('Variation Explained', 'fontsize', 25)

% %title('Test', 'fontsize', 25)

% ylabel('MSE', 'fontsize', 25)

% %title(sprintf('k = %d', ks(t)), 'fontsize', 30)

% set(gca, 'fontsize', 25)

% lgd = legend('PCA', 'LSPCA', 'kLSPCA', 'LSPCA (MLE)', 'kLSPCA (MLE)', 'ISPCA', 'SPPCA', 'Barshan', 'kBarshan', 'LDA', 'LFDA', 'kLFDA', 'Location', 'best'); lgd.FontSize = 15;

% %lgd = legend('LSPCA', 'R4', 'PLS', 'SPPCA', 'Barshan', 'SSVD', 'PCA', 'Location', 'southeast'); lgd.FontSize = 15;

% %ylim([0, 0.12])

% %set(gca, 'YScale', 'log')

% xlim([0,1])





