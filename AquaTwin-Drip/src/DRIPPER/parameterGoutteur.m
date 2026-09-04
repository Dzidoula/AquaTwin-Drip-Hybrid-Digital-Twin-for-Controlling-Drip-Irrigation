function[r_emitter, q_irr,Efficience]=parameterGoutteur()

 % Parametres d'irrigation
 %r_emitter = 0.005;     % rayon du goutteur (m)
 %q_irr=1.111e-6;        % debit d'irrigation (m^3/s)
 Efficience=0.9;
 %q_irr=7.1e-10;
 r_emitter = 0.005;
 q_irr=4.444*10^(-7);

 % Le farmer choisit le debit de son propre goutteur (liste deroulante
 % cote appli, en L/h) plutot que de subir cette valeur fixe. Plutot que
 % de changer la signature de cette fonction (appelee sans argument par
 % 18 fichiers du moteur), le backend passe la valeur choisie via une
 % variable d'environnement au sous-processus Octave — meme motif que
 % PYTHON_CMD/ENGINE_OCTAVE_CMD.
 override = getenv('Q_IRR_OVERRIDE_M3S');
 if ~isempty(override)
     override_val = str2double(override);
     if ~isnan(override_val) && override_val > 0
         q_irr = override_val;
     end
 end

end
    

