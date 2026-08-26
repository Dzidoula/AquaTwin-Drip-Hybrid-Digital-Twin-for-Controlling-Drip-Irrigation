# Points à discuter avec Alex

Document de travail — pas un correctif silencieux. Chaque point ci-dessous est soit déjà corrigé (mécanique, sans jugement scientifique), soit explicitement laissé pour décision avec Alex.

## 1. ISRIC SoilGrids ne fonctionne pas pour l'Afrique — remplacé par iSDA Africa

### Le problème

`SoilGrids_Rosetta.m` récupère Sand/Silt/Clay/BD via l'API ISRIC SoilGrids (`rest.isric.org`) pour ensuite les passer à `rosetta_cli.py`. Testé systématiquement le 2026-08-26 avec des requêtes minimales (une seule propriété, profondeur `0-5cm`) :

| Zone testée | Résultat ISRIC |
|---|---|
| Bénin — Bohicon (6.37, 2.39) | `"mean": null` |
| Bénin — Parakou (9.34, 2.63) | `"mean": null` |
| Nigeria — Lagos, Ghana — Accra | `"mean": null` |
| RDC — Kinshasa, Kenya — Nairobi, Égypte — Le Caire | `"mean": null` |
| Espagne du Nord, Inde — Pendjab | `"mean": null` |
| **USA — Iowa, Australie, Brésil/Pérou (Amazonie)** | **valeurs réelles** ✅ |

Reproductible à chaque essai — pas intermittent. Retester la même coordonnée ne change rien. Un lot de 4 requêtes séparées a aussi montré des échecs de connexion complets (HTTP 000/timeout) sur d'autres essais, donc il y a même une seconde panne indépendante (réseau) en plus de celle-ci.

**Conséquence concrète pour ce projet** : `SoilGrids_Rosetta.m` faisait un `error('... probablement océanique')` dès que `Sand`/`Silt`/`Clay`/`BD` valent `NaN` (ligne ~88, avant ce changement). Et `vanMualemParametersValor.m` appelle cette chaîne **sans condition** — même quand l'agriculteur a déjà renseigné son type de sol à l'inscription (voir point 2 ci-dessous). Résultat : tout calcul pour un champ béninois échouait, sauf si sa coordonnée exacte se trouvait déjà dans le cache local par chance.

### La solution testée : iSDA Africa

