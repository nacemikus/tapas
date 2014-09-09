function bpa = bayesian_parameter_average(varargin)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% This function calculates the Bayesian parameter average for the individual estimates handed  to
% it.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% USAGE:
%     est1 = fitModel(responses1, inputs);
%     est2 = fitModel(responses2, inputs);
%     ...
%     estn = fitModel(responsesn, inputs);
%
%     bpa = bayesian_parameter_average(est1, est2,..., estn);
% 
% INPUT ARGUMENTS:
%     varargin           Estimate structures generated by fitModel(...). Note that all estimates
%                        must have been made under the same priors.
%
% OUTPUT:
%     bpa.u              Input to agent (i.e., the inputs array from the arguments)
%     bpa.c_prc          Configuration settings for your chosen perceptual model
%                        (see the configuration file of that model for details)
%     bpa.c_obs          Configuration settings for your chosen observation model
%                        (see the configuration file of that model for details)
%     bpa.optim          A place for the optimization algorithm to dump infos of interest to it
%     bpa.p_prc          Bayesian average of estimates of perceptual parameters
%                        (see the configuration file of your chosen perceptual model for details)
%     bpa.p_obs          Bayesian average of estimates of observation parameters
%                        (see the configuration file of your chosen observation model for details)
%     bpa.traj:          Trajectories of the environmental states tracked by the perceptual model
%                        (see the configuration file of that model for details)
%
%
% PLOTTING OF RESULTS:
%     To plot the trajectories of the inferred perceptual states (as implied by the averaged
%     parameters), there is a function <modelname>_plotTraj(...) for each perceptual model. This
%     takes the structure returned by bpa(...) as its only argument.
%
%     Additionally, the function fit_plotCorr(...) plots the posterior correlation of the
%     averaged parameters. It takes the structure returned by bpa(...) as its only
%     argument. Note that this function only works if the optimization algorithm makes the
%     posterior correlation available in est.optim.Corr for all of the estimate structures handed
%     to bpa(...).
%
% --------------------------------------------------------------------------------------------------
% Copyright (C) 2013 Christoph Mathys, TNU, UZH & ETHZ
%
% This file is part of the HGF toolbox, which is released under the terms of the GNU General Public
% Licence (GPL), version 3. You can redistribute it and/or modify it under the terms of the GPL
% (either version 3 or, at your option, any later version). For further details, see the file
% COPYING or <http://www.gnu.org/licenses/>.

% Number of estimates to average
n = size(varargin,2);

% Inputs
u = varargin{1}.u;

% Determine the models involved
prc_model = varargin{1}.c_prc.model;
obs_model = varargin{1}.c_obs.model;

% Get priors
prc_priormus = varargin{1}.c_prc.priormus;
prc_priorsas = varargin{1}.c_prc.priorsas;
obs_priormus = varargin{1}.c_obs.priormus;
obs_priorsas = varargin{1}.c_obs.priorsas;

% Check whether everything matches up
for i = 2:n
    if ~strcmp(prc_model,varargin{i}.c_prc.model)
        error('Perceptual models do not match.');
    end

    if ~strcmp(obs_model,varargin{i}.c_obs.model)
        error('Observation models do not match.');
    end

    if ~isequalwithequalnans(prc_priormus,varargin{i}.c_prc.priormus) || ~isequalwithequalnans(prc_priorsas,varargin{i}.c_prc.priorsas)
        error('Perceptual priors do not match.');
    end

    if ~isequalwithequalnans(obs_priormus,varargin{i}.c_obs.priormus) || ~isequalwithequalnans(obs_priorsas,varargin{i}.c_obs.priorsas)
        error('Observation priors do not match.');
    end

    if ~isequalwithequalnans(u(:),varargin{i}.u(:))
        disp(['Warning: inputs for argument number ' num2str(i) ' do not match those for first argument.']);
    end
end

% Record configuration
bpa       = struct;
bpa.u     = u;
bpa.ign   = [];
bpa.c_prc = varargin{1}.c_prc;
bpa.c_obs = varargin{1}.c_obs;

% Determine indices of parameters that have been optimized (i.e., those that are not fixed or NaN)
opt_idx = [bpa.c_prc.priorsas, bpa.c_obs.priorsas];
opt_idx(isnan(opt_idx)) = 0;
opt_idx = find(opt_idx);

% Prior precision
priorsas = [prc_priorsas, obs_priorsas];
H0 = diag(1./priorsas(opt_idx));

% Posterior precision and covariance
H = (1-n).*H0; 

for i=1:n
    H = H + varargin{i}.optim.H;
end

Sigma = inv(H);
Corr = Cov2Corr(Sigma);

% Record results
bpa.optim.H     = H;
bpa.optim.Sigma = Sigma;
bpa.optim.Corr  = Corr;

% Prior mean
priormus = [prc_priormus, obs_priormus]';
mu0 = priormus(opt_idx);

% Posterior mean
mu = (1-n).*H0*mu0;

for i=1:n
    mui = [varargin{i}.p_prc.ptrans, varargin{i}.p_obs.ptrans]';
    mui = mui(opt_idx);
    mu = mu + varargin{i}.optim.H*mui;
end

mu = Sigma*mu;

% Replace optimized values in priormus with averaged values
ptrans = priormus';
ptrans(opt_idx) = mu';

% Separate perceptual and observation parameters
n_prcpars = length(bpa.c_prc.priormus);
ptrans_prc = ptrans(1:n_prcpars);
ptrans_obs = ptrans(n_prcpars+1:end);

% Transform MAP parameters back to their native space
[dummy, bpa.p_prc]   = bpa.c_prc.transp_prc_fun(bpa, ptrans_prc);
[dummy, bpa.p_obs]   = bpa.c_obs.transp_obs_fun(bpa, ptrans_obs);
bpa.p_prc.p      = bpa.c_prc.transp_prc_fun(bpa, ptrans_prc);
bpa.p_obs.p      = bpa.c_obs.transp_obs_fun(bpa, ptrans_obs);

% Store transformed MAP parameters
bpa.p_prc.ptrans = ptrans_prc;
bpa.p_obs.ptrans = ptrans_obs;

% Store representations at MAP estimate
bpa.traj = bpa.c_prc.prc_fun(bpa, bpa.p_prc.p);

% Print results
disp(' ')
disp('Results:');
disp(bpa.p_prc)
disp(bpa.p_obs)

end