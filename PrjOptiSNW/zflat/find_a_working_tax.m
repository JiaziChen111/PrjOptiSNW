function F=find_a_working_tax(a_aux,j,a,eta,educ,married,kids,TR,welf_checks,a2_COVID)

global theta r agrid epsilon eta_grid SS

[inc,earn]=individual_income(j,a,eta,educ);
spouse_inc=spousal_income(j,educ,kids,earn,SS(j,educ));

% inc=r*agrid(a)+epsilon(j,educ)*theta*exp(eta_grid(eta))+SS(j,educ);
% spouse_inc=spousal_income(j,educ,kids,epsilon(j,educ)*theta*exp(eta_grid(eta)),SS(j,educ));

resource_target=(1+r)*agrid(a)+epsilon(j,educ)*theta*exp(eta_grid(eta))+SS(j,educ)+(married-1)*spouse_inc-max(0,Tax_COVID(inc,(married-1)*spouse_inc,a2_COVID))+TR*welf_checks;

[inc,earn]=individual_income(j,a_aux,eta,educ);
spouse_inc=spousal_income(j,educ,kids,earn,SS(j,educ));

% inc=r*a_aux+epsilon(j,educ)*theta*exp(eta_grid(eta))+SS(j,educ);
% spouse_inc=spousal_income(j,educ,kids,epsilon(j,educ)*theta*exp(eta_grid(eta)),SS(j,educ));

resource_aux=(1+r)*a_aux+epsilon(j,educ)*theta*exp(eta_grid(eta))+SS(j,educ)+(married-1)*spouse_inc-max(0,Tax_COVID(inc,(married-1)*spouse_inc,a2_COVID));

F=resource_target-resource_aux;

end