[iSDA Africa](https://api.isda-africa.com) — service de données de sol construit spécifiquement pour l'Afrique, résolution 30m (vs 250m pour SoilGrids). Testé sur les mêmes coordonnées :

| Coordonnée | Sable | Argile | Silt | Densité apparente |
|---|---|---|---|---|
| Bohicon (6.37, 2.39) | 56% | 26% | 14% | 1,4 g/cm³ |
| Parakou, nord (9.34, 2.63) | 63% | 16% | 18% | 1,4 g/cm³ |
| Cotonou, sud (6.37, 2.42) | 60% | — | — | — |

Toutes les requêtes ont réussi, nord comme sud du pays.

### Ce qui a été fait

- Nouveau fichier `AquaTwin-Drip/src/SOIL-PARAMETER/isda_soil_texture.m` : authentification iSDA (login + cache de token local, renouvelé automatiquement toutes les ~55 min) et récupération de Sand/Silt/Clay/BD.
- `SoilGrids_Rosetta.m` : le bloc d'appel ISRIC est remplacé par un appel à `isda_soil_texture.m`. **Le nom du fichier n'a pas changé** (pour ne pas casser `classifySoilType.m`/`vanMualemParametersValor.m` qui l'appellent), mais son contenu ne touche plus ISRIC du tout — voir le commentaire en tête de fonction.
- Le calcul Rosetta en aval (`rosetta_cli.py`), le cache local par (lat, lon), et la normalisation Sand+Silt+Clay=100% : **inchangés**.
- Testé de bout en bout via Docker/Octave sur une coordonnée béninoise réelle (`dailyIrrigationRecommendation('mais', 6.3703, 2.3912, 15, [], 0, 1, 'sableux')`) : la chaîne complète (`isda_soil_texture` → `SoilGrids_Rosetta` → `vanMualemParametersValor` → `dailyIrrigationRecommendation`, avec les 222 pas de temps du solveur de Richards) tourne sans erreur, converge à chaque pas, et se termine en 162,5s avec un résultat complet :
  `should_irrigate=1 duration_s=26.38 volume=0.0000117 soil_moisture=0.003479 severe_stress=1`.
  Avant ce changement, ce même appel plantait systématiquement sur `SoilGrids_Rosetta.m:89` (`error('...probablement océanique...')`), puisqu'ISRIC renvoie `null` pour cette coordonnée.
- Variables d'environnement requises : `ISDA_USERNAME` / `ISDA_PASSWORD` (jamais commitées, même convention que `DATABASE_URL`).

### Ce qu'il reste à valider avec toi

- **iSDA (30m) n'est pas la même source que SoilGrids (250m)** — méthodologie de calibration différente. Les valeurs numériques peuvent légèrement s'écarter de ce que SoilGrids aurait donné pour le même point. C'est un changement de source de données, pas juste un correctif de robustesse.
- **`vanMualemParametersValor.m` reste appelé sans condition**, même quand l'agriculteur a choisi un type de sol à l'inscription (voir point 2). Ce changement rend cet appel fiable au lieu de planter — mais ne règle pas la question de fond : faut-il l'éviter complètement dans ce cas, avec des paramètres van Genuchten représentatifs par catégorie de sol au lieu de la valeur précise dérivée d'iSDA/Rosetta ?

## 2. Autres bugs confirmés (audit du 26/08, pas encore corrigés)

Ordonnés par sévérité. Aucun n'a été corrigé unilatéralement — ce sont des choix scientifiques, pas des coquilles évidentes.

1. **`PlanteFeatures.m` — `JJ/24`** : compare `JJ/24 <= Lini` où `JJ` est un jour brut et `Lini` déjà en jours. Le stade "Initial" dure ~24× trop longtemps (480 jours pour un maïs à `Lini=20`, cycle de 120 jours).
2. **`PredictPreviousHarvest.m` — `Tr = Tr + Tpot/ETo`** : `ETo` s'annule, donc l'accumulation n'est pas vraiment une transpiration en mm — juste la somme des coefficients culturaux. **Division par zéro possible** si `ETo(i)==0` (nuit) → `Inf`/`NaN` en cascade.
3. **`dailyIrrigationRecommendation.m` — `interp1` heures/secondes** : déjà signalé par toi en commentaire ("A REVOIR avec Alex"). `Temps` est en heures, `t_t` (solveur de Richards) en secondes.
4. **Comparaison chaînée `psi_h<psi_current<psi_omega`** (`DDFVRichardIrrigationAPI.m`/`DDFVRichardIrrigation.m`) : Octave évalue ça comme `(psi_h<psi_current)<psi_omega`, pas un test d'intervalle. Le stress hydrique est mort dans le solveur.
5. **Double négation des seuils** (`parametresSource.m:8-9`) : `SeuilsHydriques.m` renvoie déjà des seuils négatifs, ce bloc les repasse positifs — incohérent avec `psi_omega` resté négatif. Lié au point 4.
6. **`PenmanMontheithParameter.m:28` — `Rn=(1-alpha)*Rs`** : ne calcule que le rayonnement net courtes longueurs d'onde (Rns), omet le terme longwave (Rnl) — FAO-56 demande `Rn = Rns - Rnl`. Surestime ETo systématiquement.
7. **Coefficient de vent `0.208`** (`CalculEvapotranspirationJournaliere.m:16`) au lieu de `0.34` (standard FAO-56 horaire) — à confirmer si c'est une référence différente ou une erreur.
8. **Conversion ETo mm/h→m/s** (`CalculEvapotranspirationJournaliere.m:18`) jamais reconvertie en aval, alors qu'ETo est utilisé en mm/jour partout ailleurs — écart d'un facteur ~3,6 millions dans la branche météo (`T>=0`). Indépendant du point 2, mais s'additionne.
9. **`Vt>(ETr/1000)`** (`TempsEtVolumeEauNecessaireIrrigation.m:45`) : compare un volume (m³) à une hauteur d'eau (m) — dimensions incompatibles. La ligne 49 juste après multiplie correctement par la surface `A`.
10. **`TenseurSol.m`** : `r=1` codé en dur avant le `switch` → chaque type de sol produit le même tenseur isotrope, malgré des commentaires décrivant une anisotropie différenciée. Code mort.
11. **`StressCoefficient.m`** : pas de `lower()` ni de cas `otherwise`, contrairement à `PlanteFeatures.m`/`EspacementCulture.m`. Une casse différente sur `culture` plante à la ligne 18.
12. **Facteur `10^10`** (`DDFVRichardIrrigationAPI.m:21`) sur la conductivité hydraulique, sans justification trouvée — possiblement lié à la non-convergence.
13. **Convergence Picard corrigée** (déjà fait, `324dfde`) : le critère comparait une quantité qui valait algébriquement toujours `psi_current` (`psi_new - psi_inc`, alors que `psi_new = psi_current + psi_inc` par construction). Corrigé en `psi_new - psi_current`, conforme à la formule déjà correcte dans `DDFVRichardIrrigation.m` (branche `T<0`).
14. **La non-convergence n'est toujours pas remontée à l'API** : même après la correction du point 13, un run qui ne converge pas en 30 itérations continue avec le dernier `psi_new` sans exception ni indicateur dans le JSON de sortie — indissociable d'un run correct côté API. Vaudrait le coup d'exporter `Erreur`/un indicateur de convergence.
15. **Volume par plant vs par parcelle** (déjà contourné en aval, FYI) : `parametresSource.m` calcule pour un seul plant, pas tout le champ. Contourné dans `run_recommendation.m` sans toucher aux fichiers partagés avec `main.m`.

## Statut du dépôt README

Le README affiche "Validation par données expérimentales : ✅ Implémenté", mais aucune trace de validation/benchmark trouvée dans le code. Le sommaire du README promet aussi des sections ("Validation et benchmarks", "Structure du dépôt", "Équipe", "Licence", "Références") qui n'existent pas — le fichier semble tronqué en plein milieu de la section "Installation". Il annonce aussi MATLAB R2020b+/R2024a, mais `dailyIrrigationRecommendation.m` contient un contournement propre à Octave (`datenum2hour()`) — l'exécution réelle est Octave, pas MATLAB.
