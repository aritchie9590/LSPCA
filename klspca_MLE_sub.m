function [Z, L, B, K] = klspca_MLE_sub(X, Y, sigma, k, L0, Kinit)
% Inputs:
%       X: (n x p) data matrix columns are features rows are
%       observations
%
%       Y: (n x q) Response Variables
%
%       sigma: kernel bandwidth
%
%       k: desired number of reduced dimensions
%
%       L0: (p x k) initial guess at a subspace
%           -default: pass in L0 = 0 and first k principle
%           components will be used
%
%       Kinit: (n x n) optional kernel matrix initialization, pass in 0 if you want the program to construct the kernel matrix
%
% Outputs:
%
%       Z: (n x k) dimension reduced form of X; A = X*L'
%
%       L: (k x p) matrix with rowspan equal to the desired subspace
%
%       B: (k x q) regression coefficients mapping reduced X to Y
%           i.e. Y = X*L'*B
%
%       K: (n x n) kernel matrix


%create kernel matrix
if sigma == 0 && sum(abs(Kinit),'all') == 0 %to specify using a linear kernel (faster if n < p)
    X = X*X';
    X = X - mean(X); X = (X' - mean(X'))'; %centered kernel matrix
elseif sum(abs(Kinit),'all') == 0
    X = gaussian_kernel(X, X, sigma);
else
    X = Kinit;
end

%store dimensions:
[n, p] = size(X);
[~, q] = size(Y);
%norms
Xnorm = norm(X, 'fro');
Ynorm = norm(Y, 'fro');

%anonymous function for calculating Bi from Li and X
calc_B = @(X, L) (X*L) \ Y;

% initialize L0 by PCA of X, and B0 by L0
if (sum(sum(L0 ~=0)) == 0)
    L = pca(X,'NumComponents',k);
else
    L = L0;
end
% initialize the other optimization variables
B = calc_B(X, L);
var_x = (n*(p-k))^-1 * ((norm(X, 'fro')^2-norm(X*L, 'fro')^2));
alpha = max((n*k)^-1 * norm(X*L, 'fro')^2 - var_x, 0);
eta = sqrt(var_x + alpha) - sqrt(var_x);
gamma = (var_x + eta) / eta;
var_y = (n*q)^-1 * norm(Y - X*(L*B), 'fro')^2;

niter = 0;
notConverged = true;
fstar = inf;
while notConverged
    
    % Update old vars
    Lprev = L;
    fstarprev = fstar;
    
    % set up the optimization subproblem in manopt
    warning('off', 'manopt:getHessian:approx')
    warning('off', 'manopt:getgradient:approx')
    manifold = grassmannfactory(p, k, 1);
    problem.M = manifold;
    problem.cost  = @(L) 0.5*( (1/Ynorm^2)*((1/var_y)*norm(Y - X*(L*(X*L \ Y)), 'fro')^2 + + n*q*log(var_y)) + (1/Xnorm^2)*((1/var_x)*((norm(X, 'fro')^2-(alpha/(var_x+alpha))*norm(X*L, 'fro')^2)) + n*(p-k)*log(var_x) + n*k*log(var_x+alpha)));
    problem.egrad = @(L) -(1/var_y)*(1/Ynorm^2)*(X'*(Y-X*(L*(X*L \ Y))))*(X*L \ Y)' - 2*(1/var_x)*(1/Xnorm^2)*(1/gamma)*(X'*(X*L)) + (1/var_x)*(1/Xnorm^2)*(1/gamma^2)*((L*((L'*X')*X))*L + (((X')*X)*L)*L'*L);
    options.verbosity = 0;
    options.stopfun = @mystopfun;
    options.maxiter = 2000;
    
    % solve the subproblem for a number of iterations over the steifel
    % manifold
    %[L, fstar, info, ~] = barzilaiborwein(problem, L, options);
    [L, fstar, info, ~] = conjugategradient(problem, L, options);
    %[L, fstar, info, ~] = trustregions(problem, L, options);
%     info(end).iter;
%     info(end).gradnorm;
%     fstar;
    
    %update B
    B = calc_B(X, L);

    %update var_x
    if alpha>0
        var_x = (n*(p-k))^-1 * ((norm(X, 'fro')^2-norm(X*L, 'fro')^2));
    else
        var_x = (n*p)^-1 * norm(X, 'fro')^2;
    end
    
    %update alpha
    alpha = max((n*k)^-1 * norm(X*L, 'fro')^2 - var_x, 0);
    eta = sqrt(var_x + alpha) - sqrt(var_x);
    gamma = (var_x + eta) / eta;
    
    %update var_y
    var_y = (n*q)^-1 * norm(Y - X*(L*B), 'fro')^2;
    
    %% test for overall convergence
    niter = niter+1;
    subspace_discrepancy = 1 - detsim(Lprev', L');
    if subspace_discrepancy < sstol || niter>500 || (fstar - fstarprev)^2 < sstol
        notConverged = false;
    end
    
end
% set the output variables
Z = X*L;
K = X;
end

function stopnow = mystopfun(problem, x, info, last)
stopnow1 = (last >= 3 && info(last-2).cost - info(last).cost < 1e-6);
stopnow2 = info(last).gradnorm <= 1e-6;
stopnow3 = info(last).stepsize <= 1e-8;
stopnow = (stopnow1 && stopnow3) || stopnow2;
end
