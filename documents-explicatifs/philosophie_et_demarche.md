# Note de Synthèse : Optimisation vs Refonte d'Architecture
### Pourquoi 20M de lignes ne justifient pas une migration ClickHouse

---

## 1. Le Problème et le Biais Initial

* **Constat :** Timeouts de **> 28 secondes** sur les tableaux de bord et alertes mémoire en production.
* **Le Biais Spéculatif :** Confondre le volume total (20 millions de réponses) et le volume utile. La tentation naturelle était : *« PostgreSQL est dépassé, migrons vers ClickHouse avec un pipeline ETL. »*

---

## 2. Le Chiffre Clé : 0,11 % de Sélectivité

$$\text{Taux de Sélectivité} = \frac{22\,000 \text{ lignes utiles}}{19\,600\,000 \text{ lignes totales}} = \mathbf{0,11 \%}$$

* **Quand migrer vers ClickHouse (OLAP) ?** Quand une requête doit balayer **80 % à 100 %** d'une table sans filtre pour calculer une moyenne globale.
* **Le cas présent :** Filtrer 0,11 % de données pour 1 restaurant est la spécialité absolue d'un arbre **B-Tree relationnel**. Si la requête ramait, ce n'était pas la faute de PostgreSQL, mais d'un mauvais guidage (index inadaptés et requêtes redondantes).

---

## 3. Ce que l'Audit a Révélé

Plutôt qu'une refonte lourde, le profilage (`EXPLAIN ANALYZE BUFFERS`) a identifié **2 causes logicielles ciblées** :

1. **Une boucle de 134 262 itérations :** Une sous-requête non dédoublonnée forçait PostgreSQL à scanner un index 134 262 fois consécutives (**9,7s**).
2. **33 249 lectures disques évitables :** L'absence d'index composite forçait le moteur à charger 266 Mo de table brute sur disque (**8,9s**).

---

## 4. Comparatif Décisionnel (ROI)

| Critère | Option Refonte (ClickHouse + ETL) | Option Empirique (2 Index + DISTINCT) |
| :--- | :--- | :--- |
| **Délai projet** | 2 à 3 mois de développement | **Quelques jours** |
| **Complexité infra** | 2 bases, synchronisation asynchrone | **0 nouvelle brique (PostgreSQL pur)** |
| **Consistance** | Décalage (Eventual Consistency) | **Temps réel immédiat (ACID)** |
| **Coût récurrent** | Instances cloud supplémentaires | **0 € de surcoût** |
| **Temps d'exécution** | ~1 à 2 secondes | **1,3 à 2,0 secondes** |

> **Verdict :** L'optimisation chirurgicale résout 100 % du problème avec un ROI infiniment supérieur et zéro dette opérationnelle.
