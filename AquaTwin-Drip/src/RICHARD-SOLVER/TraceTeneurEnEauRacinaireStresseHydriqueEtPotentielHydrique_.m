function [SH, Pt, t, Theta_root] = TraceTeneurEnEauRacinaireStresseHydriqueEtPotentielHydrique_(lat, lon, culture, typeSol, Tmax, Psi_solution, tr, J, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s)
% NOTE (fork) : main.m appelle cette fonction en demandant 4 valeurs de
% retour ([SH, Pt, t_t, Theta_root]), mais elle n'en definissait que 2 —
% alors que t et Theta_root sont deja calcules en interne (lignes
% ci-dessous). Ce chemin de main.m n'avait donc jamais pu s'executer
% jusqu'au bout. Expose simplement ce qui existait deja, sans changer le
% calcul.

    [Hcc, RU, p_s, theta_actuel] = Solfeatures(J, culture, typeSol, lat, lon, alpha_vg, n_vg, m_vg, theta_s, theta_r, k_s);
    [X_all, Y_all, Xp, Yp, n_prim, n_dual, total_dof] = MeshGrid();
    [max_iter, tol, t] = valorsForSimulation(max(Tmax));
    [h, r, zmax] = coordonnesPlot();
    
    % Parametres de van Genuchten-Mualem
    [Capacite_hydrique, theta_func, kr_func, K_func] = VanMualemParameter(theta_s, theta_r, alpha_vg, n_vg, m_vg, k_s);
    [dr, dz, ri, zi, zr, R] = coordonneesRacinaire(r,zmax,total_dof,J,culture);
    
    % Calcul de la teneur en eau initiale
    Theta = theta_func(Psi_solution);
    Theta_root = zeros(length(zi), 1);
    t = t + tr;

    % Calcul de la teneur en eau moyenne racinaire
    for i = 1:length(zi)
        theta_mean = 0;
        for j = 1:length(ri)-1
            theta_mean = theta_mean + Theta(i, j) * ri(j) * dr * dz
        end
        theta_root = (2/((R^2) * max(zr)))* theta_mean;
        Theta_root(i) = theta_root;
    end

    % Creation de la figure
    figure;
    
    % 1. Teneur en eau
    subplot(3, 1, 1);
    plot(t, Theta_root, 'LineWidth', 2);
    xlabel('Temps (s)');
    ylabel('\theta_{root} (m^3/m^3)');
    title('Teneur en eau moyenne racinaire apres irrigation');
    grid on;

    % 2. Calcul du stress hydrique
    SH = (Hcc - Theta_root) / RU;
    
    % Stress hydrique
    subplot(3, 1, 2);
    plot(t, SH, 'LineWidth', 2);
    xlabel('Temps (s)');
    ylabel('Stress hydrique Ks');
    title('Stress hydrique apres irrigation');
   
    % 3. Potentiel hydrique du sol
    % Verifions que Theta_root est un vecteur colonne

    if size(Theta_root, 1) == 1
        Theta_root = Theta_root';
    end
    
    
    % Potentiel hydrique
    phi_s=modeleRawlsSaxton(lat,lon,theta_r, theta_s, alpha_vg, n_vg, k_s);
    Pt=phi_s(Theta_root);
    
    subplot(3, 1, 3);
    plot(t, Pt, 'LineWidth', 2);
    xlabel('Temps (s)');
    ylabel('Potentiel hydrique \psi (Pa)');
    title('Potentiel hydrique apres irrigation');
    grid on;
    

end