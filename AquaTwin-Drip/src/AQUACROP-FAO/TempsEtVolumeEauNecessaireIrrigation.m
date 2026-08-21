function [T,V]=TempsEtVolumeEauNecessaireIrrigation(q_irr,total_dof,J,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s,psi_old)

    [X_all,Y_all,Xp,Yp,n_prim,n_dual,total_dof]=MeshGrid();
    [psi_omega,psi_c,psi_h,ro,A,d_r,phi]=parametresSource(total_dof,culture,typeSol);
    [C,theta_func,kr_func,K_func]=VanMualemParameter(theta_s,theta_r,alpha_vg,n_vg,m_vg,k_s);
    [r_emitter, q_irr,Efficience]=parameterGoutteur();
    [h,r,zmax]=coordonnesPlot();
    [dr,dz,ri,zi,zr,R]=coordonneesRacinaire(r,zmax,total_dof,J,culture);
    % `psi_old` optionnel (18e argument) pour les appelants (ex. l'API
    % backend via dailyIrrigationRecommendation.m) qui font evoluer l'etat
    % du sol jour apres jour : sans lui, on retombe sur le comportement
    % d'origine (etat initial recalcule a chaque appel) pour ne pas casser
    % les scripts historiques (main.m, Trace2D*, Animation2DIrrigation...)
    % qui n'ont jamais fourni cet argument.
    if nargin < 18 || isempty(psi_old)
        psi_old =InitialSolution(lat,lon,alpha_vg,n_vg, m_vg,theta_s, theta_r,k_s);
    end
    Psi_solution=zeros(length(zi),length(ri));
    Psi_solution(1,:)=psi_old(1);
    Theta = theta_func(Psi_solution);
    Theta_root = zeros(length(zi),1);
    [Hcc,RU,p_s,theta_actuel]=Solfeatures(J,culture,typeSol,lat,lon,alpha_vg,n_vg, m_vg,theta_s, theta_r,k_s);

    for i = 1:length(zi)

        theta_mean = 0;   % RESET OBLIGATOIRE

        for j = 1:length(ri)-1
            theta_mean = theta_mean + Theta(i,j) * ri(j) * dr * dz;
        end

        theta_root = (2/(R^2 * zr)) * theta_mean;
        Theta_root(i) = theta_root;

    end
    SH=(Hcc-Theta_root)/RU ;
    [psi_omega,psi_c,psi_h,ro,Aire,d_r,phi]=parametresSource(total_dof,culture,typeSol);
    H=HauteurEauAIrriguer(total_dof,J,culture,typeSol,lat,lon,alpha_vg,n_vg, m_vg,theta_s, theta_r,k_s);
    Te=(10^(-3))*H*Aire/q_irr;
    Vt=q_irr*Te;
    
    ETo=CalculEvapotranspirationJournaliere(J,culture,typeSol,lat,lon,T,RH,u2,Rs);
    Tpot=TranspirationPotentielle(ETo,J,culture);
    ETr=EvapotranspirationRelle(Tpot,ETo,SH,J,culture);
    if (Vt>(ETr/1000))
        V=Vt;
        T=Te;
    else
        V=(ETr)*A*10^(-3);
        T=V/(q_irr);
    end
    
end