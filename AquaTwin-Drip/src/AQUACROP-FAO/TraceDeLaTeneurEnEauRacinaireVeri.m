function Theta_root=TraceDeLaTeneurEnEauRacinaireVeri(Theta_r,Psi_solution,J,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg, m_vg,theta_s, theta_r,k_s)

[X_all,Y_all,Xp,Yp,n_prim,n_dual,total_dof]=MeshGrid();
[r_emitter, q_irr,Efficience]=parameterGoutteur();
[T_,V]=TempsEtVolumeEauNecessaireIrrigation(q_irr,total_dof,J,culture,typeSol,lat,lon,T,RH,u2,Rs,alpha_vg,n_vg,m_vg,theta_s,theta_r,k_s)
[max_iter,tol,t]=valorsForSimulation(max(T_));
[h,r,zmax]=coordonnesPlot();
%[alpha_vg,n_vg, m_vg,theta_s, theta_r,k_s]=vanMualemParametersValor(lat,lon);
[Capacite_hydrique, theta_func,kr_func,K_func]=VanMualemParameter(theta_s,theta_r,alpha_vg,n_vg,m_vg,k_s);
[X_all,Y_all,Xp,Yp,n_prim,n_dual,total_dof]=MeshGrid();
[dr,dz,ri,zi,zr,R]=coordonneesRacinaire(r,zmax,total_dof,J,culture);
Theta = theta_func(Psi_solution);
Theta_root = zeros(length(zi),1);


% BUG CORRIGE (meme defaut que TraceTeneurEnEauRacinaireStresseHydriqueEt-
% PotentielHydrique_.m, verifie numeriquement — voir NOTES-POUR-ALEX.md) :
% `theta_mean` inclut un facteur `dz` jamais annule par l'ancienne
% normalisation `2/(R^2*zr)`, et `zr` n'a pas sa place dans une moyenne a
% une seule profondeur z fixee. theta_func(psi) est bornee dans
% [theta_r, theta_s] par construction (van Genuchten) ; diviser par la
% somme reelle des poids utilises (`weight_sum`) au lieu d'une constante
% analytique qui ne correspond pas a ce qui est reellement somme rend
% `theta_root` a nouveau garanti dans cette plage.
for i = 1:length(zi)

    theta_mean = 0;   % RESET REQUIRED
    weight_sum = 0;

    for j = 1:length(ri)-1
        w = ri(j) * dr * dz;
        theta_mean = theta_mean + Theta(i,j) * w;
        weight_sum = weight_sum + w;
    end

    theta_root = theta_mean / weight_sum;
    Theta_root(i) = theta_root+Theta_r(i);

end


plot(t, Theta_root, 'LineWidth', 2);
xlabel('Temps');
ylabel('\theta_{root}');
title('Teneur en eau moyenne racinaire');
grid on;

end