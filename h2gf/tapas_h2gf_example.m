function [h2gf_est, h2gf_input, sim] = tapas_h2gf_example()
% Runs an example of the h2gf using simulated data.
%

% aponteeduardo@gmail.com, chmathys@ethz.ch
% copyright (C) 2017-2018
%

%% Prepare the model
% Initialize a structure to hold the hgf
hgf = struct('c_prc', [], 'c_obs', []);
% Set the perceptual model
hgf.c_prc.prc_fun = @tapas_hgf_binary;
% Set the corresponding reparameterization function
hgf.c_prc.transp_prc_fun = @tapas_hgf_binary_transp;

% Set the observation model
hgf.c_obs.obs_fun = @tapas_unitsq_sgm; 
% Set the corresponding reparameterization function 
hgf.c_obs.transp_obs_fun = @tapas_unitsq_sgm_transp; 

% Run the config function of the perceptual model
config = tapas_hgf_binary_config();

% Copy the priors and number of levels of the perceptual model into
% the hgf structure
hgf.c_prc.priormus = config.priormus;
hgf.c_prc.priorsas = config.priorsas;
hgf.c_prc.n_levels = config.n_levels;

% Set the priors of the observational model
hgf.c_obs.priormus = 0.5;
hgf.c_obs.priorsas = 1;

% Set the weights of the priors
%
% eta weights the priors with respect to the observations. The priors
% can be interpreted as the estimated parameter distributions of
% additional, virtual subjects. Their weight eta corresponds to the
% number of virtual subjects represented by them. For example if we
% have data from ten real subjects and set eta to ten, then the priors
% will have a weight equal to that of the data. By default eta is
% one, corresponding to one virtual subject.
hgf.empirical_priors = struct('eta', []);
% eta can be a scalar, setting the same weight across all priors; or a
% vector, setting a particular weight for each prior. If eta is a
% vector, its length needs to be the sum of the lengths
% hgf.c_prc.priormus and hgf.c_obs.priormus.
hgf.empirical_priors.eta = 1;

%% Simulate data
% Number of subjects
num_subjects = 10;

% Values of omega2 and zeta for each simulated subject
om2 = [-5 -4.5 -4 -3.6 -3.4 -3.2 -3.0 -2.8 -2.6 -2.4];
ze = [0.5 1 1.3 1.4 1.5 1.7 1.8 1.9 2 2.5];
% Randomly permute the elements of ze such that there is no
% systematic association between high values of omega2 and
% high values of zeta
ze = ze(randperm(length(ze))); 

% Initialize a structure array for the simulations
sim = struct('u', [],...
             'ign', [],...
             'c_sim', [],...
             'p_prc', [],...
             'c_prc', [],...
             'traj', [],...
             'p_obs', [],...
             'c_obs', [],...
             'y', []);

% Initialize a sctructure array for the 'data' argument of h2gf_estimate
data = struct('y', cell(num_subjects, 1),...
              'u', [],...
              'ign', [],...
              'irr', []);

% Load example inputs u
[~, u] = tapas_h2gf_load_example_data();

% Generate simulated data with the chosen range of parameter settings
for i = 1:num_subjects
    sim(i) = tapas_simModel(u,...
                         'tapas_hgf_binary', [NaN,...
                                              1,...
                                              1,...
                                              NaN,...
                                              1,...
                                              1,...
                                              NaN,...
                                              0,...
                                              0,...
                                              1,...
                                              1,...
                                              NaN,...
                                              om2(i),...
                                              log(0.0025)],...
                         'tapas_unitsq_sgm', ze(i));
    % Simulated responses
    data(i).y = sim(i).y;
    % Experimental inputs
    data(i).u = sim(i).u;
end

%% Configure the sampler
% Initialize the place holder for the parameters of the 
% inference. Missing parameters are filled by default
% values. This is implemented in tapas_h2gf_inference.m
pars = struct();

% Number of samples stored 
pars.niter = 100;
% Number of samples in the burn-in phase
pars.nburnin = 100;
% Number of samples used for diagnostics. During the 
% burn-in phase the parameters of the algorithm are 
% adjusted to increase the efficiency. This happens after 
% every diagnostic cycle.
pars.ndiag = 50;

% Set up the so called temperature schedule. This is used to
% compute the model evidence. It is a matrix of NxM, where N 
% is the number of subjects and M is the number of chains used 
% to compute the model evidence. The
% temperature schedule is selected using a 5th order power rule. 
pars.T = ones(num_subjects, 1) * linspace(0.01, 1, 8).^5;

% This controls how often a 'swap' step is perform. 
pars.mc3it = 0;

%% Run the estimation
% The function tapas_h2gf_estimate() is the entry point to the
% estimation. Its behavior can be  modified by changing the default
% settings.
inference = struct();
h2gf_est = tapas_h2gf_estimate(data, hgf, inference, pars);

% Gather the input in one struct
h2gf_input = struct();
h2gf_input.data = data;
h2gf_input.hgf = hgf;
h2gf_input.inference = inference;
h2gf_input.pars = pars;

end