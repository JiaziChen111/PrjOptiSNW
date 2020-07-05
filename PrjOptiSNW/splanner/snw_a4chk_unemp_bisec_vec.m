%% SNW_A4CHK_UNEMP_BISEC_VEC (Exact Vectorized) Asset Position for Check
%    What is the value of a check? From the perspective of the value
%    function? We have Asset as a state variable, in a cash-on-hand sense,
%    how much must the asset (or think cash-on-hand) increase by, so that
%    it is equivalent to providing the household with a check? This is not
%    the same as the check amount because of tax as well as interest rates.
%    Interest rates means that you might need to offer a smaller a than the
%    check amount. The tax rate means that we might need to shift a by
%    larger than the check amount.
%
%    This function is slightly different from SNW_A4CHK_WRK. There we solve
%    the problem for working individuals who do not have an unemployment
%    shock. Here, we have the unemployment shock. This is the slower looped
%    code fzero version.
%
%    This is the faster vectorized solution. It takes as given pre-computed
%    household head and spousal income that is state-space specific, which
%    does not need to be recomputed.
%
%    * WELF_CHECKS integer the number of checks
%    * TR float the value of each check
%    * V_SS ndarray the value matrix along standard state-space dimensions:
%    (n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid)
%    * MP_PARAMS map with model parameters
%    * MP_CONTROLS map with control parameters
%
%    [V_W, EXITFLAG_FSOLVE] = SNW_A4CHK_UNEMP(WELF_CHECKS, TR, V_SS,
%    MP_PARAMS, MP_CONTROLS) solves for working value given V_SS value
%    function results, for number of check WELF_CHECKS, and given the value
%    of each check equal to TR.
%
%    See also SNWX_A4CHK_WRK_SMALL, SNWX_A4CHK_WRK_DENSE,
%    SNW_A4CHK_UNEMP_BISEC, SNW_A4CHK_UNEMP_BISEC_VEC, FIND_A_WORKING
%

%%
function [V_U, exitflag_fsolve]=snw_a4chk_unemp_bisec_vec(varargin)

%% Default and Parse
if (~isempty(varargin))
    
    if (length(varargin)==2)
        [welf_checks, V_unemp] = varargin{:};
        mp_controls = snw_mp_control('default_base');
    elseif (length(varargin)==4)
        [welf_checks, V_unemp, mp_params, mp_controls] = varargin{:};
    elseif (length(varargin)==7)
        [welf_checks, V_unemp, mp_params, mp_controls, ...
            ar_a_amz, ar_inc_unemp_amz, ar_spouse_inc_unemp_amz] = varargin{:};        
    else
        error('Need to provide 2/4/7 parameter inputs');
    end
    
else
    close all;
                
    % Solve the VFI Problem and get Value Function
    mp_params = snw_mp_param('default_tiny');
    mp_controls = snw_mp_control('default_test');
    
    % Solve for Value Function, Without One Period Unemployment Shock
    [V_ss,~,~,~] = snw_vfi_main_bisec_vec(mp_params, mp_controls);
    
    % The number of checks
    welf_checks = 2;
    
    % Solve for Value of One Period Unemployment Shock
    xi=0.5; % Proportional reduction in income due to unemployment (xi=0 refers to 0 labor income; xi=1 refers to no drop in labor income)
    b=0; % Unemployment insurance replacement rate (b=0 refers to no UI benefits; b=1 refers to 100 percent labor income replacement)
    TR = 100/58056;

    mp_params('TR') = TR;
    mp_params('xi') = xi;
    mp_params('b') = b;
    
    [V_unemp,~,~,~] = snw_vfi_main_bisec_vec(mp_params, mp_controls, V_ss);    
    
end

%% Reset All globals
% Parameters used in this code directly
global agrid n_jgrid n_agrid n_etagrid n_educgrid n_marriedgrid n_kidsgrid
% Used in find_a_working function
global theta r agrid epsilon eta_H_grid eta_S_grid SS Bequests bequests_option throw_in_ocean

%% Parse Model Parameters
params_group = values(mp_params, {'theta', 'r'});
[theta,  r] = params_group{:};

params_group = values(mp_params, {'Bequests', 'bequests_option', 'throw_in_ocean'});
[Bequests, bequests_option, throw_in_ocean] = params_group{:};

