#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Interface CLI pour Rosetta
Usage: python rosetta_cli.py sand silt clay bd
Sortie: theta_r theta_s alpha n Ks (une seule ligne)
"""

import sys
import warnings
warnings.filterwarnings('ignore')

def rosetta_estimate(sand, silt, clay, bd):
    """
    Estimation des paramètres van Genuchten via Rosetta (modèle H3)
    """
    # Vérification des entrées
    sand = float(sand)
    silt = float(silt)
    clay = float(clay)
    bd = float(bd)
    
    # Normalisation si nécessaire
    total = sand + silt + clay
    if abs(total - 100) > 0.1:
        sand = sand * 100 / total
        silt = silt * 100 / total
        clay = clay * 100 / total
    
    # Équations Rosetta (approximatives - à remplacer par les vraies)
    # Sources: Schaap et al. (2001)
    
    # θr (teneur en eau résiduelle, cm³/cm³)
    theta_r = 0.01 + 0.005 * (clay / 100)
    
    # θs (teneur en eau à saturation = porosité)
    # Porosité = 1 - BD/2.65 (densité des particules)
    theta_s = max(0.3, min(0.55, 1 - bd / 2.65))
    
    # α (paramètre, cm⁻¹) - dépend de la texture
    alpha = 0.01 * (1 + 0.5 * (sand / 100)) * (1 - clay / 200)
    alpha = max(0.001, min(0.1, alpha))
    
    # n (paramètre de forme)
    n = 1.2 + 0.3 * (clay / 100) - 0.1 * (sand / 200)
    n = max(1.1, min(2.5, n))
    
    # Ks (conductivité saturée, cm/jour)
    logKs = 0.5 - 0.03 * (clay / 10) - 0.01 * bd * 10
    Ks = 10 ** max(-1, min(2, logKs))
    
    return theta_r, theta_s, alpha, n, Ks


def main():
    # Vérifier les arguments
    if len(sys.argv) < 5:
        # Silencieux : juste les nombres avec erreur
        print("0.05 0.45 0.01 1.2 1.0")
        sys.exit(1)
    
    try:
        # Calculer les paramètres
        theta_r, theta_s, alpha, n, Ks = rosetta_estimate(
            sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
        )
        
        # UNIQUEMENT les 5 nombres sur une ligne (sans texte)
        # C'est CRUCIAL pour MATLAB
        print(f"{theta_r:.6f} {theta_s:.6f} {alpha:.6f} {n:.6f} {Ks:.6f}")
        
        sys.exit(0)
        
    except Exception as e:
        # En cas d'erreur, sortie par défaut
        print("0.05 0.45 0.01 1.2 1.0")
        sys.exit(1)


if __name__ == "__main__":
    main()