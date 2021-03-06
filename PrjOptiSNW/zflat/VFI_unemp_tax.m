function [V_VFI,ap_VFI,cons_VFI,exitflag_VFI]=VFI_unemp_tax(A_aux,B_aux,Aeq,Beq,nonlcon,options,V_ss,xi,b,a2_COVID)

%% Solve optimization problem

global beta theta r agrid epsilon eta_grid SS pi_eta pi_kids psi n_jgrid n_agrid n_etagrid n_educgrid n_marriedgrid n_kidsgrid

V_VFI=NaN(n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid);
ap_VFI=NaN(n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid);
cons_VFI=NaN(n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid);

exitflag_VFI=NaN(n_jgrid,n_agrid,n_etagrid,n_educgrid,n_marriedgrid,n_kidsgrid);

for j=1:n_jgrid % Age
   for a=1:n_agrid % Assets
       for eta=1:n_etagrid % Productivity
           for educ=1:n_educgrid % Educational level
               for married=1:n_marriedgrid % Marital status
                   for kids=1:n_kidsgrid % Number of kids
                        
                       if j<n_jgrid
                           
                           % Solve for next period's assets                   
                           x0=agrid(a); % Initial guess for ap

                           amin=0;
                           [inc,earn]=individual_income(j,a,eta,educ,xi,b);
                           spouse_inc=spousal_income(j,educ,kids,earn,SS(j,educ));
                           
%                          inc=r*agrid(a)+( epsilon(j,educ)*theta*exp(eta_grid(eta)) )*(xi+b*(1-xi))+SS(j,educ);
%                          spouse_inc=spousal_income(j,educ,kids,( epsilon(j,educ)*theta*exp(eta_grid(eta)) )*(xi+b*(1-xi)),SS(j,educ));

                           amax=min(agrid(end),(1+r)*agrid(a)+( epsilon(j,educ)*theta*exp(eta_grid(eta)) )*(xi+b*(1-xi))+SS(j,educ)+(married-1)*spouse_inc-max(0,Tax_COVID(inc,(married-1)*spouse_inc,a2_COVID)) );

                           [ap_aux,~,exitflag_VFI(j,a,eta,educ,married,kids)]=fmincon(@(x)value_func_aux_unemp_tax(x,j,a,eta,educ,married,kids,V_ss,xi,b,a2_COVID),x0,A_aux,B_aux,Aeq,Beq,amin,amax,nonlcon,options);

                           ind_aux=find(agrid<=ap_aux,1,'last');

                           % Linear interpolation
                           if ap_aux==0
                               inds(1)=1;
                               inds(2)=1;                       
                               vals(1)=1;
                               vals(2)=0;

                           elseif ap_aux==agrid(n_agrid)
                               inds(1)=n_agrid;
                               inds(2)=n_agrid;                       
                               vals(1)=1;
                               vals(2)=0;

                           else
                               inds(1)=ind_aux;
                               inds(2)=ind_aux+1;                       
                               vals(1)=1-((ap_aux-agrid(inds(1)))/(agrid(inds(2))-agrid(inds(1))));
                               vals(2)=1-vals(1);

                           end

                           cont=0;
                           for etap=1:n_etagrid
                               for kidsp=1:n_kidsgrid
                                   cont=cont+pi_eta(eta,etap)*pi_kids(kids,kidsp,j,educ,married)*(vals(1)*V_ss(j+1,inds(1),etap,educ,married,kidsp)+vals(2)*V_ss(j+1,inds(2),etap,educ,married,kidsp));
                               end
                           end

                           c_aux=(1+r)*agrid(a)+( epsilon(j,educ)*theta*exp(eta_grid(eta)) )*(xi+b*(1-xi))+SS(j,educ)+(married-1)*spouse_inc-max(0,Tax_COVID(inc,(married-1)*spouse_inc,a2_COVID))-ap_aux;

                           ap_VFI(j,a,eta,educ,married,kids)=ap_aux;
                           cons_VFI(j,a,eta,educ,married,kids)=c_aux;

                           V_VFI(j,a,eta,educ,married,kids)=utility(c_aux,married,kids)+beta*psi(j)*cont;

                           % Check end point of asset grid (ap=0)
                           c_aux3=(1+r)*agrid(a)+( epsilon(j,educ)*theta*exp(eta_grid(eta)) )*(xi+b*(1-xi))+SS(j,educ)+(married-1)*spouse_inc-max(0,Tax_COVID(inc,(married-1)*spouse_inc,a2_COVID));

                           cont=0;
                           for etap=1:n_etagrid
                               for kidsp=1:n_kidsgrid
                                   cont=cont+pi_eta(eta,etap)*pi_kids(kids,kidsp,j,educ,married)*V_ss(j+1,1,etap,educ,married,kidsp);
                               end
                           end
                           V_aux3=utility(c_aux3,married,kids)+beta*psi(j)*cont;

                           if V_aux3>V_VFI(j,a,eta,educ,married,kids)
                               ap_VFI(j,a,eta,educ,married,kids)=0;
                               cons_VFI(j,a,eta,educ,married,kids)=c_aux3;

                               V_VFI(j,a,eta,educ,married,kids)=V_aux3;
                           end

                           if cons_VFI(j,a,eta,educ,married,kids)<=0
                              disp([j,a,eta,educ,married,kids,cons_VFI(j,a,eta,educ,married,kids)])
                              error('Non-positive consumption')
                           end

                       elseif j==n_jgrid
                           
                           [inc,earn]=individual_income(j,a,eta,educ,xi,b);
                           spouse_inc=spousal_income(j,educ,kids,earn,SS(j,educ));
                           
%                          inc=r*agrid(a)+( epsilon(j,educ)*theta*exp(eta_grid(eta)) )*(xi+b*(1-xi))+SS(j,educ);
%                          spouse_inc=spousal_income(j,educ,kids,( epsilon(j,educ)*theta*exp(eta_grid(eta)) )*(xi+b*(1-xi)),SS(j,educ));
                           
                           ap_VFI(j,a,eta,educ,married,kids)=0;
                           cons_VFI(j,a,eta,educ,married,kids)=(1+r)*agrid(a)+( epsilon(j,educ)*theta*exp(eta_grid(eta)) )*(xi+b*(1-xi))+SS(j,educ)+(married-1)*spouse_inc-max(0,Tax_COVID(inc,(married-1)*spouse_inc,a2_COVID));

                           if cons_VFI(j,a,eta,educ,married,kids)<=0
                              disp([j,a,eta,educ,married,kids,cons_VFI(j,a,eta,educ,married,kids)])
                              error('Non-positive consumption')
                           end

                           V_VFI(j,a,eta,educ,married,kids)=utility(cons_VFI(j,a,eta,educ,married,kids),married,kids);
                           
                       end

                   end
               end
           end
       end
   end
   
   disp(j)
   
end


end