params_group = values(mp_params, {'agrid', 'eta_H_grid', 'eta_S_grid'});
[agrid, eta_H_grid, eta_S_grid] = params_group{:};

params_group = values(mp_params, {'epsilon', 'SS'});
[epsilon, SS] = params_group{:};

params_group = values(mp_params, ...
    {'n_jgrid', 'n_agrid', 'n_etagrid', 'n_educgrid', 'n_marriedgrid', 'n_kidsgrid'});
[n_jgrid, n_agrid, n_etagrid, n_educgrid, n_marriedgrid, n_kidsgrid] = params_group{:};

params_group = values(mp_params, {'TR', 'xi','b'});
[TR, xi, b] = params_group{:};    

%% Parse Model Controls
% Minimizer Controls
params_group = values(mp_controls, {'fl_max_trchk_perc_increase'});
[fl_max_trchk_perc_increase] = params_group{:};
params_group = values(mp_controls, {'options2'});
[options2] = params_group{:};

% Profiling Controls
params_group = values(mp_controls, {'bl_timer'});
[bl_timer] = params_group{:};

% Display Controls
params_group = values(mp_controls, {'bl_print_a4chk','bl_print_a4chk_verbose'});
[bl_print_a4chk, bl_print_a4chk_verbose] = params_group{:};

%% Timing and Profiling Start

if (bl_timer)
    tic
end

%% A. Compute Household-Head and Spousal Income

% this is only called when the function is called without mn_inc_plus_spouse_inc
if ~exist('mn_inc_plus_spouse_inc','var')
    
    % initialize
    mn_inc_unemp = NaN(n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid);
    mn_spouse_inc_unemp = NaN(n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid);
    mn_a = NaN(n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid);
    
    % Txable Income at all state-space points
    for j=1:n_jgrid % Age
        for a=1:n_agrid % Assets
            for eta=1:n_etagrid % Productivity
                for educ=1:n_educgrid % Educational level
                    for married=1:n_marriedgrid % Marital status
                        for kids=1:n_kidsgrid % Number of kids

                            [inc,earn]=individual_income(j,a,eta,educ,xi,b);
                            spouse_inc=spousal_income(j,educ,kids,earn,SS(j,educ));

                            mn_inc_unemp(j,a,eta,educ,married,kids) = inc;
                            mn_spouse_inc_unemp(j,a,eta,educ,married,kids) = (married-1)*spouse_inc*exp(eta_S_grid(eta));
                            mn_a(j,a,eta,educ,married,kids) = agrid(a);
                            
                        end
                    end
                end
            end
        end
    end
    
    % flatten the nd dimensional array
    ar_inc_unemp_amz = mn_inc_unemp(:);
    ar_spouse_inc_unemp_amz = mn_spouse_inc_unemp(:);
    ar_a_amz = mn_a(:);
    
end

%% B. Vectorized Solution for Optimal Check Adjustments

% B1. Anonymous Function where X is fraction of addition given bounds
fc_ffi_frac0t1_find_a_working = @(x) ffi_frac0t1_find_a_unemp_vec(...
    x, ...
    ar_a_amz, ar_inc_unemp_amz, ar_spouse_inc_unemp_amz, ...
    welf_checks, TR, r, fl_max_trchk_perc_increase);

% B2. Solve with Bisection
[~, ar_a_aux_unemp_bisec_amz] = ...
    ff_optim_bisec_savezrone(fc_ffi_frac0t1_find_a_working);

% B3. Reshape
mn_a_aux_unemp_bisec = reshape(ar_a_aux_unemp_bisec_amz, [n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid]);

%% C. Loop over all States, Interpolate given Bisec A_AUX_UMEMP results

% C1. Initialize
V_U=NaN(n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid);
exitflag_fsolve=NaN(n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid);

