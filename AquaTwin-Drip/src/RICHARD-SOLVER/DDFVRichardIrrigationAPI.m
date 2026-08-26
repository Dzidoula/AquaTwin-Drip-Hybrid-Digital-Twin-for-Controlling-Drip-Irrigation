function [solution, Erreur]=DDFVRichardIrrigationAPI(psi_old,J,culture,typeSol,lat,lon,Tmax,T,RH,u2,Rs,alpha_vg,n_vg, m_vg,theta_s, theta_r,k_s)
    
    % Implementation de l'equation de Richards avec conditions aux limites
    % physiques pour le systeme d'irrigation par la Methode des Volumes Finis
    % en Dualite Discrete(DDFV)
    
    AireTerrain=AireTerrainP();
    [X_all,Y_all,Xp,Yp,n_prim,n_dual,total_dof]=MeshGrid();
    [r_emitter, q_irr,Efficience]=parameterGoutteur();
    [max_iter,tol,t]=valorsForSimulation((max(Tmax)));
    [h,r,zmax]=coordonnesPlot();
    Psi_solution=zeros(length(t),total_dof);
    Psi_solution(1,:)=psi_old;
    [psi_omega,psi_c,psi_h,ro,Aire,d_r,phi]=parametresSource(total_dof,culture,typeSol);
    Erreur=zeros(1,length(t));
    ind=2;
    dt=1;
    N = 1/h;   % nombre de cellules par dimension
    psi_current = psi_old;
    K=TenseurSol(typeSol,k_s);
    D = (10^(10))*r*K; % Tenseur de permeabilite
    %[alpha_vg,n_vg, m_vg,theta_s, theta_r,k_s]=vanMualemParametersValor(lat,lon);
    [C,theta_func,kr_func,K_func]=VanMualemParameter(theta_s,theta_r,alpha_vg,n_vg,m_vg,k_s);
    k_val_=K_func(psi_current);
    ETo=CalculEvapotranspirationJournaliere(J,culture,typeSol,lat,lon,T,RH,u2,Rs); %J : jour julien
    Tpot=TranspirationPotentielle(ETo,J,culture); % Calcul de la transpiration potentielle.
    fprintf('Temps Irrigation pour chaque plant: %d', mean(Tmax));
    fprintf('Volume Eau Totale Necesaire %d', ETo*AireTerrain);
    
    for nt = 2:length(t)
         
        if psi_h<psi_current<psi_omega
            alpha_=@(psi_sol)1;
        elseif psi_c<psi_current<psi_h
            alpha_=@(psi_sol)(psi_sol-psi_c)/(psi_h-psi_c);
        else
            alpha_=@(psi_sol)0;
        end
        
        fprintf('Pas de temps %d/%d, t = %.10f s\n', nt, length(t), t(nt));
     
        % Initialisation pour la boucle de Picard
        
        for iter = 1:max_iter
            
            % Reinitialisation de la matrice et du second membre a cause de la
            % methode de Picard
            
            A = zeros(total_dof);
            F = zeros(total_dof, 1);
            I=ones(total_dof);

            % ASSEMBLAGE DES EQUATIONS PRIMALES 

            for i = 1:N
                for j = 1:N
                    idx = (j-1)*N + i;
                    xc = (i-0.5)*h;
                    yc = (j-0.5)*h;

                    % Coefficients alpha (tenseur constant)
                    D_ij = D; D_ip1j = D; D_im1j = D; D_ijp1 = D; D_ijm1 = D;

                    % Calcul des coefficients alpha (discretisation DDFV)
                    
                    alpha_center = 2*D_ij(2,2)*D_ijp1(2,2)/(D_ij(2,2)+D_ijp1(2,2)) + ...
                                   2*D_ij(2,2)*D_ijm1(2,2)/(D_ij(2,2)+D_ijm1(2,2)) + ...
                                   2*D_ij(1,1)*D_im1j(1,1)/(D_ij(1,1)+D_im1j(1,1)) + ...
                                   2*D_ij(1,1)*D_ip1j(1,1)/(D_ij(1,1)+D_ip1j(1,1));

                    alpha_north = -2*D_ij(2,2)*D_ijp1(2,2)/(D_ij(2,2)+D_ijp1(2,2));
                    alpha_south = -2*D_ij(2,2)*D_ijm1(2,2)/(D_ij(2,2)+D_ijm1(2,2));
                    alpha_east = -2*D_ij(1,1)*D_ip1j(1,1)/(D_ij(1,1)+D_ip1j(1,1));
                    alpha_west = -2*D_ij(1,1)*D_im1j(1,1)/(D_ij(1,1)+D_im1j(1,1));

                    alpha_ne = -(D_ij(2,2)*D_ijp1(2,1) + D_ijp1(2,2)*D_ij(2,1))/(D_ij(2,2)+D_ijp1(2,2)) - ...
                               (D_ij(1,1)*D_ip1j(1,2) + D_ip1j(1,1)*D_ij(1,2))/(D_ij(1,1)+D_ip1j(1,1));

                    alpha_nw = (D_ij(2,2)*D_ijp1(2,1) + D_ijp1(2,2)*D_ij(2,1))/(D_ij(2,2)+D_ijp1(2,2)) + ...
                               (D_ij(1,1)*D_im1j(1,2) + D_im1j(1,1)*D_ij(1,2))/(D_ij(1,1)+D_im1j(1,1));

                    alpha_se = (D_ij(2,2)*D_ijm1(2,1) + D_ijm1(2,2)*D_ij(2,1))/(D_ij(2,2)+D_ijm1(2,2)) + ...
                               (D_ij(1,1)*D_ip1j(1,2) + D_ip1j(1,1)*D_ij(1,2))/(D_ij(1,1)+D_ip1j(1,1));

                    alpha_sw = -(D_ij(2,2)*D_ijm1(2,1) + D_ijm1(2,2)*D_ij(2,1))/(D_ij(2,2)+D_ijm1(2,2)) - ...
                               (D_ij(1,1)*D_im1j(1,2) + D_im1j(1,1)*D_ij(1,2))/(D_ij(1,1)+D_im1j(1,1));

                    % Evaluation des coefficients non lineaires
                    psi_val = psi_current(idx);
                    C_val = C(psi_val);
                    k_val = k_val_(idx);

                    if C_val ~= 0
                        factor = dt / (r * C_val);
                    else
                        factor = dt / r;
                    end

                    % Multiplication par le facteur
                    A(idx, idx) = alpha_center * factor*k_val;

                    if j < N

                        idx_north = (j)*N + i;
                        k_val = k_val_(idx_north);
                        A(idx, idx_north) = alpha_north * factor*k_val;
                    end
                    if j > 1
                        idx_south = (j-2)*N + i;
                        k_val = k_val_(idx_south);
                        A(idx, idx_south) = alpha_south * factor*k_val;
                    end
                    if i < N
                        idx_east = (j-1)*N + (i+1);
                        k_val = k_val_(idx_east);
                        A(idx, idx_east) = alpha_east * factor*k_val;
                    end
                    if i > 1
                        idx_west = (j-1)*N + (i-1);
                        k_val = k_val_(idx_west);
                        A(idx, idx_west) = alpha_west * factor*k_val;
                    end
                    if i < N && j < N
                        idx_ne = n_prim + (j)*(N+1) + (i+1);
                        k_val = k_val_(idx_ne);
                        A(idx, idx_ne) = alpha_ne * factor*k_val;
                    end
                    if i > 1 && j < N
                        idx_nw = n_prim + (j)*(N+1) + i;
                        k_val = k_val_(idx_nw);
                        A(idx, idx_nw) = alpha_nw * factor*k_val;
                    end
                    if i < N && j > 1
                        idx_se = n_prim + (j-1)*(N+1) + (i+1);
                        k_val = k_val_(idx_se);
                        A(idx, idx_se) = alpha_se * factor*k_val;
                    end
                    if i > 1 && j > 1
                        idx_sw = n_prim + (j-1)*(N+1) + i;
                        k_val = k_val_(idx_sw);
                        A(idx, idx_sw) = alpha_sw * factor*k_val;
                    end

                    % Terme source (second membre)
                    S_pot=Aire*Tpot*ro(xc,yc)*phi(t(nt))*10^(-3)/dt;
                    S_reel=S_pot(idx)*alpha_(psi_current);
                    F(idx) = h^2 *S_reel(idx)/C_val;
                end
            end

            % ASSEMBLAGE DES EQUATIONS DUALES
            for i = 0:N
                for j = 0:N
                    idx_dual = n_prim + j*(N+1) + i + 1;
                    k_val = k_val_(idx_dual);

                    if i > 0 && i < N && j > 0 && j < N
                        D_ij = D; D_ip1j = D; D_im1j = D; D_ijp1 = D; D_ijm1 = D;
                        D_ip1jp1 = D;

                        psi_val = psi_current(idx_dual);
                        C_val = C(psi_val);

                        if C_val ~= 0
                            factor = dt / (r * C_val);
                        else
                            factor = dt / r;
                        end

                        % Coefficient diagonal beta
                        k_val = k_val_(idx_dual);
                        beta_center = (D_ijp1(2,2) + D_ip1jp1(2,2))/2 - ...
                                     (D_ip1jp1(1,2) - D_ijp1(1,2))^2/(2*(D_ijp1(1,1) + D_ip1jp1(1,1))) + ...
                                     (D_ij(2,2) + D_ip1j(2,2))/2 - ...
                                     (D_ip1j(1,2) - D_ij(1,2))^2/(2*(D_ij(1,1) + D_ip1j(1,1))) + ...
                                     (D_ip1jp1(1,1) + D_ip1j(1,1))/2 - ...
                                     (D_ip1jp1(2,1) - D_ip1j(2,1))^2/(2*(D_ip1jp1(2,2) + D_ip1j(2,2))) + ...
                                     (D_ij(1,1) + D_ijp1(1,1))/2 - ...
                                     (D_ijp1(2,1) - D_ij(2,1))^2/(2*(D_ijp1(2,2) + D_ij(2,2)));

                        A(idx_dual, idx_dual) = beta_center * factor*k_val;

                        % Voisins duaux
                        if j < N-1
                            idx_north = n_prim + (j+1)*(N+1) + i + 1;
                            k_val = k_val_(idx_north);
                            beta_north = -(D_ijp1(2,2) + D_ip1jp1(2,2))/2 + ...
                                        (D_ip1jp1(1,2) - D_ijp1(1,2))^2/(2*(D_ijp1(1,1) + D_ip1jp1(1,1)));
                            A(idx_dual, idx_north) = beta_north * factor*k_val;
                        end
                        if j > 1
                            idx_south = n_prim + (j-1)*(N+1) + i + 1;
                            k_val = k_val_(idx_south);
                            beta_south = -(D_ij(2,2) + D_ip1j(2,2))/2 + ...
                                        (D_ip1j(1,2) - D_ij(1,2))^2/(2*(D_ij(1,1) + D_ip1j(1,1)));

                            A(idx_dual, idx_south) = beta_south * factor*k_val;
                        end
                        if i < N-1
                            idx_east = n_prim + j*(N+1) + i + 2;
                            k_val = k_val_(idx_east);
                            beta_east = -(D_ip1jp1(1,1) + D_ip1j(1,1))/2 + ...
                                       (D_ip1jp1(2,1) - D_ip1j(2,1))^2/(2*(D_ip1jp1(2,2) + D_ip1j(2,2)));
                            A(idx_dual, idx_east) = beta_east * factor*k_val;
                        end
                        if i > 1
                            idx_west = n_prim + j*(N+1) + i;
                            k_val = k_val_(idx_west);
                            beta_west = -(D_ij(1,1) + D_ijp1(1,1))/2 + ...
                                       (D_ijp1(2,1) - D_ij(2,1))^2/(2*(D_ijp1(2,2) + D_ij(2,2)));
                            A(idx_dual, idx_west) = beta_west * factor*k_val;
                        end

                        % Voisins primaux connectes
                        if i >= 1 && i <= N && j >= 1 && j <= N
                            idx_prim = (j-1)*N + i;
                            k_val = k_val_(idx_prim);
                            beta_ij = -(D_ip1j(1,1)*D_ij(2,1) + D_ij(1,1)*D_ip1j(2,1))/(D_ij(1,1) + D_ip1j(1,1)) - ...
                                      (D_ijp1(2,2)*D_ij(1,2) + D_ij(2,2)*D_ijp1(1,2))/(D_ij(2,2) + D_ijp1(2,2));
                            A(idx_dual, idx_prim) = beta_ij * factor*k_val;
                        end
                        if i >= 1 && i <= N && j+1 >= 1 && j+1 <= N
                            idx_prim = (j)*N + i;
                            k_val = k_val_(idx_prim);
                            beta_ijp1 = (D_ijp1(1,1)*D_ip1jp1(2,1) + D_ip1jp1(1,1)*D_ijp1(2,1))/(D_ijp1(1,1) + D_ip1jp1(1,1)) + ...
                                        (D_ijp1(2,2)*D_ij(1,2) + D_ij(2,2)*D_ijp1(1,2))/(D_ij(2,2) + D_ijp1(2,2));
                            A(idx_dual, idx_prim) = beta_ijp1 * factor*k_val;
                        end
                        if i+1 >= 1 && i+1 <= N && j >= 1 && j <= N
                            idx_prim = (j-1)*N + (i+1);
                            k_val = k_val_(idx_prim);
                            beta_ip1j = (D_ip1j(1,1)*D_ij(2,1) + D_ij(1,1)*D_ip1j(2,1))/(D_ij(1,1) + D_ip1j(1,1)) + ...
                                       (D_ip1j(2,2)*D_ip1jp1(1,2) + D_ip1jp1(2,2)*D_ip1j(2,1))/(D_ip1j(2,2) + D_ip1jp1(2,2));
                            A(idx_dual, idx_prim) = beta_ip1j * factor*k_val;
                        end
                        if i+1 >= 1 && i+1 <= N && j+1 >= 1 && j+1 <= N
                            idx_prim = (j)*N + (i+1);
                            k_val = k_val_(idx_prim);
                            beta_ip1jp1 = -(D_ijp1(1,1)*D_ip1jp1(2,1) + D_ip1jp1(1,1)*D_ijp1(2,1))/(D_ijp1(1,1) + D_ip1jp1(1,1)) - ...
                                          (D_ip1j(2,2)*D_ip1jp1(1,2) + D_ip1jp1(2,2)*D_ip1j(2,1))/(D_ip1j(2,2) + D_ip1jp1(2,2));
                            A(idx_dual, idx_prim) = beta_ip1jp1 * factor*k_val;
                        end

                        % Terme source dual
                        xc = i*h;
                        yc = j*h;

                        S_pot=Tpot*Aire*ro(xc,yc)*phi(t(nt))*10^(-3)/dt;
                        S_reel=S_pot(idx)*alpha_(psi_current);
                        F(idx_dual) = h^2 *S_reel(idx)/C_val;
                        
                    end
                end
            end

            %% CONDITIONS AUX LIMITES 
            % Conditions aux limites de Dirichlet (fond et axe deja pris en compte)
            % Pour l'instant, pas de Dirichlet imposee
            % Condition de Neumann sur le bord irrigue (surface, r < r_emitter) 
            % On parcourt les noeuds du bord superieur (z = 0)
            
            for i = 1:N
                xc = (i-0.5)*h;
                if xc <= r_emitter
                    
                    % Bord irrigue : flux impose q_irr
                    % Trouver l'index du noeud primal correspondant

                    idx = (0)*N + i;  % j=1
                    % Contribution au second membre pour la condition de Neumann
                    % (integrale sur l'element de bord)

                    k_val = k_val_(idx);
                    F(idx) = F(idx) + ((q_irr/(2*pi*r*d_r))-k_val) * h;
                end
            end

            % Condition de Neumann homogene sur le bord atmospherique (surface, r >= r_emitter) 
            % Pas de contribution supplementaire (flux nul par defaut)
            % Condition de Dirichlet homogene sur les bords lateraux et inferieur 
            % Bord gauche (r = 0)
            
            for j = 1:N
                idx = (j-1)*N + 1;
                A(idx, :) = 0;
                A(idx, idx) = 1;
                F(idx) = 0;
            end

            % Bord droit (r = Rmax)
            for j = 1:N
                idx = (j-1)*N + N;
                A(idx, :) = 0;
                A(idx, idx) = 1;
                F(idx) = 0;
            end

            % Bord inferieur (z = Zmin)
            for i = 1:N
                idx = (N-1)*N + i;
                A(idx, :) = 0;
                A(idx, idx) = 1;
                F(idx) = 0;
            end

            % Conditions sur les noeuds duaux (bords)
            for i = 0:N
                % Bord inferieur dual (j=0)
                idx = n_prim + 0*(N+1) + i + 1;
                A(idx, :) = 0;
                A(idx, idx) = 1;
                F(idx) = 0;

                % Bord superieur dual (j=N)
                idx = n_prim + N*(N+1) + i + 1;
                A(idx, :) = 0;
                A(idx, idx) = 1;
                F(idx) = 0;
            end

            for j = 0:N
                % Bord gauche dual (i=0)
                idx = n_prim + j*(N+1) + 0 + 1;
                A(idx, :) = 0;
                A(idx, idx) = 1;
                F(idx) = 0;

                % Bord droit dual (i=N)
                idx = n_prim + j*(N+1) + N + 1;
                A(idx, :) = 0;
                A(idx, idx) = 1;
                F(idx) = 0;
            end

            %% RESOLUTION MATRICIELLE
            psi_inc = (A+I) \ F;
            
            %% RESOLUTION TEMPORELLE PAR LA METHODE D'EULER EXPLICITE
            psi_new=psi_current +psi_inc ;

            %% VERIFICATION DE LA CONVERGENCE A CAUSE DE LA METHODE D'ITERATION DE PICARD POUR LA NON-LINEARITE
            % BUG CORRIGE : comparait psi_new a psi_inc, alors que
            % psi_new = psi_current + psi_inc par construction (ligne
            % ci-dessus) — donc `psi_new - psi_inc` valait toujours
            % psi_current, quel que soit l'ecart reel entre deux iterations.
            % Le critere de convergence de Picard ne mesurait donc rien de
            % pertinent (d'ou "convergence non atteinte" quasi systematique).
            % Formule correcte deja utilisee dans DDFVRichardIrrigation.m
            % (la variante sans meteo) : comparer aux iterations successives.
            err = norm(psi_new - psi_current);
            erreur = err / (norm(psi_new) + eps);
            
            if erreur <tol && iter< max_iter
                fprintf('Convergence a l''iteration %d, erreur = %.8e\n', iter, erreur);
                psi_current = psi_new;
                break;
            else
        
        
                if iter == max_iter
                    psi_current = psi_new;
                    fprintf('Attention : convergence non atteinte apres %d iterations, erreur = %.2e\n', max_iter, err);
                end
            end
       end
    
    % Mise a jour pour le pas de temps suivant
    psi_solution = psi_current;
    
    %% METHODE PROPOSEE POUR LA STABILISATION DE LA CONVERGENCE
    k_val__=K_func(psi_current);
    k_val_=(k_val+k_val__)/2 ;
    
    % Solution
    Psi_solution(ind,:)=psi_solution;
    ind=ind+1;
    Erreur(nt)=erreur;
    

    
    
    end
    
    %% SOLUTION FINALE
    solution = Psi_solution;

     

end 