% C2. Loop
for j=1:n_jgrid % Age
    for a=1:n_agrid % Assets
        for eta=1:n_etagrid % Productivity
            for educ=1:n_educgrid % Educational level
                for married=1:n_marriedgrid % Marital status
                    for kids=1:n_kidsgrid % Number of kids
                        
                        % C3. Get the Vectorize Solved Solution
                        a_aux = mn_a_aux_unemp_bisec(j,a,eta,educ,married,kids);
                        
                        % C4. Error Check
                        if a_aux<0
                            disp(a_aux)
                            error('Check code! Should not allow for negative welfare checks')
                        elseif a_aux>agrid(n_agrid)
                            a_aux=agrid(n_agrid);
                        end
                        
                        % C5. Linear interpolation
                        ind_aux=find(agrid<=a_aux,1,'last');
                        
                        if a_aux==0
                            inds(1)=1;
                            inds(2)=1;
                            vals(1)=1;
                            vals(2)=0;                            
                        elseif a_aux==agrid(n_agrid)
                            inds(1)=n_agrid;
                            inds(2)=n_agrid;
                            vals(1)=1;
                            vals(2)=0;                            
                        else
                            inds(1)=ind_aux;
                            inds(2)=ind_aux+1;
                            vals(1)=1-((a_aux-agrid(inds(1)))/(agrid(inds(2))-agrid(inds(1))));
                            vals(2)=1-vals(1);                            
                        end
                        
                        % C6. Weight
                        V_U(j,a,eta,educ,married,kids)=vals(1)*V_unemp(j,inds(1),eta,educ,married,kids)+vals(2)*V_unemp(j,inds(2),eta,educ,married,kids);
                        
                    end
                end
            end
        end
    end
    
    if (bl_print_a4chk)
        disp(strcat(['SNW_A4CHK_UNEMP_BISEC_VEC: Finished Age Group:' ...
            num2str(j) ' of ' num2str(n_jgrid)]));
    end
    
end

%% D. Timing and Profiling End
if (bl_timer)
    toc;
    st_complete_a4chk = strjoin(...
        ["Completed SNW_A4CHK_UNEMP_BISEC_VEC", ...
         ['welf_checks=' num2str(welf_checks)], ...
         ['TR=' num2str(TR)], ...
         ['xi=' num2str(xi)], ...
         ['b=' num2str(b)], ...
         ['SNW_MP_PARAM=' char(mp_params('mp_params_name'))], ...
         ['SNW_MP_CONTROL=' char(mp_controls('mp_params_name'))] ...
        ], ";");
    disp(st_complete_a4chk);
end


%% Compare Difference between V_ss and V_W

if (bl_print_a4chk_verbose)
    mn_V_gain_check = V_U - V_unemp;
    mn_V_gain_frac_check = (V_U - V_unemp)./V_unemp;
    mp_container_map = containers.Map('KeyType','char', 'ValueType','any');
    mp_container_map('V_U') = V_U;
    mp_container_map('V_unemp') = V_unemp;
    mp_container_map('V_U_minus_V_unemp') = mn_V_gain_check;
    mp_container_map('V_U_minus_V_unemp_divide_V_unemp') = mn_V_gain_frac_check;
    ff_container_map_display(mp_container_map);
end

end

% this function is in fact identical to ffi_frac0t1_find_a_working_vec from
% snw_a4chk_wrk_bisec_vec.m
function [ar_root_zero, ar_a_aux_amz] = ...
    ffi_frac0t1_find_a_unemp_vec(...
    ar_aux_change_frac_amz, ...
    ar_a_amz, ar_inc_unemp_amz, ar_spouse_unemp_amz, ...
    welf_checks, TR, r, fl_max_trchk_perc_increase)
    
    % Max A change to account for check
    fl_a_aux_max = TR*welf_checks*fl_max_trchk_perc_increase;    
    
    % Level of A change
    ar_a_aux_amz = ar_a_amz + ar_aux_change_frac_amz.*fl_a_aux_max;
    
    % Account for Interest Rates
    ar_r_gap = (1+r).*(ar_a_amz - ar_a_aux_amz);
    
    % Account for tax, inc changes by r
    ar_tax_gap = ...
          max(0, Tax(ar_inc_unemp_amz, ar_spouse_unemp_amz)) ...
        - max(0, Tax(ar_inc_unemp_amz - ar_a_amz*r + ar_a_aux_amz*r, ar_spouse_unemp_amz));
    
    % difference equation f(a4chkchange)=0
    ar_root_zero = TR*welf_checks + ar_r_gap - ar_tax_gap;
end